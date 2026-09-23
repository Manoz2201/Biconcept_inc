import '../../invoices/domain/invoice.dart';

enum CreditNoteStatus {
  draft('draft', 'Draft'),
  issued('issued', 'Issued'),
  applied('applied', 'Applied'),
  voided('void', 'Void');

  const CreditNoteStatus(this.value, this.label);
  final String value;
  final String label;

  static CreditNoteStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => CreditNoteStatus.draft,
      );
}

class CreditNote {
  const CreditNote({
    required this.id,
    required this.creditNoteNumber,
    required this.invoiceId,
    required this.clientId,
    required this.creditNoteDate,
    required this.reason,
    required this.items,
    required this.subtotal,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.grandTotal,
    required this.status,
    required this.createdBy,
    this.issuedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String creditNoteNumber;
  final String invoiceId;
  final String clientId;
  final DateTime creditNoteDate;
  final String reason;
  final List<InvoiceItem> items;
  final double subtotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double grandTotal;
  final CreditNoteStatus status;
  final String createdBy;
  final DateTime? issuedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'creditNoteNumber': creditNoteNumber,
        'invoiceId': invoiceId,
        'clientId': clientId,
        'creditNoteDate': creditNoteDate.toIso8601String(),
        'reason': reason,
        'items': [for (final item in items) item.toJson()],
        'subtotal': subtotal,
        'totalCgst': totalCgst,
        'totalSgst': totalSgst,
        'totalIgst': totalIgst,
        'grandTotal': grandTotal,
        'status': status.value,
        'createdBy': createdBy,
        'issuedAt': ?issuedAt?.toIso8601String(),
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory CreditNote.fromJson(Map<String, dynamic> data) => CreditNote(
        id: data['id']?.toString() ?? '',
        creditNoteNumber: data['creditNoteNumber']?.toString() ?? '',
        invoiceId: data['invoiceId']?.toString() ?? '',
        clientId: data['clientId']?.toString() ?? '',
        creditNoteDate: DateTime.tryParse(data['creditNoteDate']?.toString() ?? '') ?? DateTime.now(),
        reason: data['reason']?.toString() ?? '',
        items: invoiceItemsFrom(data['items']),
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
        totalCgst: (data['totalCgst'] as num?)?.toDouble() ?? 0,
        totalSgst: (data['totalSgst'] as num?)?.toDouble() ?? 0,
        totalIgst: (data['totalIgst'] as num?)?.toDouble() ?? 0,
        grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0,
        status: CreditNoteStatus.fromString(data['status']?.toString()),
        createdBy: data['createdBy']?.toString() ?? '',
        issuedAt: DateTime.tryParse(data['issuedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
