import '../../../core/result/app_result.dart';
import '../../vendors/domain/line_items.dart';
import 'rfq.dart';
import 'vendor_quote.dart';

abstract class RFQRepository {
  Future<AppResult<List<RFQ>>> getRFQs({String? projectId, RFQStatus? status, String? category, String? createdBy});
  Future<AppResult<RFQ>> getRFQById(String id);
  Future<AppResult<List<RFQRecipient>>> getRecipients(String rfqId);
  Future<AppResult<RFQ>> createRFQ({
    required String projectId,
    required String title,
    required String description,
    required String category,
    required List<CatalogLine> items,
    required DateTime dueDate,
    List<String>? vendorIds,
  });
  Future<AppResult<RFQ>> updateRFQ(String id, Map<String, dynamic> data);
  Future<AppResult<RFQ>> sendRFQ(String id);
  Future<AppResult<RFQ>> inviteVendors(String id, List<String> vendorIds);
  Future<AppResult<RFQ>> awardRFQ(String id, String vendorId, String vendorQuoteId);
  Future<AppResult<RFQ>> cancelRFQ(String id);
}

abstract class VendorQuoteRepository {
  Future<AppResult<List<VendorQuote>>> getVendorQuotes(String rfqId);
  Future<AppResult<VendorQuote>> getVendorQuoteById(String id);
  Future<AppResult<List<VendorQuote>>> getMyQuotes(String vendorId);
  Future<AppResult<VendorQuote>> createVendorQuote({
    required String rfqId,
    required String vendorId,
    required List<PricedLine> items,
    double taxRate = 18,
    required DateTime validUntil,
    int? deliveryDays,
    String? notes,
  });
  Future<AppResult<VendorQuote>> updateVendorQuote(String id, Map<String, dynamic> data);
  Future<AppResult<VendorQuote>> submitVendorQuote(String id);
}
