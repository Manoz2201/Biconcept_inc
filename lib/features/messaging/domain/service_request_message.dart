class ServiceRequestMessage {
  const ServiceRequestMessage({
    required this.id,
    required this.serviceRequestId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.message,
    this.attachments = const [],
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String serviceRequestId;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String message;
  final List<String> attachments;
  final bool isRead;
  final DateTime? createdAt;

  static const quotationRecordRole = 'quotation';

  bool get isChat => senderRole != quotationRecordRole;

  factory ServiceRequestMessage.fromRow(String id, Map<String, dynamic> data) {
    final attachments = data['attachments'];
    return ServiceRequestMessage(
      id: id,
      serviceRequestId: data['serviceRequestId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderRole: data['senderRole']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      attachments: attachments is List ? attachments.map((e) => e.toString()).toList() : const [],
      isRead: data['isRead'] == true,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
    );
  }
}
