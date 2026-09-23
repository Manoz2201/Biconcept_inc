import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import 'service_request.dart';

abstract class ServiceRequestRepository {
  Future<AppResult<List<ServiceRequest>>> getServiceRequests({
    String? clientId,
    ServiceRequestStatus? status,
    String? assignedTo,
  });

  Future<AppResult<ServiceRequest>> getServiceRequestById(String id);

  Future<AppResult<ServiceRequest>> createServiceRequest({
    required String clientId,
    required String title,
    required String description,
    String? serviceId,
    String? enquiryId,
    List<String>? attachments,
    ServiceRequestPriority? priority,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  });

  Future<AppResult<ServiceRequest>> updateServiceRequest(String id, Map<String, dynamic> data);

  Future<AppResult<ServiceRequest>> assignTo(String id, String userId);

  Future<AppResult<ServiceRequest>> convertFromEnquiry(String enquiryId);

  Future<AppResult<ServiceRequest>> uploadAttachment(String requestId, UploadBytes file);
}
