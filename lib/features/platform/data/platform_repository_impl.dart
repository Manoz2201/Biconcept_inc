import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:archive/archive.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../auth/data/audit_repository.dart';
import '../../backup/domain/backup_models.dart';
import '../../branding/domain/branding_settings.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../currency/domain/currency.dart';
import '../../currency/domain/currency_repository.dart';
import '../../currency/domain/money.dart';
import '../../gst/domain/gst_math.dart';
import '../../gst_audit/data/gst_audit_storage_service.dart';
import '../../integrations/domain/integration_models.dart';
import '../../invoices/data/invoice_workspace_store.dart';
import '../../invoices/domain/invoice.dart';
import '../../notifications/domain/notification_models.dart';
import '../../payment_schedules/domain/payment_schedule.dart';
import '../../performance/data/cache_service.dart';
import '../../performance/domain/cache_config.dart';
import '../../projects/domain/project.dart';
import '../../projects/domain/project_status.dart';
import '../../vendor_bills/domain/vendor_bill.dart';
import '../../vendors/data/vendor_workspace.dart';
import '../../vendors/data/vendor_workspace_store.dart';
import 'platform_workspace.dart';
import 'platform_workspace_store.dart';

const _secretKeys = {
  'clientSecret',
  'secret',
  'password',
  'apiKey',
  'accessToken',
  'refreshToken',
  'fcmServerKey',
  'privateKey',
};

Map<String, dynamic> stripSecrets(Map<String, dynamic> config) => {
      for (final entry in config.entries)
        if (!_secretKeys.contains(entry.key)) entry.key: entry.value,
    };

