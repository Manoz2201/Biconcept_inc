enum ProjectVendorStatus {
  active('active', 'Active'),
  completed('completed', 'Completed'),
  terminated('terminated', 'Terminated');

  const ProjectVendorStatus(this.value, this.label);
  final String value;
  final String label;

  static ProjectVendorStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ProjectVendorStatus.active,
      );
}

class ProjectVendor {
  const ProjectVendor({
    required this.id,
    required this.projectId,
    required this.vendorId,
    this.role,
    required this.assignedAt,
    required this.assignedBy,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String vendorId;
  final String? role;
  final DateTime assignedAt;
  final String assignedBy;
  final ProjectVendorStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'vendorId': vendorId,
        'role': ?role,
        'assignedAt': assignedAt.toUtc().toIso8601String(),
        'assignedBy': assignedBy,
        'status': status.value,
        'notes': ?notes,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory ProjectVendor.fromJson(Map<String, dynamic> data) => ProjectVendor(
        id: data['id']?.toString() ?? '',
        projectId: data['projectId']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        role: data['role']?.toString(),
        assignedAt: DateTime.tryParse(data['assignedAt']?.toString() ?? '') ?? DateTime.now(),
        assignedBy: data['assignedBy']?.toString() ?? '',
        status: ProjectVendorStatus.fromString(data['status']?.toString() ?? 'active'),
        notes: data['notes']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
