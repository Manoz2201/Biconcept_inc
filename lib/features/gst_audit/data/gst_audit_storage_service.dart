import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../catalog/domain/storage_repository.dart';

class GstAuditStorageService {
  GstAuditStorageService({Storage? storage}) : _storage = storage ?? AppwriteService.storage;

  final Storage _storage;

  Future<String> upload(UploadBytes file) async {
    validateGstUpload(file.bytes, file.filename);
    final created = await _storage.createFile(
      bucketId: AppwriteService.portfolioImagesBucket,
      fileId: ID.unique(),
      file: InputFile.fromBytes(
        bytes: Uint8List.fromList(file.bytes),
        filename: sanitizeUploadName(file.filename),
      ),
      permissions: [
        Permission.read(Role.team(AppwriteService.teamStaff)),
        Permission.update(Role.team(AppwriteService.teamStaff, 'admin')),
        Permission.update(Role.team(AppwriteService.teamStaff, 'accountant')),
      ],
    );
    return created.$id;
  }

  Future<List<int>> download(String fileId) async {
    return _storage.getFileDownload(bucketId: AppwriteService.portfolioImagesBucket, fileId: fileId);
  }
}
