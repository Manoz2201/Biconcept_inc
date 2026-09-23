import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/service_request_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});

  final ServiceRequestMessage message;
  final bool mine;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.senderName, style: TextStyle(fontSize: 12, color: mine ? AppColors.onPrimary.withValues(alpha: 0.8) : AppColors.muted)),
            const SizedBox(height: 4),
            Text(message.message, style: TextStyle(color: mine ? AppColors.onPrimary : AppColors.text)),
            if (message.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${message.attachments.length} attachment(s)',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
