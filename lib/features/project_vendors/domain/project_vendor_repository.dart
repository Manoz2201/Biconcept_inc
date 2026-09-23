import '../../../core/result/app_result.dart';
import 'project_vendor.dart';

abstract class ProjectVendorRepository {
  Future<AppResult<List<ProjectVendor>>> getProjectVendors(String projectId);
  Future<AppResult<List<ProjectVendor>>> getVendorProjects(String vendorId);
  Future<AppResult<ProjectVendor>> assignVendorToProject({
    required String projectId,
    required String vendorId,
    String? role,
    String? notes,
  });
  Future<AppResult<ProjectVendor>> updateProjectVendorStatus(String id, ProjectVendorStatus status);
  Future<AppResult<void>> removeVendorFromProject(String id);
}
