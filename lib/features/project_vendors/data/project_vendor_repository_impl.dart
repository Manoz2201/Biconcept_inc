import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../vendors/data/vendor_workspace_store.dart';
import '../domain/project_vendor.dart';
import '../domain/project_vendor_repository.dart';

class ProjectVendorRepositoryImpl implements ProjectVendorRepository {
  ProjectVendorRepositoryImpl({
    AuditRepository? audit,
    VendorWorkspaceStore? store,
    String Function()? actorId,
  })  : _audit = audit ?? AuditRepository(),
        _store = store ?? VendorWorkspaceStore(),
        _actorId = actorId ?? (() => 'unknown');

  final AuditRepository _audit;
  final VendorWorkspaceStore _store;
  final String Function() _actorId;

  @override
  Future<AppResult<List<ProjectVendor>>> getProjectVendors(String projectId) {
    return AppwriteService.guard(() async {
      final snaps = await _store.list();
      return [
        for (final snap in snaps)
          for (final item in snap.workspace.assignments)
            if (item.projectId == projectId) item,
      ];
    });
  }

  @override
  Future<AppResult<List<ProjectVendor>>> getVendorProjects(String vendorId) {
    return AppwriteService.guard(() async => (await _store.getById(vendorId)).workspace.assignments);
  }

  @override
  Future<AppResult<ProjectVendor>> assignVendorToProject({
    required String projectId,
    required String vendorId,
    String? role,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(vendorId);
      if (snap.workspace.assignments.any((item) => item.projectId == projectId && item.status == ProjectVendorStatus.active)) {
        throw AppwriteException('Vendor is already assigned to this project', 400);
      }
      final row = ProjectVendor(
        id: ID.unique(),
        projectId: projectId,
        vendorId: vendorId,
        role: role?.trim(),
        assignedAt: DateTime.now().toUtc(),
        assignedBy: _actorId(),
        status: ProjectVendorStatus.active,
        notes: notes?.trim(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.assignments.add(row);
      await _store.saveWorkspace(vendorId, snap.workspace);
      await _audit.log(
        userId: _actorId(),
        action: 'vendor_assigned_to_project',
        metadata: {'id': row.id, 'projectId': projectId, 'vendorId': vendorId},
      );
      return row;
    });
  }

  @override
  Future<AppResult<ProjectVendor>> updateProjectVendorStatus(String id, ProjectVendorStatus status) {
    return AppwriteService.guard(() async {
      final host = await _store.findAssignmentHost(id);
      if (host == null) throw AppwriteException('Assignment not found', 404);
      final index = host.workspace.assignments.indexWhere((item) => item.id == id);
      final current = host.workspace.assignments[index];
      final next = ProjectVendor(
        id: current.id,
        projectId: current.projectId,
        vendorId: current.vendorId,
        role: current.role,
        assignedAt: current.assignedAt,
        assignedBy: current.assignedBy,
        status: status,
        notes: current.notes,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.assignments[index] = next;
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      return next;
    });
  }

  @override
  Future<AppResult<void>> removeVendorFromProject(String id) {
    return AppwriteService.guard(() async {
      final host = await _store.findAssignmentHost(id);
      if (host == null) throw AppwriteException('Assignment not found', 404);
      host.workspace.assignments.removeWhere((item) => item.id == id);
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_removed_from_project', metadata: {'id': id});
    });
  }
}
