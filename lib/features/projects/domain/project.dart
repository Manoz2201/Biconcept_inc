import 'project_status.dart';

class Project {
  const Project({
    required this.id,
    required this.projectNumber,
    required this.clientId,
    this.serviceRequestId,
    this.quotationId,
    required this.title,
    this.description,
    required this.status,
    this.priority,
    required this.startDate,
    required this.endDate,
    this.actualStartDate,
    this.actualEndDate,
    this.budget,
    this.spent = 0,
    this.progress = 0,
    this.assignedArchitect,
    this.teamMembers = const [],
    this.coverImageId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectNumber;
  final String clientId;
  final String? serviceRequestId;
  final String? quotationId;
  final String title;
  final String? description;
  final ProjectStatus status;
  final ProjectPriority? priority;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? actualStartDate;
  final DateTime? actualEndDate;
  final double? budget;
  final double spent;
  final int progress;
  final String? assignedArchitect;
  final List<String> teamMembers;
  final String? coverImageId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => {
        'projectNumber': projectNumber,
        'clientId': clientId,
        'serviceRequestId': ?serviceRequestId,
        'quotationId': ?quotationId,
        'title': title,
        'description': ?description,
        'status': status.value,
        'priority': ?priority?.value,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        'actualStartDate': actualStartDate?.toUtc().toIso8601String(),
        'actualEndDate': actualEndDate?.toUtc().toIso8601String(),
        'budget': ?budget,
        'spent': spent,
        'progress': progress,
        'assignedArchitect': ?assignedArchitect,
        'teamMembers': teamMembers,
        'coverImageId': ?coverImageId,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory Project.fromRow(String id, Map<String, dynamic> data) {
    final members = data['teamMembers'];
    return Project(
      id: id,
      projectNumber: data['projectNumber']?.toString() ?? '',
      clientId: data['clientId']?.toString() ?? '',
      serviceRequestId: data['serviceRequestId']?.toString(),
      quotationId: data['quotationId']?.toString(),
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString(),
      status: ProjectStatus.fromString(data['status']?.toString() ?? 'planning'),
      priority: ProjectPriority.tryParse(data['priority']?.toString()),
      startDate: DateTime.tryParse(data['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(data['endDate']?.toString() ?? '') ?? DateTime.now(),
      actualStartDate: DateTime.tryParse(data['actualStartDate']?.toString() ?? ''),
      actualEndDate: DateTime.tryParse(data['actualEndDate']?.toString() ?? ''),
      budget: (data['budget'] as num?)?.toDouble(),
      spent: (data['spent'] as num?)?.toDouble() ?? 0,
      progress: (data['progress'] as num?)?.toInt() ?? 0,
      assignedArchitect: data['assignedArchitect']?.toString(),
      teamMembers: members is List ? members.map((item) => item.toString()).toList() : const [],
      coverImageId: data['coverImageId']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}

int progressFromMilestones(Iterable<({bool completed, int weight})> milestones) {
  var total = 0;
  var done = 0;
  for (final item in milestones) {
    final weight = item.weight < 1 ? 1 : item.weight;
    total += weight;
    if (item.completed) done += weight;
  }
  if (total == 0) return 0;
  return ((done / total) * 100).round().clamp(0, 100);
}
