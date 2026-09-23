import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/user_theme_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../analytics/domain/analytics_models.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../backup/domain/backup_models.dart';
import '../../../branding/domain/branding_settings.dart';
import '../../../currency/domain/currency.dart';
import '../../../currency/domain/currency_repository.dart';
import '../../../integrations/domain/integration_models.dart';
import '../../../notifications/domain/notification_models.dart';
import '../../../payment_schedules/domain/payment_schedule.dart';
import '../../../performance/domain/cache_config.dart';
import '../../../rbac/domain/user_role.dart';
import '../../data/platform_repository_impl.dart';

T _unwrap<T>(dynamic result) => result.when(
      success: (data) => data as T,
      failure: (error) => throw Exception(error.userMessage),
    );

final platformRepositoryProvider = Provider<PlatformRepositoryImpl>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return PlatformRepositoryImpl(
    actorId: () => session.user?.accountId ?? 'unknown',
    actorRole: () => session.user?.role.value ?? UserRole.client.value,
  );
});

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) => ref.watch(platformRepositoryProvider));
final paymentScheduleRepositoryProvider = Provider<PaymentScheduleRepository>((ref) => ref.watch(platformRepositoryProvider));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => ref.watch(platformRepositoryProvider));
final integrationRepositoryProvider = Provider<IntegrationRepository>((ref) => ref.watch(platformRepositoryProvider));
final brandingRepositoryProvider = Provider<BrandingRepository>((ref) => ref.watch(platformRepositoryProvider));
final backupRepositoryProvider = Provider<BackupRepository>((ref) => ref.watch(platformRepositoryProvider));
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) => ref.watch(platformRepositoryProvider));
final kpiRepositoryProvider = Provider<KPIRepository>((ref) => ref.watch(platformRepositoryProvider));

final currenciesProvider = FutureProvider.family<List<Currency>, bool?>((ref, isActive) async {
  return _unwrap(await ref.watch(currencyRepositoryProvider).getCurrencies(isActive: isActive));
});

final baseCurrencyProvider = FutureProvider<Currency>((ref) async {
  return _unwrap(await ref.watch(currencyRepositoryProvider).getBaseCurrency());
});

final currencyByCodeProvider = FutureProvider.family<Currency, String>((ref, code) async {
  return _unwrap(await ref.watch(currencyRepositoryProvider).getCurrencyByCode(code));
});

final exchangeRateHistoryProvider = FutureProvider.family<List<ExchangeRate>, String>((ref, code) async {
  return _unwrap(await ref.watch(currencyRepositoryProvider).getExchangeRateHistory(code));
});

class ScheduleQuery {
  const ScheduleQuery({this.vendorId, this.projectId, this.status, this.from, this.to});

  final String? vendorId;
  final String? projectId;
  final PaymentScheduleStatus? status;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is ScheduleQuery &&
      other.vendorId == vendorId &&
      other.projectId == projectId &&
      other.status == status &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(vendorId, projectId, status, from, to);
}

final paymentSchedulesProvider = FutureProvider.family<List<PaymentSchedule>, ScheduleQuery>((ref, query) async {
  return _unwrap(await ref.watch(paymentScheduleRepositoryProvider).getPaymentSchedules(
        vendorId: query.vendorId,
        projectId: query.projectId,
        status: query.status,
        from: query.from,
        to: query.to,
      ));
});

final paymentScheduleByIdProvider = FutureProvider.family<PaymentSchedule, String>((ref, id) async {
  return _unwrap(await ref.watch(paymentScheduleRepositoryProvider).getPaymentScheduleById(id));
});

final upcomingPaymentsProvider = FutureProvider.family<List<PaymentSchedule>, int>((ref, days) async {
  return _unwrap(await ref.watch(paymentScheduleRepositoryProvider).getUpcomingPayments(days: days));
});

final paymentCalendarProvider = FutureProvider.family<Map<DateTime, List<PaymentSchedule>>, DateTime>((ref, month) async {
  return _unwrap(await ref.watch(paymentScheduleRepositoryProvider).getPaymentCalendar(month));
});

final unpaidVendorBillsProvider = FutureProvider.family<List<dynamic>, String>((ref, vendorId) async {
  return _unwrap(await ref.watch(paymentScheduleRepositoryProvider).unpaidBillsForVendor(vendorId));
});

final notificationsProvider = FutureProvider.family<List<NotificationLog>, NotificationStatus?>((ref, status) async {
  return _unwrap(await ref.watch(notificationRepositoryProvider).getNotifications(status: status));
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  return _unwrap(await ref.watch(notificationRepositoryProvider).getUnreadCount());
});

