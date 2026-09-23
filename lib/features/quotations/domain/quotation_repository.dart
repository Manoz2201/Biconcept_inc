import '../../../core/result/app_result.dart';
import 'quotation.dart';

abstract class QuotationRepository {
  Future<AppResult<List<Quotation>>> getQuotations({
    String? clientId,
    String? serviceRequestId,
    QuotationStatus? status,
  });

  Future<AppResult<Quotation>> getQuotationById(String id);

  Future<AppResult<Quotation>> createQuotation({
    required String serviceRequestId,
    required String clientId,
    required String title,
    required List<QuotationLineItem> items,
    double taxRate = 18,
    required DateTime validUntil,
    String? internalNotes,
  });

  Future<AppResult<Quotation>> updateQuotation(String id, Map<String, dynamic> data);

  Future<AppResult<Quotation>> sendQuotation(String id);

  Future<AppResult<Quotation>> markViewed(String id);

  Future<AppResult<Quotation>> clientRespond(String id, {required bool approved, String? notes});

  Future<AppResult<Quotation>> createRevision(String id);
}
