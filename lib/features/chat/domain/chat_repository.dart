import '../../catalog/domain/storage_repository.dart';
import 'message.dart';

abstract class ChatRepository {
  Stream<List<Conversation>> watchConversations();

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<ChatMessage> sendMessage({
    required String senderId,
    required String receiverId,
    required String body,
    String? peerName,
    List<UploadBytes>? attachments,
  });

  Future<void> retryMessage(String localId);

  Future<void> markConversationRead({
    required String conversationId,
    required String readerId,
  });

  Future<void> catchUp();

  Future<void> drainOutbox();

  void startRealtime();

  void stopRealtime();

  Future<void> ensureConversation({
    required String myId,
    required String peerId,
    required String peerName,
  });
}
