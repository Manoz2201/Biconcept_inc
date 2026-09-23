import '../../../core/result/app_result.dart';
import 'task.dart';

abstract class TaskRepository {
  Future<AppResult<List<Task>>> getTasks({
    required String projectId,
    String? milestoneId,
    String? assigneeId,
    TaskStatus? status,
    DateTime? dueBefore,
  });

  Future<AppResult<List<Task>>> getSubtasks(String parentTaskId);

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
  });

  Future<AppResult<Task>> updateTask(String id, Map<String, dynamic> data);

  Future<AppResult<Task>> updateTaskStatus(String id, TaskStatus status);

  Future<AppResult<Task>> assignTask(String id, String assigneeId);

  Future<AppResult<void>> reorderTasks(List<String> taskIds);

  Future<AppResult<void>> deleteTask(String id);
}
