enum TdsSection {
  section194C('194C', '194C — contractors'),
  section194J('194J', '194J — professional'),
  section194I('194I', '194I — rent'),
  section194A('194A', '194A — interest'),
  section194H('194H', '194H — commission'),
  section194O('194O', '194O — e-commerce');

  const TdsSection(this.value, this.label);
  final String value;
  final String label;

  static TdsSection fromString(String? raw) => values.firstWhere(
        (section) => section.value == raw || section.name == raw,
        orElse: () => TdsSection.section194J,
      );
}

enum TdsDeducteeType {
  individual('individual', 'Individual'),
  company('company', 'Company'),
  firm('firm', 'Firm'),
  huf('huf', 'HUF');

  const TdsDeducteeType(this.value, this.label);
  final String value;
  final String label;

  static TdsDeducteeType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => TdsDeducteeType.firm,
      );
}

enum Tds194JKind { technical, professional }

enum Tds194IKind { plantMachinery, landBuilding }

enum TDSStatus {
  pending('pending', 'Pending'),
  deducted('deducted', 'Deducted'),
  deposited('deposited', 'Deposited'),
  certificateIssued('certificate_issued', 'Certificate issued');

  const TDSStatus(this.value, this.label);
  final String value;
  final String label;

  static TDSStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => TDSStatus.pending,
      );
}

