import '../../../core/result/app_result.dart';
import 'project_activity.dart';

abstract class ActivityRepository {
  Future<AppResult<List<ProjectActivity>>> getProjectActivities(String projectId, {int limit = 50});

  Future<AppResult<ProjectActivity>> logActivity({
    required String projectId,
    required String action,
    Map<String, dynamic>? metadata,
  });
}
