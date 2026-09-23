import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../projects/data/project_workspace_store.dart';
import '../../projects/domain/project_activity.dart';
import '../domain/document_repository.dart';
import '../domain/project_document.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    TablesDB? tables,
    Storage? storage,
    AuditRepository? audit,
    ProjectWorkspaceStore? store,
    String? databaseId,
    String Function()? actorId,
    String Function()? actorName,
  })  : _storage = storage ?? AppwriteService.storage,
        _audit = audit ?? AuditRepository(),
        _store = store ?? ProjectWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _actorId = actorId ?? (() => 'unknown'),
        _actorName = actorName ?? (() => 'Staff');

  final Storage _storage;
  final AuditRepository _audit;
  final ProjectWorkspaceStore _store;
  final String Function() _actorId;
  final String Function() _actorName;

  @override
  Future<AppResult<List<ProjectDocument>>> getProjectDocuments(
    String projectId, {
    DocumentCategory? category,
    bool? clientVisible,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final items = [
        for (final doc in snap.workspace.documents)
          if ((category == null || doc.category == category) &&
              (clientVisible == null || doc.isClientVisible == clientVisible))
            doc,
      ]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  @override
  Future<AppResult<List<ProjectDocument>>> getDocumentVersions(String parentDocumentId) {
    return AppwriteService.guard(() async {
      final host = await _store.findDocumentHost(parentDocumentId);
      if (host == null) return const [];
      final items = [
        for (final doc in host.workspace.documents)
          if (doc.id == parentDocumentId || doc.parentDocumentId == parentDocumentId) doc,
      ]..sort((a, b) => b.version.compareTo(a.version));
      return items;
    });
  }

  @override
  Future<AppResult<ProjectDocument>> uploadDocument({
    required String projectId,
    required String title,
    required DocumentCategory category,
    required UploadBytes file,
    String? parentDocumentId,
    bool isClientVisible = true,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(projectId);
      final filename = sanitizeUploadName(file.filename);
      validateProjectUpload(file.bytes, filename);
      final created = await _storage.createFile(
        bucketId: AppwriteService.clientUploadsBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: Uint8List.fromList(file.bytes), filename: filename),
        permissions: projectRowPermissions(snap.project.clientId),
      );
      var version = 1;
      if (parentDocumentId != null) {
        final parent = snap.workspace.documents.where((item) => item.id == parentDocumentId).firstOrNull;
        version = (parent?.version ?? 0) + 1;
      }
      final now = DateTime.now().toUtc();
      final doc = ProjectDocument(
        id: ID.unique(),
        projectId: projectId,
        title: title.trim(),
        category: category,
        fileId: created.$id,
        version: version,
        parentDocumentId: parentDocumentId,
        uploadedBy: _actorId(),
        isClientVisible: isClientVisible,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.documents.add(doc);
      snap.workspace.activities.insert(
        0,
        ProjectActivity(
          id: ID.unique(),
          projectId: projectId,
          actorId: _actorId(),
          actorName: _actorName(),
          action: 'file_uploaded',
          metadata: doc.title,
          createdAt: now,
        ),
      );
      await _store.saveWorkspace(projectId, snap.workspace);
      await _audit.log(
        userId: _actorId(),
        action: 'document_uploaded',
        metadata: {'id': doc.id, 'fileId': created.$id, 'projectId': projectId},
      );
      return doc;
    });
  }

  @override
  Future<AppResult<void>> deleteDocument(String id, String fileId) {
    return AppwriteService.guard(() async {
      final host = await _store.findDocumentHost(id);
      if (host == null) return;
      host.workspace.documents.removeWhere((item) => item.id == id);
      await _store.saveWorkspace(host.project.id, host.workspace);
      try {
        await _storage.deleteFile(bucketId: AppwriteService.clientUploadsBucket, fileId: fileId);
      } catch (_) {}
      await _audit.log(
        userId: _actorId(),
        action: 'document_deleted',
        metadata: {'id': id, 'fileId': fileId, 'projectId': host.project.id},
      );
    });
  }

  @override
  String getDownloadUrl(String fileId) {
    return '${Env.appwriteEndpoint}/storage/buckets/${AppwriteService.clientUploadsBucket}/files/$fileId/view?project=${Env.appwriteProjectId}';
  }
}
