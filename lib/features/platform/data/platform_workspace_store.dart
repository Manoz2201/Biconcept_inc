import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import 'platform_workspace.dart';

class PlatformSnapshot {
  const PlatformSnapshot({required this.workspace, required this.row});

  final PlatformWorkspace workspace;
  final models.Row row;
}

class PlatformWorkspaceStore {
  PlatformWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<PlatformSnapshot> ensure() async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.platformCol,
        rowId: Env.platformRowId,
      );
      return _snap(row);
    } on AppwriteException catch (error) {
      if (error.code != 404) rethrow;
      final now = DateTime.now().toUtc();
      final workspace = PlatformWorkspace.seeded(now);
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.platformCol,
        rowId: Env.platformRowId,
        data: {
          'workspaceJson': workspace.encode(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        permissions: platformRowPermissions(),
      );
      return _snap(row);
    }
  }

  Future<PlatformSnapshot> save(PlatformWorkspace workspace) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.platformCol,
      rowId: Env.platformRowId,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      permissions: platformRowPermissions(),
    );
    return _snap(row);
  }

  PlatformSnapshot _snap(models.Row row) => PlatformSnapshot(
        workspace: PlatformWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}
