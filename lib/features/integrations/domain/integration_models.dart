import '../../../core/result/app_result.dart';

enum IntegrationProvider {
  tally('tally', 'Tally'),
  zohoBooks('zoho_books', 'Zoho Books'),
  quickBooks('quickbooks', 'QuickBooks'),
  googleCalendar('google_calendar', 'Google Calendar'),
  outlookCalendar('outlook_calendar', 'Outlook Calendar');

  const IntegrationProvider(this.value, this.label);
  final String value;
  final String label;

  static IntegrationProvider fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => IntegrationProvider.tally,
      );
}

enum SyncStatus {
  running('running', 'Running'),
  success('success', 'Success'),
  failed('failed', 'Failed'),
  partial('partial', 'Partial');

  const SyncStatus(this.value, this.label);
  final String value;
  final String label;

  static SyncStatus fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => SyncStatus.running,
      );
}

class IntegrationConfig {
  const IntegrationConfig({
    required this.id,
    required this.provider,
    required this.displayName,
    this.isActive = false,
    this.config = const {},
    this.lastSyncAt,
    this.lastSyncStatus,
    this.lastSyncError,
    this.syncFrequency = 'manual',
    this.syncDirection = 'export',
    this.entityMapping,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final IntegrationProvider provider;
  final String displayName;
  final bool isActive;
  final Map<String, dynamic> config;
  final DateTime? lastSyncAt;
  final String? lastSyncStatus;
  final String? lastSyncError;
  final String syncFrequency;
  final String syncDirection;
  final Map<String, String>? entityMapping;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.value,
        'displayName': displayName,
        'isActive': isActive,
        'config': config,
        'lastSyncAt': ?lastSyncAt?.toUtc().toIso8601String(),
        'lastSyncStatus': ?lastSyncStatus,
        'lastSyncError': ?lastSyncError,
        'syncFrequency': syncFrequency,
        'syncDirection': syncDirection,
        'entityMapping': ?entityMapping,
        'createdBy': createdBy,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory IntegrationConfig.fromJson(Map<String, dynamic> data) => IntegrationConfig(
        id: data['id']?.toString() ?? '',
        provider: IntegrationProvider.fromString(data['provider']?.toString()),
        displayName: data['displayName']?.toString() ?? '',
        isActive: data['isActive'] == true,
        config: data['config'] is Map ? Map<String, dynamic>.from(data['config'] as Map) : const {},
        lastSyncAt: DateTime.tryParse(data['lastSyncAt']?.toString() ?? ''),
        lastSyncStatus: data['lastSyncStatus']?.toString(),
        lastSyncError: data['lastSyncError']?.toString(),
        syncFrequency: data['syncFrequency']?.toString() ?? 'manual',
        syncDirection: data['syncDirection']?.toString() ?? 'export',
        entityMapping: data['entityMapping'] is Map
            ? {
                for (final entry in (data['entityMapping'] as Map).entries) entry.key.toString(): entry.value.toString(),
              }
            : null,
        createdBy: data['createdBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  IntegrationConfig copyWith({
    bool? isActive,
    Map<String, dynamic>? config,
    DateTime? lastSyncAt,
    String? lastSyncStatus,
    String? lastSyncError,
    String? syncFrequency,
    String? syncDirection,
    Map<String, String>? entityMapping,
    DateTime? updatedAt,
  }) =>
      IntegrationConfig(
        id: id,
        provider: provider,
        displayName: displayName,
        isActive: isActive ?? this.isActive,
        config: config ?? this.config,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
        lastSyncError: lastSyncError ?? this.lastSyncError,
        syncFrequency: syncFrequency ?? this.syncFrequency,
        syncDirection: syncDirection ?? this.syncDirection,
        entityMapping: entityMapping ?? this.entityMapping,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class SyncLog {
  const SyncLog({
    required this.id,
    required this.integrationId,
    required this.provider,
    required this.syncType,
    required this.direction,
    required this.entityType,
    required this.recordsProcessed,
    required this.recordsSucceeded,
    required this.recordsFailed,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.errorDetails,
    this.createdAt,
  });

  final String id;
  final String integrationId;
  final String provider;
  final String syncType;
  final String direction;
  final String entityType;
  final int recordsProcessed;
  final int recordsSucceeded;
  final int recordsFailed;
  final DateTime startedAt;
  final DateTime? completedAt;
  final SyncStatus status;
  final String? errorDetails;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'integrationId': integrationId,
        'provider': provider,
        'syncType': syncType,
        'direction': direction,
        'entityType': entityType,
        'recordsProcessed': recordsProcessed,
        'recordsSucceeded': recordsSucceeded,
        'recordsFailed': recordsFailed,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': ?completedAt?.toUtc().toIso8601String(),
        'status': status.value,
        'errorDetails': ?errorDetails,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory SyncLog.fromJson(Map<String, dynamic> data) => SyncLog(
        id: data['id']?.toString() ?? '',
        integrationId: data['integrationId']?.toString() ?? '',
        provider: data['provider']?.toString() ?? '',
        syncType: data['syncType']?.toString() ?? 'manual',
        direction: data['direction']?.toString() ?? 'export',
        entityType: data['entityType']?.toString() ?? '',
        recordsProcessed: (data['recordsProcessed'] as num?)?.toInt() ?? 0,
        recordsSucceeded: (data['recordsSucceeded'] as num?)?.toInt() ?? 0,
        recordsFailed: (data['recordsFailed'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(data['startedAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
        completedAt: DateTime.tryParse(data['completedAt']?.toString() ?? ''),
        status: SyncStatus.fromString(data['status']?.toString()),
        errorDetails: data['errorDetails']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

abstract class IntegrationRepository {
  Future<AppResult<List<IntegrationConfig>>> getIntegrations({IntegrationProvider? provider, bool? isActive});
  Future<AppResult<IntegrationConfig>> getIntegrationById(String id);
  Future<AppResult<IntegrationConfig>> createIntegration({
    required IntegrationProvider provider,
    required String displayName,
    required Map<String, dynamic> config,
  });
  Future<AppResult<IntegrationConfig>> updateIntegration(String id, Map<String, dynamic> data);
  Future<AppResult<IntegrationConfig>> toggleIntegration(String id, bool isActive);
  Future<AppResult<void>> deleteIntegration(String id);
  Future<AppResult<bool>> testConnection(String id);
  Future<AppResult<SyncLog>> syncNow(String id, {String syncType = 'incremental'});
  Future<AppResult<List<SyncLog>>> getSyncLogs(String integrationId, {int limit = 50});
  Future<AppResult<String>> exportToTally({DateTime? from, DateTime? to});
  Future<AppResult<String>> exportToZohoBooks({DateTime? from, DateTime? to});
  Future<AppResult<String>> exportToQuickBooks({DateTime? from, DateTime? to});
  Future<AppResult<int>> syncCalendarEvents({DateTime? from, DateTime? to});
}
