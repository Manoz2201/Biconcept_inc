enum TimesheetStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const TimesheetStatus(this.value, this.label);
  final String value;
  final String label;

  String toAppwriteString() => value;

  static TimesheetStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => TimesheetStatus.draft,
      );
}

class Timesheet {
  const Timesheet({
    required this.id,
    required this.projectId,
    this.taskId,
    required this.userId,
    required this.date,
    required this.hours,
    required this.description,
    this.billable = true,
    this.approvedBy,
    this.approvedAt,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? taskId;
  final String userId;
  final DateTime date;
  final double hours;
  final String description;
  final bool billable;
  final String? approvedBy;
  final DateTime? approvedAt;
  final TimesheetStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'taskId': ?taskId,
        'userId': userId,
        'date': date.toUtc().toIso8601String(),
        'hours': hours,
        'description': description,
        'billable': billable,
        'approvedBy': ?approvedBy,
        'approvedAt': approvedAt?.toUtc().toIso8601String(),
        'status': status.value,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory Timesheet.fromJson(Map<String, dynamic> data) {
    return Timesheet(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      taskId: data['taskId']?.toString(),
      userId: data['userId']?.toString() ?? '',
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      hours: (data['hours'] as num?)?.toDouble() ?? 0,
      description: data['description']?.toString() ?? '',
      billable: data['billable'] != false,
      approvedBy: data['approvedBy']?.toString(),
      approvedAt: DateTime.tryParse(data['approvedAt']?.toString() ?? ''),
      status: TimesheetStatus.fromString(data['status']?.toString() ?? 'draft'),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}

class WeeklyTimesheetSummary {
  const WeeklyTimesheetSummary({required this.hoursByDay, required this.totalHours});

  final Map<DateTime, double> hoursByDay;
  final double totalHours;
}
