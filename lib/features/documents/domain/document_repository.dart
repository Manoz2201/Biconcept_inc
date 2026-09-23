import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import 'project_document.dart';

abstract class DocumentRepository {
  Future<AppResult<List<ProjectDocument>>> getProjectDocuments(
    String projectId, {
    DocumentCategory? category,
    bool? clientVisible,
  });

  Future<AppResult<List<ProjectDocument>>> getDocumentVersions(String parentDocumentId);

  Future<AppResult<ProjectDocument>> uploadDocument({
    required String projectId,
    required String title,
    required DocumentCategory category,
    required UploadBytes file,
    String? parentDocumentId,
    bool isClientVisible,
  });

  Future<AppResult<void>> deleteDocument(String id, String fileId);

  String getDownloadUrl(String fileId);
}
