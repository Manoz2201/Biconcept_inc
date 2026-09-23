import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../../intelligence/presentation/providers/intelligence_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/ocr_models.dart';

class OCRUploadScreen extends ConsumerStatefulWidget {
  const OCRUploadScreen({super.key});

  @override
  ConsumerState<OCRUploadScreen> createState() => _OCRUploadScreenState();
}

class _OCRUploadScreenState extends ConsumerState<OCRUploadScreen> {
  var _type = OCRDocumentType.invoice;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.ocrUpload,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('OCR upload')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<OCRDocumentType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Document type'),
              items: [for (final item in OCRDocumentType.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: (value) => setState(() => _type = value ?? OCRDocumentType.invoice),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final result = await FilePicker.platform.pickFiles(withData: true);
                      final file = result?.files.single;
                      if (file?.bytes == null) return;
                      setState(() => _busy = true);
                      final created = await ref.read(intelligenceRepositoryProvider).uploadAndExtract(
                            UploadBytes(bytes: file!.bytes!, filename: file.name),
                            _type,
                          );
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      final id = created.dataOrNull?.id;
                      if (id != null) {
                        ref.invalidate(ocrDocumentsProvider(null));
                        context.go('/ocr/documents/$id');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Extract failed')));
                      }
                    },
              child: Text(_busy ? 'Extracting…' : 'Pick file and extract'),
            ),
            TextButton(onPressed: () => context.push('/ocr/documents'), child: const Text('View documents')),
          ],
        ),
      ),
    );
  }
}

class OCRDocumentListScreen extends ConsumerWidget {
  const OCRDocumentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(ocrDocumentsProvider(null));
    return PermissionGate(
      permission: Permission.ocrUpload,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('OCR documents')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/ocr/upload'),
          child: const Icon(Icons.upload_file),
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.documentType.label),
                  subtitle: Text('${item.status.label} · ${item.extractedData['invoiceNumber'] ?? item.extractedData['merchantName'] ?? item.id}'),
                  onTap: () => context.push('/ocr/documents/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OCRResultScreen extends ConsumerWidget {
  const OCRResultScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(ocrDocumentByIdProvider(documentId));
    return PermissionGate(
      permission: Permission.ocrUpload,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('OCR result')),
        body: doc.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LinearProgressIndicator(value: item.confidence ?? 0),
              Text('Confidence ${((item.confidence ?? 0) * 100).toStringAsFixed(0)}% · ${item.status.label}'),
              for (final entry in item.extractedData.entries)
                ListTile(title: Text(entry.key), subtitle: Text('${entry.value}')),
              if (item.rawText != null) ExpansionTile(title: const Text('Raw text'), children: [Padding(padding: const EdgeInsets.all(12), child: Text(item.rawText!))]),
              FilledButton(onPressed: () => context.push('/ocr/documents/$documentId/verify'), child: const Text('Verify')),
            ],
          ),
        ),
      ),
    );
  }
}

class OCRVerificationScreen extends ConsumerStatefulWidget {
  const OCRVerificationScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<OCRVerificationScreen> createState() => _OCRVerificationScreenState();
}

class _OCRVerificationScreenState extends ConsumerState<OCRVerificationScreen> {
  final _entityType = TextEditingController(text: 'vendor_bill');
  final _entityId = TextEditingController();

  @override
  void dispose() {
    _entityType.dispose();
    _entityId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(ocrDocumentByIdProvider(widget.documentId));
    return PermissionGate(
      permission: Permission.ocrVerify,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Verify OCR')),
        body: doc.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in item.extractedData.entries) ListTile(title: Text(entry.key), subtitle: Text('${entry.value}')),
              FilledButton(
                onPressed: () async {
                  await ref.read(intelligenceRepositoryProvider).verifyDocument(item.id, item.extractedData);
                  ref.invalidate(ocrDocumentByIdProvider(widget.documentId));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verified')));
                },
                child: const Text('Verify & save'),
              ),
              TextField(controller: _entityType, decoration: const InputDecoration(labelText: 'Link entity type')),
              TextField(controller: _entityId, decoration: const InputDecoration(labelText: 'Link entity ID')),
              TextButton(
                onPressed: () async {
                  final result = await ref.read(intelligenceRepositoryProvider).linkToEntity(item.id, _entityType.text.trim(), _entityId.text.trim());
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorOrNull?.userMessage ?? 'Linked')));
                },
                child: const Text('Link to bill / expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
