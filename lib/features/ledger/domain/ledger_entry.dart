enum AccountType {
  client('client', 'Client'),
  vendor('vendor', 'Vendor'),
  expense('expense', 'Expense'),
  bank('bank', 'Bank'),
  cash('cash', 'Cash'),
  gst('gst', 'GST');

  const AccountType(this.value, this.label);
  final String value;
  final String label;

  static AccountType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => AccountType.client,
      );
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.entryNumber,
    required this.entryDate,
    required this.accountType,
    this.accountId,
    required this.description,
    this.debitAmount = 0,
    this.creditAmount = 0,
    required this.balance,
    this.referenceType,
    this.referenceId,
    required this.financialYear,
    this.createdAt,
  });

  final String id;
  final String entryNumber;
  final DateTime entryDate;
  final AccountType accountType;
  final String? accountId;
  final String description;
  final double debitAmount;
  final double creditAmount;
  final double balance;
  final String? referenceType;
  final String? referenceId;
  final String financialYear;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryNumber': entryNumber,
        'entryDate': entryDate.toIso8601String(),
        'accountType': accountType.value,
        'accountId': ?accountId,
        'description': description,
        'debitAmount': debitAmount,
        'creditAmount': creditAmount,
        'balance': balance,
        'referenceType': ?referenceType,
        'referenceId': ?referenceId,
        'financialYear': financialYear,
        'createdAt': ?createdAt?.toIso8601String(),
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> data) => LedgerEntry(
        id: data['id']?.toString() ?? '',
        entryNumber: data['entryNumber']?.toString() ?? '',
        entryDate: DateTime.tryParse(data['entryDate']?.toString() ?? '') ?? DateTime.now(),
        accountType: AccountType.fromString(data['accountType']?.toString()),
        accountId: data['accountId']?.toString(),
        description: data['description']?.toString() ?? '',
        debitAmount: (data['debitAmount'] as num?)?.toDouble() ?? 0,
        creditAmount: (data['creditAmount'] as num?)?.toDouble() ?? 0,
        balance: (data['balance'] as num?)?.toDouble() ?? 0,
        referenceType: data['referenceType']?.toString(),
        referenceId: data['referenceId']?.toString(),
        financialYear: data['financialYear']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}
