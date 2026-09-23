import '../../../core/result/app_result.dart';

class UploadBytes {
  const UploadBytes({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

abstract class StorageRepository {
  Future<AppResult<String>> uploadPortfolioImage(UploadBytes file);
  Future<AppResult<String>> uploadTeamPhoto(UploadBytes file);
  Future<AppResult<void>> deleteFile(String bucketId, String fileId);
  String getFilePreviewUrl(String bucketId, String fileId, {int? width, int? height});
  String getFileViewUrl(String bucketId, String fileId);
}
