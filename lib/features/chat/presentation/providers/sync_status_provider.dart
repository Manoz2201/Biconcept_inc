import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_provider.dart';

class ChatSyncStatus {
  const ChatSyncStatus({
    this.pending = 0,
    this.failed = 0,
    this.lastError,
    this.isSyncing = false,
  });

  final int pending;
  final int failed;
  final String? lastError;
  final bool isSyncing;
}

final syncStatusProvider = StreamProvider<ChatSyncStatus>((ref) async* {
  final db = ref.watch(chatDatabaseProvider);
  Future<ChatSyncStatus> snapshot() async {
    final state = await db.readSyncState('catch_up');
    return ChatSyncStatus(
      pending: await db.pendingCount(),
      failed: await db.failedCount(),
      lastError: state.lastError,
      isSyncing: state.isSyncing,
    );
  }

  yield await snapshot();
  yield* db.watchConversations().asyncMap((_) => snapshot());
});
