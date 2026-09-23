import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../data/chat_repository_impl.dart';
import '../../data/local/database.dart';
import '../../data/local/open_chat_database.dart';
import '../../data/remote/chat_remote_datasource.dart';
import '../../domain/chat_repository.dart';
import '../../domain/message.dart';
import '../../sync/catch_up_sync.dart';
import '../../sync/sync_worker.dart';

final chatDatabaseProvider = Provider<ChatDatabase>((ref) {
  final db = ChatDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final chatRemoteProvider = Provider<ChatRemote>((ref) {
  return ChatRemoteDatasource();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepositoryImpl(
    db: ref.watch(chatDatabaseProvider),
    remote: ref.watch(chatRemoteProvider),
    userId: () => ref.read(sessionControllerProvider).user?.accountId ?? '',
  );
  ref.onDispose(repo.stopRealtime);
  return repo;
});

final chatSyncWorkerProvider = Provider<SyncWorker>((ref) {
  return SyncWorker(ref.watch(chatRepositoryProvider));
});

final chatCatchUpProvider = Provider<CatchUpSync>((ref) {
  return CatchUpSync(ref.watch(chatRepositoryProvider));
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

class ChatController {
  ChatController(this._ref);
  final Ref _ref;

  Future<ChatMessage> send({
    required String receiverId,
    required String body,
    String? peerName,
    List<UploadBytes>? attachments,
  }) async {
    final me = _ref.read(sessionControllerProvider).user?.accountId;
    if (me == null) throw StateError('Not signed in');
    final message = await _ref.read(chatRepositoryProvider).sendMessage(
          senderId: me,
          receiverId: receiverId,
          body: body,
          peerName: peerName,
          attachments: attachments,
        );
    await _ref.read(chatSyncWorkerProvider).tick();
    return message;
  }

  Future<void> retry(String localId) {
    return _ref.read(chatRepositoryProvider).retryMessage(localId);
  }

  Future<void> markRead(String conversationId) async {
    final me = _ref.read(sessionControllerProvider).user?.accountId;
    if (me == null) return;
    await _ref.read(chatRepositoryProvider).markConversationRead(
          conversationId: conversationId,
          readerId: me,
        );
  }

  Future<void> refresh() async {
    await _ref.read(chatCatchUpProvider).run();
  }

  Future<void> openPeer({required String peerId, required String peerName}) {
    final me = _ref.read(sessionControllerProvider).user?.accountId;
    if (me == null) throw StateError('Not signed in');
    return _ref.read(chatRepositoryProvider).ensureConversation(
          myId: me,
          peerId: peerId,
          peerName: peerName,
        );
  }
}

final chatControllerProvider = Provider<ChatController>(ChatController.new);

Future<Override> chatDatabaseOverride() async {
  final db = await openChatDatabase();
  return chatDatabaseProvider.overrideWithValue(db);
}
