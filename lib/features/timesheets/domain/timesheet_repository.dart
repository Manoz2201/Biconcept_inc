import '../../../core/result/app_result.dart';
import 'timesheet.dart';

abstract class TimesheetRepository {
  Future<AppResult<List<Timesheet>>> getTimesheets({
    String? projectId,
    String? userId,
    TimesheetStatus? status,
    DateTime? from,
    DateTime? to,
  });

  Future<AppResult<List<Timesheet>>> getMyTimesheets({DateTime? from, DateTime? to});

  Future<AppResult<Timesheet>> createTimesheet({
    required String projectId,
    String? taskId,
    required DateTime date,
    required double hours,
    required String description,
    bool billable,
  });

  Future<AppResult<Timesheet>> updateTimesheet(String id, Map<String, dynamic> data);

  Future<AppResult<Timesheet>> submitTimesheet(String id);

  Future<AppResult<Timesheet>> approveTimesheet(String id, String approverId);

  Future<AppResult<Timesheet>> rejectTimesheet(String id, String reason);

  Future<AppResult<WeeklyTimesheetSummary>> getWeeklySummary(String userId, DateTime weekStart);
}
