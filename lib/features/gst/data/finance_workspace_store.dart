import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../domain/gst_settings.dart';
import 'finance_workspace.dart';

class FinanceSnapshot {
  const FinanceSnapshot({required this.settings, required this.workspace, required this.row});

  final GSTSettings settings;
  final FinanceWorkspace workspace;
  final models.Row row;
}

class FinanceWorkspaceStore {
  FinanceWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<FinanceSnapshot> ensure() async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.financeCol,
        rowId: Env.financeRowId,
      );
      return _snap(row);
    } on AppwriteException catch (error) {
      if (error.code != 404) rethrow;
      final now = DateTime.now().toUtc().toIso8601String();
      final workspace = FinanceWorkspace(taxRates: FinanceWorkspace.defaultRates());
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.financeCol,
        rowId: Env.financeRowId,
        data: {
          'firmName': 'BiConcept',
          'firmAddress': 'Chennai',
          'firmCity': 'Chennai',
          'firmState': 'Tamil Nadu',
          'firmStateCode': '33',
          'firmPincode': '600001',
          'defaultTaxRate': 18,
          'financialYearStart': 4,
          'financialYearEnd': 3,
          'invoicePrefix': 'INV',
          'creditNotePrefix': 'CN',
          'debitNotePrefix': 'DN',
          'workspaceJson': workspace.encode(),
          'createdAt': now,
          'updatedAt': now,
        },
        permissions: financeRowPermissions(),
      );
      return _snap(row);
    }
  }

  Future<FinanceSnapshot> save(
    FinanceWorkspace workspace, {
    Map<String, dynamic>? settingsPatch,
  }) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.financeCol,
      rowId: Env.financeRowId,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        ...?settingsPatch,
      },
      permissions: financeRowPermissions(),
    );
    return _snap(row);
  }

  FinanceSnapshot _snap(models.Row row) => FinanceSnapshot(
        settings: GSTSettings.fromRow(row.$id, row.data),
        workspace: FinanceWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}
