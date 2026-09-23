import 'dart:async';
import 'dart:convert';

import '../../domain/message.dart';
import '../../domain/message_status.dart';
import 'tables/conversations.dart';
import 'tables/local_messages.dart';
import 'tables/sync_state.dart';

/// Local store matching Drift tables `local_messages`, `conversations`, and `sync_state`.
///
/// Table SQL lives in `tables/`. Drift / riverpod codegen is not run on Dart 3.13.
class ChatDatabase {
  ChatDatabase({Map<String, Map<String, Object?>>? messages})
      : _messages = messages ?? <String, Map<String, Object?>>{};

  final Map<String, Map<String, Object?>> _messages;
  final _conversations = <String, Map<String, Object?>>{};
  final _sync = <String, Map<String, Object?>>{};
  final _changes = StreamController<void>.broadcast();
  Future<void> Function()? _persist;

  void attachPersister(Future<void> Function() persist) => _persist = persist;

  Future<void> open() async {}

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
    final persist = _persist;
    if (persist != null) unawaited(persist());
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    yield await listMessages(conversationId);
    await for (final _ in _changes.stream) {
      yield await listMessages(conversationId);
    }
  }

  Stream<List<Conversation>> watchConversations() async* {
    yield await listConversations();
    await for (final _ in _changes.stream) {
      yield await listConversations();
    }
  }

  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final rows = _messages.values.where((row) => row['conversation_id'] == conversationId).toList()
      ..sort((a, b) => _millis(a['created_at']).compareTo(_millis(b['created_at'])));
    return [for (final row in rows) messageFromRow(row)];
  }

  Future<List<Conversation>> listConversations() async {
    final rows = _conversations.values.toList()
      ..sort((a, b) => _millis(b['last_at']).compareTo(_millis(a['last_at'])));
    return [for (final row in rows) conversationFromRow(row)];
  }

  Future<ChatMessage?> findByLocalId(String localId) async {
    final row = _messages[localId];
    return row == null ? null : messageFromRow(row);
  }

  Future<void> upsertMessage(ChatMessage message) async {
    _messages[message.localId] = {
      'local_id': message.localId,
      'remote_id': message.remoteId,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'receiver_id': message.receiverId,
      'body': message.body,
      'attachments': jsonEncode([for (final item in message.attachments) item.toJson()]),
      'status': message.status.value,
      'retry_count': message.retryCount,
      'next_retry_at': message.nextRetryAt?.millisecondsSinceEpoch,
      'created_at': message.createdAt.millisecondsSinceEpoch,
      'updated_at': message.updatedAt.millisecondsSinceEpoch,
    };
    _notify();
  }

  Future<void> upsertConversation(Conversation conversation) async {
    _conversations[conversation.id] = {
      'id': conversation.id,
      'peer_id': conversation.peerId,
      'peer_name': conversation.peerName,
      'last_message': conversation.lastMessage,
      'last_at': conversation.lastAt?.millisecondsSinceEpoch,
      'unread_count': conversation.unreadCount,
    };
    _notify();
  }

  Future<Conversation?> findConversation(String id) async {
    final row = _conversations[id];
    return row == null ? null : conversationFromRow(row);
  }

  Future<List<ChatMessage>> pendingOutbox() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final row in _messages.values)
        if (row['status'] == MessageStatus.pending.value &&
            (row['next_retry_at'] == null || _millis(row['next_retry_at']) <= now))
          messageFromRow(row),
    ];
  }

  Future<int> pendingCount() async {
    return _messages.values.where((row) => row['status'] == MessageStatus.pending.value).length;
  }

  Future<int> failedCount() async {
    return _messages.values.where((row) => row['status'] == MessageStatus.failed.value).length;
  }

  Future<SyncState> readSyncState(String key) async {
    final row = _sync[key];
    if (row == null) return SyncState(key: key);
    return SyncState(
      key: key,
      lastCursor: row['last_cursor']?.toString(),
      lastError: row['last_error']?.toString(),
      isSyncing: row['is_syncing'] == 1 || row['is_syncing'] == true,
    );
  }

  Future<void> writeSyncState(SyncState state) async {
    _sync[state.key] = {
      'key': state.key,
      'last_cursor': state.lastCursor,
      'last_error': state.lastError,
      'is_syncing': state.isSyncing ? 1 : 0,
    };
    _notify();
  }

  Map<String, dynamic> snapshot() => {
        'messages': _messages,
        'conversations': _conversations,
        'sync': _sync,
      };

  void restore(Map<String, dynamic> data) {
    void load(String key, Map<String, Map<String, Object?>> target) {
      final raw = data[key];
      if (raw is! Map) return;
      target
        ..clear()
        ..addAll({
          for (final entry in raw.entries)
            if (entry.value is Map)
              entry.key.toString(): Map<String, Object?>.from(entry.value as Map),
        });
    }

    load('messages', _messages);
    load('conversations', _conversations);
    load('sync', _sync);
    _notify();
  }

  static int _millis(Object? value) => value is num ? value.toInt() : 0;

  static ChatMessage messageFromRow(Map<String, Object?> row) {
    final raw = row['attachments']?.toString() ?? '[]';
    var attachments = const <ChatAttachment>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        attachments = [
          for (final item in decoded)
            if (item is Map) ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
        ];
      }
    } catch (_) {}
    return ChatMessage(
      localId: row['local_id']?.toString() ?? '',
      remoteId: row['remote_id']?.toString(),
      conversationId: row['conversation_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      receiverId: row['receiver_id']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      attachments: attachments,
      status: MessageStatus.fromString(row['status']?.toString() ?? 'pending'),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      nextRetryAt: row['next_retry_at'] is num
          ? DateTime.fromMillisecondsSinceEpoch((row['next_retry_at'] as num).toInt())
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((row['updated_at'] as num?)?.toInt() ?? 0),
    );
  }

  static Conversation conversationFromRow(Map<String, Object?> row) {
    return Conversation(
      id: row['id']?.toString() ?? '',
      peerId: row['peer_id']?.toString() ?? '',
      peerName: row['peer_name']?.toString() ?? '',
      lastMessage: row['last_message']?.toString() ?? '',
      lastAt: row['last_at'] is num
          ? DateTime.fromMillisecondsSinceEpoch((row['last_at'] as num).toInt())
          : null,
      unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  static const schemaSql = [
    LocalMessagesTable.createSql,
    ...LocalMessagesTable.indexes,
    ConversationsTable.createSql,
    ...ConversationsTable.indexes,
    SyncStateTable.createSql,
  ];

  Future<void> close() async {
    await _changes.close();
  }
}
