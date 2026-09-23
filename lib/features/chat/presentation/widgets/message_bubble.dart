import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/message.dart';
import '../../domain/message_status.dart';
import 'message_status_icon.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.onRetry,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: AppShadows.hover(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.body.isEmpty ? '(attachment)' : message.body,
                style: TextStyle(color: mine ? AppColors.onPrimary : AppColors.text),
              ),
            ),
            if (message.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${message.attachments.length} attachment(s)',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mine) MessageStatusIcon(status: message.status),
                if (mine && message.status == MessageStatus.failed && onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
