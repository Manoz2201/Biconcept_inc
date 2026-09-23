import '../../../core/result/app_result.dart';
import 'milestone.dart';

abstract class MilestoneRepository {
  Future<AppResult<List<Milestone>>> getMilestones(String projectId);

  Future<AppResult<Milestone>> createMilestone({
    required String projectId,
    required String title,
    required DateTime dueDate,
    String? description,
    int weight,
    int? sortOrder,
  });

  Future<AppResult<Milestone>> updateMilestone(String id, Map<String, dynamic> data);

  Future<AppResult<Milestone>> updateMilestoneStatus(String id, MilestoneStatus status);

  Future<AppResult<void>> deleteMilestone(String id);
}
