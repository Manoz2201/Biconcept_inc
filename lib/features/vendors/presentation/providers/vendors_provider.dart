import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../project_vendors/data/project_vendor_repository_impl.dart';
import '../../../project_vendors/domain/project_vendor.dart';
import '../../../project_vendors/domain/project_vendor_repository.dart';
import '../../../purchase_orders/data/po_pdf_service.dart';
import '../../../purchase_orders/data/purchase_order_repository_impl.dart';
import '../../../purchase_orders/domain/purchase_order.dart';
import '../../../purchase_orders/domain/purchase_order_repository.dart';
import '../../../rfqs/data/rfq_repository_impl.dart';
import '../../../rfqs/domain/rfq.dart';
import '../../../rfqs/domain/rfq_repository.dart';
import '../../../rfqs/domain/vendor_quote.dart';
import '../../../vendor_bills/data/vendor_bill_repository_impl.dart';
import '../../../vendor_bills/domain/vendor_bill.dart';
import '../../../vendor_bills/domain/vendor_bill_repository.dart';
import '../../../vendor_bills/domain/vendor_payment.dart';
import '../../data/vendor_repository_impl.dart';
import '../../data/vendor_workspace_store.dart';
import '../../domain/vendor.dart';
import '../../domain/vendor_rate.dart';
import '../../domain/vendor_rating.dart';
import '../../domain/vendor_repository.dart';

VendorWorkspaceStore _store() => VendorWorkspaceStore();

String Function() _actorId(Ref ref) => () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  return VendorRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

final vendorRateRepositoryProvider = Provider<VendorRateRepository>((ref) {
  return VendorRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

final vendorRatingRepositoryProvider = Provider<VendorRatingRepository>((ref) {
  return VendorRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

final rfqRepositoryProvider = Provider<RFQRepository>((ref) {
  return RFQRepositoryImpl(vendors: _store(), actorId: _actorId(ref));
});

final vendorQuoteRepositoryProvider = Provider<VendorQuoteRepository>((ref) {
  return RFQRepositoryImpl(vendors: _store(), actorId: _actorId(ref));
});

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

final poPdfServiceProvider = Provider<PurchaseOrderPdfService>((ref) => PoPdfService());

final vendorBillRepositoryProvider = Provider<VendorBillRepository>((ref) {
  return VendorBillRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

final vendorPaymentRepositoryProvider = Provider<VendorPaymentRepository>((ref) {
  return VendorBillRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

final projectVendorRepositoryProvider = Provider<ProjectVendorRepository>((ref) {
  return ProjectVendorRepositoryImpl(store: _store(), actorId: _actorId(ref));
});

class VendorQuery {
  const VendorQuery({this.search = '', this.category, this.isActive, this.isVerified});

  final String search;
  final String? category;
  final bool? isActive;
  final bool? isVerified;

  @override
  bool operator ==(Object other) =>
      other is VendorQuery &&
      other.search == search &&
      other.category == category &&
      other.isActive == isActive &&
      other.isVerified == isVerified;

  @override
  int get hashCode => Object.hash(search, category, isActive, isVerified);
}

final vendorsProvider = FutureProvider.family<List<Vendor>, VendorQuery>((ref, query) async {
  final result = await ref.watch(vendorRepositoryProvider).getVendors(
        searchTerm: query.search.trim().isEmpty ? null : query.search.trim(),
        category: query.category,
        isActive: query.isActive,
        isVerified: query.isVerified,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final vendorByIdProvider = FutureProvider.family<Vendor, String>((ref, id) async {
  final result = await ref.watch(vendorRepositoryProvider).getVendorById(id);
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final myVendorProfileProvider = FutureProvider<Vendor?>((ref) async {
  final userId = ref.watch(sessionControllerProvider).user?.accountId;
  if (userId == null) return null;
  final result = await ref.watch(vendorRepositoryProvider).getVendorByUserId(userId);
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final vendorRatesProvider = FutureProvider.family<List<VendorRate>, String>((ref, vendorId) async {
  final result = await ref.watch(vendorRateRepositoryProvider).getVendorRates(vendorId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final vendorRatingsProvider = FutureProvider.family<List<VendorRating>, String>((ref, vendorId) async {
  final result = await ref.watch(vendorRatingRepositoryProvider).getVendorRatings(vendorId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

class RfqQuery {
  const RfqQuery({this.projectId, this.status, this.category});

  final String? projectId;
  final RFQStatus? status;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is RfqQuery && other.projectId == projectId && other.status == status && other.category == category;

  @override
  int get hashCode => Object.hash(projectId, status, category);
}

final rfqsProvider = FutureProvider.family<List<RFQ>, RfqQuery>((ref, query) async {
  final result = await ref.watch(rfqRepositoryProvider).getRFQs(
        projectId: query.projectId,
        status: query.status,
        category: query.category,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final rfqByIdProvider = FutureProvider.family<RFQ, String>((ref, id) async {
  final result = await ref.watch(rfqRepositoryProvider).getRFQById(id);
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final rfqRecipientsProvider = FutureProvider.family<List<RFQRecipient>, String>((ref, rfqId) async {
  final result = await ref.watch(rfqRepositoryProvider).getRecipients(rfqId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final vendorQuotesProvider = FutureProvider.family<List<VendorQuote>, String>((ref, rfqId) async {
  final result = await ref.watch(vendorQuoteRepositoryProvider).getVendorQuotes(rfqId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

class PoQuery {
  const PoQuery({this.projectId, this.vendorId, this.status});

  final String? projectId;
  final String? vendorId;
  final PurchaseOrderStatus? status;

  @override
  bool operator ==(Object other) =>
      other is PoQuery && other.projectId == projectId && other.vendorId == vendorId && other.status == status;

  @override
  int get hashCode => Object.hash(projectId, vendorId, status);
}

final purchaseOrdersProvider = FutureProvider.family<List<PurchaseOrder>, PoQuery>((ref, query) async {
  final result = await ref.watch(purchaseOrderRepositoryProvider).getPurchaseOrders(
        projectId: query.projectId,
        vendorId: query.vendorId,
        status: query.status,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

class BillQuery {
  const BillQuery({this.vendorId, this.projectId, this.status});

  final String? vendorId;
  final String? projectId;
  final VendorBillStatus? status;

  @override
  bool operator ==(Object other) =>
      other is BillQuery && other.vendorId == vendorId && other.projectId == projectId && other.status == status;

  @override
  int get hashCode => Object.hash(vendorId, projectId, status);
}

final vendorBillsProvider = FutureProvider.family<List<VendorBill>, BillQuery>((ref, query) async {
  final result = await ref.watch(vendorBillRepositoryProvider).getVendorBills(
        vendorId: query.vendorId,
        projectId: query.projectId,
        status: query.status,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final vendorPaymentsProvider = FutureProvider.family<List<VendorPayment>, String?>((ref, vendorId) async {
  final result = await ref.watch(vendorPaymentRepositoryProvider).getVendorPayments(vendorId: vendorId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final projectVendorsProvider = FutureProvider.family<List<ProjectVendor>, String>((ref, projectId) async {
  final result = await ref.watch(projectVendorRepositoryProvider).getProjectVendors(projectId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});
