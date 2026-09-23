import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/core/widgets/permission_gate.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/domain/slug.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/theme/app_theme.dart';

class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  String? _error;
  ServiceItem? _existing;

  bool get _isNew => widget.serviceId == null;

  @override
  void initState() {
    super.initState();
    final id = widget.serviceId;
    if (id != null) {
      ref.read(catalogRepositoryProvider).getServiceById(id).then((result) {
        if (!mounted) return;
        setState(() => _existing = result.dataOrNull);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: _isNew ? Permission.catalogCreate : Permission.catalogEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(_isNew ? 'New service' : 'Edit service')),
        body: _isNew || _existing != null
            ? FormBuilder(
                key: _formKey,
                initialValue: {
                  'title': _existing?.title ?? '',
                  'slug': _existing?.slug ?? '',
                  'category': _existing?.category ?? '',
                  'shortDescription': _existing?.shortDescription ?? '',
                  'longDescription': _existing?.longDescription ?? '',
                  'icon': _existing?.icon ?? '',
                  'startingPrice': _existing?.startingPrice?.toString() ?? '',
                  'priceUnit': _existing?.priceUnit ?? '',
                  'sortOrder': _existing?.sortOrder?.toString() ?? '',
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
                        final slugField = _formKey.currentState?.fields['slug'];
                        slugField?.didChange(catalogSlug(value ?? ''));
                      },
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'slug', decoration: const InputDecoration(labelText: 'Slug')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'category',
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: FormBuilderValidators.required(),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'shortDescription',
                      decoration: const InputDecoration(labelText: 'Short description'),
                      validator: FormBuilderValidators.required(),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'longDescription',
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'Long description'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'icon',
                      decoration: const InputDecoration(labelText: 'Icon (home, office, interior, architecture, consult)'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'startingPrice',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Starting price'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'priceUnit', decoration: const InputDecoration(labelText: 'Price unit')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'sortOrder',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sort order'),
                    ),
                    FormBuilderSwitch(name: 'isActive', title: const Text('Active'), initialValue: true),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final title = form.value['title']?.toString() ?? '';
    final slugRaw = form.value['slug']?.toString() ?? '';
    final price = double.tryParse(form.value['startingPrice']?.toString() ?? '');
    final sort = int.tryParse(form.value['sortOrder']?.toString() ?? '');
    final repo = ref.read(catalogRepositoryProvider);
    final result = _isNew
        ? await repo.createService(
            ServiceItem(
              id: '',
              title: title,
              slug: slugRaw.isEmpty ? catalogSlug(title) : slugRaw,
              category: form.value['category']?.toString() ?? '',
              shortDescription: form.value['shortDescription']?.toString() ?? '',
              longDescription: form.value['longDescription']?.toString(),
              icon: form.value['icon']?.toString(),
              startingPrice: price,
              priceUnit: form.value['priceUnit']?.toString(),
              isActive: form.value['isActive'] == true,
              sortOrder: sort,
            ),
          )
        : await repo.updateService(widget.serviceId!, {
            'title': title,
            'slug': slugRaw.isEmpty ? catalogSlug(title) : slugRaw,
            'category': form.value['category']?.toString() ?? '',
            'shortDescription': form.value['shortDescription']?.toString() ?? '',
            'longDescription': form.value['longDescription']?.toString(),
            'icon': form.value['icon']?.toString(),
            'startingPrice': price,
            'priceUnit': form.value['priceUnit']?.toString(),
            'isActive': form.value['isActive'] == true,
            'sortOrder': sort,
          });
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminServicesProvider);
        ref.invalidate(publicServicesProvider);
        context.go('/admin/catalog');
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
