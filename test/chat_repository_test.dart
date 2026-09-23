import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/catalog/domain/storage_repository.dart';
import 'package:biconcept/features/chat/data/chat_repository_impl.dart';
import 'package:biconcept/features/chat/data/local/database.dart';
import 'package:biconcept/features/chat/data/remote/chat_remote_datasource.dart';
import 'package:biconcept/features/chat/domain/message.dart';
import 'package:biconcept/features/chat/domain/message_status.dart';
import 'package:biconcept/features/chat/sync/catch_up_sync.dart';
import 'package:biconcept/features/chat/sync/connectivity_listener.dart';
import 'package:biconcept/features/chat/sync/sync_worker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Tables extends Mock implements TablesDB {}

class _Storage extends Mock implements Storage {}

class FakeChatRemote implements ChatRemote {
  FakeChatRemote({this.failTimes = 0, this.hangUpload = false});

  int failTimes;
  bool hangUpload;
  final uploaded = <ChatMessage>[];
  final files = <String>[];
  final statusUpdates = <String, MessageStatus>{};
  List<ChatMessage> catchUpRows = [];
  Completer<ChatMessage>? hang;
  void Function(Map<String, dynamic>)? onEvent;

  @override
  Future<ChatMessage> uploadMessage(ChatMessage message) async {
    if (hangUpload) {
      hang ??= Completer<ChatMessage>();
      return hang!.future;
    }
    if (failTimes > 0) {
      failTimes--;
      throw Exception('offline');
    }
    final existing = uploaded.where((item) => item.localId == message.localId);
    if (existing.isNotEmpty) return existing.first;
    final sent = message.copyWith(remoteId: message.localId, status: MessageStatus.sent);
    uploaded.add(sent);
    return sent;
  }

  @override
  Future<List<ChatMessage>> catchUp({String? cursor}) async => catchUpRows;

  @override
  Future<void> updateStatus(String localId, MessageStatus status) async {
    statusUpdates[localId] = status;
  }

  @override
  Future<String> uploadFile({
    required UploadBytes file,
    required String senderId,
    required String receiverId,
  }) async {
    files.add(file.filename);
    return 'file-${files.length}';
  }

  @override
  ChatSubscription listen(void Function(Map<String, dynamic> payload) handler) {
    onEvent = handler;
    return ChatSubscription(() => onEvent = null);
  }

  @override
  ChatMessage messageFromRealtime(Map<String, dynamic> payload) {
    return ChatRemoteDatasource.messageFromRow(
      payload[r'$id']?.toString() ?? payload['localId']?.toString() ?? '',
      payload,
    );
  }
}