class TDSDeduction {
  const TDSDeduction({
    required this.id,
    required this.section,
    required this.financialYear,
    required this.quarter,
    this.deducteeId,
    required this.deducteeName,
    required this.deducteePan,
    required this.deducteeType,
    this.invoiceId,
    this.billId,
    this.paymentId,
    required this.invoiceDate,
    this.paymentDate,
    required this.grossAmount,
    required this.tdsRate,
    required this.tdsAmount,
    required this.netPayable,
    this.thresholdLimit,
    this.thresholdCrossed = false,
    required this.status,
    this.challanNumber,
    this.challanDate,
    this.certificateNumber,
    this.certificateDate,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final TdsSection section;
  final String financialYear;
  final String quarter;
  final String? deducteeId;
  final String deducteeName;
  final String deducteePan;
  final TdsDeducteeType deducteeType;
  final String? invoiceId;
  final String? billId;
  final String? paymentId;
  final DateTime invoiceDate;
  final DateTime? paymentDate;
  final double grossAmount;
  final double tdsRate;
  final double tdsAmount;
  final double netPayable;
  final double? thresholdLimit;
  final bool thresholdCrossed;
  final TDSStatus status;
  final String? challanNumber;
  final DateTime? challanDate;
  final String? certificateNumber;
  final DateTime? certificateDate;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'section': section.value,
        'financialYear': financialYear,
        'quarter': quarter,
        'deducteeId': ?deducteeId,
        'deducteeName': deducteeName,
        'deducteePan': deducteePan,
        'deducteeType': deducteeType.value,
        'invoiceId': ?invoiceId,
        'billId': ?billId,
        'paymentId': ?paymentId,
        'invoiceDate': invoiceDate.toIso8601String(),
        'paymentDate': ?paymentDate?.toIso8601String(),
        'grossAmount': grossAmount,
        'tdsRate': tdsRate,
        'tdsAmount': tdsAmount,
        'netPayable': netPayable,
        'thresholdLimit': ?thresholdLimit,
        'thresholdCrossed': thresholdCrossed,
        'status': status.value,
        'challanNumber': ?challanNumber,
        'challanDate': ?challanDate?.toIso8601String(),
        'certificateNumber': ?certificateNumber,
        'certificateDate': ?certificateDate?.toIso8601String(),
        'remarks': ?remarks,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory TDSDeduction.fromJson(Map<String, dynamic> data) => TDSDeduction(
        id: data['id']?.toString() ?? '',
        section: TdsSection.fromString(data['section']?.toString()),
        financialYear: data['financialYear']?.toString() ?? '',
        quarter: data['quarter']?.toString() ?? 'Q1',
        deducteeId: data['deducteeId']?.toString(),
        deducteeName: data['deducteeName']?.toString() ?? '',
        deducteePan: data['deducteePan']?.toString() ?? '',
        deducteeType: TdsDeducteeType.fromString(data['deducteeType']?.toString()),
        invoiceId: data['invoiceId']?.toString(),
        billId: data['billId']?.toString(),
        paymentId: data['paymentId']?.toString(),
        invoiceDate: DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
        paymentDate: DateTime.tryParse(data['paymentDate']?.toString() ?? ''),
        grossAmount: (data['grossAmount'] as num?)?.toDouble() ?? 0,
        tdsRate: (data['tdsRate'] as num?)?.toDouble() ?? 0,
        tdsAmount: (data['tdsAmount'] as num?)?.toDouble() ?? 0,
        netPayable: (data['netPayable'] as num?)?.toDouble() ?? 0,
        thresholdLimit: (data['thresholdLimit'] as num?)?.toDouble(),
        thresholdCrossed: data['thresholdCrossed'] == true,
        status: TDSStatus.fromString(data['status']?.toString()),
        challanNumber: data['challanNumber']?.toString(),
        challanDate: DateTime.tryParse(data['challanDate']?.toString() ?? ''),
        certificateNumber: data['certificateNumber']?.toString(),
        certificateDate: DateTime.tryParse(data['certificateDate']?.toString() ?? ''),
        remarks: data['remarks']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class TDSSummary {
  const TDSSummary({
    required this.gross,
    required this.tds,
    required this.net,
    required this.bySection,
  });

  final double gross;
  final double tds;
  final double net;
  final Map<String, double> bySection;
}

enum GSTTDSStatus {
  pending('pending', 'Pending'),
  deducted('deducted', 'Deducted'),
  deposited('deposited', 'Deposited'),
  returnFiled('return_filed', 'Return filed');

  const GSTTDSStatus(this.value, this.label);
  final String value;
  final String label;

  static GSTTDSStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => GSTTDSStatus.pending,
      );
}

class GSTTDS {
  const GSTTDS({
    required this.id,
    required this.financialYear,
    required this.period,
    this.contractId,
    required this.vendorId,
    required this.vendorGstin,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.taxableValue,
    required this.contractValue,
    this.tdsRate = 2,
    this.cgstTds = 0,
    this.sgstTds = 0,
    this.igstTds = 0,
    required this.totalTds,
    required this.status,
    this.challanNumber,
    this.challanDate,
    this.gstr7Filed = false,
    this.gstr7Period,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String period;
  final String? contractId;
  final String vendorId;
  final String vendorGstin;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double taxableValue;
  final double contractValue;
  final double tdsRate;
  final double cgstTds;
  final double sgstTds;
  final double igstTds;
  final double totalTds;
  final GSTTDSStatus status;
  final String? challanNumber;
  final DateTime? challanDate;
  final bool gstr7Filed;
  final String? gstr7Period;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'period': period,
        'contractId': ?contractId,
        'vendorId': vendorId,
        'vendorGstin': vendorGstin,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate.toIso8601String(),
        'taxableValue': taxableValue,
        'contractValue': contractValue,
        'tdsRate': tdsRate,
        'cgstTds': cgstTds,
        'sgstTds': sgstTds,
        'igstTds': igstTds,
        'totalTds': totalTds,
        'status': status.value,
        'challanNumber': ?challanNumber,
        'challanDate': ?challanDate?.toIso8601String(),
        'gstr7Filed': gstr7Filed,
        'gstr7Period': ?gstr7Period,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory GSTTDS.fromJson(Map<String, dynamic> data) => GSTTDS(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        period: data['period']?.toString() ?? '',
        contractId: data['contractId']?.toString(),
        vendorId: data['vendorId']?.toString() ?? '',
        vendorGstin: data['vendorGstin']?.toString() ?? '',
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        invoiceDate: DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
        taxableValue: (data['taxableValue'] as num?)?.toDouble() ?? 0,
        contractValue: (data['contractValue'] as num?)?.toDouble() ?? 0,
        tdsRate: (data['tdsRate'] as num?)?.toDouble() ?? 2,
        cgstTds: (data['cgstTds'] as num?)?.toDouble() ?? 0,
        sgstTds: (data['sgstTds'] as num?)?.toDouble() ?? 0,
        igstTds: (data['igstTds'] as num?)?.toDouble() ?? 0,
        totalTds: (data['totalTds'] as num?)?.toDouble() ?? 0,
        status: GSTTDSStatus.fromString(data['status']?.toString()),
        challanNumber: data['challanNumber']?.toString(),
        challanDate: DateTime.tryParse(data['challanDate']?.toString() ?? ''),
        gstr7Filed: data['gstr7Filed'] == true,
        gstr7Period: data['gstr7Period']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
