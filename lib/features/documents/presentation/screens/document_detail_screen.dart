import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../rbac/domain/permission.dart';
import '../providers/documents_provider.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.projectId, required this.documentId});

  final String projectId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(projectDocumentsProvider(DocumentQuery(projectId: projectId))).valueOrNull ?? const [];
    final doc = docs.where((item) => item.id == documentId).firstOrNull;
    final repo = ref.watch(documentRepositoryProvider);
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: Text('Document not found')),
      );
    }
    final versions = docs
        .where(
          (item) =>
              item.id == documentId ||
              item.parentDocumentId == documentId ||
              item.id == doc.parentDocumentId,
        )
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return PermissionGate(
      permission: Permission.documentView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(doc.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(doc.category.label),
            Text('Version ${doc.version}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => launchUrl(Uri.parse(repo.getDownloadUrl(doc.fileId))),
              child: const Text('Download / view'),
            ),
            const SizedBox(height: 16),
            const Text('Version history', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final item in versions)
              ListTile(
                title: Text('v${item.version} · ${item.title}'),
                onTap: () => launchUrl(Uri.parse(repo.getDownloadUrl(item.fileId))),
              ),
            PermissionGate(
              permission: Permission.documentDelete,
              child: TextButton(
                onPressed: () async {
                  await repo.deleteDocument(doc.id, doc.fileId);
                  ref.invalidate(projectDocumentsProvider);
                  if (context.mounted) context.pop();
                },
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
