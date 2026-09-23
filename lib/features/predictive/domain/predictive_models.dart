import '../../../core/result/app_result.dart';

class RiskPrediction {
  const RiskPrediction({
    required this.projectId,
    required this.riskScore,
    required this.riskLevel,
    required this.factors,
    required this.recommendations,
    required this.predictedDelayDays,
    required this.confidence,
  });

  final String projectId;
  final double riskScore;
  final String riskLevel;
  final List<String> factors;
  final List<String> recommendations;
  final int predictedDelayDays;
  final double confidence;
}

class MaintenanceAlert {
  const MaintenanceAlert({
    required this.id,
    required this.tenantId,
    required this.projectId,
    required this.alertType,
    required this.severity,
    required this.description,
    required this.suggestedAction,
    this.dueDate,
    this.isResolved = false,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String projectId;
  final String alertType;
  final String severity;
  final String description;
  final String suggestedAction;
  final DateTime? dueDate;
  final bool isResolved;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'projectId': projectId,
        'alertType': alertType,
        'severity': severity,
        'description': description,
        'suggestedAction': suggestedAction,
        'dueDate': ?dueDate?.toUtc().toIso8601String(),
        'isResolved': isResolved,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory MaintenanceAlert.fromJson(Map<String, dynamic> data) => MaintenanceAlert(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        projectId: data['projectId']?.toString() ?? '',
        alertType: data['alertType']?.toString() ?? '',
        severity: data['severity']?.toString() ?? 'medium',
        description: data['description']?.toString() ?? '',
        suggestedAction: data['suggestedAction']?.toString() ?? '',
        dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? ''),
        isResolved: data['isResolved'] == true,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );

  MaintenanceAlert copyWith({bool? isResolved}) => MaintenanceAlert(
        id: id,
        tenantId: tenantId,
        projectId: projectId,
        alertType: alertType,
        severity: severity,
        description: description,
        suggestedAction: suggestedAction,
        dueDate: dueDate,
        isResolved: isResolved ?? this.isResolved,
        createdAt: createdAt,
      );
}

class ProjectHealth {
  const ProjectHealth({
    required this.projectId,
    required this.score,
    required this.schedule,
    required this.budget,
    required this.client,
    required this.team,
    required this.recommendations,
  });

  final String projectId;
  final double score;
  final double schedule;
  final double budget;
  final double client;
  final double team;
  final List<String> recommendations;
}

abstract class PredictiveRepository {
  Future<AppResult<RiskPrediction>> getProjectRisk(String projectId);
  Future<AppResult<List<MaintenanceAlert>>> getMaintenanceAlerts({String? projectId, bool? isResolved});
  Future<AppResult<MaintenanceAlert>> resolveAlert(String id);
  Future<AppResult<ProjectHealth>> getProjectHealth(String projectId);
  Future<AppResult<List<double>>> getTrendForecast(String metric, {int periods = 6});
}
