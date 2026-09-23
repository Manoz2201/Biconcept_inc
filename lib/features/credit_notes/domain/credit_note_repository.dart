import '../../../core/result/app_result.dart';
import '../../invoices/domain/invoice.dart';
import 'credit_note.dart';

abstract class CreditNoteRepository {
  Future<AppResult<List<CreditNote>>> getCreditNotes({String? invoiceId, String? clientId, CreditNoteStatus? status});

  Future<AppResult<CreditNote>> createCreditNote({
    required String invoiceId,
    required String reason,
    required List<InvoiceItem> items,
  });

  Future<AppResult<CreditNote>> issueCreditNote(String id);

  Future<AppResult<CreditNote>> applyCreditNote(String id);

  Future<AppResult<CreditNote>> voidCreditNote(String id);
}
