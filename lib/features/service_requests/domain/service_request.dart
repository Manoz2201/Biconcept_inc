enum ServiceRequestStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  underReview('under_review', 'Under review'),
  quoted('quoted', 'Quoted'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  converted('converted', 'Converted');

  const ServiceRequestStatus(this.value, this.label);

  final String value;
  final String label;

  String toAppwriteString() => value;

  static ServiceRequestStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ServiceRequestStatus.draft,
      );

  bool canTransitionTo(ServiceRequestStatus next) {
    return switch (this) {
      ServiceRequestStatus.draft => next == ServiceRequestStatus.submitted,
      ServiceRequestStatus.submitted => next == ServiceRequestStatus.underReview,
      ServiceRequestStatus.underReview =>
        next == ServiceRequestStatus.quoted || next == ServiceRequestStatus.rejected,
      ServiceRequestStatus.quoted =>
        next == ServiceRequestStatus.approved || next == ServiceRequestStatus.rejected,
      ServiceRequestStatus.approved => next == ServiceRequestStatus.converted,
      ServiceRequestStatus.rejected || ServiceRequestStatus.converted => false,
    };
  }
}

enum ServiceRequestPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const ServiceRequestPriority(this.value, this.label);
  final String value;
  final String label;

  static ServiceRequestPriority? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in values) {
      if (value.value == raw) return value;
    }
    return null;
  }
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.clientId,
    this.enquiryId,
    required this.title,
    required this.description,
    this.serviceId,
    required this.status,
    this.priority,
    this.attachments = const [],
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clientId;
  final String? enquiryId;
  final String title;
  final String description;
  final String? serviceId;
  final ServiceRequestStatus status;
  final ServiceRequestPriority? priority;
  final List<String> attachments;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => {
        'clientId': clientId,
        'enquiryId': ?enquiryId,
        'title': title,
        'description': description,
        'serviceId': ?serviceId,
        'status': status.value,
        'priority': ?priority?.value,
        'attachments': attachments,
        'assignedTo': ?assignedTo,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ServiceRequest.fromRow(String id, Map<String, dynamic> data) {
    final attachments = data['attachments'];
    return ServiceRequest(
      id: id,
      clientId: data['clientId']?.toString() ?? '',
      enquiryId: data['enquiryId']?.toString(),
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      serviceId: data['serviceId']?.toString(),
      status: ServiceRequestStatus.fromString(data['status']?.toString() ?? 'draft'),
      priority: ServiceRequestPriority.tryParse(data['priority']?.toString()),
      attachments: attachments is List ? attachments.map((e) => e.toString()).toList() : const [],
      assignedTo: data['assignedTo']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
