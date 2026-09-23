import 'dart:typed_data';

import '../../../core/result/app_result.dart';
import 'payment.dart';

abstract class PaymentRepository {
  Future<AppResult<List<Payment>>> getPayments({
    String? invoiceId,
    String? clientId,
    ClientPaymentStatus? status,
    DateTime? from,
    DateTime? to,
  });

  Future<AppResult<Payment>> getPaymentById(String id);

  Future<AppResult<Payment>> createPayment({
    String? invoiceId,
    String? clientId,
    String? projectId,
    required double amount,
    required DateTime paymentDate,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? notes,
    bool completeImmediately = true,
  });

  Future<AppResult<Payment>> completePayment(String id);

  Future<AppResult<Payment>> failPayment(String id, String reason);

  Future<AppResult<Payment>> refundPayment(String id, double refundAmount, String reason);

  Future<AppResult<Uint8List>> generateReceipt(String paymentId);

  Future<AppResult<void>> shareReceipt(String paymentId);
}

abstract class RazorpayService {
  Future<AppResult<String>> createOrder({required double amount, required String receipt});

  Future<AppResult<bool>> verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
