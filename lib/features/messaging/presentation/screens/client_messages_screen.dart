import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_theme.dart';
import '../../../../ui/widgets/portal_shell.dart';
import '../providers/messages_provider.dart';

class ClientMessagesScreen extends ConsumerWidget {
  const ClientMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientInboxProvider);
    return PortalPageScaffold(
      title: 'messages',
      subtitle: 'Threads linked to your service requests.',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(child: Text('No conversations yet', style: TextStyle(color: AppColors.muted)));
          }
          return ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              return ListTile(
                title: Text(thread.request.title),
                subtitle: Text(thread.last?.message ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: thread.unread > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        child: Text('${thread.unread}', style: const TextStyle(fontSize: 12)),
                      )
                    : Text(thread.last?.createdAt?.toLocal().toString().split('.').first ?? ''),
                onTap: () => context.go('/client/requests/${thread.request.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
