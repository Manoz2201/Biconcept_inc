import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../service_requests/domain/service_request.dart';
import '../domain/message_repository.dart';
import '../domain/service_request_message.dart';

class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl({
    TablesDB? tables,
    Storage? storage,
    AuditRepository? audit,
    String? databaseId,
    String Function()? actorId,
    String Function()? actorName,
    String Function()? actorRole,
  })  : _tables = tables ?? AppwriteService.tables,
        _storage = storage ?? AppwriteService.storage,
        _audit = audit ?? AuditRepository(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown'),
        _actorName = actorName ?? (() => 'User'),
        _actorRole = actorRole ?? (() => 'client');

  final TablesDB _tables;
  final Storage _storage;
  final AuditRepository _audit;
  final String _databaseId;
  final String Function() _actorId;
  final String Function() _actorName;
  final String Function() _actorRole;

  @override
  Future<AppResult<List<ServiceRequestMessage>>> getMessages(String serviceRequestId) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        queries: [
          Query.equal('serviceRequestId', serviceRequestId),
          Query.orderAsc('createdAt'),
          Query.limit(200),
        ],
      );
      return [
        for (final row in page.rows)
          ServiceRequestMessage.fromRow(row.$id, row.data),
      ].where((message) => message.isChat).toList();
    });
  }

  @override
  Future<AppResult<ServiceRequestMessage>> sendMessage(
    String serviceRequestId,
    String message, {
    List<UploadBytes>? attachments,
  }) {
    return AppwriteService.guard(() async {
      final text = message.trim();
      if (text.isEmpty && (attachments == null || attachments.isEmpty)) {
        throw AppwriteException('Message cannot be empty', 400);
      }
      final request = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: serviceRequestId,
      );
      final sr = ServiceRequest.fromRow(request.$id, request.data);
      final fileIds = <String>[];
      for (final file in attachments ?? const <UploadBytes>[]) {
        final filename = sanitizeUploadName(file.filename);
        validateUpload(file.bytes, filename);
        final created = await _storage.createFile(
          bucketId: AppwriteService.clientUploadsBucket,
          fileId: ID.unique(),
          file: InputFile.fromBytes(
            bytes: Uint8List.fromList(file.bytes),
            filename: filename,
          ),
          permissions: clientDocumentPermissions(sr.clientId),
        );
        fileIds.add(created.$id);
      }
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        rowId: ID.unique(),
        data: {
          'serviceRequestId': serviceRequestId,
          'senderId': _actorId(),
          'senderRole': _actorRole(),
          'senderName': _actorName(),
          'message': text.isEmpty ? 'Attachment' : text,
          'attachments': fileIds,
          'isRead': false,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        permissions: clientDocumentPermissions(sr.clientId),
      );
      await _audit.log(
        userId: _actorId(),
        action: 'message_sent',
        metadata: {'id': row.$id, 'serviceRequestId': serviceRequestId},
      );
      return ServiceRequestMessage.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<void>> markAsRead(String messageId) {
    return AppwriteService.guard(() async {
      await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        rowId: messageId,
        data: {'isRead': true},
      );
    });
  }

  @override
  Future<AppResult<int>> getUnreadCount(String serviceRequestId) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        queries: [
          Query.equal('serviceRequestId', serviceRequestId),
          Query.equal('isRead', false),
          Query.limit(100),
        ],
      );
      return page.rows
          .where(
            (row) =>
                row.data['senderRole']?.toString() != ServiceRequestMessage.quotationRecordRole &&
                row.data['senderId']?.toString() != _actorId(),
          )
          .length;
    });
  }
}
