import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/appwrite/row_permissions.dart';
import '../../catalog/domain/storage_repository.dart';
import '../domain/chat_repository.dart';
import '../domain/message.dart';
import '../domain/message_status.dart';
import 'local/database.dart';
import 'remote/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required ChatDatabase db,
    required ChatRemote remote,
    required String Function() userId,
    ChatFileStore? files,
    String Function()? newLocalId,
  }) : this._(
          db,
          remote,
          userId,
          files ?? ChatFileStore(),
          newLocalId ?? (() => const Uuid().v4()),
        );

  ChatRepositoryImpl._(
    this._db,
    this._remote,
    this._userId,
    this._files,
    this._newLocalId,
  );

  final ChatDatabase _db;
  final ChatRemote _remote;
  final String Function() _userId;
  final ChatFileStore _files;
  final String Function() _newLocalId;
  ChatSubscription? _subscription;
  Future<void>? _drainFuture;

  ChatDatabase get db => _db;
  ChatRemote get remote => _remote;

  @override
  void startRealtime() {
    _subscription?.close();
    try {
      _subscription = _remote.listen((payload) {
        if (payload.isEmpty) return;
        unawaited(applyRemote(_remote.messageFromRealtime(payload)));
      });
    } catch (_) {}
  }

  @override
  void stopRealtime() {
    _subscription?.close();
    _subscription = null;
  }

  @override
  Stream<List<Conversation>> watchConversations() => _db.watchConversations();

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _db.watchMessages(conversationId);

  @override
  Future<ChatMessage> sendMessage({
    required String senderId,
    required String receiverId,
    required String body,
    String? peerName,
    List<UploadBytes>? attachments,
  }) async {
    for (final file in attachments ?? const <UploadBytes>[]) {
      validateUpload(file.bytes, sanitizeUploadName(file.filename));
    }
    final now = DateTime.now().toUtc();
    final localId = _newLocalId();
    final conversationId = conversationIdFor(senderId, receiverId);
    final stored = <ChatAttachment>[];
    for (final file in attachments ?? const <UploadBytes>[]) {
      final path = await _files.save(file, localId);
      stored.add(ChatAttachment(filename: file.filename, localPath: path));
    }
    final message = ChatMessage(
      localId: localId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      body: body.trim(),
      attachments: stored,
      status: MessageStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertMessage(message);
    await _touchConversation(
      conversationId: conversationId,
      myId: senderId,
      peerId: receiverId,
      peerName: peerName ?? receiverId,
      preview: message.body,
      at: now,
      incoming: false,
    );
    unawaited(drainOutbox());
    return message;
  }

  @override
  Future<void> retryMessage(String localId) async {
    final current = await _db.findByLocalId(localId);
    if (current == null) return;
    await _db.upsertMessage(
      current.copyWith(
        status: MessageStatus.pending,
        retryCount: 0,
        clearNextRetry: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await drainOutbox();
  }

  @override
  Future<void> markConversationRead({
    required String conversationId,
    required String readerId,
  }) async {
    final messages = await _db.listMessages(conversationId);
    for (final message in messages) {
      if (message.receiverId != readerId) continue;
      if (message.status == MessageStatus.read) continue;
      final next = message.copyWith(status: MessageStatus.read, updatedAt: DateTime.now().toUtc());
      await _db.upsertMessage(next);
      if (next.remoteId != null) {
        try {
          await _remote.updateStatus(message.localId, MessageStatus.read);
        } catch (_) {}
      }
    }
    final conversation = await _db.findConversation(conversationId);
    if (conversation != null) {
      await _db.upsertConversation(
        Conversation(
          id: conversation.id,
          peerId: conversation.peerId,
          peerName: conversation.peerName,
          lastMessage: conversation.lastMessage,
          lastAt: conversation.lastAt,
          unreadCount: 0,
        ),
      );
    }
  }

  @override
  Future<void> catchUp() async {
    final state = await _db.readSyncState('catch_up');
    await _db.writeSyncState(state.copyWith(isSyncing: true, lastError: null));
    try {
      var cursor = state.lastCursor;
      while (true) {
        final page = await _remote.catchUp(cursor: cursor);
        if (page.isEmpty) break;
        for (final message in page) {
          await applyRemote(message);
          cursor = message.createdAt.toUtc().toIso8601String();
        }
        if (page.length < 100) break;
      }
      await _db.writeSyncState(SyncState(key: 'catch_up', lastCursor: cursor, isSyncing: false));
    } catch (error) {
      await _db.writeSyncState(state.copyWith(isSyncing: false, lastError: error.toString()));
      rethrow;
    }
  }

  @override
  Future<void> drainOutbox() {
    final inFlight = _drainFuture;
    if (inFlight != null) return inFlight.then((_) => drainOutbox());
    final run = () async {
      final pending = await _db.pendingOutbox();
      for (final message in pending) {
        await _uploadOne(message);
      }
    }();
    _drainFuture = run.whenComplete(() => _drainFuture = null);
    return _drainFuture!;
  }

  @override
  Future<void> ensureConversation({
    required String myId,
    required String peerId,
    required String peerName,
  }) async {
    final id = conversationIdFor(myId, peerId);
    final existing = await _db.findConversation(id);
    if (existing != null) return;
    await _db.upsertConversation(
      Conversation(id: id, peerId: peerId, peerName: peerName),
    );
  }

  Future<void> applyRemote(ChatMessage remote) async {
    final existing = await _db.findByLocalId(remote.localId);
    final merged = existing == null
        ? remote.copyWith(
            status: remote.senderId == _userId() ? remote.status : _incomingStatus(remote.status),
          )
        : existing.copyWith(
            remoteId: remote.remoteId ?? existing.remoteId,
            status: _preferStatus(existing.status, remote.status, mine: existing.senderId == _userId()),
            attachments: _mergeAttachments(existing.attachments, remote.attachments),
            updatedAt: DateTime.now().toUtc(),
          );
    await _db.upsertMessage(merged);
    final me = _userId();
    final peerId = merged.senderId == me ? merged.receiverId : merged.senderId;
    await _touchConversation(
      conversationId: merged.conversationId,
      myId: me,
      peerId: peerId,
      peerName: peerId,
      preview: merged.body,
      at: merged.createdAt,
      incoming: merged.senderId != me && merged.status != MessageStatus.read,
    );
    if (merged.senderId != me &&
        remote.status == MessageStatus.sent &&
        merged.status != MessageStatus.read) {
      try {
        await _remote.updateStatus(merged.localId, MessageStatus.delivered);
        await _db.upsertMessage(merged.copyWith(status: MessageStatus.delivered));
      } catch (_) {}
    }
  }

  Future<void> _uploadOne(ChatMessage message) async {
    var current = message;
    try {
      final uploadedFiles = <ChatAttachment>[];
      for (final item in message.attachments) {
        if (item.uploaded) {
          uploadedFiles.add(item);
          continue;
        }
        final bytes = await _files.read(item);
        if (bytes == null) {
          uploadedFiles.add(item);
          continue;
        }
        final fileId = await _remote.uploadFile(
          file: UploadBytes(bytes: bytes, filename: item.filename),
          senderId: message.senderId,
          receiverId: message.receiverId,
        );
        uploadedFiles.add(item.copyWith(fileId: fileId, clearLocalPath: true));
      }
      current = message.copyWith(attachments: uploadedFiles);
      final remote = await _remote.uploadMessage(current);
      await _db.upsertMessage(
        current.copyWith(
          remoteId: remote.remoteId ?? current.localId,
          status: MessageStatus.sent,
          retryCount: 0,
          clearNextRetry: true,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      final retries = message.retryCount + 1;
      final failed = retries >= kChatMaxRetries;
      await _db.upsertMessage(
        current.copyWith(
          status: failed ? MessageStatus.failed : MessageStatus.pending,
          retryCount: retries,
          nextRetryAt: failed ? null : DateTime.now().add(chatBackoffFor(retries)),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<void> _touchConversation({
    required String conversationId,
    required String myId,
    required String peerId,
    required String peerName,
    required String preview,
    required DateTime at,
    required bool incoming,
  }) async {
    final existing = await _db.findConversation(conversationId);
    final unread = incoming ? (existing?.unreadCount ?? 0) + 1 : existing?.unreadCount ?? 0;
    await _db.upsertConversation(
      Conversation(
        id: conversationId,
        peerId: peerId,
        peerName: existing?.peerName.isNotEmpty == true ? existing!.peerName : peerName,
        lastMessage: preview,
        lastAt: at,
        unreadCount: unread,
      ),
    );
  }

  MessageStatus _incomingStatus(MessageStatus remote) {
    if (remote == MessageStatus.read) return MessageStatus.read;
    if (remote == MessageStatus.delivered) return MessageStatus.delivered;
    return MessageStatus.delivered;
  }

  MessageStatus _preferStatus(MessageStatus local, MessageStatus remote, {required bool mine}) {
    if (local == MessageStatus.pending || local == MessageStatus.failed) {
      if (remote == MessageStatus.sent || remote == MessageStatus.delivered || remote == MessageStatus.read) {
        return remote;
      }
      return local;
    }
    const rank = {
      MessageStatus.pending: 0,
      MessageStatus.failed: 0,
      MessageStatus.sent: 1,
      MessageStatus.delivered: 2,
      MessageStatus.read: 3,
    };
    return (rank[remote] ?? 0) >= (rank[local] ?? 0) ? remote : local;
  }

  List<ChatAttachment> _mergeAttachments(List<ChatAttachment> local, List<ChatAttachment> remote) {
    if (remote.isEmpty) return local;
    if (local.isEmpty) return remote;
    return [
      for (var i = 0; i < local.length; i++)
        local[i].copyWith(fileId: i < remote.length ? remote[i].fileId ?? local[i].fileId : local[i].fileId),
    ];
  }
}

class ChatFileStore {
  final _memory = <String, Uint8List>{};

  Future<String?> save(UploadBytes file, String localId) async {
    final key = '$localId/${file.filename}';
    _memory[key] = Uint8List.fromList(file.bytes);
    return key;
  }

  Future<Uint8List?> read(ChatAttachment attachment) async {
    final path = attachment.localPath;
    if (path == null) return null;
    return _memory[path];
  }
}

extension on SyncState {
  SyncState copyWith({String? lastCursor, String? lastError, bool? isSyncing}) {
    return SyncState(
      key: key,
      lastCursor: lastCursor ?? this.lastCursor,
      lastError: lastError,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
