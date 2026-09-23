import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';

class SitePhoto {
  const SitePhoto({
    required this.id,
    required this.tenantId,
    required this.projectId,
    this.milestoneId,
    required this.fileId,
    this.caption,
    required this.capturedAt,
    required this.capturedBy,
    this.location,
    this.aiLabels,
    this.aiProgressEstimate,
    this.aiSafetyFlags,
    this.aiMaterialDetected,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String projectId;
  final String? milestoneId;
  final String fileId;
  final String? caption;
  final DateTime capturedAt;
  final String capturedBy;
  final Map<String, double>? location;
  final List<String>? aiLabels;
  final double? aiProgressEstimate;
  final List<String>? aiSafetyFlags;
  final List<String>? aiMaterialDetected;
  final String? notes;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'projectId': projectId,
        'milestoneId': ?milestoneId,
        'fileId': fileId,
        'caption': ?caption,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'capturedBy': capturedBy,
        'location': ?location,
        'aiLabels': ?aiLabels,
        'aiProgressEstimate': ?aiProgressEstimate,
        'aiSafetyFlags': ?aiSafetyFlags,
        'aiMaterialDetected': ?aiMaterialDetected,
        'notes': ?notes,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory SitePhoto.fromJson(Map<String, dynamic> data) => SitePhoto(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        projectId: data['projectId']?.toString() ?? '',
        milestoneId: data['milestoneId']?.toString(),
        fileId: data['fileId']?.toString() ?? '',
        caption: data['caption']?.toString(),
        capturedAt: DateTime.tryParse(data['capturedAt']?.toString() ?? '') ?? DateTime.now(),
        capturedBy: data['capturedBy']?.toString() ?? '',
        location: data['location'] is Map
            ? {
                for (final entry in (data['location'] as Map).entries) entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0,
              }
            : null,
        aiLabels: data['aiLabels'] is List ? [for (final item in data['aiLabels'] as List) item.toString()] : null,
        aiProgressEstimate: (data['aiProgressEstimate'] as num?)?.toDouble(),
        aiSafetyFlags: data['aiSafetyFlags'] is List ? [for (final item in data['aiSafetyFlags'] as List) item.toString()] : null,
        aiMaterialDetected: data['aiMaterialDetected'] is List ? [for (final item in data['aiMaterialDetected'] as List) item.toString()] : null,
        notes: data['notes']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

class ImageAnalysis {
  const ImageAnalysis({
    required this.labels,
    required this.progressEstimate,
    required this.safetyFlags,
    required this.materials,
    this.confidence = 0.6,
  });

  final List<String> labels;
  final double progressEstimate;
  final List<String> safetyFlags;
  final List<String> materials;
  final double confidence;
}

abstract class ImageAIService {
  Future<AppResult<SitePhoto>> uploadPhoto({required String projectId, required UploadBytes file, String? caption, String? milestoneId});
  Future<AppResult<List<SitePhoto>>> getSitePhotos(String projectId);
  Future<AppResult<SitePhoto>> getSitePhotoById(String id);
  Future<AppResult<ImageAnalysis>> analyzeImage(String photoId);
}
