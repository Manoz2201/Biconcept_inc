enum ExpenseCategory {
  material('material', 'Material'),
  labour('labour', 'Labour'),
  travel('travel', 'Travel'),
  office('office', 'Office'),
  software('software', 'Software'),
  other('other', 'Other');

  const ExpenseCategory(this.value, this.label);
  final String value;
  final String label;

  static ExpenseCategory fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => ExpenseCategory.other,
      );
}

enum ExpenseStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  reimbursed('reimbursed', 'Reimbursed');

  const ExpenseStatus(this.value, this.label);
  final String value;
  final String label;

  static ExpenseStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ExpenseStatus.draft,
      );
}

enum ExpensePaymentStatus {
  unpaid('unpaid', 'Unpaid'),
  paid('paid', 'Paid'),
  partiallyPaid('partially_paid', 'Partially paid');

  const ExpensePaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static ExpensePaymentStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ExpensePaymentStatus.unpaid,
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.expenseNumber,
    this.projectId,
    required this.category,
    required this.description,
    required this.amount,
    this.gstAmount = 0,
    required this.totalAmount,
    required this.expenseDate,
    this.vendorId,
    this.billId,
    required this.paymentStatus,
    this.paymentMethod,
    this.receiptId,
    this.approvedBy,
    this.approvedAt,
    required this.status,
    required this.createdBy,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String expenseNumber;
  final String? projectId;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final double gstAmount;
  final double totalAmount;
  final DateTime expenseDate;
  final String? vendorId;
  final String? billId;
  final ExpensePaymentStatus paymentStatus;
  final String? paymentMethod;
  final String? receiptId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final ExpenseStatus status;
  final String createdBy;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseNumber': expenseNumber,
        'projectId': ?projectId,
        'category': category.value,
        'description': description,
        'amount': amount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
        'expenseDate': expenseDate.toIso8601String(),
        'vendorId': ?vendorId,
        'billId': ?billId,
        'paymentStatus': paymentStatus.value,
        'paymentMethod': ?paymentMethod,
        'receiptId': ?receiptId,
        'approvedBy': ?approvedBy,
        'approvedAt': ?approvedAt?.toIso8601String(),
        'status': status.value,
        'createdBy': createdBy,
        'notes': ?notes,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> data) => Expense(
        id: data['id']?.toString() ?? '',
        expenseNumber: data['expenseNumber']?.toString() ?? '',
        projectId: data['projectId']?.toString(),
        category: ExpenseCategory.fromString(data['category']?.toString()),
        description: data['description']?.toString() ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        gstAmount: (data['gstAmount'] as num?)?.toDouble() ?? 0,
        totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
        expenseDate: DateTime.tryParse(data['expenseDate']?.toString() ?? '') ?? DateTime.now(),
        vendorId: data['vendorId']?.toString(),
        billId: data['billId']?.toString(),
        paymentStatus: ExpensePaymentStatus.fromString(data['paymentStatus']?.toString()),
        paymentMethod: data['paymentMethod']?.toString(),
        receiptId: data['receiptId']?.toString(),
        approvedBy: data['approvedBy']?.toString(),
        approvedAt: DateTime.tryParse(data['approvedAt']?.toString() ?? ''),
        status: ExpenseStatus.fromString(data['status']?.toString()),
        createdBy: data['createdBy']?.toString() ?? '',
        notes: data['notes']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
