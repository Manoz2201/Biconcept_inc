import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../../core/appwrite/appwrite_client.dart';
import '../../../../core/appwrite/row_permissions.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../domain/message.dart';
import '../../domain/message_status.dart';

class ChatSubscription {
  const ChatSubscription(this.close);
  final void Function() close;
}

abstract class ChatRemote {
  Future<ChatMessage> uploadMessage(ChatMessage message);

  Future<List<ChatMessage>> catchUp({String? cursor});

  Future<void> updateStatus(String localId, MessageStatus status);

  Future<String> uploadFile({
    required UploadBytes file,
    required String senderId,
    required String receiverId,
  });

  ChatSubscription listen(void Function(Map<String, dynamic> payload) onEvent);

  ChatMessage messageFromRealtime(Map<String, dynamic> payload);
}

class ChatRemoteDatasource implements ChatRemote {
  ChatRemoteDatasource({
    TablesDB? tables,
    Storage? storage,
    Realtime? realtime,
    String? databaseId,
  }) : this._(
          tables ?? AppwriteService.tables,
          storage ?? AppwriteService.storage,
          realtime,
          databaseId ?? AppwriteService.dbId,
        );

  ChatRemoteDatasource._(
    this._tables,
    this._storage,
    this._realtime,
    this._databaseId,
  );

  final TablesDB _tables;
  final Storage _storage;
  final Realtime? _realtime;
  final String _databaseId;

  String get realtimeChannel =>
      'databases.$_databaseId.tables.${AppwriteService.chatMessagesCol}.rows';

  @override
  ChatSubscription listen(void Function(Map<String, dynamic> payload) onEvent) {
    final realtime = _realtime ?? Realtime(AppwriteService.client);
    final subscription = realtime.subscribe([realtimeChannel]);
    subscription.stream.listen((event) => onEvent(event.payload));
    return ChatSubscription(subscription.close);
  }

  @override
  Future<ChatMessage> uploadMessage(ChatMessage message) async {
    final attachments = <String>[
      for (final item in message.attachments)
        if (item.fileId != null && item.fileId!.isNotEmpty) item.fileId!,
    ];
    try {
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.chatMessagesCol,
        rowId: message.localId,
        data: {
          'localId': message.localId,
          'conversationId': message.conversationId,
          'senderId': message.senderId,
          'receiverId': message.receiverId,
          'body': message.body,
          'attachments': attachments,
          'status': MessageStatus.sent.value,
          'createdAt': message.createdAt.toUtc().toIso8601String(),
        },
        permissions: directMessagePermissions(message.senderId, message.receiverId),
      );
      return messageFromRow(row.$id, row.data);
    } on AppwriteException catch (error) {
      if (error.code == 409) {
        final existing = await _tables.getRow(
          databaseId: _databaseId,
          tableId: AppwriteService.chatMessagesCol,
          rowId: message.localId,
        );
        return messageFromRow(existing.$id, existing.data);
      }
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> catchUp({String? cursor}) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.chatMessagesCol,
      queries: [
        if (cursor != null && cursor.isNotEmpty) Query.greaterThan('createdAt', cursor),
        Query.orderAsc('createdAt'),
        Query.limit(100),
      ],
    );
    return [for (final row in page.rows) messageFromRow(row.$id, row.data)];
  }

  @override
  Future<void> updateStatus(String localId, MessageStatus status) async {
    await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.chatMessagesCol,
      rowId: localId,
      data: {'status': status.value},
    );
  }

  @override
  Future<String> uploadFile({
    required UploadBytes file,
    required String senderId,
    required String receiverId,
  }) async {
    final filename = sanitizeUploadName(file.filename);
    validateUpload(file.bytes, filename);
    final created = await _storage.createFile(
      bucketId: AppwriteService.clientUploadsBucket,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: Uint8List.fromList(file.bytes), filename: filename),
      permissions: directMessagePermissions(senderId, receiverId),
    );
    return created.$id;
  }

  @override
  ChatMessage messageFromRealtime(Map<String, dynamic> payload) {
    final id = payload[r'$id']?.toString() ?? payload['localId']?.toString() ?? '';
    return messageFromRow(id, payload);
  }

  static ChatMessage messageFromRow(String id, Map<String, dynamic> data) {
    final attachments = data['attachments'];
    final created = DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now().toUtc();
    return ChatMessage(
      localId: data['localId']?.toString() ?? id,
      remoteId: id,
      conversationId: data['conversationId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      receiverId: data['receiverId']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      attachments: [
        if (attachments is List)
          for (final item in attachments)
            ChatAttachment(filename: item.toString(), fileId: item.toString()),
      ],
      status: MessageStatus.fromString(data['status']?.toString() ?? 'sent'),
      createdAt: created,
      updatedAt: created,
    );
  }
}
