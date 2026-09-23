enum MessageStatus {
  pending('pending'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed');

  const MessageStatus(this.value);
  final String value;

  static MessageStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw,
        orElse: () => MessageStatus.pending,
      );

  bool get isOutgoingTerminal => this == MessageStatus.failed || this == MessageStatus.read;
}

Duration chatBackoffFor(int failedAttempts) {
  const steps = [1, 2, 4, 8, 16];
  if (failedAttempts <= 0) return Duration.zero;
  if (failedAttempts > 5) return const Duration(seconds: 60);
  if (failedAttempts > steps.length) return const Duration(seconds: 60);
  return Duration(seconds: steps[failedAttempts - 1]);
}

const kChatMaxRetries = 5;
