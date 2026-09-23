enum ReversalReason {
  rule37('rule37', 'Rule 37 — unpaid after 180 days'),
  rule42('rule42', 'Rule 42 — common credit'),
  rule43('rule43', 'Rule 43 — capital goods'),
  nonBusiness('non_business', 'Non-business use'),
  exemptSupply('exempt_supply', 'Exempt supply'),
  registrationCancellation('registration_cancellation', 'Registration cancellation');

  const ReversalReason(this.value, this.label);
  final String value;
  final String label;

  static ReversalReason fromString(String? raw) => values.firstWhere(
        (reason) => reason.value == raw || reason.name == raw,
        orElse: () => ReversalReason.rule37,
      );
}

enum ReversalStatus {
  pending('pending', 'Pending'),
  reported('reported', 'Reported'),
  adjusted('adjusted', 'Adjusted');

  const ReversalStatus(this.value, this.label);
  final String value;
  final String label;

  static ReversalStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ReversalStatus.pending,
      );
}

class ITCReversal {
  const ITCReversal({
    required this.id,
    required this.financialYear,
    required this.period,
    required this.itcLedgerId,
    required this.supplierGstin,
    required this.invoiceNumber,
    required this.reversalAmount,
    required this.cgstReversed,
    required this.sgstReversed,
    required this.igstReversed,
    required this.reversalReason,
    this.reversalRule,
    this.interestApplicable = false,
    this.interestAmount = 0,
    required this.status,
    this.reportedInReturn,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String period;
  final String itcLedgerId;
  final String supplierGstin;
  final String invoiceNumber;
  final double reversalAmount;
  final double cgstReversed;
  final double sgstReversed;
  final double igstReversed;
  final ReversalReason reversalReason;
  final String? reversalRule;
  final bool interestApplicable;
  final double interestAmount;
  final ReversalStatus status;
  final String? reportedInReturn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'period': period,
        'itcLedgerId': itcLedgerId,
        'supplierGstin': supplierGstin,
        'invoiceNumber': invoiceNumber,
        'reversalAmount': reversalAmount,
        'cgstReversed': cgstReversed,
        'sgstReversed': sgstReversed,
        'igstReversed': igstReversed,
        'reversalReason': reversalReason.value,
        'reversalRule': ?reversalRule,
        'interestApplicable': interestApplicable,
        'interestAmount': interestAmount,
        'status': status.value,
        'reportedInReturn': ?reportedInReturn,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory ITCReversal.fromJson(Map<String, dynamic> data) => ITCReversal(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        period: data['period']?.toString() ?? '',
        itcLedgerId: data['itcLedgerId']?.toString() ?? '',
        supplierGstin: data['supplierGstin']?.toString() ?? '',
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        reversalAmount: (data['reversalAmount'] as num?)?.toDouble() ?? 0,
        cgstReversed: (data['cgstReversed'] as num?)?.toDouble() ?? 0,
        sgstReversed: (data['sgstReversed'] as num?)?.toDouble() ?? 0,
        igstReversed: (data['igstReversed'] as num?)?.toDouble() ?? 0,
        reversalReason: ReversalReason.fromString(data['reversalReason']?.toString()),
        reversalRule: data['reversalRule']?.toString(),
        interestApplicable: data['interestApplicable'] == true,
        interestAmount: (data['interestAmount'] as num?)?.toDouble() ?? 0,
        status: ReversalStatus.fromString(data['status']?.toString()),
        reportedInReturn: data['reportedInReturn']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
