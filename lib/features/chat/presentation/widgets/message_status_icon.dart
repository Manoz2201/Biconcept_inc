import 'package:flutter/material.dart';

import '../../domain/message_status.dart';

class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({super.key, required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.pending => const Icon(Icons.schedule, size: 14),
      MessageStatus.sent => const Icon(Icons.check, size: 14),
      MessageStatus.delivered => const Icon(Icons.done_all, size: 14),
      MessageStatus.read => Icon(Icons.done_all, size: 14, color: Theme.of(context).colorScheme.primary),
      MessageStatus.failed => const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
    };
  }
}
