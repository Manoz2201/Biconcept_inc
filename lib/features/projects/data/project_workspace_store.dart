import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../domain/project.dart';
import 'project_workspace.dart';

class ProjectSnapshot {
  const ProjectSnapshot({required this.project, required this.workspace, required this.row});

  final Project project;
  final ProjectWorkspace workspace;
  final models.Row row;
}

class ProjectWorkspaceStore {
  ProjectWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<ProjectSnapshot> getById(String id) async {
    final row = await _tables.getRow(
      databaseId: _databaseId,
      tableId: AppwriteService.projectsCol,
      rowId: id,
    );
    return ProjectSnapshot(
      project: Project.fromRow(row.$id, row.data),
      workspace: ProjectWorkspace.decode(row.data['workspaceJson']?.toString()),
      row: row,
    );
  }

  Future<List<ProjectSnapshot>> list({
    String? clientId,
    String? status,
    String? assignedArchitect,
    String? searchTerm,
    int limit = 50,
  }) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.projectsCol,
      queries: [
        if (clientId != null && clientId.isNotEmpty) Query.equal('clientId', clientId),
        if (status != null && status.isNotEmpty) Query.equal('status', status),
        if (assignedArchitect != null && assignedArchitect.isNotEmpty)
          Query.equal('assignedArchitect', assignedArchitect),
        if (searchTerm != null && searchTerm.trim().isNotEmpty) Query.search('title', searchTerm.trim()),
        Query.orderDesc('createdAt'),
        Query.limit(limit),
      ],
    );
    return [
      for (final row in page.rows)
        ProjectSnapshot(
          project: Project.fromRow(row.$id, row.data),
          workspace: ProjectWorkspace.decode(row.data['workspaceJson']?.toString()),
          row: row,
        ),
    ];
  }

  Future<ProjectSnapshot> saveWorkspace(
    String id,
    ProjectWorkspace workspace, {
    Map<String, dynamic>? projectPatch,
    List<String>? permissions,
  }) async {
    final data = <String, dynamic>{
      'workspaceJson': workspace.encode(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      ...?projectPatch,
    };
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.projectsCol,
      rowId: id,
      data: data,
      permissions: permissions,
    );
    return ProjectSnapshot(
      project: Project.fromRow(row.$id, row.data),
      workspace: ProjectWorkspace.decode(row.data['workspaceJson']?.toString()),
      row: row,
    );
  }

  Future<ProjectSnapshot?> findTaskHost(String taskId) async {
    final all = await list(limit: 100);
    for (final item in all) {
      if (item.workspace.tasks.any((task) => task.id == taskId)) return item;
    }
    return null;
  }

  Future<ProjectSnapshot?> findTimesheetHost(String timesheetId) async {
    final all = await list(limit: 100);
    for (final item in all) {
      if (item.workspace.timesheets.any((row) => row.id == timesheetId)) return item;
    }
    return null;
  }

  Future<ProjectSnapshot?> findChangeRequestHost(String changeRequestId) async {
    final all = await list(limit: 100);
    for (final item in all) {
      if (item.workspace.changeRequests.any((row) => row.id == changeRequestId)) return item;
    }
    return null;
  }

  Future<ProjectSnapshot?> findDocumentHost(String documentId) async {
    final all = await list(limit: 100);
    for (final item in all) {
      if (item.workspace.documents.any((row) => row.id == documentId)) return item;
    }
    return null;
  }

  Future<ProjectSnapshot?> findMilestoneHost(String milestoneId) async {
    final all = await list(limit: 100);
    for (final item in all) {
      if (item.workspace.milestones.any((row) => row.id == milestoneId)) return item;
    }
    return null;
  }
}
