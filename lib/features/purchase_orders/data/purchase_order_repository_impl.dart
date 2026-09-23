import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../rfqs/domain/vendor_quote.dart';
import '../../vendors/data/vendor_workspace_store.dart';
import '../../vendors/domain/line_items.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  PurchaseOrderRepositoryImpl({
    Functions? functions,
    AuditRepository? audit,
    VendorWorkspaceStore? store,
    String Function()? actorId,
  })  : _functions = functions ?? AppwriteService.functions,
        _audit = audit ?? AuditRepository(),
        _store = store ?? VendorWorkspaceStore(),
        _actorId = actorId ?? (() => 'unknown');

  final Functions _functions;
  final AuditRepository _audit;
  final VendorWorkspaceStore _store;
  final String Function() _actorId;

  @override
  Future<AppResult<List<PurchaseOrder>>> getPurchaseOrders({
    String? projectId,
    String? vendorId,
    PurchaseOrderStatus? status,
  }) {
    return AppwriteService.guard(() async {
      final snaps = vendorId == null ? await _store.list() : [await _store.getById(vendorId)];
      return [
        for (final snap in snaps)
          for (final order in snap.workspace.purchaseOrders)
            if ((projectId == null || order.projectId == projectId) && (status == null || order.status == status))
              order,
      ]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    });
  }

  @override
  Future<AppResult<PurchaseOrder>> getPurchaseOrderById(String id) {
    return AppwriteService.guard(() async {
      final host = await _store.findPoHost(id);
      if (host == null) throw AppwriteException('Purchase order not found', 404);
      return host.workspace.purchaseOrders.firstWhere((item) => item.id == id);
    });
  }

  @override
  Future<AppResult<PurchaseOrder>> createPurchaseOrder({
    required String projectId,
    required String vendorId,
    String? rfqId,
    String? vendorQuoteId,
    required String title,
    required List<PricedLine> items,
    double taxRate = 18,
    required DateTime deliveryDate,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      if (items.isEmpty) throw AppwriteException('Add at least one item', 400);
      final snap = await _store.getById(vendorId);
      final draft = await _nextNumber();
      final totals = pricedTotals([for (final item in items) (quantity: item.quantity, rate: item.rate)], taxRate);
      final order = PurchaseOrder(
        id: ID.unique(),
        projectId: projectId,
        vendorId: vendorId,
        rfqId: rfqId,
        vendorQuoteId: vendorQuoteId,
        poNumber: draft,
        title: title.trim(),
        items: items,
        subtotal: totals.subtotal,
        taxRate: taxRate,
        taxAmount: totals.taxAmount,
        total: totals.total,
        deliveryDate: deliveryDate,
        status: PurchaseOrderStatus.draft,
        issuedBy: _actorId(),
        notes: notes?.trim(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.purchaseOrders.add(order);
      await _store.saveWorkspace(vendorId, snap.workspace);
      await _audit.log(userId: _actorId(), action: 'purchase_order_created', metadata: {'id': order.id, 'vendorId': vendorId});
      return order;
    });
  }

  @override
  Future<AppResult<PurchaseOrder>> issuePurchaseOrder(String id) {
    return _setStatus(id, PurchaseOrderStatus.issued, action: 'purchase_order_issued', issued: true);
  }

  @override
  Future<AppResult<PurchaseOrder>> acknowledgePurchaseOrder(String id) {
    return _setStatus(id, PurchaseOrderStatus.acknowledged, action: 'purchase_order_acknowledged', acknowledged: true);
  }

  @override
  Future<AppResult<PurchaseOrder>> updatePurchaseOrderStatus(String id, PurchaseOrderStatus status) {
    return _setStatus(id, status, action: 'purchase_order_status_changed', completed: status == PurchaseOrderStatus.completed);
  }

  @override
  Future<AppResult<PurchaseOrder>> createFromVendorQuote(String vendorQuoteId) {
    return AppwriteService.guard(() async {
      final host = await _store.findQuoteHost(vendorQuoteId);
      if (host == null) throw AppwriteException('Quote not found', 404);
      final quote = host.workspace.quotes.firstWhere((item) => item.id == vendorQuoteId);
      if (quote.status != VendorQuoteStatus.accepted && quote.status != VendorQuoteStatus.submitted) {
        throw AppwriteException('Award or submit the quote before creating a PO', 400);
      }
      var projectId = '';
      try {
        final rfq = await RfqWorkspaceStore().getById(quote.rfqId);
        projectId = rfq.rfq.projectId;
      } catch (_) {}
      return (await createPurchaseOrder(
        projectId: projectId,
        vendorId: quote.vendorId,
        rfqId: quote.rfqId,
        vendorQuoteId: quote.id,
        title: 'PO for ${quote.quoteNumber}',
        items: quote.items,
        taxRate: quote.taxRate,
        deliveryDate: DateTime.now().add(Duration(days: quote.deliveryDays ?? 30)),
      )).when(
        success: (order) => order,
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  Future<AppResult<PurchaseOrder>> _setStatus(
    String id,
    PurchaseOrderStatus status, {
    required String action,
    bool issued = false,
    bool acknowledged = false,
    bool completed = false,
  }) {
    return AppwriteService.guard(() async {
      final host = await _store.findPoHost(id);
      if (host == null) throw AppwriteException('Purchase order not found', 404);
      final index = host.workspace.purchaseOrders.indexWhere((item) => item.id == id);
      final current = host.workspace.purchaseOrders[index];
      if (!current.status.canTransitionTo(status)) {
        throw AppwriteException('Cannot change status from ${current.status.value} to ${status.value}', 400);
      }
      final now = DateTime.now().toUtc();
      final next = PurchaseOrder(
        id: current.id,
        projectId: current.projectId,
        vendorId: current.vendorId,
        rfqId: current.rfqId,
        vendorQuoteId: current.vendorQuoteId,
        poNumber: current.poNumber,
        title: current.title,
        items: current.items,
        subtotal: current.subtotal,
        taxRate: current.taxRate,
        taxAmount: current.taxAmount,
        total: current.total,
        deliveryDate: current.deliveryDate,
        status: status,
        issuedBy: current.issuedBy,
        issuedAt: issued ? now : current.issuedAt,
        acknowledgedAt: acknowledged ? now : current.acknowledgedAt,
        completedAt: completed ? now : current.completedAt,
        notes: current.notes,
        attachments: current.attachments,
        createdAt: current.createdAt,
        updatedAt: now,
      );
      host.workspace.purchaseOrders[index] = next;
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: action, metadata: {'id': id, 'status': status.value});
      await AppNotifications.instance.showImmediate(title: 'Purchase order ${status.label}', body: current.poNumber);
      return next;
    });
  }

  Future<String> _nextNumber() async {
    try {
      final execution = await _functions.createExecution(functionId: AppwriteService.generatePoNumberFn);
      final match = RegExp(r'PO-\d{4}-\d+').firstMatch(execution.responseBody);
      if (match != null) return match.group(0)!;
    } catch (_) {}
    return 'PO-${DateTime.now().year}-draft';
  }
}
