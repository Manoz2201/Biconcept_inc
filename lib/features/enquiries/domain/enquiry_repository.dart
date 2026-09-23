import '../../../core/result/app_result.dart';
import 'enquiry.dart';

abstract class EnquiryRepository {
  Future<AppResult<Enquiry>> submitEnquiry({
    required String name,
    required String email,
    String? phone,
    String? serviceId,
    required String message,
    String? source,
  });

  Future<AppResult<List<Enquiry>>> getEnquiries({
    EnquiryStatus? status,
    String? assignedTo,
  });

  Future<AppResult<Enquiry>> getEnquiryById(String id);

  Future<AppResult<Enquiry>> updateEnquiryStatus(String id, EnquiryStatus status);

  Future<AppResult<Enquiry>> assignEnquiry(String id, String userId);

  Future<AppResult<Enquiry>> addEnquiryNote(String id, String note);

  Future<AppResult<List<EnquiryAuditEvent>>> listEnquiryAudit(String enquiryId);
}

class EnquiryAuditEvent {
  const EnquiryAuditEvent({
    required this.id,
    required this.action,
    this.metadata,
    required this.timestamp,
  });

  final String id;
  final String action;
  final String? metadata;
  final DateTime timestamp;
}
