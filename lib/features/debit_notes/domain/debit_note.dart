import '../../invoices/domain/invoice.dart';

enum DebitNoteStatus {
  draft('draft', 'Draft'),
  issued('issued', 'Issued'),
  applied('applied', 'Applied'),
  voided('void', 'Void');

  const DebitNoteStatus(this.value, this.label);
  final String value;
  final String label;

  static DebitNoteStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => DebitNoteStatus.draft,
      );
}

class DebitNote {
  const DebitNote({
    required this.id,
    required this.debitNoteNumber,
    required this.invoiceId,
    required this.clientId,
    required this.debitNoteDate,
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
  final String debitNoteNumber;
  final String invoiceId;
  final String clientId;
  final DateTime debitNoteDate;
  final String reason;
  final List<InvoiceItem> items;
  final double subtotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double grandTotal;
  final DebitNoteStatus status;
  final String createdBy;
  final DateTime? issuedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'debitNoteNumber': debitNoteNumber,
        'invoiceId': invoiceId,
        'clientId': clientId,
        'debitNoteDate': debitNoteDate.toIso8601String(),
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

  factory DebitNote.fromJson(Map<String, dynamic> data) => DebitNote(
        id: data['id']?.toString() ?? '',
        debitNoteNumber: data['debitNoteNumber']?.toString() ?? '',
        invoiceId: data['invoiceId']?.toString() ?? '',
        clientId: data['clientId']?.toString() ?? '',
        debitNoteDate: DateTime.tryParse(data['debitNoteDate']?.toString() ?? '') ?? DateTime.now(),
        reason: data['reason']?.toString() ?? '',
        items: invoiceItemsFrom(data['items']),
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
        totalCgst: (data['totalCgst'] as num?)?.toDouble() ?? 0,
        totalSgst: (data['totalSgst'] as num?)?.toDouble() ?? 0,
        totalIgst: (data['totalIgst'] as num?)?.toDouble() ?? 0,
        grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0,
        status: DebitNoteStatus.fromString(data['status']?.toString()),
        createdBy: data['createdBy']?.toString() ?? '',
        issuedAt: DateTime.tryParse(data['issuedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
