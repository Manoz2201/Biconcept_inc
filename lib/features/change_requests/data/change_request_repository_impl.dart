import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../projects/data/project_workspace_store.dart';
import '../../projects/domain/project_activity.dart';
import '../domain/change_request.dart';
import '../domain/change_request_repository.dart';

class ChangeRequestRepositoryImpl implements ChangeRequestRepository {
  ChangeRequestRepositoryImpl({
    TablesDB? tables,
    AuditRepository? audit,
    ProjectWorkspaceStore? store,
    String? databaseId,
    String Function()? actorId,
    String Function()? actorName,
    String Function()? actorRole,
  })  : _audit = audit ?? AuditRepository(),
        _store = store ?? ProjectWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _actorId = actorId ?? (() => 'unknown'),
        _actorName = actorName ?? (() => 'Staff'),
        _actorRole = actorRole ?? (() => 'architect');

  final AuditRepository _audit;
  final ProjectWorkspaceStore _store;
  final String Function() _actorId;
  final String Function() _actorName;
  final String Function() _actorRole;

  @override
  Future<AppResult<List<ChangeRequest>>> getChangeRequests({
    String? projectId,
    ChangeRequestStatus? status,
  }) {
    return AppwriteService.guard(() async {
      final snapshots = projectId == null ? await _store.list(limit: 100) : [await _store.getById(projectId)];
      final items = [
        for (final snap in snapshots)
          for (final row in snap.workspace.changeRequests)
            if (status == null || row.status == status) row,
      ]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  @override
  Future<AppResult<ChangeRequest>> createChangeRequest({
    required String projectId,
    required String title,
    required String description,
    double? impactCost,
    int? impactDays,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final now = DateTime.now().toUtc();
      final row = ChangeRequest(
        id: ID.unique(),
        projectId: projectId,
        raisedBy: _actorId(),
        raisedByRole: _actorRole(),
        title: title.trim(),
        description: description.trim(),
        impactCost: impactCost,
        impactDays: impactDays,
        status: ChangeRequestStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.changeRequests.add(row);
      await _persist(snap.project.id, snap, action: 'change_request_created', metadata: {'id': row.id});
      await AppNotifications.instance.showImmediate(title: 'Change request', body: row.title);
      return row;
    });
  }

  @override
  Future<AppResult<ChangeRequest>> approveChangeRequest(
    String id, {
    double? impactCost,
    int? impactDays,
  }) {
    return AppwriteService.guard(() async {
      return _update(
        id,
        (current) => ChangeRequest(
          id: current.id,
          projectId: current.projectId,
          raisedBy: current.raisedBy,
          raisedByRole: current.raisedByRole,
          title: current.title,
          description: current.description,
          impactCost: impactCost ?? current.impactCost,
          impactDays: impactDays ?? current.impactDays,
          status: ChangeRequestStatus.approved,
          clientApproval: true,
          clientNotes: current.clientNotes,
          approvedBy: _actorId(),
          approvedAt: DateTime.now().toUtc(),
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
        action: 'change_request_approved',
        from: ChangeRequestStatus.pending,
      );
    });
  }

  @override
  Future<AppResult<ChangeRequest>> rejectChangeRequest(String id, String notes) {
    return AppwriteService.guard(() async {
      return _update(
        id,
        (current) => ChangeRequest(
          id: current.id,
          projectId: current.projectId,
          raisedBy: current.raisedBy,
          raisedByRole: current.raisedByRole,
          title: current.title,
          description: current.description,
          impactCost: current.impactCost,
          impactDays: current.impactDays,
          status: ChangeRequestStatus.rejected,
          clientApproval: current.clientApproval,
          clientNotes: notes,
          approvedBy: current.approvedBy,
          approvedAt: current.approvedAt,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
        action: 'change_request_rejected',
        from: ChangeRequestStatus.pending,
      );
    });
  }

  @override
  Future<AppResult<ChangeRequest>> implementChangeRequest(String id) {
    return AppwriteService.guard(() async {
      return _update(
        id,
        (current) => ChangeRequest(
          id: current.id,
          projectId: current.projectId,
          raisedBy: current.raisedBy,
          raisedByRole: current.raisedByRole,
          title: current.title,
          description: current.description,
          impactCost: current.impactCost,
          impactDays: current.impactDays,
          status: ChangeRequestStatus.implemented,
          clientApproval: current.clientApproval,
          clientNotes: current.clientNotes,
          approvedBy: current.approvedBy,
          approvedAt: current.approvedAt,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
        action: 'change_request_implemented',
        from: ChangeRequestStatus.approved,
      );
    });
  }

  Future<ChangeRequest> _update(
    String id,
    ChangeRequest Function(ChangeRequest current) map, {
    required String action,
    required ChangeRequestStatus from,
  }) async {
    final host = await _store.findChangeRequestHost(id);
    if (host == null) throw AppwriteException('Change request not found', 404);
    final index = host.workspace.changeRequests.indexWhere((item) => item.id == id);
    final current = host.workspace.changeRequests[index];
    if (current.status != from) {
      throw AppwriteException('Cannot $action from ${current.status.value}', 400);
    }
    final next = map(current);
    host.workspace.changeRequests[index] = next;
    await _persist(host.project.id, host, action: action, metadata: {'id': id});
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
