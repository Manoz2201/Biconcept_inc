import '../../../core/result/app_result.dart';

enum NotificationType {
  invoiceDue('invoice_due', 'Invoice due'),
  invoiceOverdue('invoice_overdue', 'Invoice overdue'),
  paymentReceived('payment_received', 'Payment received'),
  paymentFailed('payment_failed', 'Payment failed'),
  taskAssigned('task_assigned', 'Task assigned'),
  taskDue('task_due', 'Task due'),
  milestoneCompleted('milestone_completed', 'Milestone completed'),
  quotationSent('quotation_sent', 'Quotation sent'),
  quotationApproved('quotation_approved', 'Quotation approved'),
  messageReceived('message_received', 'Message received'),
  projectStatusChanged('project_status_changed', 'Project status'),
  rfqReceived('rfq_received', 'RFQ received'),
  poIssued('po_issued', 'PO issued'),
  billSubmitted('bill_submitted', 'Bill submitted'),
  billApproved('bill_approved', 'Bill approved'),
  itcMismatch('itc_mismatch', 'ITC mismatch'),
  tdsDue('tds_due', 'TDS due'),
  gstFilingDue('gst_filing_due', 'GST filing due'),
  backupCompleted('backup_completed', 'Backup completed'),
  backupFailed('backup_failed', 'Backup failed'),
  integrationSyncFailed('integration_sync_failed', 'Integration sync failed'),
  systemAlert('system_alert', 'System alert'),
  currencyRateUpdated('currency_rate_updated', 'Exchange rate updated'),
  paymentScheduleApproval('payment_schedule_approval', 'Payment schedule approval');

  const NotificationType(this.value, this.label);
  final String value;
  final String label;

  static NotificationType fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => NotificationType.systemAlert,
      );
}

enum NotificationChannel {
  email('email', 'Email'),
  push('push', 'Push'),
  sms('sms', 'SMS'),
  whatsapp('whatsapp', 'WhatsApp'),
  inApp('in_app', 'In-app');

  const NotificationChannel(this.value, this.label);
  final String value;
  final String label;

  static NotificationChannel fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => NotificationChannel.inApp,
      );
}

enum NotificationStatus {
  queued('queued', 'Queued'),
  sent('sent', 'Sent'),
  delivered('delivered', 'Delivered'),
  failed('failed', 'Failed'),
  read('read', 'Read');

  const NotificationStatus(this.value, this.label);
  final String value;
  final String label;

  static NotificationStatus fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => NotificationStatus.queued,
      );
}

