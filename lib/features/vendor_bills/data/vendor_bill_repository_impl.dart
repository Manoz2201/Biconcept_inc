import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../vendors/data/vendor_workspace_store.dart';
import '../../vendors/domain/line_items.dart';
import '../domain/vendor_bill.dart';
import '../domain/vendor_bill_repository.dart';
import '../domain/vendor_payment.dart';

class VendorBillRepositoryImpl implements VendorBillRepository, VendorPaymentRepository {
  VendorBillRepositoryImpl({
    Storage? storage,
    AuditRepository? audit,
    VendorWorkspaceStore? store,
    String Function()? actorId,
  })  : _storage = storage ?? AppwriteService.storage,
        _audit = audit ?? AuditRepository(),
        _store = store ?? VendorWorkspaceStore(),
        _actorId = actorId ?? (() => 'unknown');

  final Storage _storage;
  final AuditRepository _audit;
  final VendorWorkspaceStore _store;
  final String Function() _actorId;

  @override
  Future<AppResult<List<VendorBill>>> getVendorBills({
    String? vendorId,
    String? projectId,
    VendorBillStatus? status,
  }) {
    return AppwriteService.guard(() async {
      final snaps = vendorId == null ? await _store.list() : [await _store.getById(vendorId)];
      return [
        for (final snap in snaps)
          for (final bill in snap.workspace.bills)
            if ((projectId == null || bill.projectId == projectId) && (status == null || bill.status == status)) bill,
      ]..sort((a, b) => b.billDate.compareTo(a.billDate));
    });
  }

  @override
  Future<AppResult<VendorBill>> getVendorBillById(String id) {
    return AppwriteService.guard(() async {
      final host = await _store.findBillHost(id);
      if (host == null) throw AppwriteException('Bill not found', 404);
      return host.workspace.bills.firstWhere((item) => item.id == id);
    });
  }

  @override
  Future<AppResult<List<VendorBill>>> getMyBills(String vendorId) => getVendorBills(vendorId: vendorId);

