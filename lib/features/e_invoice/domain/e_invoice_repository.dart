import '../../../core/result/app_result.dart';
import 'e_invoice.dart';

abstract class EInvoiceRepository {
  Future<AppResult<List<EInvoice>>> getEInvoices({String? financialYear, EInvoiceStatus? status});

  Future<AppResult<EInvoice>> getEInvoiceById(String id);

  Future<AppResult<EInvoice?>> getEInvoiceByInvoiceId(String invoiceId);

  Future<AppResult<EInvoice>> generateIRN(String invoiceId);

  Future<AppResult<EInvoice>> cancelIRN(String id, String reason, String remarks);

  Future<AppResult<EInvoice>> retryIRNGeneration(String id);

  Future<AppResult<String>> exportEInvoicesToCsv({String? financialYear});

  Future<AppResult<IrpSettings>> getIrpSettings();

  Future<AppResult<IrpSettings>> saveIrpSettings(IrpSettings settings);
}
