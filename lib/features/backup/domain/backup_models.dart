import '../../../core/result/app_result.dart';

enum BackupJobType {
  full('full', 'Full'),
  incremental('incremental', 'Incremental'),
  entities('entities', 'Selected entities');

  const BackupJobType(this.value, this.label);
  final String value;
  final String label;

  static BackupJobType fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => BackupJobType.full,
      );
}

enum BackupStatus {
  running('running', 'Running'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed'),
  restored('restored', 'Restored');

  const BackupStatus(this.value, this.label);
  final String value;
  final String label;

  static BackupStatus fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => BackupStatus.running,
      );
}

class BackupJob {
  const BackupJob({
    required this.id,
    required this.jobName,
    required this.jobType,
    this.entities,
    required this.frequency,
    this.retentionDays = 30,
    required this.storageLocation,
    this.storageConfig,
    this.encryptionEnabled = true,
    this.compressionEnabled = true,
    this.lastRunAt,
    this.lastRunStatus,
    this.lastRunSize,
    this.nextRunAt,
    this.isActive = true,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String jobName;
  final BackupJobType jobType;
  final List<String>? entities;
  final String frequency;
  final int retentionDays;
  final String storageLocation;
  final Map<String, dynamic>? storageConfig;
  final bool encryptionEnabled;
  final bool compressionEnabled;
  final DateTime? lastRunAt;
  final String? lastRunStatus;
  final int? lastRunSize;
  final DateTime? nextRunAt;
  final bool isActive;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobName': jobName,
        'jobType': jobType.value,
        'entities': ?entities,
        'frequency': frequency,
        'retentionDays': retentionDays,
        'storageLocation': storageLocation,
        'storageConfig': ?storageConfig,
        'encryptionEnabled': encryptionEnabled,
        'compressionEnabled': compressionEnabled,
        'lastRunAt': ?lastRunAt?.toUtc().toIso8601String(),
        'lastRunStatus': ?lastRunStatus,
        'lastRunSize': ?lastRunSize,
        'nextRunAt': ?nextRunAt?.toUtc().toIso8601String(),
        'isActive': isActive,
        'createdBy': createdBy,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory BackupJob.fromJson(Map<String, dynamic> data) => BackupJob(
        id: data['id']?.toString() ?? '',
        jobName: data['jobName']?.toString() ?? '',
        jobType: BackupJobType.fromString(data['jobType']?.toString()),
        entities: data['entities'] is List ? [for (final item in data['entities'] as List) item.toString()] : null,
        frequency: data['frequency']?.toString() ?? 'manual',
        retentionDays: (data['retentionDays'] as num?)?.toInt() ?? 30,
        storageLocation: data['storageLocation']?.toString() ?? 'appwrite',
        storageConfig: data['storageConfig'] is Map ? Map<String, dynamic>.from(data['storageConfig'] as Map) : null,
        encryptionEnabled: data['encryptionEnabled'] != false,
        compressionEnabled: data['compressionEnabled'] != false,
        lastRunAt: DateTime.tryParse(data['lastRunAt']?.toString() ?? ''),
        lastRunStatus: data['lastRunStatus']?.toString(),
        lastRunSize: (data['lastRunSize'] as num?)?.toInt(),
        nextRunAt: DateTime.tryParse(data['nextRunAt']?.toString() ?? ''),
        isActive: data['isActive'] != false,
        createdBy: data['createdBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class BackupHistory {
  const BackupHistory({
    required this.id,
    required this.backupJobId,
    required this.fileName,
    required this.fileId,
    required this.fileSize,
    required this.entities,
    required this.recordCount,
    required this.encryptionEnabled,
    required this.compressionEnabled,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.restoredAt,
    this.restoredBy,
    this.checksum,
    this.createdAt,
  });

  final String id;
  final String backupJobId;
  final String fileName;
  final String fileId;
  final int fileSize;
  final List<String> entities;
  final int recordCount;
  final bool encryptionEnabled;
  final bool compressionEnabled;
  final BackupStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? restoredAt;
  final String? restoredBy;
  final String? checksum;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'backupJobId': backupJobId,
        'fileName': fileName,
        'fileId': fileId,
        'fileSize': fileSize,
        'entities': entities,
        'recordCount': recordCount,
        'encryptionEnabled': encryptionEnabled,
        'compressionEnabled': compressionEnabled,
        'status': status.value,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': ?completedAt?.toUtc().toIso8601String(),
        'restoredAt': ?restoredAt?.toUtc().toIso8601String(),
        'restoredBy': ?restoredBy,
        'checksum': ?checksum,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory BackupHistory.fromJson(Map<String, dynamic> data) => BackupHistory(
        id: data['id']?.toString() ?? '',
        backupJobId: data['backupJobId']?.toString() ?? '',
        fileName: data['fileName']?.toString() ?? '',
        fileId: data['fileId']?.toString() ?? '',
        fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
        entities: data['entities'] is List ? [for (final item in data['entities'] as List) item.toString()] : const [],
        recordCount: (data['recordCount'] as num?)?.toInt() ?? 0,
        encryptionEnabled: data['encryptionEnabled'] == true,
        compressionEnabled: data['compressionEnabled'] == true,
        status: BackupStatus.fromString(data['status']?.toString()),
        startedAt: DateTime.tryParse(data['startedAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
        completedAt: DateTime.tryParse(data['completedAt']?.toString() ?? ''),
        restoredAt: DateTime.tryParse(data['restoredAt']?.toString() ?? ''),
        restoredBy: data['restoredBy']?.toString(),
        checksum: data['checksum']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );

  BackupHistory copyWith({
    BackupStatus? status,
    DateTime? restoredAt,
    String? restoredBy,
    DateTime? completedAt,
    String? fileId,
    int? fileSize,
    String? checksum,
  }) =>
      BackupHistory(
        id: id,
        backupJobId: backupJobId,
        fileName: fileName,
        fileId: fileId ?? this.fileId,
        fileSize: fileSize ?? this.fileSize,
        entities: entities,
        recordCount: recordCount,
        encryptionEnabled: encryptionEnabled,
        compressionEnabled: compressionEnabled,
        status: status ?? this.status,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        restoredAt: restoredAt ?? this.restoredAt,
        restoredBy: restoredBy ?? this.restoredBy,
        checksum: checksum ?? this.checksum,
        createdAt: createdAt,
      );
}

class RestorePreview {
  const RestorePreview({required this.recordCount, required this.entities, required this.checksumOk});

  final int recordCount;
  final List<String> entities;
  final bool checksumOk;
}

abstract class BackupRepository {
  Future<AppResult<List<BackupJob>>> getBackupJobs({bool? isActive});
  Future<AppResult<BackupJob>> getBackupJobById(String id);
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
  });
  Future<AppResult<BackupJob>> updateBackupJob(String id, Map<String, dynamic> data);
  Future<AppResult<void>> deleteBackupJob(String id);
  Future<AppResult<BackupHistory>> runBackupNow(String id);
  Future<AppResult<List<BackupHistory>>> getBackupHistory({String? backupJobId});
  Future<AppResult<RestorePreview>> restoreFromBackup(String backupHistoryId, {bool dryRun = false});
  Future<AppResult<String>> downloadBackup(String backupHistoryId);
  Future<AppResult<void>> deleteBackup(String backupHistoryId);
  Future<AppResult<bool>> verifyBackup(String backupHistoryId);
}
