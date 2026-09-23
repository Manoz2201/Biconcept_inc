import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../projects/data/project_workspace_store.dart';
import '../../data/change_request_repository_impl.dart';
import '../../domain/change_request.dart';
import '../../domain/change_request_repository.dart';

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  return ChangeRequestRepositoryImpl(
    store: ProjectWorkspaceStore(),
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown',
    actorName: () => ref.read(sessionControllerProvider).user?.name ?? 'Staff',
    actorRole: () => ref.read(sessionControllerProvider).user?.role.value ?? 'client',
  );
});

class ChangeRequestQuery {
  const ChangeRequestQuery({this.projectId, this.status});

  final String? projectId;
  final ChangeRequestStatus? status;

  @override
  bool operator ==(Object other) =>
      other is ChangeRequestQuery && other.projectId == projectId && other.status == status;

  @override
  int get hashCode => Object.hash(projectId, status);
}

final changeRequestsProvider =
    FutureProvider.family<List<ChangeRequest>, ChangeRequestQuery>((ref, query) async {
  final result = await ref.watch(changeRequestRepositoryProvider).getChangeRequests(
        projectId: query.projectId,
        status: query.status,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});
