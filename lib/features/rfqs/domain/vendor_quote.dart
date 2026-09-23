import '../../vendors/domain/line_items.dart';

enum VendorQuoteStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected');

  const VendorQuoteStatus(this.value, this.label);
  final String value;
  final String label;

  static VendorQuoteStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => VendorQuoteStatus.draft,
      );
}

class VendorQuote {
  const VendorQuote({
    required this.id,
    required this.rfqId,
    required this.vendorId,
    required this.quoteNumber,
    required this.items,
    required this.subtotal,
    this.taxRate = 18,
    required this.taxAmount,
    required this.total,
    required this.validUntil,
    this.deliveryDays,
    this.notes,
    required this.status,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String rfqId;
  final String vendorId;
  final String quoteNumber;
  final List<PricedLine> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final DateTime validUntil;
  final int? deliveryDays;
  final String? notes;
  final VendorQuoteStatus status;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rfqId': rfqId,
        'vendorId': vendorId,
        'quoteNumber': quoteNumber,
        'items': [for (final item in items) item.toJson()],
        'subtotal': subtotal,
        'taxRate': taxRate,
        'taxAmount': taxAmount,
        'total': total,
        'validUntil': validUntil.toUtc().toIso8601String(),
        'deliveryDays': ?deliveryDays,
        'notes': ?notes,
        'status': status.value,
        'submittedAt': submittedAt?.toUtc().toIso8601String(),
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory VendorQuote.fromJson(Map<String, dynamic> data) => VendorQuote(
        id: data['id']?.toString() ?? '',
        rfqId: data['rfqId']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        quoteNumber: data['quoteNumber']?.toString() ?? '',
        items: pricedLinesFrom(decodeJsonList(data['items'])),
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18,
        taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
        total: (data['total'] as num?)?.toDouble() ?? 0,
        validUntil: DateTime.tryParse(data['validUntil']?.toString() ?? '') ?? DateTime.now(),
        deliveryDays: (data['deliveryDays'] as num?)?.toInt(),
        notes: data['notes']?.toString(),
        status: VendorQuoteStatus.fromString(data['status']?.toString() ?? 'draft'),
        submittedAt: DateTime.tryParse(data['submittedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
