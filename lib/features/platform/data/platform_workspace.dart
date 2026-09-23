import 'dart:convert';

import '../../analytics/domain/analytics_models.dart';
import '../../backup/domain/backup_models.dart';
import '../../branding/domain/branding_settings.dart';
import '../../currency/domain/currency.dart';
import '../../integrations/domain/integration_models.dart';
import '../../notifications/domain/notification_models.dart';
import '../../payment_schedules/domain/payment_schedule.dart';
import '../../performance/domain/cache_config.dart';

class PlatformWorkspace {
  PlatformWorkspace({
    List<Currency>? currencies,
    List<ExchangeRate>? exchangeRates,
    List<PaymentSchedule>? paymentSchedules,
    List<NotificationLog>? notifications,
    List<NotificationPreferences>? notificationPreferences,
    List<IntegrationConfig>? integrations,
    List<SyncLog>? syncLogs,
    BrandingSettings? branding,
    List<BackupJob>? backupJobs,
    List<BackupHistory>? backupHistory,
    List<AnalyticsEvent>? analyticsEvents,
    List<KPIMetric>? kpiMetrics,
    Map<String, Map<String, String>>? fcmTokens,
    List<OfflineAction>? offlineQueue,
    Map<String, double>? kpiTargets,
  })  : currencies = currencies ?? [],
        exchangeRates = exchangeRates ?? [],
        paymentSchedules = paymentSchedules ?? [],
        notifications = notifications ?? [],
        notificationPreferences = notificationPreferences ?? [],
        integrations = integrations ?? [],
        syncLogs = syncLogs ?? [],
        branding = branding ?? BrandingSettings.defaults,
        backupJobs = backupJobs ?? [],
        backupHistory = backupHistory ?? [],
        analyticsEvents = analyticsEvents ?? [],
        kpiMetrics = kpiMetrics ?? [],
        fcmTokens = fcmTokens ?? {},
        offlineQueue = offlineQueue ?? [],
        kpiTargets = kpiTargets ?? {};

  final List<Currency> currencies;
  final List<ExchangeRate> exchangeRates;
  final List<PaymentSchedule> paymentSchedules;
  final List<NotificationLog> notifications;
  final List<NotificationPreferences> notificationPreferences;
  final List<IntegrationConfig> integrations;
  final List<SyncLog> syncLogs;
  final BrandingSettings branding;
  final List<BackupJob> backupJobs;
  final List<BackupHistory> backupHistory;
  final List<AnalyticsEvent> analyticsEvents;
  final List<KPIMetric> kpiMetrics;
  final Map<String, Map<String, String>> fcmTokens;
  final List<OfflineAction> offlineQueue;
  final Map<String, double> kpiTargets;

  static PlatformWorkspace seeded([DateTime? now]) {
    final stamp = now ?? DateTime.now().toUtc();
    return PlatformWorkspace(currencies: defaultCurrencies(stamp));
  }

  String encode() => jsonEncode({
        'currencies': [for (final item in currencies) item.toJson()],
        'exchangeRates': [for (final item in exchangeRates) item.toJson()],
        'paymentSchedules': [for (final item in paymentSchedules) item.toJson()],
        'notifications': [for (final item in notifications.take(400)) item.toJson()],
        'notificationPreferences': [for (final item in notificationPreferences) item.toJson()],
        'integrations': [for (final item in integrations) item.toJson()],
        'syncLogs': [for (final item in syncLogs.take(200)) item.toJson()],
        'branding': branding.toJson(),
        'backupJobs': [for (final item in backupJobs) item.toJson()],
        'backupHistory': [for (final item in backupHistory.take(100)) item.toJson()],
        'analyticsEvents': [for (final item in analyticsEvents.take(200)) item.toJson()],
        'kpiMetrics': [for (final item in kpiMetrics) item.toJson()],
        'fcmTokens': fcmTokens,
        'offlineQueue': [for (final item in offlineQueue) item.toJson()],
        'kpiTargets': kpiTargets,
      });

