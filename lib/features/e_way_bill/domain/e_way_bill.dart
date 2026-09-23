enum EWayBillStatus {
  pending('pending', 'Pending'),
  generated('generated', 'Generated'),
  cancelled('cancelled', 'Cancelled'),
  expired('expired', 'Expired'),
  extended('extended', 'Extended');

  const EWayBillStatus(this.value, this.label);
  final String value;
  final String label;

  static EWayBillStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => EWayBillStatus.pending,
      );
}

enum EwbSupplyType {
  outward('outward', 'Outward'),
  inward('inward', 'Inward');

  const EwbSupplyType(this.value, this.label);
  final String value;
  final String label;

  static EwbSupplyType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => EwbSupplyType.outward,
      );
}

enum EwbSubSupplyType {
  supply('supply', 'Supply'),
  jobWork('job_work', 'Job work'),
  skdCkd('skd_ckd', 'SKD / CKD'),
  recipientNotKnown('recipient_not_known', 'Recipient not known'),
  forOwnUse('for_own_use', 'For own use');

  const EwbSubSupplyType(this.value, this.label);
  final String value;
  final String label;

  static EwbSubSupplyType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => EwbSubSupplyType.supply,
      );
}

enum EwbDocumentType {
  taxInvoice('tax_invoice', 'Tax invoice'),
  billOfSupply('bill_of_supply', 'Bill of supply'),
  deliveryChallan('delivery_challan', 'Delivery challan');

  const EwbDocumentType(this.value, this.label);
  final String value;
  final String label;

  static EwbDocumentType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => EwbDocumentType.taxInvoice,
      );
}

enum EwbTransportMode {
  road('road', 'Road'),
  rail('rail', 'Rail'),
  air('air', 'Air'),
  ship('ship', 'Ship');

  const EwbTransportMode(this.value, this.label);
  final String value;
  final String label;

  static EwbTransportMode fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => EwbTransportMode.road,
      );
}

