import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../domain/invoice.dart';
import 'invoice_workspace.dart';

class InvoiceSnapshot {
  const InvoiceSnapshot({required this.invoice, required this.workspace, required this.row});

  final Invoice invoice;
  final InvoiceWorkspace workspace;
  final models.Row row;
}

class InvoiceWorkspaceStore {
  InvoiceWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<InvoiceSnapshot> getById(String id) async {
    final row = await _tables.getRow(
      databaseId: _databaseId,
      tableId: AppwriteService.invoicesCol,
      rowId: id,
    );
    return _snap(row);
  }

  Future<List<InvoiceSnapshot>> list({
    String? clientId,
    String? status,
    String? projectId,
    int limit = 100,
  }) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.invoicesCol,
      queries: [
        if (clientId != null && clientId.isNotEmpty) Query.equal('clientId', clientId),
        if (status != null) Query.equal('status', status),
        if (projectId != null && projectId.isNotEmpty) Query.equal('projectId', projectId),
        Query.orderDesc('invoiceDate'),
        Query.limit(limit),
      ],
    );
    return [for (final row in page.rows) _snap(row)];
  }

  Future<InvoiceSnapshot> saveWorkspace(
    String id,
    InvoiceWorkspace workspace, {
    Map<String, dynamic>? invoicePatch,
    List<String>? permissions,
  }) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.invoicesCol,
      rowId: id,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        ...?invoicePatch,
      },
      permissions: permissions,
    );
    return _snap(row);
  }

  Future<InvoiceSnapshot?> findPaymentHost(String paymentId) async {
    final rows = await list();
    for (final row in rows) {
      if (row.workspace.payments.any((item) => item.id == paymentId)) return row;
    }
    return null;
  }

  Future<InvoiceSnapshot?> findCreditHost(String noteId) async {
    final rows = await list();
    for (final row in rows) {
      if (row.workspace.creditNotes.any((item) => item.id == noteId)) return row;
    }
    return null;
  }

  Future<InvoiceSnapshot?> findDebitHost(String noteId) async {
    final rows = await list();
    for (final row in rows) {
      if (row.workspace.debitNotes.any((item) => item.id == noteId)) return row;
    }
    return null;
  }

  InvoiceSnapshot _snap(models.Row row) => InvoiceSnapshot(
        invoice: Invoice.fromRow(row.$id, row.data),
        workspace: InvoiceWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}
