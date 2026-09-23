enum EInvoiceStatus {
  pending('pending', 'Pending'),
  generated('generated', 'Generated'),
  cancelled('cancelled', 'Cancelled'),
  failed('failed', 'Failed');

  const EInvoiceStatus(this.value, this.label);
  final String value;
  final String label;

  static EInvoiceStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => EInvoiceStatus.pending,
      );
}

class EInvoice {
  const EInvoice({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.irn,
    this.ackNumber,
    this.ackDate,
    this.qrCode,
    this.signedInvoice,
    this.signedQrCode,
    required this.status,
    this.errorMessage,
    this.retryCount = 0,
    this.irpResponse,
    this.cancelledAt,
    this.cancelReason,
    this.cancelRemarks,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String invoiceId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String? irn;
  final String? ackNumber;
  final DateTime? ackDate;
  final String? qrCode;
  final String? signedInvoice;
  final String? signedQrCode;
  final EInvoiceStatus status;
  final String? errorMessage;
  final int retryCount;
  final String? irpResponse;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelRemarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate.toIso8601String(),
        'irn': ?irn,
        'ackNumber': ?ackNumber,
        'ackDate': ?ackDate?.toIso8601String(),
        'qrCode': ?qrCode,
        'signedInvoice': ?signedInvoice,
        'signedQrCode': ?signedQrCode,
        'status': status.value,
        'errorMessage': ?errorMessage,
        'retryCount': retryCount,
        'irpResponse': ?irpResponse,
        'cancelledAt': ?cancelledAt?.toIso8601String(),
        'cancelReason': ?cancelReason,
        'cancelRemarks': ?cancelRemarks,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory EInvoice.fromJson(Map<String, dynamic> data) => EInvoice(
        id: data['id']?.toString() ?? '',
        invoiceId: data['invoiceId']?.toString() ?? '',
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        invoiceDate: DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
        irn: data['irn']?.toString(),
        ackNumber: data['ackNumber']?.toString(),
        ackDate: DateTime.tryParse(data['ackDate']?.toString() ?? ''),
        qrCode: data['qrCode']?.toString(),
        signedInvoice: data['signedInvoice']?.toString(),
        signedQrCode: data['signedQrCode']?.toString(),
        status: EInvoiceStatus.fromString(data['status']?.toString()),
        errorMessage: data['errorMessage']?.toString(),
        retryCount: (data['retryCount'] as num?)?.toInt() ?? 0,
        irpResponse: data['irpResponse']?.toString(),
        cancelledAt: DateTime.tryParse(data['cancelledAt']?.toString() ?? ''),
        cancelReason: data['cancelReason']?.toString(),
        cancelRemarks: data['cancelRemarks']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class IrpSettings {
  const IrpSettings({
    this.environment = 'sandbox',
    this.autoGenerate = false,
  });

  final String environment;
  final bool autoGenerate;

  Map<String, dynamic> toJson() => {'environment': environment, 'autoGenerate': autoGenerate};

  factory IrpSettings.fromJson(Map<String, dynamic>? data) => IrpSettings(
        environment: data?['environment']?.toString() ?? 'sandbox',
        autoGenerate: data?['autoGenerate'] == true,
      );
}