String fnvChecksum(List<int> bytes) {
  var hash = 2166136261;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String nextScheduleNumber(Iterable<PaymentSchedule> existing, DateTime now) {
  final fy = financialYearLabel(now);
  final prefix = 'PS/$fy/';
  var max = 0;
  for (final item in existing) {
    if (!item.scheduleNumber.startsWith(prefix)) continue;
    final n = int.tryParse(item.scheduleNumber.split('/').last) ?? 0;
    if (n > max) max = n;
  }
  return '$prefix${(max + 1).toString().padLeft(4, '0')}';
}

String tallyXmlExport(List<Invoice> invoices) {
  final buffer = StringBuffer()
    ..writeln('<ENVELOPE>')
    ..writeln('<HEADER><TALLYREQUEST>Import Data</TALLYREQUEST></HEADER>')
    ..writeln('<BODY><IMPORTDATA><REQUESTDATA>');
  for (final invoice in invoices) {
    buffer
      ..writeln('<TALLYMESSAGE>')
      ..writeln('<VOUCHER VCHTYPE="Sales">')
      ..writeln('<DATE>${invoice.invoiceDate.toLocal().toIso8601String().split('T').first}</DATE>')
      ..writeln('<VOUCHERNUMBER>${_xml(invoice.invoiceNumber)}</VOUCHERNUMBER>')
      ..writeln('<PARTYLEDGERNAME>${_xml(invoice.clientId)}</PARTYLEDGERNAME>')
      ..writeln('<AMOUNT>${invoice.grandTotal}</AMOUNT>')
      ..writeln('</VOUCHER></TALLYMESSAGE>');
  }
  buffer.writeln('</REQUESTDATA></IMPORTDATA></BODY></ENVELOPE>');
  return buffer.toString();
}

String _xml(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

class PlatformRepositoryImpl
    implements
        CurrencyRepository,
        PaymentScheduleRepository,
        NotificationRepository,
        IntegrationRepository,
        BrandingRepository,
        BackupRepository,
        AnalyticsRepository,
        KPIRepository,
        CacheService {
  PlatformRepositoryImpl({
    PlatformWorkspaceStore? store,
    InvoiceWorkspaceStore? invoices,
    VendorWorkspaceStore? vendors,
    GstAuditStorageService? files,
    Functions? functions,
    TablesDB? tables,
    AuditRepository? audit,
    MemoryCacheService? cache,
    String Function()? actorId,
    String Function()? actorRole,
  })  : _store = store ?? PlatformWorkspaceStore(),
        _invoices = invoices ?? InvoiceWorkspaceStore(),
        _vendors = vendors ?? VendorWorkspaceStore(),
        _files = files ?? GstAuditStorageService(),
        _functions = functions ?? AppwriteService.functions,
        _tables = tables ?? AppwriteService.tables,
        _audit = audit ?? AuditRepository(),
        _cache = cache ?? memoryCache,
        _actorId = actorId ?? (() => 'unknown'),
        _actorRole = actorRole ?? (() => 'admin');

  final PlatformWorkspaceStore _store;
  final InvoiceWorkspaceStore _invoices;
  final VendorWorkspaceStore _vendors;
  final GstAuditStorageService _files;
  final Functions _functions;
  final TablesDB _tables;
  final AuditRepository _audit;
  final MemoryCacheService _cache;
  final String Function() _actorId;
  final String Function() _actorRole;

  Future<PlatformWorkspace> _ws() async => (await _store.ensure()).workspace;

  Future<PlatformWorkspace> _save(PlatformWorkspace workspace) async =>
      (await _store.save(workspace)).workspace;

  Future<void> _log(String action, [Map<String, dynamic>? metadata]) async {
    await _audit.log(userId: _actorId(), action: action, metadata: metadata);
  }

  Future<void> _ping(String title, String body) =>
      AppNotifications.instance.showImmediate(title: title, body: body);

  T _require<T>(T? item, String label) {
    if (item == null) throw AppwriteException('$label not found', 404);
    return item;
  }

  Currency _currency(PlatformWorkspace ws, String code) {
    return _require(
      ws.currencies.cast<Currency?>().firstWhere((item) => item?.code == code.toUpperCase(), orElse: () => null),
      'Currency',
    );
  }

  Future<Map<String, dynamic>?> _fn(String id, Map<String, dynamic> body) async {
    try {
      final execution = await _functions.createExecution(functionId: id, body: jsonEncode(body));
      final decoded = jsonDecode(execution.responseBody);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  @override
  Future<AppResult<List<Currency>>> getCurrencies({bool? isActive}) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).currencies.where((item) => isActive == null || item.isActive == isActive).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      return rows;
    });
  }

  @override
  Future<AppResult<Currency>> getCurrencyByCode(String code) {
    return AppwriteService.guard(() async => _currency(await _ws(), code));
  }

  @override
  Future<AppResult<Currency>> getBaseCurrency() {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return _require(
        ws.currencies.cast<Currency?>().firstWhere((item) => item?.isBaseCurrency == true, orElse: () => null),
        'Base currency',
      );
    });
  }

  @override
  Future<AppResult<Currency>> createCurrency({
    required String code,
    required String name,
    required String symbol,
    required double exchangeRate,
    int decimalPlaces = 2,
  }) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final normalized = code.toUpperCase();
      if (ws.currencies.any((item) => item.code == normalized)) {
        throw AppwriteException('Currency $normalized already exists', 409);
      }
      final now = DateTime.now().toUtc();
      final row = Currency(
        id: ID.unique(),
        code: normalized,
        name: name,
        symbol: symbol,
        decimalPlaces: decimalPlaces,
        exchangeRate: exchangeRate,
        lastUpdated: now,
        createdAt: now,
        updatedAt: now,
      );
      await _save(ws.copyWith(currencies: [...ws.currencies, row]));
      await _log('currency_created', {'code': normalized});
      return row;
    });
  }

  @override
  Future<AppResult<Currency>> updateCurrency(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.currencies.cast<Currency?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Currency');
      final next = Currency.fromJson({...current.toJson(), ...data, 'id': id, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(currencies: [for (final item in ws.currencies) item.id == id ? next : item]));
      await _log('currency_updated', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Currency>> setBaseCurrency(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final target = _require(ws.currencies.cast<Currency?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Currency');
      final now = DateTime.now().toUtc();
      final next = [
        for (final item in ws.currencies)
          item.copyWith(isBaseCurrency: item.id == id, exchangeRate: item.id == id ? 1 : item.exchangeRate, updatedAt: now),
      ];
      await _save(ws.copyWith(currencies: next));
      await _log('base_currency_changed', {'code': target.code});
      await _notifyStaff('Base currency changed', 'Base currency is now ${target.code}', NotificationType.currencyRateUpdated);
      return next.firstWhere((item) => item.id == id);
    });
  }

  @override
  Future<AppResult<Currency>> deactivateCurrency(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.currencies.cast<Currency?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Currency');
      if (current.isBaseCurrency) throw AppwriteException('Base currency cannot be deactivated', 400);
      final next = current.copyWith(isActive: false, updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(currencies: [for (final item in ws.currencies) item.id == id ? next : item]));
      await _log('currency_deactivated', {'code': current.code});
      return next;
    });
  }

  @override
  Future<AppResult<List<ExchangeRate>>> getExchangeRateHistory(String currencyCode, {DateTime? from, DateTime? to}) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).exchangeRates.where((item) {
        if (item.currencyCode != currencyCode.toUpperCase()) return false;
        if (from != null && item.effectiveDate.isBefore(from)) return false;
        if (to != null && item.effectiveDate.isAfter(to)) return false;
        return true;
      }).toList()
        ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
      return rows;
    });
  }

  @override
  Future<AppResult<Currency>> updateExchangeRate(String currencyCode, double rate, String source) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _currency(ws, currencyCode);
      final now = DateTime.now().toUtc();
      final history = ExchangeRate(
        id: ID.unique(),
        currencyCode: current.code,
        rate: rate,
        effectiveDate: now,
        source: source,
        createdAt: now,
      );
      final next = current.copyWith(exchangeRate: rate, lastUpdated: now, updatedAt: now);
      await _save(ws.copyWith(
        currencies: [for (final item in ws.currencies) item.id == current.id ? next : item],
        exchangeRates: [...ws.exchangeRates, history],
      ));
      await _log('exchange_rate_updated', {'code': current.code, 'rate': rate, 'source': source});
      if (current.exchangeRate > 0 && (rate - current.exchangeRate).abs() / current.exchangeRate > 0.02) {
        await _notifyStaff('Exchange rate updated', '${current.code} moved more than 2%', NotificationType.currencyRateUpdated);
      }
      return next;
    });
  }

  @override
  Future<AppResult<Money>> convert(Money amount, String targetCurrencyCode) {
    return AppwriteService.guard(() async {
      final target = _currency(await _ws(), targetCurrencyCode);
      return amount.convertTo(target);
    });
  }

  @override
  Future<AppResult<String>> formatMoney(Money money, {String? locale}) {
    return AppwriteService.guard(() async => money.format(locale: locale));
  }

  @override
  Future<AppResult<List<PaymentSchedule>>> getPaymentSchedules({
    String? vendorId,
    String? projectId,
    PaymentScheduleStatus? status,
    DateTime? from,
    DateTime? to,
  }) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).paymentSchedules.where((item) {
        if (vendorId != null && item.vendorId != vendorId) return false;
        if (projectId != null && item.projectId != projectId) return false;
        if (status != null && item.status != status) return false;
        if (from != null && item.scheduledDate.isBefore(from)) return false;
        if (to != null && item.scheduledDate.isAfter(to)) return false;
        return true;
      }).toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      return rows;
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> getPaymentScheduleById(String id) {
    return AppwriteService.guard(() async {
      return _require(
        (await _ws()).paymentSchedules.cast<PaymentSchedule?>().firstWhere((item) => item?.id == id, orElse: () => null),
        'Payment schedule',
      );
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> createPaymentSchedule({
    required String vendorId,
    required List<String> billIds,
    required DateTime scheduledDate,
    required String paymentMethod,
    String? projectId,
    String? priority,
    String? notes,
    String? bankAccountId,
  }) {
    return AppwriteService.guard(() async {
      if (billIds.isEmpty) throw AppwriteException('Select at least one bill', 400);
      final vendor = await _vendors.getById(vendorId);
      final bills = [for (final id in billIds) vendor.workspace.bills.firstWhere((item) => item.id == id, orElse: () => throw AppwriteException('Bill $id not found', 404))];
      final total = bills.fold<double>(0, (sum, item) => sum + item.remaining);
      final now = DateTime.now().toUtc();
      final ws = await _ws();
      final row = PaymentSchedule(
        id: ID.unique(),
        scheduleNumber: nextScheduleNumber(ws.paymentSchedules, now),
        vendorId: vendorId,
        projectId: projectId,
        billIds: billIds,
        totalAmount: moneyRound(total),
        scheduledDate: scheduledDate,
        status: PaymentScheduleStatus.draft,
        priority: priority ?? 'normal',
        paymentMethod: paymentMethod,
        bankAccountId: bankAccountId,
        notes: notes,
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      await _save(ws.copyWith(paymentSchedules: [...ws.paymentSchedules, row]));
      await _log('payment_schedule_created', {'id': row.id, 'number': row.scheduleNumber});
      await _notifyStaff('Payment schedule created', row.scheduleNumber, NotificationType.paymentScheduleApproval);
      return row;
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> updatePaymentSchedule(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.paymentSchedules.cast<PaymentSchedule?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Payment schedule');
      if (current.status != PaymentScheduleStatus.draft) {
        throw AppwriteException('Only draft schedules can be edited', 400);
      }
      final next = PaymentSchedule.fromJson({...current.toJson(), ...data, 'id': id, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(paymentSchedules: [for (final item in ws.paymentSchedules) item.id == id ? next : item]));
      return next;
    });
  }

  Future<PaymentSchedule> _transition(String id, PaymentScheduleStatus from, PaymentScheduleStatus to, {String? notes, String? reason}) async {
    final ws = await _ws();
    final current = _require(ws.paymentSchedules.cast<PaymentSchedule?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Payment schedule');
    if (current.status != from) throw AppwriteException('Schedule is ${current.status.label}', 400);
    final now = DateTime.now().toUtc();
    final next = current.copyWith(
      status: to,
      notes: notes ?? current.notes,
      failureReason: reason,
      approvedBy: to == PaymentScheduleStatus.approved ? _actorId() : current.approvedBy,
      approvedAt: to == PaymentScheduleStatus.approved ? now : current.approvedAt,
      processedBy: to == PaymentScheduleStatus.completed || to == PaymentScheduleStatus.failed ? _actorId() : current.processedBy,
      processedAt: to == PaymentScheduleStatus.completed || to == PaymentScheduleStatus.failed ? now : current.processedAt,
      updatedAt: now,
    );
    await _save(ws.copyWith(paymentSchedules: [for (final item in ws.paymentSchedules) item.id == id ? next : item]));
    return next;
  }

  @override
  Future<AppResult<PaymentSchedule>> submitForApproval(String id) {
    return AppwriteService.guard(() async {
      final next = await _transition(id, PaymentScheduleStatus.draft, PaymentScheduleStatus.pendingApproval);
      await _log('payment_schedule_submitted', {'id': id});
      await _notifyStaff('Payment schedule needs approval', next.scheduleNumber, NotificationType.paymentScheduleApproval);
      return next;
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> approvePaymentSchedule(String id, String approverId) {
    return AppwriteService.guard(() async {
      final next = await _transition(id, PaymentScheduleStatus.pendingApproval, PaymentScheduleStatus.approved);
      await _log('payment_schedule_approved', {'id': id, 'approverId': approverId});
      return next;
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> rejectPaymentSchedule(String id, String reason) {
    return AppwriteService.guard(() async {
      final current = (await getPaymentScheduleById(id)).dataOrNull;
      if (current == null) throw AppwriteException('Payment schedule not found', 404);
      final next = await _transition(id, PaymentScheduleStatus.pendingApproval, PaymentScheduleStatus.draft, notes: '${current.notes ?? ''}\nRejected: $reason'.trim());
      await _log('payment_schedule_rejected', {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> schedulePayment(String id) {
    return AppwriteService.guard(() async {
      final next = await _transition(id, PaymentScheduleStatus.approved, PaymentScheduleStatus.scheduled);
      await _log('payment_schedule_scheduled', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> processPayment(String id) {
    return AppwriteService.guard(() async {
      var current = _require(
        (await _ws()).paymentSchedules.cast<PaymentSchedule?>().firstWhere((item) => item?.id == id, orElse: () => null),
        'Payment schedule',
      );
      if (current.status != PaymentScheduleStatus.scheduled && current.status != PaymentScheduleStatus.approved) {
        throw AppwriteException('Schedule must be approved or scheduled', 400);
      }
      if (current.status == PaymentScheduleStatus.approved) {
        current = await _transition(id, PaymentScheduleStatus.approved, PaymentScheduleStatus.scheduled);
      }
      await _transition(id, PaymentScheduleStatus.scheduled, PaymentScheduleStatus.processing);
      final remote = await _fn(AppwriteService.processPaymentScheduleFn, {'scheduleId': id});
      try {
        final vendor = await _vendors.getById(current.vendorId);
        final bills = [
          for (final bill in vendor.workspace.bills)
            if (current.billIds.contains(bill.id))
              VendorBill.fromJson({
                ...bill.toJson(),
                'paidAmount': bill.total,
                'paymentStatus': PaymentStatusFlag.paid.value,
                'status': VendorBillStatus.paid.value,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              })
            else
              bill,
        ];
        await _vendors.saveWorkspace(
          current.vendorId,
          VendorWorkspace(
            rates: vendor.workspace.rates,
            ratings: vendor.workspace.ratings,
            quotes: vendor.workspace.quotes,
            purchaseOrders: vendor.workspace.purchaseOrders,
            bills: bills,
            payments: vendor.workspace.payments,
            assignments: vendor.workspace.assignments,
          ),
        );
        final next = await _transition(id, PaymentScheduleStatus.processing, PaymentScheduleStatus.completed);
        await _log('payment_schedule_processed', {'id': id, 'remote': remote != null});
        await _notifyStaff('Payment processed', next.scheduleNumber, NotificationType.paymentReceived);
        return next;
      } catch (error) {
        final failed = await _transition(id, PaymentScheduleStatus.processing, PaymentScheduleStatus.failed, reason: '$error');
        await _log('payment_schedule_processed', {'id': id, 'failed': true});
        await _notifyStaff('Payment failed', failed.scheduleNumber, NotificationType.paymentFailed);
        return failed;
      }
    });
  }

  @override
  Future<AppResult<PaymentSchedule>> cancelPaymentSchedule(String id, String reason) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.paymentSchedules.cast<PaymentSchedule?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Payment schedule');
      if (!current.status.canCancel) throw AppwriteException('This schedule cannot be cancelled', 400);
      final next = current.copyWith(status: PaymentScheduleStatus.cancelled, notes: '${current.notes ?? ''}\nCancelled: $reason'.trim(), updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(paymentSchedules: [for (final item in ws.paymentSchedules) item.id == id ? next : item]));
      await _log('payment_schedule_cancelled', {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<BatchPaymentSummary>> batchProcess(List<String> scheduleIds) {
    return AppwriteService.guard(() async {
      final succeeded = <String>[];
      final failed = <String>[];
      final pending = <String>[];
      for (final id in scheduleIds) {
        final result = await processPayment(id);
        result.when(
          success: (row) {
            if (row.status == PaymentScheduleStatus.completed) {
              succeeded.add(id);
            } else if (row.status == PaymentScheduleStatus.failed) {
              failed.add(id);
            } else {
              pending.add(id);
            }
          },
          failure: (_) => failed.add(id),
        );
      }
      return BatchPaymentSummary(succeeded: succeeded, failed: failed, pending: pending);
    });
  }

  @override
  Future<AppResult<List<PaymentSchedule>>> getUpcomingPayments({int days = 7}) {
    return AppwriteService.guard(() async {
      final now = DateTime.now();
      final until = now.add(Duration(days: days));
      return (await _ws()).paymentSchedules.where((item) {
        final open = item.status == PaymentScheduleStatus.approved || item.status == PaymentScheduleStatus.scheduled;
        return open && !item.scheduledDate.isBefore(DateTime(now.year, now.month, now.day)) && !item.scheduledDate.isAfter(until);
      }).toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    });
  }

  @override
  Future<AppResult<Map<DateTime, List<PaymentSchedule>>>> getPaymentCalendar(DateTime month) {
    return AppwriteService.guard(() async {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      final grouped = <DateTime, List<PaymentSchedule>>{};
      for (final item in (await _ws()).paymentSchedules) {
        if (item.scheduledDate.isBefore(start) || item.scheduledDate.isAfter(end)) continue;
        final day = DateTime(item.scheduledDate.year, item.scheduledDate.month, item.scheduledDate.day);
        grouped.putIfAbsent(day, () => []).add(item);
      }
      return grouped;
    });
  }

  @override
  Future<AppResult<List<VendorBill>>> unpaidBillsForVendor(String vendorId) {
    return AppwriteService.guard(() async {
      final vendor = await _vendors.getById(vendorId);
      return vendor.workspace.bills.where((item) => item.remaining > 0 && item.status != VendorBillStatus.rejected).toList();
    });
  }

  @override
  Future<AppResult<List<NotificationLog>>> getNotifications({String? userId, NotificationStatus? status, int limit = 50}) {
    return AppwriteService.guard(() async {
      final uid = userId ?? _actorId();
      final rows = (await _ws()).notifications.where((item) {
        if (item.userId != uid) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return rows.take(limit).toList();
    });
  }

  @override
  Future<AppResult<int>> getUnreadCount() {
    return AppwriteService.guard(() async {
      final uid = _actorId();
      return (await _ws()).notifications.where((item) => item.userId == uid && item.status != NotificationStatus.read).length;
    });
  }

  @override
  Future<AppResult<NotificationLog>> markAsRead(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.notifications.cast<NotificationLog?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Notification');
      final next = current.copyWith(status: NotificationStatus.read, readAt: DateTime.now().toUtc());
      await _save(ws.copyWith(notifications: [for (final item in ws.notifications) item.id == id ? next : item]));
      await _log('notification_read', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<void>> markAllAsRead() {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final uid = _actorId();
      final now = DateTime.now().toUtc();
      await _save(ws.copyWith(notifications: [
        for (final item in ws.notifications)
          item.userId == uid && item.status != NotificationStatus.read ? item.copyWith(status: NotificationStatus.read, readAt: now) : item,
      ]));
    });
  }

  @override
  Future<AppResult<void>> deleteNotification(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(notifications: [for (final item in ws.notifications) if (item.id != id) item]));
    });
  }

  @override
  Future<AppResult<NotificationPreferences>> getNotificationPreferences() {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final uid = _actorId();
      return ws.notificationPreferences.cast<NotificationPreferences?>().firstWhere((item) => item?.userId == uid, orElse: () => null) ??
          NotificationPreferences(id: uid, userId: uid);
    });
  }

  @override
  Future<AppResult<NotificationPreferences>> updateNotificationPreferences(Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final uid = _actorId();
      final current = ws.notificationPreferences.cast<NotificationPreferences?>().firstWhere((item) => item?.userId == uid, orElse: () => null) ??
          NotificationPreferences(id: uid, userId: uid);
      final next = NotificationPreferences.fromJson({...current.toJson(), ...data, 'id': current.id, 'userId': uid, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      final exists = ws.notificationPreferences.any((item) => item.userId == uid);
      await _save(ws.copyWith(notificationPreferences: [
        if (exists) for (final item in ws.notificationPreferences) item.userId == uid ? next : item,
        if (!exists) ...ws.notificationPreferences,
        if (!exists) next,
      ]));
      await _log('notification_preferences_updated', {'userId': uid});
      return next;
    });
  }

  @override
  Future<AppResult<void>> registerFCMToken(String token, String platform) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final tokens = Map<String, Map<String, String>>.from(ws.fcmTokens);
      tokens[_actorId()] = {'token': token, 'platform': platform};
      await _save(ws.copyWith(fcmTokens: tokens));
    });
  }

  @override
  Future<AppResult<void>> unregisterFCMToken(String token) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final tokens = Map<String, Map<String, String>>.from(ws.fcmTokens)..removeWhere((_, value) => value['token'] == token);
      await _save(ws.copyWith(fcmTokens: tokens));
    });
  }

  @override
  Future<AppResult<NotificationLog>> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    NotificationType type = NotificationType.systemAlert,
  }) {
    return AppwriteService.guard(() async => _deliver(userId: userId, title: title, body: body, actionUrl: actionUrl, metadata: metadata, type: type));
  }

  Future<NotificationLog> _deliver({
    required String userId,
    required String title,
    required String body,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    required NotificationType type,
  }) async {
    final ws = await _ws();
    final prefs = ws.notificationPreferences.cast<NotificationPreferences?>().firstWhere((item) => item?.userId == userId, orElse: () => null) ??
        NotificationPreferences(id: userId, userId: userId);
    final quiet = prefs.inQuietHours(DateTime.now());
    final allowed = prefs.eventEnabled(type) && prefs.inAppEnabled && !quiet;
    final now = DateTime.now().toUtc();
    final row = NotificationLog(
      id: ID.unique(),
      userId: userId,
      title: title,
      body: body,
      type: type,
      channel: NotificationChannel.inApp,
      status: allowed ? NotificationStatus.delivered : NotificationStatus.queued,
      actionUrl: actionUrl,
      metadata: metadata == null ? null : jsonEncode(metadata),
      sentAt: now,
      deliveredAt: allowed ? now : null,
      createdAt: now,
    );
    await _save(ws.copyWith(notifications: [row, ...ws.notifications].take(400).toList()));
    if (allowed && prefs.pushEnabled) {
      await _fn(AppwriteService.sendPushNotificationFn, {'userId': userId, 'title': title, 'body': body, 'actionUrl': actionUrl, 'metadata': metadata});
      await _ping(title, body);
    }
    return row;
  }

  Future<void> _notifyStaff(String title, String body, NotificationType type) async {
    await _deliver(userId: _actorId(), title: title, body: body, type: type);
  }

  @override
  Future<AppResult<List<NotificationLog>>> getNotificationLog({String? userId, NotificationChannel? channel, NotificationStatus? status}) {
    return getNotifications(userId: userId, status: status);
  }

  @override
  Future<AppResult<List<IntegrationConfig>>> getIntegrations({IntegrationProvider? provider, bool? isActive}) {
    return AppwriteService.guard(() async {
      return (await _ws()).integrations.where((item) {
        if (provider != null && item.provider != provider) return false;
        if (isActive != null && item.isActive != isActive) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<IntegrationConfig>> getIntegrationById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).integrations.cast<IntegrationConfig?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Integration');
    });
  }

  @override
  Future<AppResult<IntegrationConfig>> createIntegration({
    required IntegrationProvider provider,
    required String displayName,
    required Map<String, dynamic> config,
  }) {
    return AppwriteService.guard(() async {
      final now = DateTime.now().toUtc();
      final row = IntegrationConfig(
        id: ID.unique(),
        provider: provider,
        displayName: displayName,
        config: stripSecrets(config),
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(integrations: [...ws.integrations, row]));
      await _log('integration_created', {'id': row.id, 'provider': provider.value});
      return row;
    });
  }

  @override
  Future<AppResult<IntegrationConfig>> updateIntegration(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.integrations.cast<IntegrationConfig?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Integration');
      final merged = {...current.toJson(), ...data, 'id': id};
      if (data['config'] is Map) merged['config'] = stripSecrets(Map<String, dynamic>.from(data['config'] as Map));
      final next = IntegrationConfig.fromJson(merged);
      await _save(ws.copyWith(integrations: [for (final item in ws.integrations) item.id == id ? next : item]));
      await _log('integration_updated', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<IntegrationConfig>> toggleIntegration(String id, bool isActive) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.integrations.cast<IntegrationConfig?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Integration');
      final next = current.copyWith(isActive: isActive, updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(integrations: [for (final item in ws.integrations) item.id == id ? next : item]));
      if (!isActive) await _log('integration_disabled', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteIntegration(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(integrations: [for (final item in ws.integrations) if (item.id != id) item]));
    });
  }

  @override
  Future<AppResult<bool>> testConnection(String id) {
    return AppwriteService.guard(() async {
      final item = _require((await _ws()).integrations.cast<IntegrationConfig?>().firstWhere((row) => row?.id == id, orElse: () => null), 'Integration');
      final remote = await _fn(AppwriteService.integrationSyncFn, {'integrationId': id, 'syncType': 'test'});
      return remote?['ok'] == true || item.config.isNotEmpty || item.provider == IntegrationProvider.tally;
    });
  }

  @override
  Future<AppResult<SyncLog>> syncNow(String id, {String syncType = 'incremental'}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final item = _require(ws.integrations.cast<IntegrationConfig?>().firstWhere((row) => row?.id == id, orElse: () => null), 'Integration');
      final now = DateTime.now().toUtc();
      final remote = await _fn(AppwriteService.integrationSyncFn, {'integrationId': id, 'syncType': syncType});
      final processed = (remote?['recordsProcessed'] as num?)?.toInt() ?? 0;
      final succeeded = (remote?['recordsSucceeded'] as num?)?.toInt() ?? processed;
      final failed = (remote?['recordsFailed'] as num?)?.toInt() ?? 0;
      final log = SyncLog(
        id: ID.unique(),
        integrationId: id,
        provider: item.provider.value,
        syncType: syncType,
        direction: item.syncDirection,
        entityType: 'invoice',
        recordsProcessed: processed,
        recordsSucceeded: succeeded,
        recordsFailed: failed,
        startedAt: now,
        completedAt: DateTime.now().toUtc(),
        status: failed > 0 ? SyncStatus.partial : SyncStatus.success,
        createdAt: now,
      );
      final updated = item.copyWith(
        lastSyncAt: log.completedAt,
        lastSyncStatus: log.status.value,
        updatedAt: log.completedAt,
      );
      await _save(ws.copyWith(
        integrations: [for (final row in ws.integrations) row.id == id ? updated : row],
        syncLogs: [log, ...ws.syncLogs],
      ));
      await _log('integration_synced', {'id': id});
      if (failed > 0) {
        await _notifyStaff('Integration sync failed', item.displayName, NotificationType.integrationSyncFailed);
      }
      return log;
    });
  }

  @override
  Future<AppResult<List<SyncLog>>> getSyncLogs(String integrationId, {int limit = 50}) {
    return AppwriteService.guard(() async {
      return (await _ws()).syncLogs.where((item) => item.integrationId == integrationId).take(limit).toList();
    });
  }

  @override
  Future<AppResult<String>> exportToTally({DateTime? from, DateTime? to}) {
    return AppwriteService.guard(() async {
      final invoices = [for (final row in await _invoices.list()) row.invoice].where((item) {
        if (from != null && item.invoiceDate.isBefore(from)) return false;
        if (to != null && item.invoiceDate.isAfter(to)) return false;
        return item.status != InvoiceStatus.voided && item.status != InvoiceStatus.cancelled;
      }).toList();
      return tallyXmlExport(invoices);
    });
  }

  @override
  Future<AppResult<String>> exportToZohoBooks({DateTime? from, DateTime? to}) {
    return exportToTally(from: from, to: to);
  }

  @override
  Future<AppResult<String>> exportToQuickBooks({DateTime? from, DateTime? to}) {
    return exportToTally(from: from, to: to);
  }

  @override
  Future<AppResult<int>> syncCalendarEvents({DateTime? from, DateTime? to}) {
    return AppwriteService.guard(() async {
      final remote = await _fn(AppwriteService.integrationSyncFn, {'syncType': 'calendar', 'from': from?.toIso8601String(), 'to': to?.toIso8601String()});
      return (remote?['recordsSucceeded'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Future<AppResult<BrandingSettings>> getBrandingSettings() {
    return AppwriteService.guard(() async => (await _ws()).branding);
  }

  @override
  Future<AppResult<BrandingSettings>> updateBrandingSettings(Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final next = BrandingSettings.fromJson({...ws.branding.toJson(), ...data, 'id': 'firm', 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(branding: next));
      await _log('branding_updated', {'firmName': next.firmName});
      await _notifyStaff('Branding updated', next.firmName, NotificationType.systemAlert);
      return next;
    });
  }

  Future<BrandingSettings> _uploadBrand(UploadBytes file, Map<String, dynamic> patch) async {
    validateUpload(file.bytes, file.filename);
    final created = await AppwriteService.storage.createFile(
      bucketId: AppwriteService.portfolioImagesBucket,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: Uint8List.fromList(file.bytes), filename: sanitizeUploadName(file.filename)),
      permissions: [
        Permission.read(Role.team(AppwriteService.teamStaff)),
        Permission.update(Role.team(AppwriteService.teamStaff, 'admin')),
      ],
    );
    return (await updateBrandingSettings({...patch, patch.keys.first: created.$id})).when(
      success: (data) => data,
      failure: (error) => throw AppwriteException(error.userMessage, 400),
    );
  }

  @override
  Future<AppResult<BrandingSettings>> uploadLogo(UploadBytes file, {bool isDark = false}) {
    return AppwriteService.guard(() async => _uploadBrand(file, {isDark ? 'logoDarkFileId' : 'logoFileId': ''}));
  }

  @override
  Future<AppResult<BrandingSettings>> uploadFavicon(UploadBytes file) {
    return AppwriteService.guard(() async => _uploadBrand(file, {'faviconFileId': ''}));
  }

  @override
  Future<AppResult<BrandingSettings>> resetToDefaults() {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(branding: BrandingSettings.defaults));
      await _log('branding_updated', {'reset': true});
      return BrandingSettings.defaults;
    });
  }

  @override
  Future<AppResult<BrandingSettings>> verifyCustomDomain(String token) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final expected = 'biconcept-verify=${ws.branding.id}';
      if (token.trim() != expected) throw AppwriteException('DNS TXT record does not match $expected', 400);
      return (await updateBrandingSettings({'domainVerified': true})).when(
        success: (data) => data,
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  @override
  Future<AppResult<List<BackupJob>>> getBackupJobs({bool? isActive}) {
    return AppwriteService.guard(() async {
      return (await _ws()).backupJobs.where((item) => isActive == null || item.isActive == isActive).toList();
    });
  }

  @override
  Future<AppResult<BackupJob>> getBackupJobById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).backupJobs.cast<BackupJob?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Backup job');
    });
  }

  @override
  Future<AppResult<BackupJob>> createBackupJob({
    required String jobName,
    required BackupJobType jobType,
    required String frequency,
    required int retentionDays,
    required String storageLocation,
    List<String>? entities,
    Map<String, dynamic>? storageConfig,
    bool encryptionEnabled = true,
    bool compressionEnabled = true,
  }) {
    return AppwriteService.guard(() async {
      final now = DateTime.now().toUtc();
      final row = BackupJob(
        id: ID.unique(),
        jobName: jobName,
        jobType: jobType,
        entities: entities,
        frequency: frequency,
        retentionDays: retentionDays,
        storageLocation: storageLocation,
        storageConfig: storageConfig,
        encryptionEnabled: encryptionEnabled,
        compressionEnabled: compressionEnabled,
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(backupJobs: [...ws.backupJobs, row]));
      await _log('backup_job_created', {'id': row.id});
      return row;
    });
  }

  @override
  Future<AppResult<BackupJob>> updateBackupJob(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.backupJobs.cast<BackupJob?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Backup job');
      final next = BackupJob.fromJson({...current.toJson(), ...data, 'id': id, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(backupJobs: [for (final item in ws.backupJobs) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteBackupJob(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(backupJobs: [for (final item in ws.backupJobs) if (item.id != id) item]));
    });
  }

  @override
  Future<AppResult<BackupHistory>> runBackupNow(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final job = _require(ws.backupJobs.cast<BackupJob?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Backup job');
      await _fn(AppwriteService.createBackupFn, {'backupJobId': id});
      final now = DateTime.now().toUtc();
      final payload = utf8.encode(ws.encode());
      final bytes = job.compressionEnabled ? (GZipEncoder().encode(payload) ?? payload) : payload;
      final fileId = await _files.upload(UploadBytes(bytes: bytes, filename: 'backup-${job.id}-$now.zip'));
      final history = BackupHistory(
        id: ID.unique(),
        backupJobId: id,
        fileName: 'backup-${job.jobName}-$now.zip',
        fileId: fileId,
        fileSize: bytes.length,
        entities: job.entities ?? const ['platform'],
        recordCount: ws.currencies.length + ws.paymentSchedules.length + ws.integrations.length,
        encryptionEnabled: job.encryptionEnabled,
        compressionEnabled: job.compressionEnabled,
        status: BackupStatus.completed,
        startedAt: now,
        completedAt: DateTime.now().toUtc(),
        checksum: fnvChecksum(bytes),
        createdAt: now,
      );
      final updatedJob = BackupJob.fromJson({...job.toJson(), 'lastRunAt': now.toIso8601String(), 'lastRunStatus': 'success', 'lastRunSize': bytes.length});
      await _save(ws.copyWith(backupJobs: [for (final item in ws.backupJobs) item.id == id ? updatedJob : item], backupHistory: [history, ...ws.backupHistory]));
      await _log('backup_completed', {'id': history.id});
      await _notifyStaff('Backup completed', job.jobName, NotificationType.backupCompleted);
      return history;
    });
  }

  @override
  Future<AppResult<List<BackupHistory>>> getBackupHistory({String? backupJobId}) {
    return AppwriteService.guard(() async {
      return (await _ws()).backupHistory.where((item) => backupJobId == null || item.backupJobId == backupJobId).toList();
    });
  }

  @override
  Future<AppResult<RestorePreview>> restoreFromBackup(String backupHistoryId, {bool dryRun = false}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final history = _require(ws.backupHistory.cast<BackupHistory?>().firstWhere((item) => item?.id == backupHistoryId, orElse: () => null), 'Backup');
      final bytes = await _files.download(history.fileId);
      final raw = history.compressionEnabled ? GZipDecoder().decodeBytes(bytes) : bytes;
      final decoded = PlatformWorkspace.decode(utf8.decode(raw));
      final preview = RestorePreview(
        recordCount: decoded.currencies.length + decoded.paymentSchedules.length,
        entities: history.entities,
        checksumOk: history.checksum == null || history.checksum == fnvChecksum(bytes),
      );
      if (dryRun) return preview;
      await _fn(AppwriteService.restoreBackupFn, {'backupHistoryId': backupHistoryId});
      final now = DateTime.now().toUtc();
      await _save(decoded.copyWith(
        backupHistory: [
          for (final item in ws.backupHistory) item.id == backupHistoryId ? item.copyWith(status: BackupStatus.restored, restoredAt: now, restoredBy: _actorId()) : item,
        ],
        backupJobs: ws.backupJobs,
      ));
      await _log('backup_restored', {'id': backupHistoryId});
      await _notifyStaff('Restore completed', history.fileName, NotificationType.backupCompleted);
      return preview;
    });
  }

  @override
  Future<AppResult<String>> downloadBackup(String backupHistoryId) {
    return AppwriteService.guard(() async {
      final history = _require((await _ws()).backupHistory.cast<BackupHistory?>().firstWhere((item) => item?.id == backupHistoryId, orElse: () => null), 'Backup');
      return '${Env.appwriteEndpoint}/storage/buckets/${AppwriteService.portfolioImagesBucket}/files/${history.fileId}/view?project=${Env.appwriteProjectId}';
    });
  }

  @override
  Future<AppResult<void>> deleteBackup(String backupHistoryId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(backupHistory: [for (final item in ws.backupHistory) if (item.id != backupHistoryId) item]));
      await _log('backup_deleted', {'id': backupHistoryId});
    });
  }

  @override
  Future<AppResult<bool>> verifyBackup(String backupHistoryId) {
    return AppwriteService.guard(() async {
      final preview = await restoreFromBackup(backupHistoryId, dryRun: true);
      return preview.when(success: (data) => data.checksumOk, failure: (error) => throw AppwriteException(error.userMessage, 400));
    });
  }

  @override
  Future<AppResult<AnalyticsEvent>> trackEvent({required String eventName, Map<String, dynamic>? properties, String? page}) {
    return AppwriteService.guard(() async {
      final now = DateTime.now().toUtc();
      final admin = _actorRole() == 'admin' || _actorRole() == 'superAdmin' || _actorRole() == 'super_admin';
      final row = AnalyticsEvent(
        id: ID.unique(),
        eventName: eventName,
        userId: admin ? _actorId() : null,
        userRole: _actorRole(),
        properties: properties,
        page: page,
        timestamp: now,
        createdAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(analyticsEvents: [row, ...ws.analyticsEvents].take(200).toList()));
      return row;
    });
  }

  @override
  Future<AppResult<void>> trackScreenView(String screenName) async {
    final result = await trackEvent(eventName: 'screen_view', page: screenName);
    return result.when(success: (_) => const Success(null), failure: Failure.new);
  }

  @override
  Future<AppResult<void>> trackButtonClick(String buttonName, Map<String, dynamic>? metadata) async {
    final result = await trackEvent(eventName: 'button_click', properties: {'button': buttonName, ...?metadata});
    return result.when(success: (_) => const Success(null), failure: Failure.new);
  }

  @override
  Future<AppResult<void>> trackError(String errorType, String message) async {
    final result = await trackEvent(eventName: 'error_occurred', properties: {'errorType': errorType, 'message': message});
    return result.when(success: (_) => const Success(null), failure: Failure.new);
  }

  @override
  Future<AppResult<List<KPIMetric>>> getKPIMetrics({String? metricName, String? period, DateTime? from, DateTime? to}) {
    return AppwriteService.guard(() async {
      return (await _ws()).kpiMetrics.where((item) {
        if (metricName != null && item.metricName != metricName) return false;
        if (period != null && item.period != period) return false;
        if (from != null && item.periodStart.isBefore(from)) return false;
        if (to != null && item.periodEnd.isAfter(to)) return false;
        return true;
      }).toList()
        ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    });
  }

  @override
  Future<AppResult<List<KPIMetric>>> getKPITrend(String metricName, {int periods = 12}) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).kpiMetrics.where((item) => item.metricName == metricName).toList()
        ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
      return rows.take(periods).toList();
    });
  }

  @override
  Future<AppResult<List<CohortData>>> getCohortAnalysis({String cohortType = 'client_signup', String period = 'monthly'}) {
    return AppwriteService.guard(() async {
      final invoices = [for (final row in await _invoices.list()) row.invoice];
      final groups = <String, List<Invoice>>{};
      for (final invoice in invoices) {
        final key = '${invoice.invoiceDate.year}-${invoice.invoiceDate.month.toString().padLeft(2, '0')}';
        groups.putIfAbsent(key, () => []).add(invoice);
      }
      return [
        for (final entry in groups.entries)
          CohortData(
            cohortName: entry.key,
            cohortDate: DateTime.tryParse('${entry.key}-01') ?? DateTime.now(),
            size: {for (final item in entry.value) item.clientId}.length,
            retentionRates: {0: 1, 1: entry.value.any((item) => item.status == InvoiceStatus.paid) ? 0.6 : 0.3},
            revenueLTV: entry.value.fold<double>(0, (sum, item) => sum + item.grandTotal) / ({for (final item in entry.value) item.clientId}.length.clamp(1, 9999)),
            avgProjectValue: entry.value.fold<double>(0, (sum, item) => sum + item.grandTotal) / entry.value.length.clamp(1, 9999),
          ),
      ];
    });
  }

  @override
  Future<AppResult<FunnelData>> getFunnelAnalysis(String funnelName) {
    return AppwriteService.guard(() async {
      final enquiries = await _count(AppwriteService.enquiriesCol);
      final requests = await _count(AppwriteService.serviceRequestsCol);
      final projects = await _listProjects();
      final invoices = [for (final row in await _invoices.list()) row.invoice];
      return switch (funnelName) {
        'quote_to_payment' => buildFunnel('quote_to_payment', [
            ('Quotation sent', invoices.length),
            ('Invoice issued', invoices.where((item) => item.status != InvoiceStatus.draft).length),
            ('Payment received', invoices.where((item) => item.status == InvoiceStatus.paid || item.status == InvoiceStatus.partiallyPaid).length),
          ]),
        'project_delivery' => buildFunnel('project_delivery', [
            ('Project created', projects.length),
            ('In progress', projects.where((item) => item.status == ProjectStatus.inProgress || item.status == ProjectStatus.review).length),
            ('Completed', projects.where((item) => item.status == ProjectStatus.completed).length),
          ]),
        _ => buildFunnel('lead_to_project', [
            ('Enquiry', enquiries),
            ('Service request', requests),
            ('Project', projects.length),
          ]),
      };
    });
  }

  Future<int> _count(String tableId) async {
    try {
      final page = await _tables.listRows(databaseId: AppwriteService.dbId, tableId: tableId, queries: [Query.limit(1)]);
      return page.total;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Project>> _listProjects() async {
    try {
      final page = await _tables.listRows(databaseId: AppwriteService.dbId, tableId: AppwriteService.projectsCol, queries: [Query.limit(100)]);
      return [for (final row in page.rows) Project.fromRow(row.$id, row.data)];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<AppResult<RevenueAnalytics>> getRevenueAnalytics({DateTime? from, DateTime? to, String groupBy = 'month'}) {
    return AppwriteService.guard(() async {
      final invoices = [for (final row in await _invoices.list()) row.invoice].where((item) {
        if (item.status == InvoiceStatus.voided || item.status == InvoiceStatus.cancelled) return false;
        if (from != null && item.invoiceDate.isBefore(from)) return false;
        if (to != null && item.invoiceDate.isAfter(to)) return false;
        return true;
      }).toList();
      final byPeriod = <String, double>{};
      final top = <String, double>{};
      var outstanding = 0.0;
      for (final invoice in invoices) {
        final key = '${invoice.invoiceDate.year}-${invoice.invoiceDate.month.toString().padLeft(2, '0')}';
        byPeriod[key] = (byPeriod[key] ?? 0) + invoice.grandTotal;
        top[invoice.clientId] = (top[invoice.clientId] ?? 0) + invoice.grandTotal;
        outstanding += (invoice.grandTotal - invoice.paidAmount).clamp(0, invoice.grandTotal);
      }
      final total = invoices.fold<double>(0, (sum, item) => sum + item.grandTotal);
      return RevenueAnalytics(
        totalRevenue: total,
        avgInvoiceValue: invoices.isEmpty ? 0 : total / invoices.length,
        outstanding: outstanding,
        byPeriod: byPeriod,
        topClients: top,
      );
    });
  }

  @override
  Future<AppResult<UserAnalytics>> getUserAnalytics({DateTime? from, DateTime? to}) {
    return AppwriteService.guard(() async {
      final events = (await _ws()).analyticsEvents.where((item) {
        if (from != null && item.timestamp.isBefore(from)) return false;
        if (to != null && item.timestamp.isAfter(to)) return false;
        return true;
      });
      final now = DateTime.now();
      bool within(Duration span, AnalyticsEvent item) => item.timestamp.isAfter(now.subtract(span));
      final usage = <String, int>{};
      for (final event in events) {
        usage[event.eventName] = (usage[event.eventName] ?? 0) + 1;
      }
      return UserAnalytics(
        dau: events.where((item) => within(const Duration(days: 1), item)).map((item) => item.userId ?? item.sessionId ?? item.id).toSet().length,
        wau: events.where((item) => within(const Duration(days: 7), item)).map((item) => item.userId ?? item.sessionId ?? item.id).toSet().length,
        mau: events.where((item) => within(const Duration(days: 30), item)).map((item) => item.userId ?? item.sessionId ?? item.id).toSet().length,
        featureUsage: usage,
      );
    });
  }

  @override
  Future<AppResult<String>> exportAnalyticsReport({required String reportType, DateTime? from, DateTime? to}) {
    return AppwriteService.guard(() async {
      final kpis = (await _ws()).kpiMetrics;
      await _log('analytics_report_exported', {'type': reportType});
      return 'metric,value,period\n${[for (final item in kpis) '${item.metricName},${item.metricValue},${item.period}'].join('\n')}';
    });
  }

  @override
  Future<AppResult<List<KPIMetric>>> getKPIs({String? period, DateTime? periodStart}) {
    return getKPIMetrics(period: period, from: periodStart);
  }

  @override
  Future<AppResult<KPIMetric>> getKPIByName(String metricName, {String? dimension, String? dimensionValue}) {
    return AppwriteService.guard(() async {
      return _require(
        (await _ws()).kpiMetrics.cast<KPIMetric?>().firstWhere(
              (item) => item?.metricName == metricName && (dimension == null || item?.dimension == dimension),
              orElse: () => null,
            ),
        'KPI',
      );
    });
  }

  @override
  Future<AppResult<List<KPIMetric>>> computeKPIs() {
    return AppwriteService.guard(() async {
      await _fn(AppwriteService.computeKpiMetricsFn, {});
      final invoices = [for (final row in await _invoices.list()) row.invoice];
      final projects = await _listProjects();
      final now = DateTime.now().toUtc();
      final start = DateTime(now.year, now.month, 1);
      final revenue = invoices.where((item) => item.status != InvoiceStatus.voided && !item.invoiceDate.isBefore(start)).fold<double>(0, (sum, item) => sum + item.grandTotal);
      final completed = projects.where((item) => item.status == ProjectStatus.completed).length;
      final ws = await _ws();
      KPIMetric metric(String name, double value, String unit) {
        final previous = ws.kpiMetrics.cast<KPIMetric?>().firstWhere((item) => item?.metricName == name && item?.periodStart != start, orElse: () => null);
        final change = previous == null || previous.metricValue == 0 ? null : ((value - previous.metricValue) / previous.metricValue) * 100;
        final target = ws.kpiTargets[name];
        return KPIMetric(
          id: '${name}_${start.toIso8601String()}',
          metricName: name,
          metricValue: value,
          metricUnit: unit,
          period: 'monthly',
          periodStart: start,
          periodEnd: DateTime(now.year, now.month + 1, 0),
          comparisonValue: previous?.metricValue,
          changePercent: change,
          target: target,
          status: kpiStatusFor(value: value, target: target),
          createdAt: now,
          updatedAt: now,
        );
      }

      final rows = [
        metric('revenue', revenue, 'INR'),
        metric('active_projects', projects.where((item) => !item.status.isTerminal).length.toDouble(), 'count'),
        metric('project_completion_rate', projects.isEmpty ? 0 : completed / projects.length * 100, 'percent'),
        metric('avg_project_duration_days', _avgDuration(projects), 'days'),
        metric('leads_converted', (await _count(AppwriteService.enquiriesCol)).toDouble(), 'count'),
      ];
      final merged = [
        for (final item in ws.kpiMetrics)
          if (!rows.any((row) => row.id == item.id)) item,
        ...rows,
      ];
      await _save(ws.copyWith(kpiMetrics: merged));
      return rows;
    });
  }

  double _avgDuration(List<Project> projects) {
    final done = projects.where((item) => item.actualEndDate != null);
    if (done.isEmpty) return 0;
    final days = done.map((item) => item.actualEndDate!.difference(item.startDate).inDays).fold<int>(0, (sum, item) => sum + item);
    return days / done.length;
  }

  @override
  Future<AppResult<KPIMetric>> setKPITarget(String metricName, double target) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final targets = Map<String, double>.from(ws.kpiTargets)..[metricName] = target;
      final current = ws.kpiMetrics.cast<KPIMetric?>().firstWhere((item) => item?.metricName == metricName, orElse: () => null);
      final updated = current?.copyWith(target: target, status: kpiStatusFor(value: current.metricValue, target: target), updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(
        kpiTargets: targets,
        kpiMetrics: updated == null ? ws.kpiMetrics : [for (final item in ws.kpiMetrics) item.id == updated.id ? updated : item],
      ));
      await _log('kpi_target_set', {'metric': metricName, 'target': target});
      if (updated != null && updated.status == 'off_track') {
        await _notifyStaff('KPI target missed', metricName, NotificationType.systemAlert);
      }
      return updated ??
          KPIMetric(
            id: metricName,
            metricName: metricName,
            metricValue: 0,
            period: 'monthly',
            periodStart: DateTime.now(),
            periodEnd: DateTime.now(),
            target: target,
            status: 'at_risk',
          );
    });
  }

  @override
  Future<AppResult<String>> getKPIStatus(String metricName) {
    return AppwriteService.guard(() async {
      final item = (await _ws()).kpiMetrics.cast<KPIMetric?>().firstWhere((row) => row?.metricName == metricName, orElse: () => null);
      return item?.status ?? kpiStatusFor(value: item?.metricValue ?? 0, target: (await _ws()).kpiTargets[metricName]);
    });
  }

  @override
  Future<void> init() => _cache.init();

  @override
  T? get<T>(String key, {Duration? ttl}) => _cache.get<T>(key, ttl: ttl);

  @override
  void put<T>(String key, T value, {Duration? ttl}) => _cache.put(key, value, ttl: ttl);

  @override
  void delete(String key) => _cache.delete(key);

  @override
  void clear() => _cache.clear();

  @override
  void clearExpired() => _cache.clearExpired();

  @override
  void enqueue(OfflineAction action) => _cache.enqueue(action);

  @override
  OfflineAction? dequeue() => _cache.dequeue();

  @override
  List<OfflineAction> getAll() => _cache.getAll();

  @override
  void clearQueue() => _cache.clearQueue();
}
