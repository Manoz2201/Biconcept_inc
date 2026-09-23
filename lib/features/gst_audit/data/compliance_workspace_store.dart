import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../gst/domain/gst_math.dart';
import 'compliance_workspace.dart';

class ComplianceSnapshot {
  const ComplianceSnapshot({required this.workspace, required this.row});

  final ComplianceWorkspace workspace;
  final models.Row row;
}

class ComplianceWorkspaceStore {
  ComplianceWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<ComplianceSnapshot> ensure() async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.complianceCol,
        rowId: Env.complianceRowId,
      );
      return _snap(row);
    } on AppwriteException catch (error) {
      if (error.code != 404) rethrow;
      final now = DateTime.now().toUtc();
      final workspace = ComplianceWorkspace();
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.complianceCol,
        rowId: Env.complianceRowId,
        data: {
          'financialYear': financialYearLabel(now),
          'workspaceJson': workspace.encode(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        permissions: complianceRowPermissions(),
      );
      return _snap(row);
    }
  }

  Future<ComplianceSnapshot> save(ComplianceWorkspace workspace) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.complianceCol,
      rowId: Env.complianceRowId,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      permissions: complianceRowPermissions(),
    );
    return _snap(row);
  }

  ComplianceSnapshot _snap(models.Row row) => ComplianceSnapshot(
        workspace: ComplianceWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}
