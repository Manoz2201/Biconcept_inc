import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../rfqs/domain/rfq.dart';
import '../domain/vendor.dart';
import 'vendor_workspace.dart';

class VendorSnapshot {
  const VendorSnapshot({required this.vendor, required this.workspace, required this.row});

  final Vendor vendor;
  final VendorWorkspace workspace;
  final models.Row row;
}

class RfqSnapshot {
  const RfqSnapshot({required this.rfq, required this.workspace, required this.row});

  final RFQ rfq;
  final RfqWorkspace workspace;
  final models.Row row;
}

class VendorWorkspaceStore {
  VendorWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<VendorSnapshot> getById(String id) async {
    final row = await _tables.getRow(
      databaseId: _databaseId,
      tableId: AppwriteService.vendorsCol,
      rowId: id,
    );
    return _vendorSnap(row);
  }

  Future<List<VendorSnapshot>> list({
    String? searchTerm,
    bool? isActive,
    bool? isVerified,
    String? userId,
    int limit = 100,
  }) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.vendorsCol,
      queries: [
        if (searchTerm != null && searchTerm.trim().isNotEmpty) Query.search('companyName', searchTerm.trim()),
        if (isActive != null) Query.equal('isActive', isActive),
        if (isVerified != null) Query.equal('isVerified', isVerified),
        if (userId != null && userId.isNotEmpty) Query.equal('userId', userId),
        Query.orderDesc('createdAt'),
        Query.limit(limit),
      ],
    );
    return [for (final row in page.rows) _vendorSnap(row)];
  }

  Future<VendorSnapshot> saveWorkspace(
    String id,
    VendorWorkspace workspace, {
    Map<String, dynamic>? vendorPatch,
    List<String>? permissions,
  }) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.vendorsCol,
      rowId: id,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        ...?vendorPatch,
      },
      permissions: permissions,
    );
    return _vendorSnap(row);
  }

  Future<VendorSnapshot?> findQuoteHost(String quoteId) async {
    final all = await list();
    for (final item in all) {
      if (item.workspace.quotes.any((row) => row.id == quoteId)) return item;
    }
    return null;
  }

  Future<VendorSnapshot?> findPoHost(String poId) async {
    final all = await list();
    for (final item in all) {
      if (item.workspace.purchaseOrders.any((row) => row.id == poId)) return item;
    }
    return null;
  }

  Future<VendorSnapshot?> findBillHost(String billId) async {
    final all = await list();
    for (final item in all) {
      if (item.workspace.bills.any((row) => row.id == billId)) return item;
    }
    return null;
  }

  Future<VendorSnapshot?> findPaymentHost(String paymentId) async {
    final all = await list();
    for (final item in all) {
      if (item.workspace.payments.any((row) => row.id == paymentId)) return item;
    }
    return null;
  }

  Future<VendorSnapshot?> findRateHost(String rateId) async {
    final all = await list();
    for (final item in all) {
      if (item.workspace.rates.any((row) => row.id == rateId)) return item;
    }
    return null;
  }

  Future<VendorSnapshot?> findAssignmentHost(String assignmentId) async {
    final all = await list();
    for (final item in all) {
      if (item.workspace.assignments.any((row) => row.id == assignmentId)) return item;
    }
    return null;
  }

  VendorSnapshot _vendorSnap(models.Row row) => VendorSnapshot(
        vendor: Vendor.fromRow(row.$id, row.data),
        workspace: VendorWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}

class RfqWorkspaceStore {
  RfqWorkspaceStore({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<RfqSnapshot> getById(String id) async {
    final row = await _tables.getRow(
      databaseId: _databaseId,
      tableId: AppwriteService.rfqsCol,
      rowId: id,
    );
    return _snap(row);
  }

  Future<List<RfqSnapshot>> list({
    String? projectId,
    String? status,
    String? category,
    String? createdBy,
    int limit = 50,
  }) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.rfqsCol,
      queries: [
        if (projectId != null && projectId.isNotEmpty) Query.equal('projectId', projectId),
        if (status != null && status.isNotEmpty) Query.equal('status', status),
        if (category != null && category.isNotEmpty) Query.equal('category', category),
        if (createdBy != null && createdBy.isNotEmpty) Query.equal('createdBy', createdBy),
        Query.orderDesc('createdAt'),
        Query.limit(limit),
      ],
    );
    return [for (final row in page.rows) _snap(row)];
  }

  Future<RfqSnapshot> saveWorkspace(
    String id,
    RfqWorkspace workspace, {
    Map<String, dynamic>? rfqPatch,
    List<String>? permissions,
  }) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.rfqsCol,
      rowId: id,
      data: {
        'workspaceJson': workspace.encode(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        ...?rfqPatch,
      },
      permissions: permissions,
    );
    return _snap(row);
  }

  RfqSnapshot _snap(models.Row row) => RfqSnapshot(
        rfq: RFQ.fromRow(row.$id, row.data),
        workspace: RfqWorkspace.decode(row.data['workspaceJson']?.toString()),
        row: row,
      );
}
