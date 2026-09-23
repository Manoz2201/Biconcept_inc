class CacheTtl {
  const CacheTtl(this.key, this.duration);
  final String key;
  final Duration duration;

  static const userProfile = Duration(hours: 1);
  static const catalog = Duration(hours: 6);
  static const projectList = Duration(minutes: 5);
  static const invoiceList = Duration(minutes: 2);
  static const dashboard = Duration(minutes: 5);
  static const notifications = Duration(seconds: 30);

  static Duration forKey(String key) {
    if (key.startsWith('user_profile_')) return userProfile;
    if (key == 'services_list' || key == 'portfolio_list') return catalog;
    if (key.startsWith('project_')) return projectList;
    if (key.startsWith('invoice_')) return invoiceList;
    if (key.startsWith('dashboard')) return dashboard;
    if (key.startsWith('notifications')) return notifications;
    return const Duration(minutes: 5);
  }
}

class OfflineAction {
  const OfflineAction({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'payload': payload,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'lastError': ?lastError,
      };

  factory OfflineAction.fromJson(Map<String, dynamic> data) => OfflineAction(
        id: data['id']?.toString() ?? '',
        actionType: data['actionType']?.toString() ?? '',
        payload: data['payload'] is Map ? Map<String, dynamic>.from(data['payload'] as Map) : const {},
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
        attempts: (data['attempts'] as num?)?.toInt() ?? 0,
        lastError: data['lastError']?.toString(),
      );
}

abstract class CacheService {
  Future<void> init();
  T? get<T>(String key, {Duration? ttl});
  void put<T>(String key, T value, {Duration? ttl});
  void delete(String key);
  void clear();
  void clearExpired();
  void enqueue(OfflineAction action);
  OfflineAction? dequeue();
  List<OfflineAction> getAll();
  void clearQueue();
}
