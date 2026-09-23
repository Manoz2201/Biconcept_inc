import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../domain/milestone.dart';
import '../domain/milestone_repository.dart';
import '../domain/project.dart';
import '../domain/project_activity.dart';
import 'project_workspace.dart';
import 'project_workspace_store.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  MilestoneRepositoryImpl({
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
  Future<AppResult<List<Milestone>>> getMilestones(String projectId) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final items = [...snap.workspace.milestones]
        ..sort((a, b) {
          final order = (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);
          if (order != 0) return order;
          return a.dueDate.compareTo(b.dueDate);
        });
      return items;
    });
  }

  @override
  Future<AppResult<Milestone>> createMilestone({
    required String projectId,
    required String title,
    required DateTime dueDate,
    String? description,
    int weight = 1,
    int? sortOrder,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final now = DateTime.now().toUtc();
      final milestone = Milestone(
        id: ID.unique(),
        projectId: projectId,
        title: title.trim(),
        description: description,
        dueDate: dueDate,
        status: MilestoneStatus.pending,
        weight: weight < 1 ? 1 : weight,
        sortOrder: sortOrder ?? snap.workspace.milestones.length,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.milestones.add(milestone);
      await _persist(snap.project.id, snap.workspace, action: 'milestone_created', metadata: {'id': milestone.id});
      return milestone;
    });
  }

  @override
  Future<AppResult<Milestone>> updateMilestone(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final host = await _store.findMilestoneHost(id);
      if (host == null) throw AppwriteException('Milestone not found', 404);
      final index = host.workspace.milestones.indexWhere((item) => item.id == id);
      final current = host.workspace.milestones[index];
      final next = Milestone(
        id: current.id,
        projectId: current.projectId,
        title: data['title']?.toString() ?? current.title,
        description: data['description']?.toString() ?? current.description,
        dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? current.dueDate,
        completedAt: current.completedAt,
        status: current.status,
        weight: (data['weight'] as num?)?.toInt() ?? current.weight,
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.milestones[index] = next;
      await _persist(host.project.id, host.workspace, action: 'milestone_updated', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Milestone>> updateMilestoneStatus(String id, MilestoneStatus status) {
    return AppwriteService.guard(() async {
      final host = await _store.findMilestoneHost(id);
      if (host == null) throw AppwriteException('Milestone not found', 404);
      final index = host.workspace.milestones.indexWhere((item) => item.id == id);
      final current = host.workspace.milestones[index];
      final next = Milestone(
        id: current.id,
        projectId: current.projectId,
        title: current.title,
        description: current.description,
        dueDate: current.dueDate,
        completedAt: status == MilestoneStatus.completed ? DateTime.now().toUtc() : current.completedAt,
        status: status,
        weight: current.weight,
        sortOrder: current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.milestones[index] = next;
      await _persist(host.project.id, host.workspace, action: 'milestone_status_changed', metadata: {
        'id': id,
        'status': status.value,
      });
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteMilestone(String id) {
    return AppwriteService.guard(() async {
      final host = await _store.findMilestoneHost(id);
      if (host == null) return;
      host.workspace.milestones.removeWhere((item) => item.id == id);
      await _persist(host.project.id, host.workspace, action: 'milestone_deleted', metadata: {'id': id});
    });
  }

  Future<void> _persist(
    String projectId,
    ProjectWorkspace workspace, {
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    final progress = progressFromMilestones([
      for (final item in workspace.milestones) (completed: item.isComplete, weight: item.weight),
    ]);
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
    await _store.saveWorkspace(projectId, workspace, projectPatch: {'progress': progress});
    await _audit.log(userId: _actorId(), action: action, metadata: {'projectId': projectId, ...?metadata});
  }
}
