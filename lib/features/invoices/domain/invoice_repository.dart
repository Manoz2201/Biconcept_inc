import 'dart:typed_data';

import '../../../core/result/app_result.dart';
import 'invoice.dart';

abstract class InvoiceRepository {
  Future<AppResult<List<Invoice>>> getInvoices({
    String? clientId,
    InvoiceStatus? status,
    DateTime? from,
    DateTime? to,
    String? projectId,
  });

  Future<AppResult<Invoice>> getInvoiceById(String id);

  Future<AppResult<Invoice>> createInvoice({
    required String clientId,
    required DateTime invoiceDate,
    required DateTime dueDate,
    required String placeOfSupply,
    required String placeOfSupplyCode,
    required List<InvoiceItem> items,
    String? projectId,
    String? quotationId,
    String? notes,
    String? termsAndConditions,
    String? bankDetails,
  });

  Future<AppResult<Invoice>> updateInvoice(String id, List<InvoiceItem> items, {String? notes, String? termsAndConditions, String? bankDetails, DateTime? dueDate});

  Future<AppResult<Invoice>> issueInvoice(String id);

  Future<AppResult<Invoice>> voidInvoice(String id, String reason);

  Future<AppResult<Invoice>> updatePaymentStatus(String invoiceId);

  Future<AppResult<Uint8List>> generatePdf(String id);

  Future<AppResult<void>> sharePdf(String id);

  String exportInvoicesToCsv(List<Invoice> invoices);
}

abstract class InvoiceDocumentService {
  Future<Uint8List> generatePdf(Invoice invoice, {String? clientName, String? firmName, String? firmGstin, String? clientGstin});

  Future<void> sharePdf(Invoice invoice, {String? clientName, String? firmName, String? firmGstin, String? clientGstin});
}
