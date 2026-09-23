enum TaskStatus {
  todo('todo', 'To do'),
  inProgress('in_progress', 'In progress'),
  review('review', 'Review'),
  done('done', 'Done'),
  blocked('blocked', 'Blocked');

  const TaskStatus(this.value, this.label);
  final String value;
  final String label;

  String toAppwriteString() => value;

  static TaskStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => TaskStatus.todo,
      );

  bool canTransitionTo(TaskStatus next) {
    if (this == next) return true;
    return switch (this) {
      TaskStatus.todo =>
        next == TaskStatus.inProgress || next == TaskStatus.blocked,
      TaskStatus.inProgress =>
        next == TaskStatus.review || next == TaskStatus.blocked || next == TaskStatus.todo,
      TaskStatus.review =>
        next == TaskStatus.done || next == TaskStatus.inProgress,
      TaskStatus.blocked =>
        next == TaskStatus.todo || next == TaskStatus.inProgress,
      TaskStatus.done => next == TaskStatus.inProgress,
    };
  }
}

enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const TaskPriority(this.value, this.label);
  final String value;
  final String label;

  static TaskPriority? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in values) {
      if (value.value == raw || value.name == raw) return value;
    }
    return null;
  }
}

class Task {
  const Task({
    required this.id,
    required this.projectId,
    this.milestoneId,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.status,
    this.priority,
    this.assigneeId,
    required this.reporterId,
    this.dueDate,
    this.completedAt,
    this.estimatedHours,
    this.actualHours = 0,
    this.tags = const [],
    this.attachments = const [],
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? milestoneId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority? priority;
  final String? assigneeId;
  final String reporterId;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double? estimatedHours;
  final double actualHours;
  final List<String> tags;
  final List<String> attachments;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'milestoneId': ?milestoneId,
        'parentTaskId': ?parentTaskId,
        'title': title,
        'description': ?description,
        'status': status.value,
        'priority': ?priority?.value,
        'assigneeId': ?assigneeId,
        'reporterId': reporterId,
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'estimatedHours': ?estimatedHours,
        'actualHours': actualHours,
        'tags': tags,
        'attachments': attachments,
        'sortOrder': ?sortOrder,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> data) {
    List<String> strings(Object? value) =>
        value is List ? value.map((item) => item.toString()).toList() : const [];
    return Task(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      milestoneId: data['milestoneId']?.toString(),
      parentTaskId: data['parentTaskId']?.toString(),
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString(),
      status: TaskStatus.fromString(data['status']?.toString() ?? 'todo'),
      priority: TaskPriority.tryParse(data['priority']?.toString()),
      assigneeId: data['assigneeId']?.toString(),
      reporterId: data['reporterId']?.toString() ?? '',
      dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? ''),
      completedAt: DateTime.tryParse(data['completedAt']?.toString() ?? ''),
      estimatedHours: (data['estimatedHours'] as num?)?.toDouble(),
      actualHours: (data['actualHours'] as num?)?.toDouble() ?? 0,
      tags: strings(data['tags']),
      attachments: strings(data['attachments']),
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
