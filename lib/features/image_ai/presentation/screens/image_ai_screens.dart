import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../../intelligence/presentation/providers/intelligence_providers.dart';
import '../../../rbac/domain/permission.dart';

class SitePhotoGalleryScreen extends ConsumerWidget {
  const SitePhotoGalleryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(sitePhotosProvider(projectId));
    return PermissionGate(
      permission: Permission.sitePhotoUpload,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Site photos')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/projects/$projectId/photos/capture'),
          child: const Icon(Icons.photo_camera_outlined),
        ),
        body: photos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No site photos yet'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return InkWell(
                      onTap: () => context.push('/projects/$projectId/photos/${item.id}'),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.caption ?? 'Site photo', maxLines: 2, overflow: TextOverflow.ellipsis),
                              const Spacer(),
                              if (item.aiProgressEstimate != null) Text('${item.aiProgressEstimate!.toStringAsFixed(0)}%'),
                              Wrap(
                                spacing: 4,
                                children: [
                                  for (final flag in item.aiSafetyFlags ?? const <String>[])
                                    Chip(label: Text(flag, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class SitePhotoCaptureScreen extends ConsumerStatefulWidget {
  const SitePhotoCaptureScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<SitePhotoCaptureScreen> createState() => _SitePhotoCaptureScreenState();
}

class _SitePhotoCaptureScreenState extends ConsumerState<SitePhotoCaptureScreen> {
  final _caption = TextEditingController();
  UploadBytes? _file;
  var _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.sitePhotoUpload,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Capture site photo')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _caption, decoration: const InputDecoration(labelText: 'Caption (materials, safety, progress)')),
            ListTile(
              title: Text(_file?.filename ?? 'Choose photo'),
              trailing: const Icon(Icons.attach_file),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
                final file = result?.files.single;
                if (file?.bytes == null) return;
                setState(() => _file = UploadBytes(bytes: file!.bytes!, filename: file.name));
              },
            ),
            FilledButton(
              onPressed: _busy || _file == null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final created = await ref.read(intelligenceRepositoryProvider).uploadPhoto(
                            projectId: widget.projectId,
                            file: _file!,
                            caption: _caption.text.trim(),
                          );
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (created.dataOrNull != null) {
                        ref.invalidate(sitePhotosProvider(widget.projectId));
                        context.go('/projects/${widget.projectId}/photos/${created.dataOrNull!.id}');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Upload failed')));
                      }
                    },
              child: Text(_busy ? 'Uploading…' : 'Upload and analyze'),
            ),
          ],
        ),
      ),
    );
  }
}

class SitePhotoDetailScreen extends ConsumerWidget {
  const SitePhotoDetailScreen({super.key, required this.projectId, required this.photoId});

  final String projectId;
  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(sitePhotoByIdProvider(photoId));
    return PermissionGate(
      permission: Permission.sitePhotoAnalyze,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Photo analysis')),
        body: photo.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.caption ?? 'Site photo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (item.aiProgressEstimate ?? 0) / 100),
              Text('Progress ${(item.aiProgressEstimate ?? 0).toStringAsFixed(0)}%'),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [for (final label in item.aiLabels ?? const <String>[]) Chip(label: Text(label))]),
              const SizedBox(height: 8),
              for (final flag in item.aiSafetyFlags ?? const <String>[])
                ListTile(leading: const Icon(Icons.warning_amber, color: Colors.orange), title: Text(flag)),
              for (final material in item.aiMaterialDetected ?? const <String>[]) Chip(label: Text(material)),
              FilledButton(
                onPressed: () async {
                  await ref.read(intelligenceRepositoryProvider).analyzeImage(item.id);
                  ref.invalidate(sitePhotoByIdProvider(photoId));
                },
                child: const Text('Re-run analysis'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageAnalysisScreen extends ConsumerStatefulWidget {
  const ImageAnalysisScreen({super.key});

  @override
  ConsumerState<ImageAnalysisScreen> createState() => _ImageAnalysisScreenState();
}

class _ImageAnalysisScreenState extends ConsumerState<ImageAnalysisScreen> {
  final _projectId = TextEditingController();
  final _caption = TextEditingController();
  String? _summary;

  @override
  void dispose() {
    _projectId.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.aiImageAnalyze,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Image analysis')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _projectId, decoration: const InputDecoration(labelText: 'Project ID')),
            TextField(controller: _caption, decoration: const InputDecoration(labelText: 'Describe the photo')),
            FilledButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
                final file = result?.files.single;
                if (file?.bytes == null) return;
                final created = await ref.read(intelligenceRepositoryProvider).uploadPhoto(
                      projectId: _projectId.text.trim(),
                      file: UploadBytes(bytes: file!.bytes!, filename: file.name),
                      caption: _caption.text.trim(),
                    );
                final photo = created.dataOrNull;
                if (photo == null) return;
                setState(() {
                  _summary =
                      'Labels: ${photo.aiLabels?.join(', ')}\nProgress: ${photo.aiProgressEstimate}\nSafety: ${photo.aiSafetyFlags?.join(', ')}';
                });
              },
              child: const Text('Upload and analyze'),
            ),
            if (_summary != null) Text(_summary!),
          ],
        ),
      ),
    );
  }
}
