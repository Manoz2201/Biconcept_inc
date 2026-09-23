import 'dart:convert';

class QuotationLineItem {
  const QuotationLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;

  double calculateTotal() => total;

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };

  factory QuotationLineItem.fromJson(Map<String, dynamic> json) {
    return QuotationLineItem(
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class QuotationTotals {
  const QuotationTotals({
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
  });

  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;

  static QuotationTotals fromItems(List<QuotationLineItem> items, {double taxRate = 18}) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final taxAmount = subtotal * taxRate / 100;
    return QuotationTotals(
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: subtotal + taxAmount,
    );
  }
}

enum QuotationStatus {
  draft('draft', 'Draft'),
  sent('sent', 'Sent'),
  viewed('viewed', 'Viewed'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  revisionRequested('revision_requested', 'Revision requested'),
  expired('expired', 'Expired');

  const QuotationStatus(this.value, this.label);
  final String value;
  final String label;

  static QuotationStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => QuotationStatus.draft,
      );
}

class Quotation {
  const Quotation({
    required this.id,
    required this.serviceRequestId,
    required this.clientId,
    required this.quotationNumber,
    required this.title,
    required this.items,
    required this.subtotal,
    this.taxRate = 18,
    required this.taxAmount,
    required this.total,
    required this.validUntil,
    required this.status,
    this.clientNotes,
    this.internalNotes,
    this.revisionNumber = 0,
    this.createdAt,
    this.updatedAt,
    this.sequence,
  });

  final String id;
  final String serviceRequestId;
  final String clientId;
  final String quotationNumber;
  final String title;
  final List<QuotationLineItem> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final DateTime validUntil;
  final QuotationStatus status;
  final String? clientNotes;
  final String? internalNotes;
  final int revisionNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? sequence;

  QuotationStatus get effectiveStatus {
    if (status == QuotationStatus.sent || status == QuotationStatus.viewed) {
      if (validUntil.isBefore(DateTime.now())) return QuotationStatus.expired;
    }
    return status;
  }

  Quotation copyWith({
    String? id,
    String? serviceRequestId,
    String? clientId,
    String? quotationNumber,
    String? title,
    List<QuotationLineItem>? items,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? total,
    DateTime? validUntil,
    QuotationStatus? status,
    String? clientNotes,
    String? internalNotes,
    int? revisionNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sequence,
  }) {
    return Quotation(
      id: id ?? this.id,
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
      clientId: clientId ?? this.clientId,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      title: title ?? this.title,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      clientNotes: clientNotes ?? this.clientNotes,
      internalNotes: internalNotes ?? this.internalNotes,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sequence: sequence ?? this.sequence,
    );
  }

  static String numberFromSequence(String sequence, DateTime when) {
    final padded = sequence.padLeft(3, '0');
    return 'QT-${when.year}-$padded';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceRequestId': serviceRequestId,
        'clientId': clientId,
        'quotationNumber': quotationNumber,
        'title': title,
        'items': [for (final item in items) item.toJson()],
        'subtotal': subtotal,
        'taxRate': taxRate,
        'taxAmount': taxAmount,
        'total': total,
        'validUntil': validUntil.toIso8601String(),
        'status': status.value,
        'clientNotes': ?clientNotes,
        'internalNotes': ?internalNotes,
        'revisionNumber': revisionNumber,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Quotation.fromJson(String id, Map<String, dynamic> json, {String? sequence}) {
    final rawItems = json['items'];
    return Quotation(
      id: id,
      serviceRequestId: json['serviceRequestId']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      quotationNumber: json['quotationNumber']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      items: rawItems is List
          ? [
              for (final item in rawItems)
                if (item is Map<String, dynamic>) QuotationLineItem.fromJson(item)
                else if (item is Map) QuotationLineItem.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 18,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? '') ?? DateTime.now(),
      status: QuotationStatus.fromString(json['status']?.toString() ?? 'draft'),
      clientNotes: json['clientNotes']?.toString(),
      internalNotes: json['internalNotes']?.toString(),
      revisionNumber: (json['revisionNumber'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      sequence: sequence,
    );
  }

  static Quotation? tryParseMessage(String id, String payload, {String? sequence}) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return Quotation.fromJson(id, Map<String, dynamic>.from(decoded), sequence: sequence);
    } catch (_) {
      return null;
    }
  }
}
