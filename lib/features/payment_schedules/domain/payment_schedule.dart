import '../../currency/domain/currency.dart';
import '../../currency/domain/money.dart';
import '../../vendor_bills/domain/vendor_bill.dart';
import '../../../core/result/app_result.dart';

enum PaymentScheduleStatus {
  draft('draft', 'Draft'),
  pendingApproval('pending_approval', 'Pending approval'),
  approved('approved', 'Approved'),
  scheduled('scheduled', 'Scheduled'),
  processing('processing', 'Processing'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  failed('failed', 'Failed');

  const PaymentScheduleStatus(this.value, this.label);
  final String value;
  final String label;

  static PaymentScheduleStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => PaymentScheduleStatus.draft,
      );

  bool get canCancel =>
      this == draft || this == pendingApproval || this == approved || this == scheduled;
}

class PaymentSchedule {
  const PaymentSchedule({
    required this.id,
    required this.scheduleNumber,
    required this.vendorId,
    this.projectId,
    required this.billIds,
    required this.totalAmount,
    this.currencyCode = 'INR',
    required this.scheduledDate,
    required this.status,
    this.priority = 'normal',
    required this.paymentMethod,
    this.bankAccountId,
    this.approvedBy,
    this.approvedAt,
    this.processedBy,
    this.processedAt,
    this.failureReason,
    this.notes,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String scheduleNumber;
  final String vendorId;
  final String? projectId;
  final List<String> billIds;
  final double totalAmount;
  final String currencyCode;
  final DateTime scheduledDate;
  final PaymentScheduleStatus status;
  final String priority;
  final String paymentMethod;
  final String? bankAccountId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? processedBy;
  final DateTime? processedAt;
  final String? failureReason;
  final String? notes;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Money money(Currency currency) => Money(totalAmount, currency);

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduleNumber': scheduleNumber,
        'vendorId': vendorId,
        'projectId': ?projectId,
        'billIds': billIds,
        'totalAmount': totalAmount,
        'currency': currencyCode,
        'scheduledDate': scheduledDate.toUtc().toIso8601String(),
        'status': status.value,
        'priority': priority,
        'paymentMethod': paymentMethod,
        'bankAccountId': ?bankAccountId,
        'approvedBy': ?approvedBy,
        'approvedAt': ?approvedAt?.toUtc().toIso8601String(),
        'processedBy': ?processedBy,
        'processedAt': ?processedAt?.toUtc().toIso8601String(),
        'failureReason': ?failureReason,
        'notes': ?notes,
        'createdBy': createdBy,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory PaymentSchedule.fromJson(Map<String, dynamic> data) => PaymentSchedule(
        id: data['id']?.toString() ?? '',
        scheduleNumber: data['scheduleNumber']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        projectId: data['projectId']?.toString(),
        billIds: [
          if (data['billIds'] is List)
            for (final item in data['billIds'] as List) item.toString(),
        ],
        totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
        currencyCode: (data['currency']?.toString() ?? 'INR').toUpperCase(),
        scheduledDate: DateTime.tryParse(data['scheduledDate']?.toString() ?? '') ?? DateTime.now(),
        status: PaymentScheduleStatus.fromString(data['status']?.toString()),
        priority: data['priority']?.toString() ?? 'normal',
        paymentMethod: data['paymentMethod']?.toString() ?? 'bank_transfer',
        bankAccountId: data['bankAccountId']?.toString(),
        approvedBy: data['approvedBy']?.toString(),
        approvedAt: DateTime.tryParse(data['approvedAt']?.toString() ?? ''),
        processedBy: data['processedBy']?.toString(),
        processedAt: DateTime.tryParse(data['processedAt']?.toString() ?? ''),
        failureReason: data['failureReason']?.toString(),
        notes: data['notes']?.toString(),
        createdBy: data['createdBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  PaymentSchedule copyWith({
    PaymentScheduleStatus? status,
    String? notes,
    String? approvedBy,
    DateTime? approvedAt,
    String? processedBy,
    DateTime? processedAt,
    String? failureReason,
    DateTime? scheduledDate,
    DateTime? updatedAt,
  }) =>
      PaymentSchedule(
        id: id,
        scheduleNumber: scheduleNumber,
        vendorId: vendorId,
        projectId: projectId,
        billIds: billIds,
        totalAmount: totalAmount,
        currencyCode: currencyCode,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        status: status ?? this.status,
        priority: priority,
        paymentMethod: paymentMethod,
        bankAccountId: bankAccountId,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedAt: approvedAt ?? this.approvedAt,
        processedBy: processedBy ?? this.processedBy,
        processedAt: processedAt ?? this.processedAt,
        failureReason: failureReason ?? this.failureReason,
        notes: notes ?? this.notes,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class BatchPaymentSummary {
  const BatchPaymentSummary({
    required this.succeeded,
    required this.failed,
    required this.pending,
  });

  final List<String> succeeded;
  final List<String> failed;
  final List<String> pending;
}

abstract class PaymentScheduleRepository {
  Future<AppResult<List<PaymentSchedule>>> getPaymentSchedules({
    String? vendorId,
    String? projectId,
    PaymentScheduleStatus? status,
    DateTime? from,
    DateTime? to,
  });
  Future<AppResult<PaymentSchedule>> getPaymentScheduleById(String id);
  Future<AppResult<PaymentSchedule>> createPaymentSchedule({
    required String vendorId,
    required List<String> billIds,
    required DateTime scheduledDate,
    required String paymentMethod,
    String? projectId,
    String? priority,
    String? notes,
    String? bankAccountId,
  });
  Future<AppResult<PaymentSchedule>> updatePaymentSchedule(String id, Map<String, dynamic> data);
  Future<AppResult<PaymentSchedule>> submitForApproval(String id);
  Future<AppResult<PaymentSchedule>> approvePaymentSchedule(String id, String approverId);
  Future<AppResult<PaymentSchedule>> rejectPaymentSchedule(String id, String reason);
  Future<AppResult<PaymentSchedule>> schedulePayment(String id);
  Future<AppResult<PaymentSchedule>> processPayment(String id);
  Future<AppResult<PaymentSchedule>> cancelPaymentSchedule(String id, String reason);
  Future<AppResult<BatchPaymentSummary>> batchProcess(List<String> scheduleIds);
  Future<AppResult<List<PaymentSchedule>>> getUpcomingPayments({int days = 7});
  Future<AppResult<Map<DateTime, List<PaymentSchedule>>>> getPaymentCalendar(DateTime month);
  Future<AppResult<List<VendorBill>>> unpaidBillsForVendor(String vendorId);
}
