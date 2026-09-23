import 'message_status.dart';

class ChatAttachment {
  const ChatAttachment({
    required this.filename,
    this.localPath,
    this.fileId,
  });

  final String filename;
  final String? localPath;
  final String? fileId;

  bool get uploaded => fileId != null && fileId!.isNotEmpty;

  ChatAttachment copyWith({
    String? filename,
    String? localPath,
    String? fileId,
    bool clearLocalPath = false,
  }) {
    return ChatAttachment(
      filename: filename ?? this.filename,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      fileId: fileId ?? this.fileId,
    );
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        if (localPath != null) 'localPath': localPath,
        if (fileId != null) 'fileId': fileId,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      filename: json['filename']?.toString() ?? 'file',
      localPath: json['localPath']?.toString(),
      fileId: json['fileId']?.toString(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.localId,
    this.remoteId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.body,
    this.attachments = const [],
    required this.status,
    this.retryCount = 0,
    this.nextRetryAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String localId;
  final String? remoteId;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String body;
  final List<ChatAttachment> attachments;
  final MessageStatus status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPendingUpload => status == MessageStatus.pending || status == MessageStatus.failed;

  ChatMessage copyWith({
    String? remoteId,
    String? body,
    List<ChatAttachment>? attachments,
    MessageStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    DateTime? updatedAt,
    bool clearNextRetry = false,
  }) {
    return ChatMessage(
      localId: localId,
      remoteId: remoteId ?? this.remoteId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      body: body ?? this.body,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: clearNextRetry ? null : nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    this.lastMessage = '',
    this.lastAt,
    this.unreadCount = 0,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String lastMessage;
  final DateTime? lastAt;
  final int unreadCount;
}

class SyncState {
  const SyncState({
    required this.key,
    this.lastCursor,
    this.lastError,
    this.isSyncing = false,
  });

  final String key;
  final String? lastCursor;
  final String? lastError;
  final bool isSyncing;
}

String conversationIdFor(String userA, String userB) {
  final ids = [userA, userB]..sort();
  return '${ids[0]}_${ids[1]}';
}

String peerIdFromConversation(String conversationId, String myId) {
  final parts = conversationId.split('_');
  if (parts.length < 2) return conversationId;
  return parts[0] == myId ? parts.sublist(1).join('_') : parts[0];
}
