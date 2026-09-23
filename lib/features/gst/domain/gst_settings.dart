class GSTSettings {
  const GSTSettings({
    required this.id,
    this.firmGstin,
    this.firmPan,
    required this.firmName,
    required this.firmAddress,
    required this.firmCity,
    required this.firmState,
    required this.firmStateCode,
    required this.firmPincode,
    this.defaultTaxRate = 18,
    this.financialYearStart = 4,
    this.financialYearEnd = 3,
    this.invoicePrefix = 'INV',
    this.creditNotePrefix = 'CN',
    this.debitNotePrefix = 'DN',
    this.fyLockedYears = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? firmGstin;
  final String? firmPan;
  final String firmName;
  final String firmAddress;
  final String firmCity;
  final String firmState;
  final String firmStateCode;
  final String firmPincode;
  final double defaultTaxRate;
  final int financialYearStart;
  final int financialYearEnd;
  final String invoicePrefix;
  final String creditNotePrefix;
  final String debitNotePrefix;
  final List<String> fyLockedYears;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GSTSettings.fromRow(String id, Map<String, dynamic> data) {
    List<String> years(Object? raw) =>
        raw is List ? raw.map((item) => item.toString()).toList() : const [];
    return GSTSettings(
      id: id,
      firmGstin: data['firmGstin']?.toString(),
      firmPan: data['firmPan']?.toString(),
      firmName: data['firmName']?.toString() ?? 'BiConcept',
      firmAddress: data['firmAddress']?.toString() ?? '',
      firmCity: data['firmCity']?.toString() ?? '',
      firmState: data['firmState']?.toString() ?? 'Tamil Nadu',
      firmStateCode: data['firmStateCode']?.toString() ?? '33',
      firmPincode: data['firmPincode']?.toString() ?? '',
      defaultTaxRate: (data['defaultTaxRate'] as num?)?.toDouble() ?? 18,
      financialYearStart: (data['financialYearStart'] as num?)?.toInt() ?? 4,
      financialYearEnd: (data['financialYearEnd'] as num?)?.toInt() ?? 3,
      invoicePrefix: data['invoicePrefix']?.toString() ?? 'INV',
      creditNotePrefix: data['creditNotePrefix']?.toString() ?? 'CN',
      debitNotePrefix: data['debitNotePrefix']?.toString() ?? 'DN',
      fyLockedYears: years(data['fyLockedYears']),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toRow() => {
        'firmGstin': ?firmGstin,
        'firmPan': ?firmPan,
        'firmName': firmName,
        'firmAddress': firmAddress,
        'firmCity': firmCity,
        'firmState': firmState,
        'firmStateCode': firmStateCode,
        'firmPincode': firmPincode,
        'defaultTaxRate': defaultTaxRate,
        'financialYearStart': financialYearStart,
        'financialYearEnd': financialYearEnd,
        'invoicePrefix': invoicePrefix,
        'creditNotePrefix': creditNotePrefix,
        'debitNotePrefix': debitNotePrefix,
        'fyLockedYears': fyLockedYears,
      };
}

enum TaxRateType {
  goods('goods', 'Goods'),
  services('services', 'Services');

  const TaxRateType(this.value, this.label);
  final String value;
  final String label;

  static TaxRateType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => TaxRateType.services,
      );
}

class TaxRate {
  const TaxRate({
    required this.id,
    required this.hsnSacCode,
    required this.description,
    required this.taxRate,
    this.cessRate,
    required this.type,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String hsnSacCode;
  final String description;
  final double taxRate;
  final double? cessRate;
  final TaxRateType type;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hsnSacCode': hsnSacCode,
        'description': description,
        'taxRate': taxRate,
        'cessRate': ?cessRate,
        'type': type.value,
        'isActive': isActive,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory TaxRate.fromJson(Map<String, dynamic> data) => TaxRate(
        id: data['id']?.toString() ?? '',
        hsnSacCode: data['hsnSacCode']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0,
        cessRate: (data['cessRate'] as num?)?.toDouble(),
        type: TaxRateType.fromString(data['type']?.toString()),
        isActive: data['isActive'] != false,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

enum GSTReturnType {
  gstr1('GSTR1', 'GSTR-1'),
  gstr3b('GSTR3B', 'GSTR-3B'),
  gstr2b('GSTR2B', 'GSTR-2B');

  const GSTReturnType(this.value, this.label);
  final String value;
  final String label;

  static GSTReturnType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => GSTReturnType.gstr1,
      );
}

enum GSTReturnStatus {
  draft('draft', 'Draft'),
  filed('filed', 'Filed'),
  acknowledged('acknowledged', 'Acknowledged');

  const GSTReturnStatus(this.value, this.label);
  final String value;
  final String label;

  static GSTReturnStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => GSTReturnStatus.draft,
      );
}

class GSTReturn {
  const GSTReturn({
    required this.id,
    required this.returnType,
    required this.period,
    required this.financialYear,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    this.totalCess = 0,
    required this.status,
    this.filedAt,
    this.acknowledgedAt,
    this.acknowledgementNumber,
    this.data,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final GSTReturnType returnType;
  final String period;
  final String financialYear;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final GSTReturnStatus status;
  final DateTime? filedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgementNumber;
  final String? data;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'returnType': returnType.value,
        'period': period,
        'financialYear': financialYear,
        'totalTaxableValue': totalTaxableValue,
        'totalCgst': totalCgst,
        'totalSgst': totalSgst,
        'totalIgst': totalIgst,
        'totalCess': totalCess,
        'status': status.value,
        'filedAt': ?filedAt?.toIso8601String(),
        'acknowledgedAt': ?acknowledgedAt?.toIso8601String(),
        'acknowledgementNumber': ?acknowledgementNumber,
        'data': ?data,
        'createdBy': createdBy,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory GSTReturn.fromJson(Map<String, dynamic> data) => GSTReturn(
        id: data['id']?.toString() ?? '',
        returnType: GSTReturnType.fromString(data['returnType']?.toString()),
        period: data['period']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        totalTaxableValue: (data['totalTaxableValue'] as num?)?.toDouble() ?? 0,
        totalCgst: (data['totalCgst'] as num?)?.toDouble() ?? 0,
        totalSgst: (data['totalSgst'] as num?)?.toDouble() ?? 0,
        totalIgst: (data['totalIgst'] as num?)?.toDouble() ?? 0,
        totalCess: (data['totalCess'] as num?)?.toDouble() ?? 0,
        status: GSTReturnStatus.fromString(data['status']?.toString()),
        filedAt: DateTime.tryParse(data['filedAt']?.toString() ?? ''),
        acknowledgedAt: DateTime.tryParse(data['acknowledgedAt']?.toString() ?? ''),
        acknowledgementNumber: data['acknowledgementNumber']?.toString(),
        data: data['data']?.toString(),
        createdBy: data['createdBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class BankStatementLine {
  const BankStatementLine({
    required this.id,
    required this.entryDate,
    required this.description,
    required this.amount,
    this.matchedReferenceId,
    this.matched = false,
  });

  final String id;
  final DateTime entryDate;
  final String description;
  final double amount;
  final String? matchedReferenceId;
  final bool matched;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryDate': entryDate.toIso8601String(),
        'description': description,
        'amount': amount,
        'matchedReferenceId': ?matchedReferenceId,
        'matched': matched,
      };

  factory BankStatementLine.fromJson(Map<String, dynamic> data) => BankStatementLine(
        id: data['id']?.toString() ?? '',
        entryDate: DateTime.tryParse(data['entryDate']?.toString() ?? '') ?? DateTime.now(),
        description: data['description']?.toString() ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        matchedReferenceId: data['matchedReferenceId']?.toString(),
        matched: data['matched'] == true,
      );
}
