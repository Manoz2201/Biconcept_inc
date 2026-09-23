import 'dart:typed_data';

import '../../../core/result/app_result.dart';
import '../../vendors/domain/line_items.dart';
import 'purchase_order.dart';

abstract class PurchaseOrderRepository {
  Future<AppResult<List<PurchaseOrder>>> getPurchaseOrders({
    String? projectId,
    String? vendorId,
    PurchaseOrderStatus? status,
  });
  Future<AppResult<PurchaseOrder>> getPurchaseOrderById(String id);
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
  });
  Future<AppResult<PurchaseOrder>> issuePurchaseOrder(String id);
  Future<AppResult<PurchaseOrder>> acknowledgePurchaseOrder(String id);
  Future<AppResult<PurchaseOrder>> updatePurchaseOrderStatus(String id, PurchaseOrderStatus status);
  Future<AppResult<PurchaseOrder>> createFromVendorQuote(String vendorQuoteId);
}

abstract class PurchaseOrderPdfService {
  Future<Uint8List> generatePdf(PurchaseOrder order, {String? vendorName, String? projectTitle});
  Future<void> sharePdf(PurchaseOrder order, {String? vendorName, String? projectTitle});
}
