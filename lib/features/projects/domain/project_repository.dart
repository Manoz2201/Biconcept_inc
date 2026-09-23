import '../../../core/result/app_result.dart';
import 'project.dart';
import 'project_status.dart';

abstract class ProjectRepository {
  Future<AppResult<List<Project>>> getProjects({
    String? clientId,
    ProjectStatus? status,
    String? assignedArchitect,
    String? searchTerm,
  });

  Future<AppResult<Project>> getProjectById(String id);

  Future<AppResult<Project>> createProject({
    required String clientId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? serviceRequestId,
    String? quotationId,
    double? budget,
    String? assignedArchitect,
    List<String>? teamMembers,
    ProjectPriority? priority,
  });

  Future<AppResult<Project>> updateProject(String id, Map<String, dynamic> data);

  Future<AppResult<Project>> updateProjectStatus(String id, ProjectStatus status);

  Future<AppResult<Project>> recalculateProgress(String id);

  Future<AppResult<Project>> convertFromServiceRequest(String serviceRequestId);

  Future<AppResult<Project>> assignArchitect(String id, String architectId);

  Future<AppResult<Project>> addTeamMember(String id, String userId);

  Future<AppResult<Project>> removeTeamMember(String id, String userId);
}