  @override
  Future<AppResult<VendorBill>> createVendorBill({
    required String vendorId,
    required String billNumber,
    required DateTime billDate,
    required DateTime dueDate,
    required List<PricedLine> items,
    double taxRate = 18,
    String? purchaseOrderId,
    String? projectId,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      if (items.isEmpty) throw AppwriteException('Add at least one item', 400);
      final snap = await _store.getById(vendorId);
      final totals = pricedTotals([for (final item in items) (quantity: item.quantity, rate: item.rate)], taxRate);
      final bill = VendorBill(
        id: ID.unique(),
        vendorId: vendorId,
        projectId: projectId,
        purchaseOrderId: purchaseOrderId,
        billNumber: billNumber.trim(),
        billDate: billDate,
        dueDate: dueDate,
        items: items,
        subtotal: totals.subtotal,
        taxRate: taxRate,
        taxAmount: totals.taxAmount,
        total: totals.total,
        status: VendorBillStatus.draft,
        notes: notes?.trim(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.bills.add(bill);
      await _store.saveWorkspace(vendorId, snap.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_bill_created', metadata: {'id': bill.id, 'vendorId': vendorId});
      return bill;
    });
  }

  @override
  Future<AppResult<VendorBill>> submitVendorBill(String id) {
    return _setBill(id, VendorBillStatus.submitted, action: 'vendor_bill_submitted');
  }

  @override
  Future<AppResult<VendorBill>> approveVendorBill(String id, String approverId) {
    return _setBill(id, VendorBillStatus.approved, action: 'vendor_bill_approved', approvedBy: approverId);
  }

  @override
  Future<AppResult<VendorBill>> rejectVendorBill(String id, String reason) {
    return _setBill(id, VendorBillStatus.rejected, action: 'vendor_bill_rejected', notes: reason);
  }

  @override
  Future<AppResult<VendorBill>> uploadBillAttachment(String billId, UploadBytes file) {
    return AppwriteService.guard(() async {
      final host = await _store.findBillHost(billId);
      if (host == null) throw AppwriteException('Bill not found', 404);
      final filename = sanitizeUploadName(file.filename);
      validateUpload(file.bytes, filename);
      final uploaded = await _storage.createFile(
        bucketId: Env.clientUploadsBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: file.bytes, filename: filename),
        permissions: vendorRowPermissions(host.vendor.userId),
      );
      final index = host.workspace.bills.indexWhere((item) => item.id == billId);
      final current = host.workspace.bills[index];
      host.workspace.bills[index] = VendorBill(
        id: current.id,
        vendorId: current.vendorId,
        projectId: current.projectId,
        purchaseOrderId: current.purchaseOrderId,
        billNumber: current.billNumber,
        billDate: current.billDate,
        dueDate: current.dueDate,
        items: current.items,
        subtotal: current.subtotal,
        taxRate: current.taxRate,
        taxAmount: current.taxAmount,
        total: current.total,
        status: current.status,
        approvedBy: current.approvedBy,
        approvedAt: current.approvedAt,
        paidAmount: current.paidAmount,
        paymentStatus: current.paymentStatus,
        attachmentId: uploaded.$id,
        notes: current.notes,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      return host.workspace.bills[index];
    });
  }

  @override
  Future<AppResult<List<VendorPayment>>> getVendorPayments({String? vendorId, String? billId, String? projectId}) {
    return AppwriteService.guard(() async {
      final snaps = vendorId == null ? await _store.list() : [await _store.getById(vendorId)];
      return [
        for (final snap in snaps)
          for (final payment in snap.workspace.payments)
            if ((billId == null || payment.billId == billId) && (projectId == null || payment.projectId == projectId))
              payment,
      ]..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    });
  }

  @override
  Future<AppResult<VendorPayment>> createVendorPayment({
    required String billId,
    required double amount,
    required DateTime paymentDate,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final host = await _store.findBillHost(billId);
      if (host == null) throw AppwriteException('Bill not found', 404);
      final bill = host.workspace.bills.firstWhere((item) => item.id == billId);
      final payment = VendorPayment(
        id: ID.unique(),
        vendorId: bill.vendorId,
        billId: billId,
        projectId: bill.projectId,
        amount: amount,
        paymentDate: paymentDate,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        status: VendorPaymentStatus.pending,
        processedBy: _actorId(),
        notes: notes?.trim(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.payments.add(payment);
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_payment_created', metadata: {'id': payment.id, 'billId': billId});
      return payment;
    });
  }

  @override
  Future<AppResult<VendorPayment>> completePayment(String id) {
    return _setPayment(id, VendorPaymentStatus.completed, action: 'vendor_payment_completed');
  }

  @override
  Future<AppResult<VendorPayment>> failPayment(String id, String reason) {
    return _setPayment(id, VendorPaymentStatus.failed, action: 'vendor_payment_failed', notes: reason);
  }

  Future<AppResult<VendorBill>> _setBill(
    String id,
    VendorBillStatus status, {
    required String action,
    String? approvedBy,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final host = await _store.findBillHost(id);
      if (host == null) throw AppwriteException('Bill not found', 404);
      final index = host.workspace.bills.indexWhere((item) => item.id == id);
      final current = host.workspace.bills[index];
      host.workspace.bills[index] = VendorBill(
        id: current.id,
        vendorId: current.vendorId,
        projectId: current.projectId,
        purchaseOrderId: current.purchaseOrderId,
        billNumber: current.billNumber,
        billDate: current.billDate,
        dueDate: current.dueDate,
        items: current.items,
        subtotal: current.subtotal,
        taxRate: current.taxRate,
        taxAmount: current.taxAmount,
        total: current.total,
        status: status,
        approvedBy: approvedBy ?? current.approvedBy,
        approvedAt: approvedBy == null ? current.approvedAt : DateTime.now().toUtc(),
        paidAmount: current.paidAmount,
        paymentStatus: current.paymentStatus,
        attachmentId: current.attachmentId,
        notes: notes ?? current.notes,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: action, metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'Bill ${status.label}', body: current.billNumber);
      return host.workspace.bills[index];
    });
  }

  Future<AppResult<VendorPayment>> _setPayment(
    String id,
    VendorPaymentStatus status, {
    required String action,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final host = await _store.findPaymentHost(id);
      if (host == null) throw AppwriteException('Payment not found', 404);
      final pIndex = host.workspace.payments.indexWhere((item) => item.id == id);
      final current = host.workspace.payments[pIndex];
      host.workspace.payments[pIndex] = VendorPayment(
        id: current.id,
        vendorId: current.vendorId,
        billId: current.billId,
        projectId: current.projectId,
        amount: current.amount,
        paymentDate: current.paymentDate,
        paymentMethod: current.paymentMethod,
        referenceNumber: current.referenceNumber,
        status: status,
        processedBy: current.processedBy,
        notes: notes ?? current.notes,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      _refreshBillPayment(host, current.billId);
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: action, metadata: {'id': id});
      return host.workspace.payments[pIndex];
    });
  }

  void _refreshBillPayment(VendorSnapshot host, String billId) {
    final paid = host.workspace.payments
        .where((item) => item.billId == billId && item.status == VendorPaymentStatus.completed)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final index = host.workspace.bills.indexWhere((item) => item.id == billId);
    if (index < 0) return;
    final bill = host.workspace.bills[index];
    final flag = paid <= 0
        ? PaymentStatusFlag.unpaid
        : paid >= bill.total
            ? PaymentStatusFlag.paid
            : PaymentStatusFlag.partial;
    final status = flag == PaymentStatusFlag.paid
        ? VendorBillStatus.paid
        : flag == PaymentStatusFlag.partial
            ? VendorBillStatus.partiallyPaid
            : bill.status;
    host.workspace.bills[index] = VendorBill(
      id: bill.id,
      vendorId: bill.vendorId,
      projectId: bill.projectId,
      purchaseOrderId: bill.purchaseOrderId,
      billNumber: bill.billNumber,
      billDate: bill.billDate,
      dueDate: bill.dueDate,
      items: bill.items,
      subtotal: bill.subtotal,
      taxRate: bill.taxRate,
      taxAmount: bill.taxAmount,
      total: bill.total,
      status: status,
      approvedBy: bill.approvedBy,
      approvedAt: bill.approvedAt,
      paidAmount: paid,
      paymentStatus: flag,
      attachmentId: bill.attachmentId,
      notes: bill.notes,
      createdAt: bill.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
