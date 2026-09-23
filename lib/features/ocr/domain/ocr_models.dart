import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';

enum OCRDocumentType {
  invoice('invoice', 'Invoice'),
  receipt('receipt', 'Receipt'),
  contract('contract', 'Contract'),
  purchaseOrder('purchase_order', 'Purchase order'),
  gstInvoice('gst_invoice', 'GST invoice');

  const OCRDocumentType(this.value, this.label);
  final String value;
  final String label;

  static OCRDocumentType fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => OCRDocumentType.invoice,
      );
}

enum OCRStatus {
  pending('pending', 'Pending'),
  processing('processing', 'Processing'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed'),
  verified('verified', 'Verified');

  const OCRStatus(this.value, this.label);
  final String value;
  final String label;

  static OCRStatus fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => OCRStatus.pending,
      );
}

class OCRDocument {
  const OCRDocument({
    required this.id,
    required this.tenantId,
    required this.documentType,
    required this.fileId,
    required this.extractedData,
    this.rawText,
    this.confidence,
    required this.status,
    this.linkedEntityType,
    this.linkedEntityId,
    required this.uploadedBy,
    this.verifiedBy,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final OCRDocumentType documentType;
  final String fileId;
  final Map<String, dynamic> extractedData;
  final String? rawText;
  final double? confidence;
  final OCRStatus status;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final String uploadedBy;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'documentType': documentType.value,
        'fileId': fileId,
        'extractedData': extractedData,
        'rawText': ?rawText,
        'confidence': ?confidence,
        'status': status.value,
        'linkedEntityType': ?linkedEntityType,
        'linkedEntityId': ?linkedEntityId,
        'uploadedBy': uploadedBy,
        'verifiedBy': ?verifiedBy,
        'verifiedAt': ?verifiedAt?.toUtc().toIso8601String(),
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory OCRDocument.fromJson(Map<String, dynamic> data) => OCRDocument(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        documentType: OCRDocumentType.fromString(data['documentType']?.toString()),
        fileId: data['fileId']?.toString() ?? '',
        extractedData: data['extractedData'] is Map ? Map<String, dynamic>.from(data['extractedData'] as Map) : const {},
        rawText: data['rawText']?.toString(),
        confidence: (data['confidence'] as num?)?.toDouble(),
        status: OCRStatus.fromString(data['status']?.toString()),
        linkedEntityType: data['linkedEntityType']?.toString(),
        linkedEntityId: data['linkedEntityId']?.toString(),
        uploadedBy: data['uploadedBy']?.toString() ?? '',
        verifiedBy: data['verifiedBy']?.toString(),
        verifiedAt: DateTime.tryParse(data['verifiedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

abstract class OCRRepository {
  Future<AppResult<OCRDocument>> uploadAndExtract(UploadBytes file, OCRDocumentType type);
  Future<AppResult<List<OCRDocument>>> getDocuments({OCRDocumentType? type, OCRStatus? status});
  Future<AppResult<OCRDocument>> getDocumentById(String id);
  Future<AppResult<OCRDocument>> verifyDocument(String id, Map<String, dynamic> correctedData);
  Future<AppResult<OCRDocument>> linkToEntity(String documentId, String entityType, String entityId);
  Future<AppResult<Map<String, dynamic>>> extractInvoiceData(String text);
}
