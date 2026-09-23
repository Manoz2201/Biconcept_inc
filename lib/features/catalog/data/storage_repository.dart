import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../domain/storage_repository.dart';

class StorageRepositoryImpl implements StorageRepository {
  StorageRepositoryImpl({Storage? storage}) : _storage = storage ?? AppwriteService.storage;

  final Storage _storage;

  @override
  Future<AppResult<String>> uploadPortfolioImage(UploadBytes file) {
    return _upload(AppwriteService.portfolioImagesBucket, file);
  }

  @override
  Future<AppResult<String>> uploadTeamPhoto(UploadBytes file) {
    return _upload(AppwriteService.teamPhotosBucket, file);
  }

  Future<AppResult<String>> _upload(String bucketId, UploadBytes file) {
    return AppwriteService.guard(() async {
      final created = await _storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: Uint8List.fromList(file.bytes),
          filename: file.filename,
        ),
        permissions: [Permission.read(Role.any())],
      );
      return created.$id;
    });
  }

  @override
  Future<AppResult<void>> deleteFile(String bucketId, String fileId) {
    return AppwriteService.guard(() async {
      await _storage.deleteFile(bucketId: bucketId, fileId: fileId);
    });
  }

  @override
  String getFilePreviewUrl(String bucketId, String fileId, {int? width, int? height}) {
    final params = <String>[
      'project=${Env.appwriteProjectId}',
      if (width != null) 'width=$width',
      if (height != null) 'height=$height',
    ];
    return '${Env.appwriteEndpoint}/storage/buckets/$bucketId/files/$fileId/preview?${params.join('&')}';
  }

  @override
  String getFileViewUrl(String bucketId, String fileId) {
    return '${Env.appwriteEndpoint}/storage/buckets/$bucketId/files/$fileId/view?project=${Env.appwriteProjectId}';
  }
}
