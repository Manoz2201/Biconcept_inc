enum VendorPaymentStatus {
  pending('pending', 'Pending'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed');

  const VendorPaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static VendorPaymentStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => VendorPaymentStatus.pending,
      );
}

enum PaymentMethod {
  bankTransfer('bank_transfer', 'Bank transfer'),
  cheque('cheque', 'Cheque'),
  upi('upi', 'UPI'),
  cash('cash', 'Cash'),
  other('other', 'Other');

  const PaymentMethod(this.value, this.label);
  final String value;
  final String label;

  static PaymentMethod fromString(String raw) => values.firstWhere(
        (method) => method.value == raw || method.name == raw,
        orElse: () => PaymentMethod.other,
      );
}

class VendorPayment {
  const VendorPayment({
    required this.id,
    required this.vendorId,
    required this.billId,
    this.projectId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber,
    required this.status,
    required this.processedBy,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String vendorId;
  final String billId;
  final String? projectId;
  final double amount;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final VendorPaymentStatus status;
  final String processedBy;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorId': vendorId,
        'billId': billId,
        'projectId': ?projectId,
        'amount': amount,
        'paymentDate': paymentDate.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod.value,
        'referenceNumber': ?referenceNumber,
        'status': status.value,
        'processedBy': processedBy,
        'notes': ?notes,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory VendorPayment.fromJson(Map<String, dynamic> data) => VendorPayment(
        id: data['id']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        billId: data['billId']?.toString() ?? '',
        projectId: data['projectId']?.toString(),
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        paymentDate: DateTime.tryParse(data['paymentDate']?.toString() ?? '') ?? DateTime.now(),
        paymentMethod: PaymentMethod.fromString(data['paymentMethod']?.toString() ?? 'other'),
        referenceNumber: data['referenceNumber']?.toString(),
        status: VendorPaymentStatus.fromString(data['status']?.toString() ?? 'pending'),
        processedBy: data['processedBy']?.toString() ?? '',
        notes: data['notes']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
