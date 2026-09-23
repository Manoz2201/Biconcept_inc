import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;
  final bool embedded;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider).markRead(widget.conversationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final me = ref.watch(sessionControllerProvider).user?.accountId ?? '';
    final conversations = ref.watch(conversationsProvider).valueOrNull ?? const [];
    final conversation = conversations.where((item) => item.id == widget.conversationId).firstOrNull;
    final peerId = conversation?.peerId ?? peerIdFromConversation(widget.conversationId, me);
    return Scaffold(
      appBar: AppBar(
        title: Text(conversation?.peerName.isNotEmpty == true ? conversation!.peerName : 'Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(widget.embedded ? '/client/chat' : '/chat'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(chatControllerProvider).refresh(),
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(children: [ListTile(title: Text('$error'))]),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No messages yet'),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final message = items[index];
                      return ChatMessageBubble(
                        message: message,
                        mine: message.senderId == me,
                        onRetry: () => ref.read(chatControllerProvider).retry(message.localId),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: PermissionGate(
              permission: Permission.messageSend,
              child: ChatMessageInput(
                onSend: (text, files) async {
                  try {
                    await ref.read(chatControllerProvider).send(
                          receiverId: peerId,
                          body: text,
                          peerName: conversation?.peerName,
                          attachments: files,
                        );
                    await ref.read(chatControllerProvider).markRead(widget.conversationId);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$error')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
