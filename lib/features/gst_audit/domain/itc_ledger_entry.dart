enum ITCStatus {
  eligible('eligible', 'Eligible'),
  claimed('claimed', 'Claimed'),
  reversed('reversed', 'Reversed'),
  ineligible('ineligible', 'Ineligible'),
  pending('pending', 'Pending');

  const ITCStatus(this.value, this.label);
  final String value;
  final String label;

  static ITCStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ITCStatus.pending,
      );
}

enum MatchStatus {
  matched('matched', 'Matched'),
  mismatched('mismatched', 'Mismatched'),
  missingIn2b('missing_in_2b', 'Missing in 2B'),
  missingInBooks('missing_in_books', 'Missing in books'),
  exactMatch('exact_match', 'Exact match'),
  suggestedMatch('suggested_match', 'Suggested match');

  const MatchStatus(this.value, this.label);
  final String value;
  final String label;

  static MatchStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => MatchStatus.mismatched,
      );
}

class ITCLedgerEntry {
  const ITCLedgerEntry({
    required this.id,
    required this.financialYear,
    required this.period,
    this.gstr2bId,
    required this.supplierGstin,
    required this.supplierName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    this.cessAmount = 0,
    required this.totalTax,
    required this.itcEligible,
    this.itcClaimed = 0,
    this.itcReversed = 0,
    required this.itcStatus,
    this.reversalReason,
    this.matchedBillId,
    required this.matchStatus,
    this.mismatchReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String period;
  final String? gstr2bId;
  final String supplierGstin;
  final String supplierName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double totalTax;
  final double itcEligible;
  final double itcClaimed;
  final double itcReversed;
  final ITCStatus itcStatus;
  final String? reversalReason;
  final String? matchedBillId;
  final MatchStatus matchStatus;
  final String? mismatchReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'period': period,
        'gstr2bId': ?gstr2bId,
        'supplierGstin': supplierGstin,
        'supplierName': supplierName,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate.toIso8601String(),
        'taxableValue': taxableValue,
        'cgstAmount': cgstAmount,
        'sgstAmount': sgstAmount,
        'igstAmount': igstAmount,
        'cessAmount': cessAmount,
        'totalTax': totalTax,
        'itcEligible': itcEligible,
        'itcClaimed': itcClaimed,
        'itcReversed': itcReversed,
        'itcStatus': itcStatus.value,
        'reversalReason': ?reversalReason,
        'matchedBillId': ?matchedBillId,
        'matchStatus': matchStatus.value,
        'mismatchReason': ?mismatchReason,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory ITCLedgerEntry.fromJson(Map<String, dynamic> data) => ITCLedgerEntry(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        period: data['period']?.toString() ?? '',
        gstr2bId: data['gstr2bId']?.toString(),
        supplierGstin: data['supplierGstin']?.toString() ?? '',
        supplierName: data['supplierName']?.toString() ?? '',
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        invoiceDate: DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
        taxableValue: (data['taxableValue'] as num?)?.toDouble() ?? 0,
        cgstAmount: (data['cgstAmount'] as num?)?.toDouble() ?? 0,
        sgstAmount: (data['sgstAmount'] as num?)?.toDouble() ?? 0,
        igstAmount: (data['igstAmount'] as num?)?.toDouble() ?? 0,
        cessAmount: (data['cessAmount'] as num?)?.toDouble() ?? 0,
        totalTax: (data['totalTax'] as num?)?.toDouble() ?? 0,
        itcEligible: (data['itcEligible'] as num?)?.toDouble() ?? 0,
        itcClaimed: (data['itcClaimed'] as num?)?.toDouble() ?? 0,
        itcReversed: (data['itcReversed'] as num?)?.toDouble() ?? 0,
        itcStatus: ITCStatus.fromString(data['itcStatus']?.toString()),
        reversalReason: data['reversalReason']?.toString(),
        matchedBillId: data['matchedBillId']?.toString(),
        matchStatus: MatchStatus.fromString(data['matchStatus']?.toString()),
        mismatchReason: data['mismatchReason']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  ITCLedgerEntry copyWith({
    ITCStatus? itcStatus,
    double? itcClaimed,
    double? itcReversed,
    String? reversalReason,
    MatchStatus? matchStatus,
    String? mismatchReason,
    DateTime? updatedAt,
  }) =>
      ITCLedgerEntry(
        id: id,
        financialYear: financialYear,
        period: period,
        gstr2bId: gstr2bId,
        supplierGstin: supplierGstin,
        supplierName: supplierName,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        taxableValue: taxableValue,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        igstAmount: igstAmount,
        cessAmount: cessAmount,
        totalTax: totalTax,
        itcEligible: itcEligible,
        itcClaimed: itcClaimed ?? this.itcClaimed,
        itcReversed: itcReversed ?? this.itcReversed,
        itcStatus: itcStatus ?? this.itcStatus,
        reversalReason: reversalReason ?? this.reversalReason,
        matchedBillId: matchedBillId,
        matchStatus: matchStatus ?? this.matchStatus,
        mismatchReason: mismatchReason ?? this.mismatchReason,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class ITCSummary {
  const ITCSummary({
    required this.eligible,
    required this.claimed,
    required this.reversed,
    required this.pending,
    required this.bySupplier,
  });

  final double eligible;
  final double claimed;
  final double reversed;
  final double pending;
  final Map<String, double> bySupplier;
}
