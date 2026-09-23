import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/project_document.dart';
import '../providers/documents_provider.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final _title = TextEditingController();
  DocumentCategory _category = DocumentCategory.drawing;
  String? _parentId;
  var _clientVisible = true;
  UploadBytes? _file;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(projectDocumentsProvider(DocumentQuery(projectId: widget.projectId))).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.documentUpload,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload document')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            DropdownButtonFormField<DocumentCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final item in DocumentCategory.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: (value) => setState(() => _category = value ?? DocumentCategory.other),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              decoration: const InputDecoration(labelText: 'New version of'),
              items: [
                const DropdownMenuItem(value: null, child: Text('New document')),
                for (final item in docs) DropdownMenuItem(value: item.id, child: Text(item.title)),
              ],
              onChanged: (value) => setState(() => _parentId = value),
            ),
            SwitchListTile(value: _clientVisible, onChanged: (value) => setState(() => _clientVisible = value), title: const Text('Visible to client')),
            ListTile(
              title: Text(_file?.filename ?? 'Choose file'),
              trailing: const Icon(Icons.attach_file),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(withData: true);
                final file = result?.files.single;
                if (file?.bytes == null) return;
                setState(() => _file = UploadBytes(bytes: file!.bytes!, filename: file.name));
              },
            ),
            FilledButton(onPressed: _busy ? null : _upload, child: Text(_busy ? 'Uploading…' : 'Upload')),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    final file = _file;
    if (_title.text.trim().isEmpty || file == null) {
      setState(() => _error = 'Title and file are required');
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(documentRepositoryProvider).uploadDocument(
          projectId: widget.projectId,
          title: _title.text,
          category: _category,
          file: file,
          parentDocumentId: _parentId,
          isClientVisible: _clientVisible,
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(projectDocumentsProvider);
        context.pop();
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
