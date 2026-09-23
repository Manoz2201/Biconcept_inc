import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../domain/project_activity.dart';
import '../domain/task.dart';
import '../domain/task_repository.dart';
import 'project_workspace.dart';
import 'project_workspace_store.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    TablesDB? tables,
    AuditRepository? audit,
    ProjectWorkspaceStore? store,
    String? databaseId,
    String Function()? actorId,
    String Function()? actorName,
  })  : _audit = audit ?? AuditRepository(),
        _store = store ?? ProjectWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _actorId = actorId ?? (() => 'unknown'),
        _actorName = actorName ?? (() => 'Staff');

  final AuditRepository _audit;
  final ProjectWorkspaceStore _store;
  final String Function() _actorId;
  final String Function() _actorName;

  @override
  Future<AppResult<List<Task>>> getTasks({
    required String projectId,
    String? milestoneId,
    String? assigneeId,
    TaskStatus? status,
    DateTime? dueBefore,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      return [
        for (final task in snap.workspace.tasks)
          if ((milestoneId == null || task.milestoneId == milestoneId) &&
              (assigneeId == null || task.assigneeId == assigneeId) &&
              (status == null || task.status == status) &&
              (dueBefore == null || (task.dueDate != null && !task.dueDate!.isAfter(dueBefore))))
            task,
      ]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    });
  }

  @override
  Future<AppResult<List<Task>>> getSubtasks(String parentTaskId) {
    return AppwriteService.guard(() async {
      final host = await _store.findTaskHost(parentTaskId);
      if (host == null) return const [];
      return [for (final task in host.workspace.tasks) if (task.parentTaskId == parentTaskId) task];
    });
  }

  @override
  Future<AppResult<Task>> createTask({
    required String projectId,
    required String title,
    required String reporterId,
    String? description,
    String? milestoneId,
    String? parentTaskId,
    TaskStatus? status,
    TaskPriority? priority,
    String? assigneeId,
    DateTime? dueDate,
    double? estimatedHours,
    List<String>? tags,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final now = DateTime.now().toUtc();
      final task = Task(
        id: ID.unique(),
        projectId: projectId,
        milestoneId: milestoneId,
        parentTaskId: parentTaskId,
        title: title.trim(),
        description: description,
        status: status ?? TaskStatus.todo,
        priority: priority,
        assigneeId: assigneeId,
        reporterId: reporterId,
        dueDate: dueDate,
        estimatedHours: estimatedHours,
        tags: tags ?? const [],
        sortOrder: snap.workspace.tasks.length,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.tasks.add(task);
      await _persist(
        snap.project.id,
        snap.workspace,
        action: 'task_created',
        metadata: {'id': task.id},
        permissions: projectRowPermissions(snap.project.clientId, assigneeId: assigneeId),
      );
      if (assigneeId != null && assigneeId.isNotEmpty) {
        await AppNotifications.instance.showImmediate(
          title: 'Task assigned',
          body: task.title,
        );
      }
      return task;
    });
  }

  @override
  Future<AppResult<Task>> updateTask(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final host = await _requireTask(id);
      final index = host.workspace.tasks.indexWhere((item) => item.id == id);
      final current = host.workspace.tasks[index];
      final next = Task(
        id: current.id,
        projectId: current.projectId,
        milestoneId: data['milestoneId']?.toString() ?? current.milestoneId,
        parentTaskId: current.parentTaskId,
        title: data['title']?.toString() ?? current.title,
        description: data['description']?.toString() ?? current.description,
        status: current.status,
        priority: TaskPriority.tryParse(data['priority']?.toString()) ?? current.priority,
        assigneeId: data['assigneeId']?.toString() ?? current.assigneeId,
        reporterId: current.reporterId,
        dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? current.dueDate,
        completedAt: current.completedAt,
        estimatedHours: (data['estimatedHours'] as num?)?.toDouble() ?? current.estimatedHours,
        actualHours: (data['actualHours'] as num?)?.toDouble() ?? current.actualHours,
        tags: current.tags,
        attachments: current.attachments,
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.tasks[index] = next;
      await _persist(host.project.id, host.workspace, action: 'task_updated', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Task>> updateTaskStatus(String id, TaskStatus status) {
    return AppwriteService.guard(() async {
      final host = await _requireTask(id);
      final index = host.workspace.tasks.indexWhere((item) => item.id == id);
      final current = host.workspace.tasks[index];
      if (!current.status.canTransitionTo(status)) {
        throw AppwriteException('Cannot change task from ${current.status.value} to ${status.value}', 400);
      }
      final next = Task(
        id: current.id,
        projectId: current.projectId,
        milestoneId: current.milestoneId,
        parentTaskId: current.parentTaskId,
        title: current.title,
        description: current.description,
        status: status,
        priority: current.priority,
        assigneeId: current.assigneeId,
        reporterId: current.reporterId,
        dueDate: current.dueDate,
        completedAt: status == TaskStatus.done ? DateTime.now().toUtc() : current.completedAt,
        estimatedHours: current.estimatedHours,
        actualHours: current.actualHours,
        tags: current.tags,
        attachments: current.attachments,
        sortOrder: current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.tasks[index] = next;
      await _persist(
        host.project.id,
        host.workspace,
        action: 'task_status_changed',
        metadata: {'id': id, 'status': status.value},
      );
      return next;
    });
  }

  @override
  Future<AppResult<Task>> assignTask(String id, String assigneeId) {
    return AppwriteService.guard(() async {
      final host = await _requireTask(id);
      final index = host.workspace.tasks.indexWhere((item) => item.id == id);
      final current = host.workspace.tasks[index];
      final next = Task(
        id: current.id,
        projectId: current.projectId,
        milestoneId: current.milestoneId,
        parentTaskId: current.parentTaskId,
        title: current.title,
        description: current.description,
        status: current.status,
        priority: current.priority,
        assigneeId: assigneeId,
        reporterId: current.reporterId,
        dueDate: current.dueDate,
        completedAt: current.completedAt,
        estimatedHours: current.estimatedHours,
        actualHours: current.actualHours,
        tags: current.tags,
        attachments: current.attachments,
        sortOrder: current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.tasks[index] = next;
      await _persist(
        host.project.id,
        host.workspace,
        action: 'task_assigned',
        metadata: {'id': id, 'assigneeId': assigneeId},
        permissions: projectRowPermissions(host.project.clientId, assigneeId: assigneeId),
      );
      await AppNotifications.instance.showImmediate(title: 'Task assigned', body: next.title);
      return next;
    });
  }

  @override
  Future<AppResult<void>> reorderTasks(List<String> taskIds) {
    return AppwriteService.guard(() async {
      if (taskIds.isEmpty) return;
      final host = await _requireTask(taskIds.first);
      for (var i = 0; i < taskIds.length; i++) {
        final index = host.workspace.tasks.indexWhere((item) => item.id == taskIds[i]);
        if (index < 0) continue;
        final current = host.workspace.tasks[index];
        host.workspace.tasks[index] = Task(
          id: current.id,
          projectId: current.projectId,
          milestoneId: current.milestoneId,
          parentTaskId: current.parentTaskId,
          title: current.title,
          description: current.description,
          status: current.status,
          priority: current.priority,
          assigneeId: current.assigneeId,
          reporterId: current.reporterId,
          dueDate: current.dueDate,
          completedAt: current.completedAt,
          estimatedHours: current.estimatedHours,
          actualHours: current.actualHours,
          tags: current.tags,
          attachments: current.attachments,
          sortOrder: i,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      await _store.saveWorkspace(host.project.id, host.workspace);
    });
  }

  @override
  Future<AppResult<void>> deleteTask(String id) {
    return AppwriteService.guard(() async {
      final host = await _store.findTaskHost(id);
      if (host == null) return;
      host.workspace.tasks.removeWhere((item) => item.id == id || item.parentTaskId == id);
      await _persist(host.project.id, host.workspace, action: 'task_deleted', metadata: {'id': id});
    });
  }

  Future<ProjectSnapshot> _requireTask(String id) async {
    final host = await _store.findTaskHost(id);
    if (host == null) throw AppwriteException('Task not found', 404);
    return host;
  }

  Future<void> _persist(
    String projectId,
    ProjectWorkspace workspace, {
    required String action,
    Map<String, dynamic>? metadata,
    List<String>? permissions,
  }) async {
    workspace.activities.insert(
      0,
      ProjectActivity(
        id: ID.unique(),
        projectId: projectId,
        actorId: _actorId(),
        actorName: _actorName(),
        action: action,
        metadata: metadata?.toString(),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await _store.saveWorkspace(projectId, workspace, permissions: permissions);
    await _audit.log(userId: _actorId(), action: action, metadata: {'projectId': projectId, ...?metadata});
  }
}
