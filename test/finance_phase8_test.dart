import 'package:biconcept/features/analytics/domain/analytics_models.dart';
import 'package:biconcept/features/currency/domain/currency.dart';
import 'package:biconcept/features/currency/domain/money.dart';
import 'package:biconcept/features/notifications/domain/notification_models.dart';
import 'package:biconcept/features/payment_schedules/domain/payment_schedule.dart';
import 'package:biconcept/features/platform/data/platform_repository_impl.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 4, 1);
  final inr = defaultCurrencies(now).firstWhere((item) => item.isBaseCurrency);
  final usd = defaultCurrencies(now).firstWhere((item) => item.code == 'USD');

  test('Money arithmetic and conversion', () {
    final a = Money(100, usd);
    final b = Money(50, usd);
    expect((a + b).amount, 150);
    expect((a - b).amount, 50);
    expect((a * 2).amount, 200);
    expect((a / 4).amount, 25);
    expect(() => a + Money(1, inr), throwsArgumentError);
    expect(a.convertTo(inr).amount, 8350);
    expect(a.toBase(inr).amount, 8350);
    expect(a.format().startsWith(r'$'), isTrue);
  });

  test('only one seeded base currency and INR rate is 1', () {
    final rows = defaultCurrencies(now);
    expect(rows.where((item) => item.isBaseCurrency).length, 1);
    expect(inr.exchangeRate, 1);
    expect(inr.code, 'INR');
  });

  test('schedule numbers increment inside the financial year', () {
    final first = nextScheduleNumber(const [], now);
    expect(first, 'PS/2026-27/0001');
    final second = nextScheduleNumber([
      PaymentSchedule(
        id: '1',
        scheduleNumber: first,
        vendorId: 'v',
        billIds: const [],
        totalAmount: 10,
        scheduledDate: now,
        status: PaymentScheduleStatus.draft,
        paymentMethod: 'bank_transfer',
        createdBy: 'u',
      ),
    ], now);
    expect(second, 'PS/2026-27/0002');
  });

  test('schedule cancel is blocked after processing', () {
    expect(PaymentScheduleStatus.draft.canCancel, isTrue);
    expect(PaymentScheduleStatus.scheduled.canCancel, isTrue);
    expect(PaymentScheduleStatus.processing.canCancel, isFalse);
    expect(PaymentScheduleStatus.completed.canCancel, isFalse);
  });

  test('integration config drops secrets', () {
    final clean = stripSecrets({'host': 'http://tally', 'clientSecret': 'x', 'accessToken': 'y'});
    expect(clean['host'], 'http://tally');
    expect(clean.containsKey('clientSecret'), isFalse);
    expect(clean.containsKey('accessToken'), isFalse);
  });

  test('quiet hours wrap midnight', () {
    const prefs = NotificationPreferences(id: 'u', userId: 'u', quietHoursStart: '22:00', quietHoursEnd: '07:00');
    expect(prefs.inQuietHours(DateTime(2026, 4, 1, 23)), isTrue);
    expect(prefs.inQuietHours(DateTime(2026, 4, 1, 6)), isTrue);
    expect(prefs.inQuietHours(DateTime(2026, 4, 1, 10)), isFalse);
  });

  test('funnel and KPI status helpers', () {
    final funnel = buildFunnel('lead_to_project', [('Enquiry', 10), ('Request', 5), ('Project', 2)]);
    expect(funnel.steps.length, 3);
    expect(funnel.conversionRate, 0.2);
    expect(funnel.steps[1].conversionFromPrevious, 0.5);
    expect(kpiStatusFor(value: 100, target: 80), 'on_track');
    expect(kpiStatusFor(value: 85, target: 100), 'at_risk');
    expect(kpiStatusFor(value: 50, target: 100), 'off_track');
  });

  test('checksum is stable', () {
    expect(fnvChecksum([1, 2, 3]), fnvChecksum([1, 2, 3]));
    expect(fnvChecksum([1, 2, 3]), isNot(fnvChecksum([3, 2, 1])));
  });

  test('phase 8 role mapping', () {
    expect(hasPermission(UserRole.accountant, Permission.paymentScheduleApprove), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.brandingEdit), isFalse);
    expect(hasPermission(UserRole.architect, Permission.analyticsView), isTrue);
    expect(hasPermission(UserRole.architect, Permission.backupRestore), isFalse);
    expect(hasPermission(UserRole.client, Permission.notificationPreferenceEdit), isTrue);
    expect(hasPermission(UserRole.client, Permission.backupView), isFalse);
    expect(hasPermission(UserRole.vendor, Permission.exchangeRateView), isTrue);
    expect(hasPermission(UserRole.admin, Permission.systemSettingsEdit), isTrue);
  });
}