class NotificationLog {
  const NotificationLog({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.channel,
    required this.status,
    this.referenceType,
    this.referenceId,
    this.actionUrl,
    this.metadata,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failureReason,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationChannel channel;
  final NotificationStatus status;
  final String? referenceType;
  final String? referenceId;
  final String? actionUrl;
  final String? metadata;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? failureReason;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.value,
        'channel': channel.value,
        'status': status.value,
        'referenceType': ?referenceType,
        'referenceId': ?referenceId,
        'actionUrl': ?actionUrl,
        'metadata': ?metadata,
        'sentAt': ?sentAt?.toUtc().toIso8601String(),
        'deliveredAt': ?deliveredAt?.toUtc().toIso8601String(),
        'readAt': ?readAt?.toUtc().toIso8601String(),
        'failureReason': ?failureReason,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory NotificationLog.fromJson(Map<String, dynamic> data) => NotificationLog(
        id: data['id']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        title: data['title']?.toString() ?? '',
        body: data['body']?.toString() ?? '',
        type: NotificationType.fromString(data['type']?.toString()),
        channel: NotificationChannel.fromString(data['channel']?.toString()),
        status: NotificationStatus.fromString(data['status']?.toString()),
        referenceType: data['referenceType']?.toString(),
        referenceId: data['referenceId']?.toString(),
        actionUrl: data['actionUrl']?.toString(),
        metadata: data['metadata']?.toString(),
        sentAt: DateTime.tryParse(data['sentAt']?.toString() ?? ''),
        deliveredAt: DateTime.tryParse(data['deliveredAt']?.toString() ?? ''),
        readAt: DateTime.tryParse(data['readAt']?.toString() ?? ''),
        failureReason: data['failureReason']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );

  NotificationLog copyWith({
    NotificationStatus? status,
    DateTime? readAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    String? failureReason,
  }) =>
      NotificationLog(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        channel: channel,
        status: status ?? this.status,
        referenceType: referenceType,
        referenceId: referenceId,
        actionUrl: actionUrl,
        metadata: metadata,
        sentAt: sentAt ?? this.sentAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        readAt: readAt ?? this.readAt,
        failureReason: failureReason ?? this.failureReason,
        createdAt: createdAt,
      );
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.id,
    required this.userId,
    this.emailEnabled = true,
    this.pushEnabled = true,
    this.smsEnabled = false,
    this.whatsappEnabled = false,
    this.inAppEnabled = true,
    this.digestFrequency = 'instant',
    this.quietHoursStart,
    this.quietHoursEnd,
    this.channelPreferences,
    this.eventPreferences,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final bool emailEnabled;
  final bool pushEnabled;
  final bool smsEnabled;
  final bool whatsappEnabled;
  final bool inAppEnabled;
  final String digestFrequency;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final Map<String, bool>? channelPreferences;
  final Map<String, bool>? eventPreferences;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool eventEnabled(NotificationType type) => eventPreferences?[type.value] ?? true;

  bool channelOn(NotificationChannel channel) => switch (channel) {
        NotificationChannel.email => emailEnabled,
        NotificationChannel.push => pushEnabled,
        NotificationChannel.sms => smsEnabled,
        NotificationChannel.whatsapp => whatsappEnabled,
        NotificationChannel.inApp => inAppEnabled,
      };

  bool inQuietHours(DateTime now) {
    final start = quietHoursStart;
    final end = quietHoursEnd;
    if (start == null || end == null || start.isEmpty || end.isEmpty) return false;
    final current = now.hour * 60 + now.minute;
    int minutes(String raw) {
      final parts = raw.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return hour * 60 + minute;
    }

    final from = minutes(start);
    final to = minutes(end);
    if (from == to) return false;
    if (from < to) return current >= from && current < to;
    return current >= from || current < to;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'emailEnabled': emailEnabled,
        'pushEnabled': pushEnabled,
        'smsEnabled': smsEnabled,
        'whatsappEnabled': whatsappEnabled,
        'inAppEnabled': inAppEnabled,
        'digestFrequency': digestFrequency,
        'quietHoursStart': ?quietHoursStart,
        'quietHoursEnd': ?quietHoursEnd,
        'channelPreferences': ?channelPreferences,
        'eventPreferences': ?eventPreferences,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> data) => NotificationPreferences(
        id: data['id']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        emailEnabled: data['emailEnabled'] != false,
        pushEnabled: data['pushEnabled'] != false,
        smsEnabled: data['smsEnabled'] == true,
        whatsappEnabled: data['whatsappEnabled'] == true,
        inAppEnabled: data['inAppEnabled'] != false,
        digestFrequency: data['digestFrequency']?.toString() ?? 'instant',
        quietHoursStart: data['quietHoursStart']?.toString(),
        quietHoursEnd: data['quietHoursEnd']?.toString(),
        channelPreferences: _boolMap(data['channelPreferences']),
        eventPreferences: _boolMap(data['eventPreferences']),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  static Map<String, bool>? _boolMap(Object? raw) {
    if (raw is! Map) return null;
    return {
      for (final entry in raw.entries) entry.key.toString(): entry.value == true,
    };
  }
}

abstract class NotificationRepository {
  Future<AppResult<List<NotificationLog>>> getNotifications({
    String? userId,
    NotificationStatus? status,
    int limit = 50,
  });
  Future<AppResult<int>> getUnreadCount();
  Future<AppResult<NotificationLog>> markAsRead(String id);
  Future<AppResult<void>> markAllAsRead();
  Future<AppResult<void>> deleteNotification(String id);
  Future<AppResult<NotificationPreferences>> getNotificationPreferences();
  Future<AppResult<NotificationPreferences>> updateNotificationPreferences(Map<String, dynamic> data);
  Future<AppResult<void>> registerFCMToken(String token, String platform);
  Future<AppResult<void>> unregisterFCMToken(String token);
  Future<AppResult<NotificationLog>> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    NotificationType type = NotificationType.systemAlert,
  });
  Future<AppResult<List<NotificationLog>>> getNotificationLog({
    String? userId,
    NotificationChannel? channel,
    NotificationStatus? status,
  });
}
