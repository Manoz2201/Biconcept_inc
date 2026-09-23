enum MilestoneStatus {
  pending('pending', 'Pending'),
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed'),
  overdue('overdue', 'Overdue');

  const MilestoneStatus(this.value, this.label);
  final String value;
  final String label;

  String toAppwriteString() => value;

  static MilestoneStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => MilestoneStatus.pending,
      );
}

class Milestone {
  const Milestone({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.dueDate,
    this.completedAt,
    required this.status,
    this.weight = 1,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final DateTime? completedAt;
  final MilestoneStatus status;
  final int weight;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isComplete => status == MilestoneStatus.completed;

  MilestoneStatus get effectiveStatus {
    if (status == MilestoneStatus.completed) return status;
    if (dueDate.isBefore(DateTime.now()) && status != MilestoneStatus.completed) {
      return MilestoneStatus.overdue;
    }
    return status;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'description': ?description,
        'dueDate': dueDate.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'status': status.value,
        'weight': weight,
        'sortOrder': ?sortOrder,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory Milestone.fromJson(Map<String, dynamic> data) {
    return Milestone(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString(),
      dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(data['completedAt']?.toString() ?? ''),
      status: MilestoneStatus.fromString(data['status']?.toString() ?? 'pending'),
      weight: (data['weight'] as num?)?.toInt() ?? 1,
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