class EWayBill {
  const EWayBill({
    required this.id,
    this.eInvoiceId,
    this.invoiceId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.ewayBillNumber,
    this.ewayBillDate,
    this.validUntil,
    required this.supplyType,
    required this.subSupplyType,
    required this.documentType,
    required this.fromGstin,
    this.fromTradeName,
    required this.fromAddress,
    required this.fromPlace,
    required this.fromPincode,
    required this.fromStateCode,
    this.toGstin,
    this.toTradeName,
    required this.toAddress,
    required this.toPlace,
    required this.toPincode,
    required this.toStateCode,
    required this.totalValue,
    required this.taxableValue,
    this.cgstValue,
    this.sgstValue,
    this.igstValue,
    this.cessValue,
    required this.hsnCode,
    this.transporterId,
    this.transporterName,
    this.transportMode,
    this.vehicleNumber,
    this.vehicleType,
    this.distance,
    required this.status,
    this.partA,
    this.partB,
    this.errorMessage,
    this.retryCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? eInvoiceId;
  final String? invoiceId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String? ewayBillNumber;
  final DateTime? ewayBillDate;
  final DateTime? validUntil;
  final EwbSupplyType supplyType;
  final EwbSubSupplyType subSupplyType;
  final EwbDocumentType documentType;
  final String fromGstin;
  final String? fromTradeName;
  final String fromAddress;
  final String fromPlace;
  final String fromPincode;
  final String fromStateCode;
  final String? toGstin;
  final String? toTradeName;
  final String toAddress;
  final String toPlace;
  final String toPincode;
  final String toStateCode;
  final double totalValue;
  final double taxableValue;
  final double? cgstValue;
  final double? sgstValue;
  final double? igstValue;
  final double? cessValue;
  final String hsnCode;
  final String? transporterId;
  final String? transporterName;
  final EwbTransportMode? transportMode;
  final String? vehicleNumber;
  final String? vehicleType;
  final int? distance;
  final EWayBillStatus status;
  final String? partA;
  final String? partB;
  final String? errorMessage;
  final int retryCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EWayBillStatus get displayStatus {
    if (status == EWayBillStatus.generated && validUntil != null && validUntil!.isBefore(DateTime.now())) {
      return EWayBillStatus.expired;
    }
    return status;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eInvoiceId': ?eInvoiceId,
        'invoiceId': ?invoiceId,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate.toIso8601String(),
        'ewayBillNumber': ?ewayBillNumber,
        'ewayBillDate': ?ewayBillDate?.toIso8601String(),
        'validUntil': ?validUntil?.toIso8601String(),
        'supplyType': supplyType.value,
        'subSupplyType': subSupplyType.value,
        'documentType': documentType.value,
        'fromGstin': fromGstin,
        'fromTradeName': ?fromTradeName,
        'fromAddress': fromAddress,
        'fromPlace': fromPlace,
        'fromPincode': fromPincode,
        'fromStateCode': fromStateCode,
        'toGstin': ?toGstin,
        'toTradeName': ?toTradeName,
        'toAddress': toAddress,
        'toPlace': toPlace,
        'toPincode': toPincode,
        'toStateCode': toStateCode,
        'totalValue': totalValue,
        'taxableValue': taxableValue,
        'cgstValue': ?cgstValue,
        'sgstValue': ?sgstValue,
        'igstValue': ?igstValue,
        'cessValue': ?cessValue,
        'hsnCode': hsnCode,
        'transporterId': ?transporterId,
        'transporterName': ?transporterName,
        'transportMode': ?transportMode?.value,
        'vehicleNumber': ?vehicleNumber,
        'vehicleType': ?vehicleType,
        'distance': ?distance,
        'status': status.value,
        'partA': ?partA,
        'partB': ?partB,
        'errorMessage': ?errorMessage,
        'retryCount': retryCount,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory EWayBill.fromJson(Map<String, dynamic> data) => EWayBill(
        id: data['id']?.toString() ?? '',
        eInvoiceId: data['eInvoiceId']?.toString(),
        invoiceId: data['invoiceId']?.toString(),
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        invoiceDate: DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
        ewayBillNumber: data['ewayBillNumber']?.toString(),
        ewayBillDate: DateTime.tryParse(data['ewayBillDate']?.toString() ?? ''),
        validUntil: DateTime.tryParse(data['validUntil']?.toString() ?? ''),
        supplyType: EwbSupplyType.fromString(data['supplyType']?.toString()),
        subSupplyType: EwbSubSupplyType.fromString(data['subSupplyType']?.toString()),
        documentType: EwbDocumentType.fromString(data['documentType']?.toString()),
        fromGstin: data['fromGstin']?.toString() ?? '',
        fromTradeName: data['fromTradeName']?.toString(),
        fromAddress: data['fromAddress']?.toString() ?? '',
        fromPlace: data['fromPlace']?.toString() ?? '',
        fromPincode: data['fromPincode']?.toString() ?? '',
        fromStateCode: data['fromStateCode']?.toString() ?? '',
        toGstin: data['toGstin']?.toString(),
        toTradeName: data['toTradeName']?.toString(),
        toAddress: data['toAddress']?.toString() ?? '',
        toPlace: data['toPlace']?.toString() ?? '',
        toPincode: data['toPincode']?.toString() ?? '',
        toStateCode: data['toStateCode']?.toString() ?? '',
        totalValue: (data['totalValue'] as num?)?.toDouble() ?? 0,
        taxableValue: (data['taxableValue'] as num?)?.toDouble() ?? 0,
        cgstValue: (data['cgstValue'] as num?)?.toDouble(),
        sgstValue: (data['sgstValue'] as num?)?.toDouble(),
        igstValue: (data['igstValue'] as num?)?.toDouble(),
        cessValue: (data['cessValue'] as num?)?.toDouble(),
        hsnCode: data['hsnCode']?.toString() ?? '',
        transporterId: data['transporterId']?.toString(),
        transporterName: data['transporterName']?.toString(),
        transportMode: data['transportMode'] == null ? null : EwbTransportMode.fromString(data['transportMode']?.toString()),
        vehicleNumber: data['vehicleNumber']?.toString(),
        vehicleType: data['vehicleType']?.toString(),
        distance: (data['distance'] as num?)?.toInt(),
        status: EWayBillStatus.fromString(data['status']?.toString()),
        partA: data['partA']?.toString(),
        partB: data['partB']?.toString(),
        errorMessage: data['errorMessage']?.toString(),
        retryCount: (data['retryCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
