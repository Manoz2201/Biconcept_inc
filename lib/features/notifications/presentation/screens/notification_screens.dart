import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/notification_models.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(notificationsProvider(null));
    return PermissionGate(
      permission: Permission.notificationPreferenceView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(notificationRepositoryProvider).markAllAsRead();
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
              },
              child: const Text('Mark all read'),
            ),
            IconButton(onPressed: () => context.push('/notifications/preferences'), icon: const Icon(Icons.tune)),
          ],
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No notifications yet'))
              : ListView(
                  children: [
                    for (final item in items)
                      ListTile(
                        title: Text(item.title),
                        subtitle: Text(item.body),
                        leading: Icon(item.status == NotificationStatus.read ? Icons.notifications_none : Icons.notifications_active),
                        onTap: () async {
                          await ref.read(notificationRepositoryProvider).markAsRead(item.id);
                          ref.invalidate(notificationsProvider);
                          if (!context.mounted) return;
                          if (item.actionUrl != null && item.actionUrl!.startsWith('/')) {
                            context.go(item.actionUrl!);
                          } else {
                            context.push('/notifications/${item.id}');
                          }
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class NotificationDetailScreen extends ConsumerWidget {
  const NotificationDetailScreen({super.key, required this.notificationId});

  final String notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(notificationsProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) {
          final item = items.cast<NotificationLog?>().firstWhere((row) => row?.id == notificationId, orElse: () => null);
          if (item == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleLarge),
              Text(item.body),
              Text(item.type.label),
              if (item.actionUrl != null) Text(item.actionUrl!),
            ],
          );
        },
      ),
    );
  }
}

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    return PermissionGate(
      permission: Permission.notificationPreferenceEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Notification preferences')),
        body: prefs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (item) => ListView(
            children: [
              SwitchListTile(
                title: const Text('Email'),
                value: item.emailEnabled,
                onChanged: (value) => _patch(ref, {'emailEnabled': value}),
              ),
              SwitchListTile(
                title: const Text('Push'),
                value: item.pushEnabled,
                onChanged: (value) => _patch(ref, {'pushEnabled': value}),
              ),
              SwitchListTile(
                title: const Text('SMS'),
                value: item.smsEnabled,
                onChanged: (value) => _patch(ref, {'smsEnabled': value}),
              ),
              SwitchListTile(
                title: const Text('WhatsApp'),
                value: item.whatsappEnabled,
                onChanged: (value) => _patch(ref, {'whatsappEnabled': value}),
              ),
              SwitchListTile(
                title: const Text('In-app'),
                value: item.inAppEnabled,
                onChanged: (value) => _patch(ref, {'inAppEnabled': value}),
              ),
              ListTile(
                title: const Text('Digest'),
                subtitle: Text(item.digestFrequency),
                onTap: () => _patch(ref, {'digestFrequency': item.digestFrequency == 'instant' ? 'daily' : 'instant'}),
              ),
              ListTile(
                title: const Text('Quiet hours'),
                subtitle: Text('${item.quietHoursStart ?? '22:00'} – ${item.quietHoursEnd ?? '07:00'}'),
                onTap: () => _patch(ref, {'quietHoursStart': '22:00', 'quietHoursEnd': '07:00'}),
              ),
              const Padding(padding: EdgeInsets.all(16), child: Text('Event types')),
              for (final type in NotificationType.values)
                SwitchListTile(
                  title: Text(type.label),
                  value: item.eventEnabled(type),
                  onChanged: (value) {
                    final map = {...?item.eventPreferences, type.value: value};
                    _patch(ref, {'eventPreferences': map});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _patch(WidgetRef ref, Map<String, dynamic> data) async {
    await ref.read(notificationRepositoryProvider).updateNotificationPreferences(data);
    ref.invalidate(notificationPreferencesProvider);
  }
}
