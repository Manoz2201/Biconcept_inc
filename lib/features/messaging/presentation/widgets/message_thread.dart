import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/service_request_message.dart';
import '../providers/messages_provider.dart';
import 'message_bubble.dart';
import 'message_input.dart';

class MessageThread extends ConsumerWidget {
  const MessageThread({super.key, required this.serviceRequestId});

  final String serviceRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(messagesProvider(serviceRequestId));
    final me = ref.watch(sessionControllerProvider).user?.accountId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('$error'),
          data: (messages) {
            if (messages.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No messages yet'),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(ref, messages, me));
            return Column(
              children: [
                for (final message in messages)
                  MessageBubble(message: message, mine: message.senderId == me),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        MessageInput(
          onSend: (text, files) async {
            final wait = ref.read(messageCooldownProvider).remaining();
            if (wait != null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Wait ${wait.inSeconds + 1}s before sending again')),
                );
              }
              return;
            }
            final result = await ref.read(messageRepositoryProvider).sendMessage(
                  serviceRequestId,
                  text,
                  attachments: files,
                );
            if (result.isSuccess) ref.read(messageCooldownProvider).markSent();
            ref.invalidate(messagesProvider(serviceRequestId));
            ref.invalidate(unreadCountProvider(serviceRequestId));
            ref.invalidate(clientInboxProvider);
          },
        ),
      ],
    );
  }

  Future<void> _markRead(WidgetRef ref, List<ServiceRequestMessage> messages, String? me) async {
    final repo = ref.read(messageRepositoryProvider);
    for (final message in messages) {
      if (!message.isRead && message.senderId != me) {
        await repo.markAsRead(message.id);
      }
    }
  }
}
