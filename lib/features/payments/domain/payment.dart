enum PaymentMethod {
  razorpay('razorpay', 'Razorpay'),
  stripe('stripe', 'Stripe'),
  bankTransfer('bank_transfer', 'Bank transfer'),
  cheque('cheque', 'Cheque'),
  upi('upi', 'UPI'),
  cash('cash', 'Cash'),
  other('other', 'Other');

  const PaymentMethod(this.value, this.label);
  final String value;
  final String label;

  static PaymentMethod fromString(String? raw) => values.firstWhere(
        (method) => method.value == raw || method.name == raw,
        orElse: () => PaymentMethod.other,
      );
}

enum ClientPaymentStatus {
  pending('pending', 'Pending'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed'),
  refunded('refunded', 'Refunded');

  const ClientPaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static ClientPaymentStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ClientPaymentStatus.pending,
      );
}

class Payment {
  const Payment({
    required this.id,
    required this.paymentNumber,
    this.invoiceId,
    this.clientId,
    this.projectId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber,
    this.gatewayOrderId,
    this.gatewayPaymentId,
    this.gatewaySignature,
    required this.status,
    this.receiptNumber,
    this.notes,
    required this.processedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String paymentNumber;
  final String? invoiceId;
  final String? clientId;
  final String? projectId;
  final double amount;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? gatewayOrderId;
  final String? gatewayPaymentId;
  final String? gatewaySignature;
  final ClientPaymentStatus status;
  final String? receiptNumber;
  final String? notes;
  final String processedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'paymentNumber': paymentNumber,
        'invoiceId': ?invoiceId,
        'clientId': ?clientId,
        'projectId': ?projectId,
        'amount': amount,
        'paymentDate': paymentDate.toIso8601String(),
        'paymentMethod': paymentMethod.value,
        'referenceNumber': ?referenceNumber,
        'gatewayOrderId': ?gatewayOrderId,
        'gatewayPaymentId': ?gatewayPaymentId,
        'gatewaySignature': ?gatewaySignature,
        'status': status.value,
        'receiptNumber': ?receiptNumber,
        'notes': ?notes,
        'processedBy': processedBy,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory Payment.fromJson(Map<String, dynamic> data) => Payment(
        id: data['id']?.toString() ?? '',
        paymentNumber: data['paymentNumber']?.toString() ?? '',
        invoiceId: data['invoiceId']?.toString(),
        clientId: data['clientId']?.toString(),
        projectId: data['projectId']?.toString(),
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        paymentDate: DateTime.tryParse(data['paymentDate']?.toString() ?? '') ?? DateTime.now(),
        paymentMethod: PaymentMethod.fromString(data['paymentMethod']?.toString()),
        referenceNumber: data['referenceNumber']?.toString(),
        gatewayOrderId: data['gatewayOrderId']?.toString(),
        gatewayPaymentId: data['gatewayPaymentId']?.toString(),
        gatewaySignature: data['gatewaySignature']?.toString(),
        status: ClientPaymentStatus.fromString(data['status']?.toString()),
        receiptNumber: data['receiptNumber']?.toString(),
        notes: data['notes']?.toString(),
        processedBy: data['processedBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
