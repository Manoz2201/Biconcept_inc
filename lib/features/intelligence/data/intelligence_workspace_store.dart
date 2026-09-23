import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import 'intelligence_workspace.dart';

class IntelligenceSnapshot {
  const IntelligenceSnapshot({required this.workspace, required this.row});

  final IntelligenceWorkspace workspace;
  final models.Row row;
}

class IntelligenceWorkspaceStore {
  IntelligenceWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<IntelligenceSnapshot> ensure() async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.intelligenceCol,
        rowId: Env.intelligenceRowId,
      );
      return _snap(row);
    } on AppwriteException catch (error) {
      if (error.code != 404) rethrow;
      final now = DateTime.now().toUtc();
      final workspace = IntelligenceWorkspace();
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.intelligenceCol,
        rowId: Env.intelligenceRowId,
        data: {
          'workspaceJson': workspace.encode(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        permissions: intelligenceRowPermissions(),
      );
      return _snap(row);
    }
  }

  Future<IntelligenceSnapshot> save(IntelligenceWorkspace workspace) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.intelligenceCol,
      rowId: Env.intelligenceRowId,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      permissions: intelligenceRowPermissions(),
    );
    return _snap(row);
  }

  IntelligenceSnapshot _snap(models.Row row) => IntelligenceSnapshot(
        workspace: IntelligenceWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}
