import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../vendors/domain/line_items.dart';
import 'vendor_bill.dart';
import 'vendor_payment.dart';

abstract class VendorBillRepository {
  Future<AppResult<List<VendorBill>>> getVendorBills({
    String? vendorId,
    String? projectId,
    VendorBillStatus? status,
  });
  Future<AppResult<VendorBill>> getVendorBillById(String id);
  Future<AppResult<List<VendorBill>>> getMyBills(String vendorId);
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
  });
  Future<AppResult<VendorBill>> submitVendorBill(String id);
  Future<AppResult<VendorBill>> approveVendorBill(String id, String approverId);
  Future<AppResult<VendorBill>> rejectVendorBill(String id, String reason);
  Future<AppResult<VendorBill>> uploadBillAttachment(String billId, UploadBytes file);
}

abstract class VendorPaymentRepository {
  Future<AppResult<List<VendorPayment>>> getVendorPayments({String? vendorId, String? billId, String? projectId});
  Future<AppResult<VendorPayment>> createVendorPayment({
    required String billId,
    required double amount,
    required DateTime paymentDate,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? notes,
  });
  Future<AppResult<VendorPayment>> completePayment(String id);
  Future<AppResult<VendorPayment>> failPayment(String id, String reason);
}
