import '../../../core/result/app_result.dart';

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.id,
    required this.eventName,
    this.userId,
    this.userRole,
    this.sessionId,
    this.properties,
    this.page,
    this.deviceType,
    this.platform,
    this.appVersion,
    required this.timestamp,
    this.createdAt,
  });

  final String id;
  final String eventName;
  final String? userId;
  final String? userRole;
  final String? sessionId;
  final Map<String, dynamic>? properties;
  final String? page;
  final String? deviceType;
  final String? platform;
  final String? appVersion;
  final DateTime timestamp;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventName': eventName,
        'userId': ?userId,
        'userRole': ?userRole,
        'sessionId': ?sessionId,
        'properties': ?properties,
        'page': ?page,
        'deviceType': ?deviceType,
        'platform': ?platform,
        'appVersion': ?appVersion,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> data) => AnalyticsEvent(
        id: data['id']?.toString() ?? '',
        eventName: data['eventName']?.toString() ?? '',
        userId: data['userId']?.toString(),
        userRole: data['userRole']?.toString(),
        sessionId: data['sessionId']?.toString(),
        properties: data['properties'] is Map ? Map<String, dynamic>.from(data['properties'] as Map) : null,
        page: data['page']?.toString(),
        deviceType: data['deviceType']?.toString(),
        platform: data['platform']?.toString(),
        appVersion: data['appVersion']?.toString(),
        timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now().toUtc(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

class KPIMetric {
  const KPIMetric({
    required this.id,
    required this.metricName,
    required this.metricValue,
    this.metricUnit,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    this.dimension,
    this.dimensionValue,
    this.comparisonValue,
    this.changePercent,
    this.target,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String metricName;
  final double metricValue;
  final String? metricUnit;
  final String period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? dimension;
  final String? dimensionValue;
  final double? comparisonValue;
  final double? changePercent;
  final double? target;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'metricName': metricName,
        'metricValue': metricValue,
        'metricUnit': ?metricUnit,
        'period': period,
        'periodStart': periodStart.toUtc().toIso8601String(),
        'periodEnd': periodEnd.toUtc().toIso8601String(),
        'dimension': ?dimension,
        'dimensionValue': ?dimensionValue,
        'comparisonValue': ?comparisonValue,
        'changePercent': ?changePercent,
        'target': ?target,
        'status': ?status,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory KPIMetric.fromJson(Map<String, dynamic> data) => KPIMetric(
        id: data['id']?.toString() ?? '',
        metricName: data['metricName']?.toString() ?? '',
        metricValue: (data['metricValue'] as num?)?.toDouble() ?? 0,
        metricUnit: data['metricUnit']?.toString(),
        period: data['period']?.toString() ?? 'monthly',
        periodStart: DateTime.tryParse(data['periodStart']?.toString() ?? '') ?? DateTime.now(),
        periodEnd: DateTime.tryParse(data['periodEnd']?.toString() ?? '') ?? DateTime.now(),
        dimension: data['dimension']?.toString(),
        dimensionValue: data['dimensionValue']?.toString(),
        comparisonValue: (data['comparisonValue'] as num?)?.toDouble(),
        changePercent: (data['changePercent'] as num?)?.toDouble(),
        target: (data['target'] as num?)?.toDouble(),
        status: data['status']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  KPIMetric copyWith({double? target, String? status, DateTime? updatedAt}) => KPIMetric(
        id: id,
        metricName: metricName,
        metricValue: metricValue,
        metricUnit: metricUnit,
        period: period,
        periodStart: periodStart,
        periodEnd: periodEnd,
        dimension: dimension,
        dimensionValue: dimensionValue,
        comparisonValue: comparisonValue,
        changePercent: changePercent,
        target: target ?? this.target,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class CohortData {
  const CohortData({
    required this.cohortName,
    required this.cohortDate,
    required this.size,
    required this.retentionRates,
    required this.revenueLTV,
    required this.avgProjectValue,
  });

  final String cohortName;
  final DateTime cohortDate;
  final int size;
  final Map<int, double> retentionRates;
  final double revenueLTV;
  final double avgProjectValue;

  Map<String, dynamic> toJson() => {
        'cohortName': cohortName,
        'cohortDate': cohortDate.toIso8601String(),
        'size': size,
        'retentionRates': {for (final entry in retentionRates.entries) '${entry.key}': entry.value},
        'revenueLTV': revenueLTV,
        'avgProjectValue': avgProjectValue,
      };

  factory CohortData.fromJson(Map<String, dynamic> data) => CohortData(
        cohortName: data['cohortName']?.toString() ?? '',
        cohortDate: DateTime.tryParse(data['cohortDate']?.toString() ?? '') ?? DateTime.now(),
        size: (data['size'] as num?)?.toInt() ?? 0,
        retentionRates: {
          if (data['retentionRates'] is Map)
            for (final entry in (data['retentionRates'] as Map).entries)
              int.tryParse(entry.key.toString()) ?? 0: (entry.value as num?)?.toDouble() ?? 0,
        },
        revenueLTV: (data['revenueLTV'] as num?)?.toDouble() ?? 0,
        avgProjectValue: (data['avgProjectValue'] as num?)?.toDouble() ?? 0,
      );
}

class FunnelStep {
  const FunnelStep({
    required this.stepName,
    required this.count,
    required this.conversionFromPrevious,
    required this.conversionFromStart,
  });

  final String stepName;
  final int count;
  final double conversionFromPrevious;
  final double conversionFromStart;
}

class FunnelData {
  const FunnelData({
    required this.funnelName,
    required this.steps,
    required this.conversionRate,
  });

  final String funnelName;
  final List<FunnelStep> steps;
  final double conversionRate;
}

class RevenueAnalytics {
  const RevenueAnalytics({
    required this.totalRevenue,
    required this.avgInvoiceValue,
    required this.outstanding,
    required this.byPeriod,
    required this.topClients,
  });

  final double totalRevenue;
  final double avgInvoiceValue;
  final double outstanding;
  final Map<String, double> byPeriod;
  final Map<String, double> topClients;
}

class UserAnalytics {
  const UserAnalytics({
    required this.dau,
    required this.wau,
    required this.mau,
    required this.featureUsage,
  });

  final int dau;
  final int wau;
  final int mau;
  final Map<String, int> featureUsage;
}

String kpiStatusFor({required double value, double? target}) {
  if (target == null || target <= 0) return 'on_track';
  final ratio = value / target;
  if (ratio >= 1) return 'on_track';
  if (ratio >= 0.8) return 'at_risk';
  return 'off_track';
}

FunnelData buildFunnel(String name, List<(String, int)> steps) {
  if (steps.isEmpty) return FunnelData(funnelName: name, steps: const [], conversionRate: 0);
  final start = steps.first.$2 == 0 ? 1 : steps.first.$2;
  final mapped = <FunnelStep>[];
  for (var i = 0; i < steps.length; i++) {
    final previous = i == 0 ? steps[i].$2 : steps[i - 1].$2;
    mapped.add(
      FunnelStep(
        stepName: steps[i].$1,
        count: steps[i].$2,
        conversionFromPrevious: previous == 0 ? 0 : steps[i].$2 / previous,
        conversionFromStart: steps[i].$2 / start,
      ),
    );
  }
  return FunnelData(
    funnelName: name,
    steps: mapped,
    conversionRate: mapped.last.conversionFromStart,
  );
}

abstract class AnalyticsRepository {
  Future<AppResult<AnalyticsEvent>> trackEvent({
    required String eventName,
    Map<String, dynamic>? properties,
    String? page,
  });
  Future<AppResult<void>> trackScreenView(String screenName);
  Future<AppResult<void>> trackButtonClick(String buttonName, Map<String, dynamic>? metadata);
  Future<AppResult<void>> trackError(String errorType, String message);
  Future<AppResult<List<KPIMetric>>> getKPIMetrics({String? metricName, String? period, DateTime? from, DateTime? to});
  Future<AppResult<List<KPIMetric>>> getKPITrend(String metricName, {int periods = 12});
  Future<AppResult<List<CohortData>>> getCohortAnalysis({String cohortType = 'client_signup', String period = 'monthly'});
  Future<AppResult<FunnelData>> getFunnelAnalysis(String funnelName);
  Future<AppResult<RevenueAnalytics>> getRevenueAnalytics({DateTime? from, DateTime? to, String groupBy = 'month'});
  Future<AppResult<UserAnalytics>> getUserAnalytics({DateTime? from, DateTime? to});
  Future<AppResult<String>> exportAnalyticsReport({required String reportType, DateTime? from, DateTime? to});
}

abstract class KPIRepository {
  Future<AppResult<List<KPIMetric>>> getKPIs({String? period, DateTime? periodStart});
  Future<AppResult<KPIMetric>> getKPIByName(String metricName, {String? dimension, String? dimensionValue});
  Future<AppResult<List<KPIMetric>>> computeKPIs();
  Future<AppResult<KPIMetric>> setKPITarget(String metricName, double target);
  Future<AppResult<String>> getKPIStatus(String metricName);
}
