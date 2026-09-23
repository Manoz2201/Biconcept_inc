import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../projects/data/project_workspace_store.dart';
import '../../data/timesheet_repository_impl.dart';
import '../../domain/timesheet.dart';
import '../../domain/timesheet_repository.dart';

final timesheetRepositoryProvider = Provider<TimesheetRepository>((ref) {
  return TimesheetRepositoryImpl(
    store: ProjectWorkspaceStore(),
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown',
    actorName: () => ref.read(sessionControllerProvider).user?.name ?? 'Staff',
  );
});

class TimesheetQuery {
  const TimesheetQuery({this.projectId, this.userId, this.status, this.from, this.to});

  final String? projectId;
  final String? userId;
  final TimesheetStatus? status;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is TimesheetQuery &&
      other.projectId == projectId &&
      other.userId == userId &&
      other.status == status &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(projectId, userId, status, from, to);
}

final timesheetsProvider = FutureProvider.family<List<Timesheet>, TimesheetQuery>((ref, query) async {
  final result = await ref.watch(timesheetRepositoryProvider).getTimesheets(
        projectId: query.projectId,
        userId: query.userId,
        status: query.status,
        from: query.from,
        to: query.to,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});