models.Row _row(String id, Map<String, dynamic> data) => models.Row(
      $id: id,
      $sequence: '1',
      $tableId: 'chat_messages',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

void main() {
  test('conversation ids are stable regardless of argument order', () {
    expect(conversationIdFor('b', 'a'), 'a_b');
    expect(conversationIdFor('a', 'b'), conversationIdFor('b', 'a'));
  });

  test('backoff is 1s 2s 4s 8s 16s then 60s', () {
    expect(chatBackoffFor(1), const Duration(seconds: 1));
    expect(chatBackoffFor(2), const Duration(seconds: 2));
    expect(chatBackoffFor(3), const Duration(seconds: 4));
    expect(chatBackoffFor(4), const Duration(seconds: 8));
    expect(chatBackoffFor(5), const Duration(seconds: 16));
    expect(chatBackoffFor(6), const Duration(seconds: 60));
    expect(kChatMaxRetries, 5);
  });

  test('send writes pending locally before Appwrite returns', () async {
    final db = ChatDatabase();
    final remote = FakeChatRemote(hangUpload: true);
    final repo = ChatRepositoryImpl(
      db: db,
      remote: remote,
      userId: () => 'me',
      newLocalId: () => 'local-1',
    );

    final message = await repo.sendMessage(senderId: 'me', receiverId: 'you', body: 'Hi');
    expect(message.status, MessageStatus.pending);
    expect((await db.findByLocalId('local-1'))!.status, MessageStatus.pending);
    expect(remote.uploaded, isEmpty);

    var spins = 0;
    while (remote.hang == null && spins < 10) {
      await Future<void>.value();
      spins++;
    }
    expect(remote.hang, isNotNull);
    remote.hang!.complete(message.copyWith(remoteId: 'local-1', status: MessageStatus.sent));
    await repo.drainOutbox();
    expect((await db.findByLocalId('local-1'))!.status, MessageStatus.sent);
  });

  test('outbox upload marks sent and replaces attachment path with fileId', () async {
    final db = ChatDatabase();
    final remote = FakeChatRemote();
    final repo = ChatRepositoryImpl(
      db: db,
      remote: remote,
      userId: () => 'me',
      newLocalId: () => 'local-2',
    );
    await repo.sendMessage(
      senderId: 'me',
      receiverId: 'you',
      body: 'plan',
      attachments: [UploadBytes(bytes: List<int>.filled(8, 1), filename: 'plan.pdf')],
    );
    await repo.drainOutbox();
    final stored = await db.findByLocalId('local-2');
    expect(stored!.status, MessageStatus.sent);
    expect(stored.attachments.single.fileId, 'file-1');
    expect(stored.attachments.single.localPath, isNull);
    expect(remote.files, ['plan.pdf']);
  });

  test('five failed uploads mark failed and retry button resets the outbox', () async {
    final db = ChatDatabase();
    final remote = FakeChatRemote(failTimes: 5);
    final repo = ChatRepositoryImpl(
      db: db,
      remote: remote,
      userId: () => 'me',
      newLocalId: () => 'local-3',
    );
    await repo.sendMessage(senderId: 'me', receiverId: 'you', body: 'Hi');
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 4; i++) {
      final current = await db.findByLocalId('local-3');
      await db.upsertMessage(current!.copyWith(clearNextRetry: true, status: MessageStatus.pending));
      await repo.drainOutbox();
    }
    expect((await db.findByLocalId('local-3'))!.status, MessageStatus.failed);
    expect((await db.findByLocalId('local-3'))!.retryCount, 5);

    remote.failTimes = 0;
    await repo.retryMessage('local-3');
    expect((await db.findByLocalId('local-3'))!.status, MessageStatus.sent);
    expect((await db.findByLocalId('local-3'))!.retryCount, 0);
  });

  test('incoming realtime rows are written locally and acked delivered', () async {
    final db = ChatDatabase();
    final remote = FakeChatRemote();
    final repo = ChatRepositoryImpl(db: db, remote: remote, userId: () => 'me');
    repo.startRealtime();
    remote.onEvent!({
      r'$id': 'in-1',
      'localId': 'in-1',
      'conversationId': conversationIdFor('me', 'you'),
      'senderId': 'you',
      'receiverId': 'me',
      'body': 'Hello',
      'attachments': const <String>[],
      'status': 'sent',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await Future<void>.delayed(Duration.zero);
    final stored = await db.findByLocalId('in-1');
    expect(stored!.status, MessageStatus.delivered);
    expect(remote.statusUpdates['in-1'], MessageStatus.delivered);
    expect((await db.listConversations()).single.unreadCount, 1);
    repo.stopRealtime();
  });

  test('catch-up writes Appwrite rows into the local DB', () async {
    final db = ChatDatabase();
    final remote = FakeChatRemote();
    remote.catchUpRows = [
      ChatMessage(
        localId: 'c1',
        remoteId: 'c1',
        conversationId: conversationIdFor('me', 'you'),
        senderId: 'you',
        receiverId: 'me',
        body: 'catch up',
        status: MessageStatus.sent,
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
      ),
    ];
    final repo = ChatRepositoryImpl(db: db, remote: remote, userId: () => 'me');
    await CatchUpSync(repo).run();
    expect((await db.findByLocalId('c1'))!.body, 'catch up');
    expect((await db.readSyncState('catch_up')).lastCursor, '2026-01-01T00:00:00.000Z');
  });

  test('reconnect runs catch-up and the outbox worker', () async {
    final db = ChatDatabase();
    final remote = FakeChatRemote(failTimes: 1);
    final repo = ChatRepositoryImpl(
      db: db,
      remote: remote,
      userId: () => 'me',
      newLocalId: () => 'local-4',
    );
    await repo.sendMessage(senderId: 'me', receiverId: 'you', body: 'queued');
    await Future<void>.delayed(Duration.zero);
    expect((await db.findByLocalId('local-4'))!.status, MessageStatus.pending);
    await db.upsertMessage(
      (await db.findByLocalId('local-4'))!.copyWith(clearNextRetry: true, status: MessageStatus.pending),
    );

    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    final listener = ChatConnectivityListener(
      catchUp: CatchUpSync(repo),
      worker: SyncWorker(repo),
      checkConnectivity: () async => [ConnectivityResult.none],
      onConnectivityChanged: changes.stream,
    );
    await listener.start();
    expect(listener.isOnline, isFalse);
    changes.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    await repo.drainOutbox();
    expect((await db.findByLocalId('local-4'))!.status, MessageStatus.sent);
    await listener.dispose();
    await changes.close();
  });

  test('409 on createRow returns the existing row (dedup by localId)', () async {
    final tables = _Tables();
    when(
      () => tables.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
        permissions: any(named: 'permissions'),
      ),
    ).thenThrow(AppwriteException('document_already_exists', 409));
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer(
      (_) async => _row('local-dup', {
        'localId': 'local-dup',
        'conversationId': 'a_b',
        'senderId': 'a',
        'receiverId': 'b',
        'body': 'Hi',
        'attachments': const <String>[],
        'status': 'sent',
        'createdAt': '2026-01-01T00:00:00.000Z',
      }),
    );
    final remote = ChatRemoteDatasource(tables: tables, storage: _Storage(), databaseId: 'db');
    final result = await remote.uploadMessage(
      ChatMessage(
        localId: 'local-dup',
        conversationId: 'a_b',
        senderId: 'a',
        receiverId: 'b',
        body: 'Hi',
        status: MessageStatus.pending,
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
      ),
    );
    expect(result.remoteId, 'local-dup');
    expect(result.status, MessageStatus.sent);
  });
}
