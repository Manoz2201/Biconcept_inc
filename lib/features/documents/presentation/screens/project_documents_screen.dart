import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/project_document.dart';
import '../providers/documents_provider.dart';

class ProjectDocumentsScreen extends ConsumerStatefulWidget {
  const ProjectDocumentsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectDocumentsScreen> createState() => _ProjectDocumentsScreenState();
}

class _ProjectDocumentsScreenState extends ConsumerState<ProjectDocumentsScreen> {
  DocumentCategory? _category;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectDocumentsProvider(DocumentQuery(projectId: widget.projectId, category: _category)));
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/projects/${widget.projectId}/documents/upload'),
        child: const Icon(Icons.upload_file),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilterChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                for (final item in DocumentCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(item.label),
                      selected: _category == item,
                      onSelected: (_) => setState(() => _category = item),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (items) => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.3),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final doc = items[index];
                  return Card(
                    child: InkWell(
                      onTap: () => context.push('/admin/projects/${widget.projectId}/documents/${doc.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.insert_drive_file_outlined),
                            const SizedBox(height: 8),
                            Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text('${doc.category.label} · v${doc.version}'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