final notificationPreferencesProvider = FutureProvider<NotificationPreferences>((ref) async {
  return _unwrap(await ref.watch(notificationRepositoryProvider).getNotificationPreferences());
});

final integrationsProvider = FutureProvider.family<List<IntegrationConfig>, IntegrationProvider?>((ref, provider) async {
  return _unwrap(await ref.watch(integrationRepositoryProvider).getIntegrations(provider: provider));
});

final integrationByIdProvider = FutureProvider.family<IntegrationConfig, String>((ref, id) async {
  return _unwrap(await ref.watch(integrationRepositoryProvider).getIntegrationById(id));
});

final syncLogsProvider = FutureProvider.family<List<SyncLog>, String>((ref, id) async {
  return _unwrap(await ref.watch(integrationRepositoryProvider).getSyncLogs(id));
});

final brandingSettingsProvider = FutureProvider<BrandingSettings>((ref) async {
  return _unwrap(await ref.watch(brandingRepositoryProvider).getBrandingSettings());
});

Color _hex(String raw, Color fallback) {
  final clean = raw.replaceAll('#', '');
  if (clean.length != 6) return fallback;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

const _legacyBrandPrimaries = {'#E8877A', '#0A2F30'};

Color _brandPrimary(String? raw, Color fallback) {
  final value = raw?.trim().toUpperCase();
  if (value == null || value.isEmpty || _legacyBrandPrimaries.contains(value)) return fallback;
  return _hex(value, fallback);
}

final themeFromBrandingProvider = Provider<ThemeData>((ref) {
  final preset = AppThemePresets.byId(ref.watch(userThemeProvider));
  if (preset.id != AppThemePresets.defaultId) {
    return AppTheme.fromPalette(preset.palette);
  }
  final branding = ref.watch(brandingSettingsProvider).asData?.value;
  if (branding == null) return AppTheme.light();
  return AppTheme.light(primaryOverride: _brandPrimary(branding.primaryColor, AppColors.primary));
});

final darkThemeFromBrandingProvider = Provider<ThemeData>((ref) {
  final preset = AppThemePresets.byId(ref.watch(userThemeProvider));
  if (preset.id != AppThemePresets.defaultId) {
    return AppTheme.fromPalette(preset.palette);
  }
  final branding = ref.watch(brandingSettingsProvider).asData?.value;
  if (branding == null) return AppTheme.dark();
  return AppTheme.dark(primaryOverride: _brandPrimary(branding.primaryColor, AppPalette.dark.primaryAccent));
});

final backupJobsProvider = FutureProvider.family<List<BackupJob>, bool?>((ref, isActive) async {
  return _unwrap(await ref.watch(backupRepositoryProvider).getBackupJobs(isActive: isActive));
});

final backupHistoryProvider = FutureProvider.family<List<BackupHistory>, String?>((ref, jobId) async {
  return _unwrap(await ref.watch(backupRepositoryProvider).getBackupHistory(backupJobId: jobId));
});

final kpiMetricsProvider = FutureProvider.family<List<KPIMetric>, String?>((ref, period) async {
  return _unwrap(await ref.watch(kpiRepositoryProvider).getKPIs(period: period));
});

final kpiTrendProvider = FutureProvider.family<List<KPIMetric>, String>((ref, name) async {
  return _unwrap(await ref.watch(analyticsRepositoryProvider).getKPITrend(name));
});

final cohortAnalysisProvider = FutureProvider<List<CohortData>>((ref) async {
  return _unwrap(await ref.watch(analyticsRepositoryProvider).getCohortAnalysis());
});

final funnelAnalysisProvider = FutureProvider.family<FunnelData, String>((ref, name) async {
  return _unwrap(await ref.watch(analyticsRepositoryProvider).getFunnelAnalysis(name));
});

final revenueAnalyticsProvider = FutureProvider<RevenueAnalytics>((ref) async {
  return _unwrap(await ref.watch(analyticsRepositoryProvider).getRevenueAnalytics());
});

final userAnalyticsProvider = FutureProvider<UserAnalytics>((ref) async {
  return _unwrap(await ref.watch(analyticsRepositoryProvider).getUserAnalytics());
});

final connectivityStatusProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((result) => !result.contains(ConnectivityResult.none));
});

final offlineQueueProvider = Provider<List<OfflineAction>>((ref) {
  return ref.watch(platformRepositoryProvider).getAll();
});
