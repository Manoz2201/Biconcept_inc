import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../domain/payment_repository.dart';

class RazorpayServiceImpl implements RazorpayService {
  RazorpayServiceImpl({Functions? functions}) : _functions = functions ?? AppwriteService.functions;

  final Functions _functions;

  bool get isConfigured => Env.razorpayKeyId.isNotEmpty;

  @override
  Future<AppResult<String>> createOrder({required double amount, required String receipt}) {
    return AppwriteService.guard(() async {
      if (!isConfigured) {
        throw AppwriteException('Online checkout is not configured. Record a bank or UPI payment instead.', 400);
      }
      final execution = await _functions.createExecution(
        functionId: AppwriteService.createRazorpayOrderFn,
        body: jsonEncode({'amount': amount, 'currency': 'INR', 'receipt': receipt}),
      );
      final body = jsonDecode(execution.responseBody);
      if (body is Map && body['orderId'] != null) return body['orderId'].toString();
      throw AppwriteException('Could not create a Razorpay order. The Function is not deployed.', 400);
    });
  }

  @override
  Future<AppResult<bool>> verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    return AppwriteService.guard(() async {
      final execution = await _functions.createExecution(
        functionId: AppwriteService.verifyRazorpaySignatureFn,
        body: jsonEncode({'orderId': orderId, 'paymentId': paymentId, 'signature': signature}),
      );
      final body = jsonDecode(execution.responseBody);
      return body is Map && body['valid'] == true;
    });
  }
}
