import '../../vendors/domain/line_items.dart';

enum PurchaseOrderStatus {
  draft('draft', 'Draft'),
  issued('issued', 'Issued'),
  acknowledged('acknowledged', 'Acknowledged'),
  inProgress('in_progress', 'In progress'),
  delivered('delivered', 'Delivered'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const PurchaseOrderStatus(this.value, this.label);
  final String value;
  final String label;

  String toAppwriteString() => value;

  static PurchaseOrderStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => PurchaseOrderStatus.draft,
      );

  bool get isTerminal => this == completed || this == cancelled;

  bool canTransitionTo(PurchaseOrderStatus next) {
    if (this == next) return true;
    return switch (this) {
      PurchaseOrderStatus.draft => next == PurchaseOrderStatus.issued || next == PurchaseOrderStatus.cancelled,
      PurchaseOrderStatus.issued =>
        next == PurchaseOrderStatus.acknowledged || next == PurchaseOrderStatus.cancelled,
      PurchaseOrderStatus.acknowledged =>
        next == PurchaseOrderStatus.inProgress || next == PurchaseOrderStatus.cancelled,
      PurchaseOrderStatus.inProgress =>
        next == PurchaseOrderStatus.delivered || next == PurchaseOrderStatus.cancelled,
      PurchaseOrderStatus.delivered => next == PurchaseOrderStatus.completed,
      PurchaseOrderStatus.completed || PurchaseOrderStatus.cancelled => false,
    };
  }
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.projectId,
    required this.vendorId,
    this.rfqId,
    this.vendorQuoteId,
    required this.poNumber,
    required this.title,
    required this.items,
    required this.subtotal,
    this.taxRate = 18,
    required this.taxAmount,
    required this.total,
    required this.deliveryDate,
    required this.status,
    required this.issuedBy,
    this.issuedAt,
    this.acknowledgedAt,
    this.completedAt,
    this.notes,
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String vendorId;
  final String? rfqId;
  final String? vendorQuoteId;
  final String poNumber;
  final String title;
  final List<PricedLine> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final DateTime deliveryDate;
  final PurchaseOrderStatus status;
  final String issuedBy;
  final DateTime? issuedAt;
  final DateTime? acknowledgedAt;
  final DateTime? completedAt;
  final String? notes;
  final List<String> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'vendorId': vendorId,
        'rfqId': ?rfqId,
        'vendorQuoteId': ?vendorQuoteId,
        'poNumber': poNumber,
        'title': title,
        'items': [for (final item in items) item.toJson()],
        'subtotal': subtotal,
        'taxRate': taxRate,
        'taxAmount': taxAmount,
        'total': total,
        'deliveryDate': deliveryDate.toUtc().toIso8601String(),
        'status': status.value,
        'issuedBy': issuedBy,
        'issuedAt': issuedAt?.toUtc().toIso8601String(),
        'acknowledgedAt': acknowledgedAt?.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'notes': ?notes,
        'attachments': attachments,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory PurchaseOrder.fromJson(Map<String, dynamic> data) {
    final attachments = data['attachments'];
    return PurchaseOrder(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      vendorId: data['vendorId']?.toString() ?? '',
      rfqId: data['rfqId']?.toString(),
      vendorQuoteId: data['vendorQuoteId']?.toString(),
      poNumber: data['poNumber']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      items: pricedLinesFrom(decodeJsonList(data['items'])),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      deliveryDate: DateTime.tryParse(data['deliveryDate']?.toString() ?? '') ?? DateTime.now(),
      status: PurchaseOrderStatus.fromString(data['status']?.toString() ?? 'draft'),
      issuedBy: data['issuedBy']?.toString() ?? '',
      issuedAt: DateTime.tryParse(data['issuedAt']?.toString() ?? ''),
      acknowledgedAt: DateTime.tryParse(data['acknowledgedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(data['completedAt']?.toString() ?? ''),
      notes: data['notes']?.toString(),
      attachments: attachments is List ? attachments.map((item) => item.toString()).toList() : const [],
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
