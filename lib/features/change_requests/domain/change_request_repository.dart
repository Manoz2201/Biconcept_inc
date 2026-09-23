import '../../../core/result/app_result.dart';
import 'change_request.dart';

abstract class ChangeRequestRepository {
  Future<AppResult<List<ChangeRequest>>> getChangeRequests({
    String? projectId,
    ChangeRequestStatus? status,
  });

  Future<AppResult<ChangeRequest>> createChangeRequest({
    required String projectId,
    required String title,
    required String description,
    double? impactCost,
    int? impactDays,
  });

  Future<AppResult<ChangeRequest>> approveChangeRequest(
    String id, {
    double? impactCost,
    int? impactDays,
  });

  Future<AppResult<ChangeRequest>> rejectChangeRequest(String id, String notes);

  Future<AppResult<ChangeRequest>> implementChangeRequest(String id);
}
