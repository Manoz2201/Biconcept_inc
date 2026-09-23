import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../projects/data/project_workspace_store.dart';
import '../../projects/domain/project_activity.dart';
import '../domain/timesheet.dart';
import '../domain/timesheet_repository.dart';

class TimesheetRepositoryImpl implements TimesheetRepository {
  TimesheetRepositoryImpl({
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
  Future<AppResult<List<Timesheet>>> getTimesheets({
    String? projectId,
    String? userId,
    TimesheetStatus? status,
    DateTime? from,
    DateTime? to,
  }) {
    return AppwriteService.guard(() async {
      final snapshots = projectId == null ? await _store.list(limit: 100) : [await _store.getById(projectId)];
      final items = [
        for (final snap in snapshots)
          for (final row in snap.workspace.timesheets)
            if ((userId == null || row.userId == userId) &&
                (status == null || row.status == status) &&
                (from == null || !row.date.isBefore(from)) &&
                (to == null || !row.date.isAfter(to)))
              row,
      ]..sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  @override
  Future<AppResult<List<Timesheet>>> getMyTimesheets({DateTime? from, DateTime? to}) {
    return getTimesheets(userId: _actorId(), from: from, to: to);
  }

  @override
  Future<AppResult<Timesheet>> createTimesheet({
    required String projectId,
    String? taskId,
    required DateTime date,
    required double hours,
    required String description,
    bool billable = true,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final now = DateTime.now().toUtc();
      final row = Timesheet(
        id: ID.unique(),
        projectId: projectId,
        taskId: taskId,
        userId: _actorId(),
        date: date,
        hours: hours,
        description: description.trim(),
        billable: billable,
        status: TimesheetStatus.draft,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.timesheets.add(row);
      await _persist(snap.project.id, snap, action: 'timesheet_created', metadata: {'id': row.id});
      return row;
    });
  }

  @override
  Future<AppResult<Timesheet>> updateTimesheet(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final host = await _store.findTimesheetHost(id);
      if (host == null) throw AppwriteException('Timesheet not found', 404);
      final index = host.workspace.timesheets.indexWhere((item) => item.id == id);
      final current = host.workspace.timesheets[index];
      if (current.status != TimesheetStatus.draft && current.status != TimesheetStatus.rejected) {
        throw AppwriteException('Only draft or rejected timesheets can be edited', 400);
      }
      final next = Timesheet(
        id: current.id,
        projectId: current.projectId,
        taskId: data['taskId']?.toString() ?? current.taskId,
        userId: current.userId,
        date: DateTime.tryParse(data['date']?.toString() ?? '') ?? current.date,
        hours: (data['hours'] as num?)?.toDouble() ?? current.hours,
        description: data['description']?.toString() ?? current.description,
        billable: data['billable'] as bool? ?? current.billable,
        approvedBy: current.approvedBy,
        approvedAt: current.approvedAt,
        status: current.status,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.timesheets[index] = next;
      await _persist(host.project.id, host, action: 'timesheet_updated', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Timesheet>> submitTimesheet(String id) {
    return AppwriteService.guard(() async {
      final next = await _setStatus(id, TimesheetStatus.submitted, action: 'timesheet_submitted');
      await AppNotifications.instance.showImmediate(title: 'Timesheet submitted', body: next.description);
      return next;
    });
  }

  @override
  Future<AppResult<Timesheet>> approveTimesheet(String id, String approverId) {
    return AppwriteService.guard(() async {
      final host = await _store.findTimesheetHost(id);
      if (host == null) throw AppwriteException('Timesheet not found', 404);
      final index = host.workspace.timesheets.indexWhere((item) => item.id == id);
      final current = host.workspace.timesheets[index];
      if (current.status != TimesheetStatus.submitted) {
        throw AppwriteException('Only submitted timesheets can be approved', 400);
      }
      final next = Timesheet(
        id: current.id,
        projectId: current.projectId,
        taskId: current.taskId,
        userId: current.userId,
        date: current.date,
        hours: current.hours,
        description: current.description,
        billable: current.billable,
        approvedBy: approverId,
        approvedAt: DateTime.now().toUtc(),
        status: TimesheetStatus.approved,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.timesheets[index] = next;
      await _persist(host.project.id, host, action: 'timesheet_approved', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'Timesheet approved', body: next.description);
      return next;
    });
  }

  @override
  Future<AppResult<Timesheet>> rejectTimesheet(String id, String reason) {
    return AppwriteService.guard(() async {
      final next = await _setStatus(
        id,
        TimesheetStatus.rejected,
        action: 'timesheet_rejected',
        extra: {'reason': reason},
      );
      await AppNotifications.instance.showImmediate(title: 'Timesheet rejected', body: reason);
      return next;
    });
  }

  @override
  Future<AppResult<WeeklyTimesheetSummary>> getWeeklySummary(String userId, DateTime weekStart) {
    return AppwriteService.guard(() async {
      final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final end = start.add(const Duration(days: 6));
      final rows = await getTimesheets(userId: userId, from: start, to: end);
      return rows.when(
        success: (items) {
          final hoursByDay = <DateTime, double>{};
          var total = 0.0;
          for (final item in items) {
            final day = DateTime(item.date.year, item.date.month, item.date.day);
            hoursByDay[day] = (hoursByDay[day] ?? 0) + item.hours;
            total += item.hours;
          }
          return WeeklyTimesheetSummary(hoursByDay: hoursByDay, totalHours: total);
        },
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  Future<Timesheet> _setStatus(
    String id,
    TimesheetStatus status, {
    required String action,
    Map<String, dynamic>? extra,
  }) async {
    final host = await _store.findTimesheetHost(id);
    if (host == null) throw AppwriteException('Timesheet not found', 404);
    final index = host.workspace.timesheets.indexWhere((item) => item.id == id);
    final current = host.workspace.timesheets[index];
    final next = Timesheet(
      id: current.id,
      projectId: current.projectId,
      taskId: current.taskId,
      userId: current.userId,
      date: current.date,
      hours: current.hours,
      description: current.description,
      billable: current.billable,
      approvedBy: current.approvedBy,
      approvedAt: current.approvedAt,
      status: status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    host.workspace.timesheets[index] = next;
    await _persist(host.project.id, host, action: action, metadata: {'id': id, ...?extra});
    return next;
  }

  Future<void> _persist(
    String projectId,
    ProjectSnapshot host, {
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    host.workspace.activities.insert(
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
    await _store.saveWorkspace(projectId, host.workspace);
    await _audit.log(userId: _actorId(), action: action, metadata: {'projectId': projectId, ...?metadata});
  }
}
