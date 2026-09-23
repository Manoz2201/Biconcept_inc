import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import 'service_request_message.dart';

abstract class MessageRepository {
  Future<AppResult<List<ServiceRequestMessage>>> getMessages(String serviceRequestId);

  Future<AppResult<ServiceRequestMessage>> sendMessage(
    String serviceRequestId,
    String message, {
    List<UploadBytes>? attachments,
  });

  Future<AppResult<void>> markAsRead(String messageId);

  Future<AppResult<int>> getUnreadCount(String serviceRequestId);
}
