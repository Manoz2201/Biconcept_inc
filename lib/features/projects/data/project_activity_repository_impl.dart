import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../domain/activity_repository.dart';
import '../domain/project_activity.dart';
import 'project_workspace_store.dart';

class ProjectActivityRepositoryImpl implements ActivityRepository {
  ProjectActivityRepositoryImpl({
    TablesDB? tables,
    ProjectWorkspaceStore? store,
    String? databaseId,
    String Function()? actorId,
    String Function()? actorName,
  })  : _store = store ?? ProjectWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _actorId = actorId ?? (() => 'unknown'),
        _actorName = actorName ?? (() => 'Staff');

  final ProjectWorkspaceStore _store;
  final String Function() _actorId;
  final String Function() _actorName;

  @override
  Future<AppResult<List<ProjectActivity>>> getProjectActivities(String projectId, {int limit = 50}) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final items = [...snap.workspace.activities]
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items.take(limit).toList();
    });
  }

  @override
  Future<AppResult<ProjectActivity>> logActivity({
    required String projectId,
    required String action,
    Map<String, dynamic>? metadata,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final activity = ProjectActivity(
        id: ID.unique(),
        projectId: projectId,
        actorId: _actorId(),
        actorName: _actorName(),
        action: action,
        metadata: metadata == null ? null : jsonEncode(metadata),
        createdAt: DateTime.now().toUtc(),
      );
      snap.workspace.activities.insert(0, activity);
      await _store.saveWorkspace(projectId, snap.workspace);
      return activity;
    });
  }
}
