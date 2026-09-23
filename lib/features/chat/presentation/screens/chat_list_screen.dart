import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_theme.dart';
import '../../../../ui/widgets/portal_shell.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../../rbac/domain/user_role.dart';
import '../../../rbac/presentation/rbac_provider.dart';
import '../../../user_management/presentation/providers/user_providers.dart';
import '../../domain/message.dart';
import '../providers/chat_provider.dart';
import '../providers/sync_status_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final fab = _canStartChat(ref)
        ? FloatingActionButton(
            onPressed: () => _newChat(context, ref),
            child: const Icon(Icons.chat_outlined),
          )
        : null;
    final body = RefreshIndicator(
        onRefresh: () => ref.read(chatControllerProvider).refresh(),
        child: conversations.when(
          loading: () => ListView(children: [const LinearProgressIndicator()]),
          error: (error, _) => ListView(children: [ListTile(title: Text('$error'))]),
          data: (items) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (sync != null && (sync.pending > 0 || sync.failed > 0 || sync.isSyncing))
                  ListTile(
                    dense: true,
                    leading: sync.isSyncing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_outlined),
                    title: Text(
                      sync.failed > 0
                          ? '${sync.failed} failed · tap a message to retry'
                          : sync.pending > 0
                              ? '${sync.pending} waiting to send'
                              : 'Syncing',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No conversations yet', style: TextStyle(color: AppColors.muted)),
                  ),
                for (final item in items)
                  ListTile(
                    title: Text(item.peerName.isEmpty ? item.peerId : item.peerName),
                    subtitle: Text(item.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: item.unreadCount > 0
                        ? CircleAvatar(radius: 12, child: Text('${item.unreadCount}', style: const TextStyle(fontSize: 12)))
                        : null,
                    onTap: () {
                      final path = embedded ? '/client/chat/${item.id}' : '/chat/${item.id}';
                      context.push(path);
                    },
                  ),
              ],
            );
          },
        ),
    );
    if (embedded) {
      return PortalPageScaffold(
        title: 'messages',
        subtitle: 'Conversations with the studio.',
        floatingActionButton: fab,
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/app')),
      ),
      floatingActionButton: fab,
      body: body,
    );
  }

  bool _canStartChat(WidgetRef ref) {
    final rbac = ref.watch(rbacProvider);
    return rbac.allows(Permission.userView) || rbac.allows(Permission.clientView);
  }

  Future<void> _newChat(BuildContext context, WidgetRef ref) async {
    final me = ref.read(sessionControllerProvider).user;
    if (me == null) return;
    final users = ref.read(userListProvider).valueOrNull?.users ?? const [];
    final peers = users.where((user) {
      if (user.accountId == me.accountId) return false;
      if (me.role == UserRole.client) return user.role.isStaff;
      return true;
    }).toList();
    if (peers.isEmpty) {
      await ref.read(userListProvider.notifier).apply(const UserListQuery());
    }
    if (!context.mounted) return;
    final picked = await showDialog<Conversation?>(
      context: context,
      builder: (context) {
        final latest = ref.read(userListProvider).valueOrNull?.users ?? peers;
        final options = latest.where((user) => user.accountId != me.accountId).toList();
        return SimpleDialog(
          title: const Text('New chat'),
          children: [
            if (options.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No people to chat with yet')),
            for (final user in options)
              SimpleDialogOption(
                onPressed: () async {
                  await ref.read(chatControllerProvider).openPeer(peerId: user.accountId, peerName: user.name);
                  if (context.mounted) {
                    Navigator.pop(
                      context,
                      Conversation(
                        id: conversationIdFor(me.accountId, user.accountId),
                        peerId: user.accountId,
                        peerName: user.name,
                      ),
                    );
                  }
                },
                child: Text(user.name.isEmpty ? user.email : user.name),
              ),
          ],
        );
      },
    );
    if (picked != null && context.mounted) {
      final path = embedded ? '/client/chat/${picked.id}' : '/chat/${picked.id}';
      context.push(path);
    }
  }
}
