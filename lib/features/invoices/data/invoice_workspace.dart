import 'dart:convert';

import '../../credit_notes/domain/credit_note.dart';
import '../../debit_notes/domain/debit_note.dart';
import '../../payments/domain/payment.dart';

class InvoiceWorkspace {
  InvoiceWorkspace({
    List<Payment>? payments,
    List<CreditNote>? creditNotes,
    List<DebitNote>? debitNotes,
  })  : payments = payments ?? [],
        creditNotes = creditNotes ?? [],
        debitNotes = debitNotes ?? [];

  final List<Payment> payments;
  final List<CreditNote> creditNotes;
  final List<DebitNote> debitNotes;

  String encode() => jsonEncode({
        'payments': [for (final item in payments) item.toJson()],
        'creditNotes': [for (final item in creditNotes) item.toJson()],
        'debitNotes': [for (final item in debitNotes) item.toJson()],
      });

  factory InvoiceWorkspace.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return InvoiceWorkspace();
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return InvoiceWorkspace();
      List<Map<String, dynamic>> maps(Object? value) => [
            if (value is List)
              for (final item in value)
                if (item is Map) Map<String, dynamic>.from(item),
          ];
      return InvoiceWorkspace(
        payments: [for (final item in maps(data['payments'])) Payment.fromJson(item)],
        creditNotes: [for (final item in maps(data['creditNotes'])) CreditNote.fromJson(item)],
        debitNotes: [for (final item in maps(data['debitNotes'])) DebitNote.fromJson(item)],
      );
    } catch (_) {
      return InvoiceWorkspace();
    }
  }
}
