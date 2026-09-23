import '../../vendors/domain/line_items.dart';

enum RFQStatus {
  draft('draft', 'Draft'),
  sent('sent', 'Sent'),
  receiving('receiving', 'Receiving'),
  underReview('under_review', 'Under review'),
  awarded('awarded', 'Awarded'),
  cancelled('cancelled', 'Cancelled');

  const RFQStatus(this.value, this.label);
  final String value;
  final String label;

  String toAppwriteString() => value;

  static RFQStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => RFQStatus.draft,
      );

  bool get canEdit => this == draft;
  bool get isOpen => this == sent || this == receiving || this == underReview;

  bool canTransitionTo(RFQStatus next) {
    return switch (this) {
      RFQStatus.draft => next == RFQStatus.sent || next == RFQStatus.cancelled,
      RFQStatus.sent =>
        next == RFQStatus.receiving || next == RFQStatus.underReview || next == RFQStatus.cancelled,
      RFQStatus.receiving =>
        next == RFQStatus.underReview || next == RFQStatus.cancelled,
      RFQStatus.underReview => next == RFQStatus.awarded || next == RFQStatus.cancelled,
      RFQStatus.awarded || RFQStatus.cancelled => false,
    };
  }
}

enum RFQRecipientStatus {
  invited('invited', 'Invited'),
  responded('responded', 'Responded'),
  declined('declined', 'Declined'),
  noResponse('no_response', 'No response');

  const RFQRecipientStatus(this.value, this.label);
  final String value;
  final String label;

  static RFQRecipientStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => RFQRecipientStatus.invited,
      );
}

class RFQRecipient {
  const RFQRecipient({
    required this.id,
    required this.rfqId,
    required this.vendorId,
    required this.invitedAt,
    this.respondedAt,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String rfqId;
  final String vendorId;
  final DateTime invitedAt;
  final DateTime? respondedAt;
  final RFQRecipientStatus status;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rfqId': rfqId,
        'vendorId': vendorId,
        'invitedAt': invitedAt.toUtc().toIso8601String(),
        'respondedAt': respondedAt?.toUtc().toIso8601String(),
        'status': status.value,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  factory RFQRecipient.fromJson(Map<String, dynamic> data) => RFQRecipient(
        id: data['id']?.toString() ?? '',
        rfqId: data['rfqId']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        invitedAt: DateTime.tryParse(data['invitedAt']?.toString() ?? '') ?? DateTime.now(),
        respondedAt: DateTime.tryParse(data['respondedAt']?.toString() ?? ''),
        status: RFQRecipientStatus.fromString(data['status']?.toString() ?? 'invited'),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

class RFQ {
  const RFQ({
    required this.id,
    required this.projectId,
    required this.rfqNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.items,
    required this.dueDate,
    required this.status,
    this.awardedVendorId,
    this.awardedAt,
    required this.createdBy,
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String rfqNumber;
  final String title;
  final String description;
  final String category;
  final List<CatalogLine> items;
  final DateTime dueDate;
  final RFQStatus status;
  final String? awardedVendorId;
  final DateTime? awardedAt;
  final String createdBy;
  final List<String> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RFQ.fromRow(String id, Map<String, dynamic> data) {
    final attachments = data['attachments'];
    return RFQ(
      id: id,
      projectId: data['projectId']?.toString() ?? '',
      rfqNumber: data['rfqNumber']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      category: data['category']?.toString() ?? 'other',
      items: catalogLinesFrom(decodeJsonList(data['itemsJson'] ?? data['items'])),
      dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? DateTime.now(),
      status: RFQStatus.fromString(data['status']?.toString() ?? 'draft'),
      awardedVendorId: data['awardedVendorId']?.toString(),
      awardedAt: DateTime.tryParse(data['awardedAt']?.toString() ?? ''),
      createdBy: data['createdBy']?.toString() ?? '',
      attachments: attachments is List ? attachments.map((item) => item.toString()).toList() : const [],
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
