import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/core/widgets/permission_gate.dart';
import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/domain/slug.dart';
import 'package:biconcept/features/catalog/domain/storage_repository.dart';
import 'package:biconcept/features/catalog/presentation/providers/portfolio_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/theme/app_theme.dart';

class PortfolioFormScreen extends ConsumerStatefulWidget {
  const PortfolioFormScreen({super.key, this.itemId});

  final String? itemId;

  @override
  ConsumerState<PortfolioFormScreen> createState() => _PortfolioFormScreenState();
}

class _PortfolioFormScreenState extends ConsumerState<PortfolioFormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  String? _error;
  PortfolioItem? _existing;
  String? _coverId;
  List<String> _gallery = [];

  bool get _isNew => widget.itemId == null;

  @override
  void initState() {
    super.initState();
    final id = widget.itemId;
    if (id != null) {
      ref.read(catalogRepositoryProvider).getPortfolioById(id).then((result) {
        if (!mounted) return;
        final item = result.dataOrNull;
        setState(() {
          _existing = item;
          _coverId = item?.coverImageId;
          _gallery = [...?item?.galleryImageIds];
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: _isNew ? Permission.catalogCreate : Permission.catalogEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(_isNew ? 'New portfolio item' : 'Edit portfolio item')),
        body: _isNew || _existing != null
            ? FormBuilder(
                key: _formKey,
                initialValue: {
                  'title': _existing?.title ?? '',
                  'slug': _existing?.slug ?? '',
                  'projectType': _existing?.projectType ?? '',
                  'location': _existing?.location ?? '',
                  'area': _existing?.area ?? '',
                  'year': _existing?.year?.toString() ?? '',
                  'description': _existing?.description ?? '',
                  'testimonial': _existing?.testimonial ?? '',
                  'clientName': _existing?.clientName ?? '',
                  'sortOrder': _existing?.sortOrder?.toString() ?? '',
                  'isFeatured': _existing?.isFeatured ?? false,
                  'isActive': _existing?.isActive ?? true,
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null) Text(_error!, style: TextStyle(color: AppColors.down)),
                    FormBuilderTextField(
                      name: 'title',
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: FormBuilderValidators.required(),
                      onChanged: (value) {
                        if (!_isNew) return;
                        _formKey.currentState?.fields['slug']?.didChange(catalogSlug(value ?? ''));
                      },
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'slug', decoration: const InputDecoration(labelText: 'Slug')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'projectType',
                      decoration: const InputDecoration(labelText: 'Project type'),
                      validator: FormBuilderValidators.required(),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'location', decoration: const InputDecoration(labelText: 'Location')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'area', decoration: const InputDecoration(labelText: 'Area')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'year',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Year'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'description',
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'testimonial',
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Testimonial'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'clientName', decoration: const InputDecoration(labelText: 'Client name')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'sortOrder',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sort order'),
                    ),
                    FormBuilderSwitch(name: 'isFeatured', title: const Text('Featured'), initialValue: false),
                    FormBuilderSwitch(name: 'isActive', title: const Text('Active'), initialValue: true),
                    const SizedBox(height: 12),
                    Text('Cover image${_coverId == null ? '' : ' (uploaded)'}'),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _busy ? null : _pickCover, child: const Text('Upload cover')),
                    const SizedBox(height: 12),
                    const Text('Gallery'),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _busy ? null : _pickGallery, child: const Text('Add gallery images')),
                    for (var i = 0; i < _gallery.length; i++)
                      ListTile(
                        title: Text(_gallery[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: i == 0
                                  ? null
                                  : () => setState(() {
                                        final swap = _gallery[i - 1];
                                        _gallery[i - 1] = _gallery[i];
                                        _gallery[i] = swap;
                                      }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              onPressed: i == _gallery.length - 1
                                  ? null
                                  : () => setState(() {
                                        final swap = _gallery[i + 1];
                                        _gallery[i + 1] = _gallery[i];
                                        _gallery[i] = swap;
                                      }),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _gallery.removeAt(i)),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<UploadBytes?> _pickOne() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return UploadBytes(bytes: bytes, filename: file.name);
  }

  Future<void> _pickCover() async {
    final file = await _pickOne();
    if (file == null) return;
    final uploaded = await ref.read(storageRepositoryProvider).uploadPortfolioImage(file);
    uploaded.when(
      success: (id) => setState(() => _coverId = id),
      failure: (error) => setState(() => _error = error.userMessage),
    );
  }

  Future<void> _pickGallery() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true, allowMultiple: true);
    if (result == null) return;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final uploaded = await ref.read(storageRepositoryProvider).uploadPortfolioImage(
            UploadBytes(bytes: bytes, filename: file.name),
          );
      uploaded.when(
        success: (id) => setState(() => _gallery.add(id)),
        failure: (error) => setState(() => _error = error.userMessage),
      );
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    final cover = _coverId;
    if (cover == null || cover.isEmpty) {
      setState(() => _error = 'Upload a cover image');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final title = form.value['title']?.toString() ?? '';
    final slugRaw = form.value['slug']?.toString() ?? '';
    final repo = ref.read(catalogRepositoryProvider);
    final result = _isNew
        ? await repo.createPortfolioItem(
            PortfolioItem(
              id: '',
              title: title,
              slug: slugRaw.isEmpty ? catalogSlug(title) : slugRaw,
              projectType: form.value['projectType']?.toString() ?? '',
              location: form.value['location']?.toString(),
              area: form.value['area']?.toString(),
              year: int.tryParse(form.value['year']?.toString() ?? ''),
              description: form.value['description']?.toString(),
              coverImageId: cover,
              galleryImageIds: _gallery,
              testimonial: form.value['testimonial']?.toString(),
              clientName: form.value['clientName']?.toString(),
              isFeatured: form.value['isFeatured'] == true,
              isActive: form.value['isActive'] == true,
              sortOrder: int.tryParse(form.value['sortOrder']?.toString() ?? ''),
            ),
          )
        : await repo.updatePortfolioItem(widget.itemId!, {
            'title': title,
            'slug': slugRaw.isEmpty ? catalogSlug(title) : slugRaw,
            'projectType': form.value['projectType']?.toString() ?? '',
            'location': form.value['location']?.toString(),
            'area': form.value['area']?.toString(),
            'year': int.tryParse(form.value['year']?.toString() ?? ''),
            'description': form.value['description']?.toString(),
            'coverImageId': cover,
            'galleryImageIds': _gallery,
            'testimonial': form.value['testimonial']?.toString(),
            'clientName': form.value['clientName']?.toString(),
            'isFeatured': form.value['isFeatured'] == true,
            'isActive': form.value['isActive'] == true,
            'sortOrder': int.tryParse(form.value['sortOrder']?.toString() ?? ''),
          });
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminPortfolioProvider);
        ref.invalidate(publicPortfolioProvider);
        ref.invalidate(featuredPortfolioProvider);
        context.go('/admin/catalog');
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
