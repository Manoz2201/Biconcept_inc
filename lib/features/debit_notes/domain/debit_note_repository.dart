import '../../../core/result/app_result.dart';
import '../../invoices/domain/invoice.dart';
import 'debit_note.dart';

abstract class DebitNoteRepository {
  Future<AppResult<List<DebitNote>>> getDebitNotes({String? invoiceId, String? clientId, DebitNoteStatus? status});

  Future<AppResult<DebitNote>> createDebitNote({
    required String invoiceId,
    required String reason,
    required List<InvoiceItem> items,
  });

  Future<AppResult<DebitNote>> issueDebitNote(String id);

  Future<AppResult<DebitNote>> applyDebitNote(String id);

  Future<AppResult<DebitNote>> voidDebitNote(String id);
}
