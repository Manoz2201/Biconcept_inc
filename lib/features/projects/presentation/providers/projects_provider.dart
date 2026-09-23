import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rbac/domain/user_role.dart';
import '../../data/milestone_repository_impl.dart';
import '../../data/project_activity_repository_impl.dart';
import '../../data/project_repository_impl.dart';
import '../../data/project_workspace_store.dart';
import '../../data/task_repository_impl.dart';
import '../../domain/activity_repository.dart';
import '../../domain/milestone.dart';
import '../../domain/milestone_repository.dart';
import '../../domain/project.dart';
import '../../domain/project_activity.dart';
import '../../domain/project_repository.dart';
import '../../domain/project_status.dart';
import '../../domain/task.dart';
import '../../domain/task_repository.dart';

ProjectWorkspaceStore _store(Ref ref) => ProjectWorkspaceStore();

String Function() _actorId(Ref ref) => () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';

String Function() _actorName(Ref ref) => () => ref.read(sessionControllerProvider).user?.name ?? 'Staff';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(
    store: _store(ref),
    actorId: _actorId(ref),
    actorName: _actorName(ref),
  );
});

final milestoneRepositoryProvider = Provider<MilestoneRepository>((ref) {
  return MilestoneRepositoryImpl(
    store: _store(ref),
    actorId: _actorId(ref),
    actorName: _actorName(ref),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(
    store: _store(ref),
    actorId: _actorId(ref),
    actorName: _actorName(ref),
  );
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ProjectActivityRepositoryImpl(
    store: _store(ref),
    actorId: _actorId(ref),
    actorName: _actorName(ref),
  );
});

class ProjectQuery {
  const ProjectQuery({this.clientId, this.status, this.assignedArchitect, this.search = ''});

  final String? clientId;
  final ProjectStatus? status;
  final String? assignedArchitect;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is ProjectQuery &&
      other.clientId == clientId &&
      other.status == status &&
      other.assignedArchitect == assignedArchitect &&
      other.search == search;

  @override
  int get hashCode => Object.hash(clientId, status, assignedArchitect, search);
}

final projectsProvider = FutureProvider.family<List<Project>, ProjectQuery>((ref, query) async {
  final session = ref.watch(sessionControllerProvider);
  final scopedClientId = session.user?.role == UserRole.client ? session.user?.accountId : query.clientId;
  final result = await ref.watch(projectRepositoryProvider).getProjects(
        clientId: scopedClientId,
        status: query.status,
        assignedArchitect: query.assignedArchitect,
        searchTerm: query.search.trim().isEmpty ? null : query.search.trim(),
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final projectByIdProvider = FutureProvider.family<Project, String>((ref, id) async {
  final result = await ref.watch(projectRepositoryProvider).getProjectById(id);
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final milestonesProvider = FutureProvider.family<List<Milestone>, String>((ref, projectId) async {
  final result = await ref.watch(milestoneRepositoryProvider).getMilestones(projectId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

class TaskQuery {
  const TaskQuery({required this.projectId, this.milestoneId, this.assigneeId, this.status});

  final String projectId;
  final String? milestoneId;
  final String? assigneeId;
  final TaskStatus? status;

  @override
  bool operator ==(Object other) =>
      other is TaskQuery &&
      other.projectId == projectId &&
      other.milestoneId == milestoneId &&
      other.assigneeId == assigneeId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(projectId, milestoneId, assigneeId, status);
}

final tasksProvider = FutureProvider.family<List<Task>, TaskQuery>((ref, query) async {
  final result = await ref.watch(taskRepositoryProvider).getTasks(
        projectId: query.projectId,
        milestoneId: query.milestoneId,
        assigneeId: query.assigneeId,
        status: query.status,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final subtasksProvider = FutureProvider.family<List<Task>, String>((ref, parentTaskId) async {
  final result = await ref.watch(taskRepositoryProvider).getSubtasks(parentTaskId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final projectActivitiesProvider = FutureProvider.family<List<ProjectActivity>, String>((ref, projectId) async {
  final result = await ref.watch(activityRepositoryProvider).getProjectActivities(projectId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});
