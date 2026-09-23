import '../../vendors/domain/line_items.dart';

enum VendorBillStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  underReview('under_review', 'Under review'),
  approved('approved', 'Approved'),
  partiallyPaid('partially_paid', 'Partially paid'),
  paid('paid', 'Paid'),
  rejected('rejected', 'Rejected');

  const VendorBillStatus(this.value, this.label);
  final String value;
  final String label;

  static VendorBillStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => VendorBillStatus.draft,
      );
}

enum PaymentStatusFlag {
  unpaid('unpaid', 'Unpaid'),
  partial('partial', 'Partial'),
  paid('paid', 'Paid');

  const PaymentStatusFlag(this.value, this.label);
  final String value;
  final String label;

  static PaymentStatusFlag fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => PaymentStatusFlag.unpaid,
      );
}

class VendorBill {
  const VendorBill({
    required this.id,
    required this.vendorId,
    this.projectId,
    this.purchaseOrderId,
    required this.billNumber,
    required this.billDate,
    required this.dueDate,
    required this.items,
    required this.subtotal,
    this.taxRate = 18,
    required this.taxAmount,
    required this.total,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.paidAmount = 0,
    this.paymentStatus = PaymentStatusFlag.unpaid,
    this.attachmentId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String vendorId;
  final String? projectId;
  final String? purchaseOrderId;
  final String billNumber;
  final DateTime billDate;
  final DateTime dueDate;
  final List<PricedLine> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final VendorBillStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final double paidAmount;
  final PaymentStatusFlag paymentStatus;
  final String? attachmentId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get remaining => (total - paidAmount).clamp(0, total);

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorId': vendorId,
        'projectId': ?projectId,
        'purchaseOrderId': ?purchaseOrderId,
        'billNumber': billNumber,
        'billDate': billDate.toUtc().toIso8601String(),
        'dueDate': dueDate.toUtc().toIso8601String(),
        'items': [for (final item in items) item.toJson()],
        'subtotal': subtotal,
        'taxRate': taxRate,
        'taxAmount': taxAmount,
        'total': total,
        'status': status.value,
        'approvedBy': ?approvedBy,
        'approvedAt': approvedAt?.toUtc().toIso8601String(),
        'paidAmount': paidAmount,
        'paymentStatus': paymentStatus.value,
        'attachmentId': ?attachmentId,
        'notes': ?notes,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory VendorBill.fromJson(Map<String, dynamic> data) => VendorBill(
        id: data['id']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        projectId: data['projectId']?.toString(),
        purchaseOrderId: data['purchaseOrderId']?.toString(),
        billNumber: data['billNumber']?.toString() ?? '',
        billDate: DateTime.tryParse(data['billDate']?.toString() ?? '') ?? DateTime.now(),
        dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? DateTime.now(),
        items: pricedLinesFrom(decodeJsonList(data['items'])),
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18,
        taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
        total: (data['total'] as num?)?.toDouble() ?? 0,
        status: VendorBillStatus.fromString(data['status']?.toString() ?? 'draft'),
        approvedBy: data['approvedBy']?.toString(),
        approvedAt: DateTime.tryParse(data['approvedAt']?.toString() ?? ''),
        paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
        paymentStatus: PaymentStatusFlag.fromString(data['paymentStatus']?.toString()),
        attachmentId: data['attachmentId']?.toString(),
        notes: data['notes']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
