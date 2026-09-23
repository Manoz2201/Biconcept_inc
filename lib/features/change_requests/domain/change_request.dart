enum ChangeRequestStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  implemented('implemented', 'Implemented');

  const ChangeRequestStatus(this.value, this.label);
  final String value;
  final String label;

  String toAppwriteString() => value;

  static ChangeRequestStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ChangeRequestStatus.pending,
      );
}

class ChangeRequest {
  const ChangeRequest({
    required this.id,
    required this.projectId,
    required this.raisedBy,
    required this.raisedByRole,
    required this.title,
    required this.description,
    this.impactCost,
    this.impactDays,
    required this.status,
    this.clientApproval = false,
    this.clientNotes,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String raisedBy;
  final String raisedByRole;
  final String title;
  final String description;
  final double? impactCost;
  final int? impactDays;
  final ChangeRequestStatus status;
  final bool clientApproval;
  final String? clientNotes;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'raisedBy': raisedBy,
        'raisedByRole': raisedByRole,
        'title': title,
        'description': description,
        'impactCost': ?impactCost,
        'impactDays': ?impactDays,
        'status': status.value,
        'clientApproval': clientApproval,
        'clientNotes': ?clientNotes,
        'approvedBy': ?approvedBy,
        'approvedAt': approvedAt?.toUtc().toIso8601String(),
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory ChangeRequest.fromJson(Map<String, dynamic> data) {
    return ChangeRequest(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      raisedBy: data['raisedBy']?.toString() ?? '',
      raisedByRole: data['raisedByRole']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      impactCost: (data['impactCost'] as num?)?.toDouble(),
      impactDays: (data['impactDays'] as num?)?.toInt(),
      status: ChangeRequestStatus.fromString(data['status']?.toString() ?? 'pending'),
      clientApproval: data['clientApproval'] == true,
      clientNotes: data['clientNotes']?.toString(),
      approvedBy: data['approvedBy']?.toString(),
      approvedAt: DateTime.tryParse(data['approvedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
