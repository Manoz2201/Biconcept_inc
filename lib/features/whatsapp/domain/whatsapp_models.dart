import '../../../core/result/app_result.dart';

enum WhatsAppStatus {
  queued('queued', 'Queued'),
  sent('sent', 'Sent'),
  delivered('delivered', 'Delivered'),
  read('read', 'Read'),
  failed('failed', 'Failed');

  const WhatsAppStatus(this.value, this.label);
  final String value;
  final String label;

  static WhatsAppStatus fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => WhatsAppStatus.queued,
      );
}

class WhatsAppMessage {
  const WhatsAppMessage({
    required this.id,
    required this.tenantId,
    required this.clientId,
    this.projectId,
    this.templateName,
    required this.messageType,
    required this.direction,
    required this.status,
    this.messageId,
    required this.content,
    this.referenceType,
    this.referenceId,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failureReason,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String clientId;
  final String? projectId;
  final String? templateName;
  final String messageType;
  final String direction;
  final WhatsAppStatus status;
  final String? messageId;
  final Map<String, dynamic> content;
  final String? referenceType;
  final String? referenceId;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? failureReason;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'clientId': clientId,
        'projectId': ?projectId,
        'templateName': ?templateName,
        'messageType': messageType,
        'direction': direction,
        'status': status.value,
        'messageId': ?messageId,
        'content': content,
        'referenceType': ?referenceType,
        'referenceId': ?referenceId,
        'sentAt': ?sentAt?.toUtc().toIso8601String(),
        'deliveredAt': ?deliveredAt?.toUtc().toIso8601String(),
        'readAt': ?readAt?.toUtc().toIso8601String(),
        'failureReason': ?failureReason,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory WhatsAppMessage.fromJson(Map<String, dynamic> data) => WhatsAppMessage(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        clientId: data['clientId']?.toString() ?? '',
        projectId: data['projectId']?.toString(),
        templateName: data['templateName']?.toString(),
        messageType: data['messageType']?.toString() ?? 'text',
        direction: data['direction']?.toString() ?? 'outbound',
        status: WhatsAppStatus.fromString(data['status']?.toString()),
        messageId: data['messageId']?.toString(),
        content: data['content'] is Map ? Map<String, dynamic>.from(data['content'] as Map) : const {},
        referenceType: data['referenceType']?.toString(),
        referenceId: data['referenceId']?.toString(),
        sentAt: DateTime.tryParse(data['sentAt']?.toString() ?? ''),
        deliveredAt: DateTime.tryParse(data['deliveredAt']?.toString() ?? ''),
        readAt: DateTime.tryParse(data['readAt']?.toString() ?? ''),
        failureReason: data['failureReason']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

class WhatsAppTemplate {
  const WhatsAppTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.language,
    required this.components,
    this.status = 'approved',
  });

  final String id;
  final String name;
  final String category;
  final String language;
  final List<String> components;
  final String status;
}

class WhatsAppConfig {
  const WhatsAppConfig({this.phoneNumberId, this.webhookUrl});

  final String? phoneNumberId;
  final String? webhookUrl;

  Map<String, dynamic> toJson() => {'phoneNumberId': ?phoneNumberId, 'webhookUrl': ?webhookUrl};

  factory WhatsAppConfig.fromJson(Map<String, dynamic>? data) => WhatsAppConfig(
        phoneNumberId: data?['phoneNumberId']?.toString(),
        webhookUrl: data?['webhookUrl']?.toString(),
      );
}

const kWhatsAppTemplates = [
  WhatsAppTemplate(id: 'project_update', name: 'project_update', category: 'project_updates', language: 'en', components: ['name', 'project', 'progress', 'milestone']),
  WhatsAppTemplate(id: 'payment_reminder', name: 'payment_reminder', category: 'payment_reminders', language: 'en', components: ['name', 'invoice_no', 'amount', 'due_date']),
  WhatsAppTemplate(id: 'quotation_sent', name: 'quotation_sent', category: 'quotation_sent', language: 'en', components: ['name', 'quote_no', 'amount']),
  WhatsAppTemplate(id: 'milestone_completed', name: 'milestone_completed', category: 'milestone_completed', language: 'en', components: ['name', 'project', 'milestone']),
  WhatsAppTemplate(id: 'site_visit_scheduled', name: 'site_visit_scheduled', category: 'project_updates', language: 'en', components: ['name', 'project', 'date', 'time']),
  WhatsAppTemplate(id: 'document_ready', name: 'document_ready', category: 'project_updates', language: 'en', components: ['name', 'document_type']),
];

abstract class WhatsAppRepository {
  Future<AppResult<List<WhatsAppMessage>>> getMessages({String? clientId, String? projectId, WhatsAppStatus? status});
  Future<AppResult<WhatsAppMessage>> sendTextMessage({required String clientId, required String text, String? referenceType, String? referenceId});
  Future<AppResult<WhatsAppMessage>> sendTemplateMessage({required String clientId, required String templateName, required List<String> variables});
  Future<AppResult<List<WhatsAppTemplate>>> getTemplates();
  Future<AppResult<WhatsAppConfig>> getConfig();
  Future<AppResult<WhatsAppConfig>> updateConfig(Map<String, dynamic> data);
}
