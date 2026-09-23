enum GSTR9Status {
  draft('draft', 'Draft'),
  prepared('prepared', 'Prepared'),
  filed('filed', 'Filed'),
  acknowledged('acknowledged', 'Acknowledged');

  const GSTR9Status(this.value, this.label);
  final String value;
  final String label;

  static GSTR9Status fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => GSTR9Status.draft,
      );
}

class GSTR9Return {
  const GSTR9Return({
    required this.id,
    required this.financialYear,
    required this.gstin,
    required this.legalName,
    this.tradeName,
    this.part1BasicDetails,
    this.part2OutwardSupplies,
    this.part3ITC,
    this.part4TaxPaid,
    this.part5Transactions,
    this.part6Other,
    required this.totalTurnover,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    this.totalCess = 0,
    required this.totalItcClaimed,
    required this.totalItcReversed,
    required this.netTaxPayable,
    required this.status,
    this.filedAt,
    this.acknowledgementNumber,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String gstin;
  final String legalName;
  final String? tradeName;
  final String? part1BasicDetails;
  final String? part2OutwardSupplies;
  final String? part3ITC;
  final String? part4TaxPaid;
  final String? part5Transactions;
  final String? part6Other;
  final double totalTurnover;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalItcClaimed;
  final double totalItcReversed;
  final double netTaxPayable;
  final GSTR9Status status;
  final DateTime? filedAt;
  final String? acknowledgementNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'gstin': gstin,
        'legalName': legalName,
        'tradeName': ?tradeName,
        'part1BasicDetails': ?part1BasicDetails,
        'part2OutwardSupplies': ?part2OutwardSupplies,
        'part3ITC': ?part3ITC,
        'part4TaxPaid': ?part4TaxPaid,
        'part5Transactions': ?part5Transactions,
        'part6Other': ?part6Other,
        'totalTurnover': totalTurnover,
        'totalTaxableValue': totalTaxableValue,
        'totalCgst': totalCgst,
        'totalSgst': totalSgst,
        'totalIgst': totalIgst,
        'totalCess': totalCess,
        'totalItcClaimed': totalItcClaimed,
        'totalItcReversed': totalItcReversed,
        'netTaxPayable': netTaxPayable,
        'status': status.value,
        'filedAt': ?filedAt?.toIso8601String(),
        'acknowledgementNumber': ?acknowledgementNumber,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory GSTR9Return.fromJson(Map<String, dynamic> data) => GSTR9Return(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        gstin: data['gstin']?.toString() ?? '',
        legalName: data['legalName']?.toString() ?? '',
        tradeName: data['tradeName']?.toString(),
        part1BasicDetails: data['part1BasicDetails']?.toString(),
        part2OutwardSupplies: data['part2OutwardSupplies']?.toString(),
        part3ITC: data['part3ITC']?.toString(),
        part4TaxPaid: data['part4TaxPaid']?.toString(),
        part5Transactions: data['part5Transactions']?.toString(),
        part6Other: data['part6Other']?.toString(),
        totalTurnover: (data['totalTurnover'] as num?)?.toDouble() ?? 0,
        totalTaxableValue: (data['totalTaxableValue'] as num?)?.toDouble() ?? 0,
        totalCgst: (data['totalCgst'] as num?)?.toDouble() ?? 0,
        totalSgst: (data['totalSgst'] as num?)?.toDouble() ?? 0,
        totalIgst: (data['totalIgst'] as num?)?.toDouble() ?? 0,
        totalCess: (data['totalCess'] as num?)?.toDouble() ?? 0,
        totalItcClaimed: (data['totalItcClaimed'] as num?)?.toDouble() ?? 0,
        totalItcReversed: (data['totalItcReversed'] as num?)?.toDouble() ?? 0,
        netTaxPayable: (data['netTaxPayable'] as num?)?.toDouble() ?? 0,
        status: GSTR9Status.fromString(data['status']?.toString()),
        filedAt: DateTime.tryParse(data['filedAt']?.toString() ?? ''),
        acknowledgementNumber: data['acknowledgementNumber']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

enum GSTR9CStatus {
  draft('draft', 'Draft'),
  prepared('prepared', 'Prepared'),
  selfCertified('self_certified', 'Self-certified'),
  filed('filed', 'Filed');

  const GSTR9CStatus(this.value, this.label);
  final String value;
  final String label;

  static GSTR9CStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => GSTR9CStatus.draft,
      );
}

class GSTR9CReconciliation {
  const GSTR9CReconciliation({
    required this.id,
    required this.financialYear,
    required this.gstr9Id,
    required this.reconciliationData,
    required this.turnoverAsPerAudited,
    required this.turnoverAsPerReturns,
    required this.difference,
    this.reasonForDifference,
    required this.taxableTurnoverAudited,
    required this.taxableTurnoverReturns,
    required this.itcAsPerAudited,
    required this.itcAsPerReturns,
    required this.itcDifference,
    this.itcReason,
    required this.status,
    this.certifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String gstr9Id;
  final String reconciliationData;
  final double turnoverAsPerAudited;
  final double turnoverAsPerReturns;
  final double difference;
  final String? reasonForDifference;
  final double taxableTurnoverAudited;
  final double taxableTurnoverReturns;
  final double itcAsPerAudited;
  final double itcAsPerReturns;
  final double itcDifference;
  final String? itcReason;
  final GSTR9CStatus status;
  final DateTime? certifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'gstr9Id': gstr9Id,
        'reconciliationData': reconciliationData,
        'turnoverAsPerAudited': turnoverAsPerAudited,
        'turnoverAsPerReturns': turnoverAsPerReturns,
        'difference': difference,
        'reasonForDifference': ?reasonForDifference,
        'taxableTurnoverAudited': taxableTurnoverAudited,
        'taxableTurnoverReturns': taxableTurnoverReturns,
        'itcAsPerAudited': itcAsPerAudited,
        'itcAsPerReturns': itcAsPerReturns,
        'itcDifference': itcDifference,
        'itcReason': ?itcReason,
        'status': status.value,
        'certifiedAt': ?certifiedAt?.toIso8601String(),
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory GSTR9CReconciliation.fromJson(Map<String, dynamic> data) => GSTR9CReconciliation(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        gstr9Id: data['gstr9Id']?.toString() ?? '',
        reconciliationData: data['reconciliationData']?.toString() ?? '{}',
        turnoverAsPerAudited: (data['turnoverAsPerAudited'] as num?)?.toDouble() ?? 0,
        turnoverAsPerReturns: (data['turnoverAsPerReturns'] as num?)?.toDouble() ?? 0,
        difference: (data['difference'] as num?)?.toDouble() ?? 0,
        reasonForDifference: data['reasonForDifference']?.toString(),
        taxableTurnoverAudited: (data['taxableTurnoverAudited'] as num?)?.toDouble() ?? 0,
        taxableTurnoverReturns: (data['taxableTurnoverReturns'] as num?)?.toDouble() ?? 0,
        itcAsPerAudited: (data['itcAsPerAudited'] as num?)?.toDouble() ?? 0,
        itcAsPerReturns: (data['itcAsPerReturns'] as num?)?.toDouble() ?? 0,
        itcDifference: (data['itcDifference'] as num?)?.toDouble() ?? 0,
        itcReason: data['itcReason']?.toString(),
        status: GSTR9CStatus.fromString(data['status']?.toString()),
        certifiedAt: DateTime.tryParse(data['certifiedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
