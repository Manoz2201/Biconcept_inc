class ProjectActivity {
  const ProjectActivity({
    required this.id,
    required this.projectId,
    required this.actorId,
    required this.actorName,
    required this.action,
    this.metadata,
    this.createdAt,
  });

  final String id;
  final String projectId;
  final String actorId;
  final String actorName;
  final String action;
  final String? metadata;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'actorId': actorId,
        'actorName': actorName,
        'action': action,
        'metadata': ?metadata,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  factory ProjectActivity.fromJson(Map<String, dynamic> data) {
    return ProjectActivity(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      actorId: data['actorId']?.toString() ?? '',
      actorName: data['actorName']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      metadata: data['metadata']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
    );
  }
}