  factory PlatformWorkspace.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return PlatformWorkspace.seeded();
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return PlatformWorkspace.seeded();
      List<Map<String, dynamic>> maps(Object? value) => [
            if (value is List)
              for (final item in value)
                if (item is Map) Map<String, dynamic>.from(item),
          ];
      final branding = data['branding'];
      final tokens = data['fcmTokens'];
      final targets = data['kpiTargets'];
      final currencies = [for (final item in maps(data['currencies'])) Currency.fromJson(item)];
      return PlatformWorkspace(
        currencies: currencies.isEmpty ? defaultCurrencies(DateTime.now().toUtc()) : currencies,
        exchangeRates: [for (final item in maps(data['exchangeRates'])) ExchangeRate.fromJson(item)],
        paymentSchedules: [for (final item in maps(data['paymentSchedules'])) PaymentSchedule.fromJson(item)],
        notifications: [for (final item in maps(data['notifications'])) NotificationLog.fromJson(item)],
        notificationPreferences: [for (final item in maps(data['notificationPreferences'])) NotificationPreferences.fromJson(item)],
        integrations: [for (final item in maps(data['integrations'])) IntegrationConfig.fromJson(item)],
        syncLogs: [for (final item in maps(data['syncLogs'])) SyncLog.fromJson(item)],
        branding: BrandingSettings.fromJson(branding is Map ? Map<String, dynamic>.from(branding) : const {}),
        backupJobs: [for (final item in maps(data['backupJobs'])) BackupJob.fromJson(item)],
        backupHistory: [for (final item in maps(data['backupHistory'])) BackupHistory.fromJson(item)],
        analyticsEvents: [for (final item in maps(data['analyticsEvents'])) AnalyticsEvent.fromJson(item)],
        kpiMetrics: [for (final item in maps(data['kpiMetrics'])) KPIMetric.fromJson(item)],
        fcmTokens: tokens is Map
            ? {
                for (final entry in tokens.entries)
                  if (entry.value is Map)
                    entry.key.toString(): {
                      for (final inner in (entry.value as Map).entries) inner.key.toString(): inner.value.toString(),
                    },
              }
            : {},
        offlineQueue: [for (final item in maps(data['offlineQueue'])) OfflineAction.fromJson(item)],
        kpiTargets: targets is Map
            ? {
                for (final entry in targets.entries) entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0,
              }
            : {},
      );
    } catch (_) {
      return PlatformWorkspace.seeded();
    }
  }

  PlatformWorkspace copyWith({
    List<Currency>? currencies,
    List<ExchangeRate>? exchangeRates,
    List<PaymentSchedule>? paymentSchedules,
    List<NotificationLog>? notifications,
    List<NotificationPreferences>? notificationPreferences,
    List<IntegrationConfig>? integrations,
    List<SyncLog>? syncLogs,
    BrandingSettings? branding,
    List<BackupJob>? backupJobs,
    List<BackupHistory>? backupHistory,
    List<AnalyticsEvent>? analyticsEvents,
    List<KPIMetric>? kpiMetrics,
    Map<String, Map<String, String>>? fcmTokens,
    List<OfflineAction>? offlineQueue,
    Map<String, double>? kpiTargets,
  }) =>
      PlatformWorkspace(
        currencies: currencies ?? this.currencies,
        exchangeRates: exchangeRates ?? this.exchangeRates,
        paymentSchedules: paymentSchedules ?? this.paymentSchedules,
        notifications: notifications ?? this.notifications,
        notificationPreferences: notificationPreferences ?? this.notificationPreferences,
        integrations: integrations ?? this.integrations,
        syncLogs: syncLogs ?? this.syncLogs,
        branding: branding ?? this.branding,
        backupJobs: backupJobs ?? this.backupJobs,
        backupHistory: backupHistory ?? this.backupHistory,
        analyticsEvents: analyticsEvents ?? this.analyticsEvents,
        kpiMetrics: kpiMetrics ?? this.kpiMetrics,
        fcmTokens: fcmTokens ?? this.fcmTokens,
        offlineQueue: offlineQueue ?? this.offlineQueue,
        kpiTargets: kpiTargets ?? this.kpiTargets,
      );
}
