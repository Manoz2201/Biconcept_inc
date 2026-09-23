import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../projects/data/project_workspace_store.dart';
import '../../data/document_repository_impl.dart';
import '../../domain/document_repository.dart';
import '../../domain/project_document.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(
    store: ProjectWorkspaceStore(),
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown',
    actorName: () => ref.read(sessionControllerProvider).user?.name ?? 'Staff',
  );
});

class DocumentQuery {
  const DocumentQuery({required this.projectId, this.category, this.clientVisible});

  final String projectId;
  final DocumentCategory? category;
  final bool? clientVisible;

  @override
  bool operator ==(Object other) =>
      other is DocumentQuery &&
      other.projectId == projectId &&
      other.category == category &&
      other.clientVisible == clientVisible;

  @override
  int get hashCode => Object.hash(projectId, category, clientVisible);
}

final projectDocumentsProvider =
    FutureProvider.family<List<ProjectDocument>, DocumentQuery>((ref, query) async {
  final result = await ref.watch(documentRepositoryProvider).getProjectDocuments(
        query.projectId,
        category: query.category,
        clientVisible: query.clientVisible,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});
