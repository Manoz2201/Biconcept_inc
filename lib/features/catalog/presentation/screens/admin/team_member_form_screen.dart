import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/core/widgets/permission_gate.dart';
import 'package:biconcept/features/catalog/domain/storage_repository.dart';
import 'package:biconcept/features/catalog/domain/team_member.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/team_provider.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/theme/app_theme.dart';

class TeamMemberFormScreen extends ConsumerStatefulWidget {
  const TeamMemberFormScreen({super.key, this.memberId});

  final String? memberId;

  @override
  ConsumerState<TeamMemberFormScreen> createState() => _TeamMemberFormScreenState();
}

class _TeamMemberFormScreenState extends ConsumerState<TeamMemberFormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  String? _error;
  TeamMember? _existing;
  String? _photoId;

  bool get _isNew => widget.memberId == null;

  @override
  void initState() {
    super.initState();
    final id = widget.memberId;
    if (id != null) {
      ref.read(catalogRepositoryProvider).getTeamMemberById(id).then((result) {
        if (!mounted) return;
        setState(() {
          _existing = result.dataOrNull;
          _photoId = result.dataOrNull?.photoId;
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
        appBar: AppBar(title: Text(_isNew ? 'New team member' : 'Edit team member')),
        body: _isNew || _existing != null
            ? FormBuilder(
                key: _formKey,
                initialValue: {
                  'name': _existing?.name ?? '',
                  'role': _existing?.role ?? '',
                  'bio': _existing?.bio ?? '',
                  'email': _existing?.email ?? '',
                  'linkedin': _existing?.linkedin ?? '',
                  'sortOrder': _existing?.sortOrder?.toString() ?? '',
                  'isActive': _existing?.isActive ?? true,
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null) Text(_error!, style: TextStyle(color: AppColors.down)),
                    FormBuilderTextField(
                      name: 'name',
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: FormBuilderValidators.required(),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'role',
                      decoration: const InputDecoration(labelText: 'Role'),
                      validator: FormBuilderValidators.required(),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'bio',
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'email', decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(name: 'linkedin', decoration: const InputDecoration(labelText: 'LinkedIn URL')),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'sortOrder',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sort order'),
                    ),
                    FormBuilderSwitch(name: 'isActive', title: const Text('Active'), initialValue: true),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _pickPhoto,
                      child: Text(_photoId == null ? 'Upload photo' : 'Replace photo'),
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

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final uploaded = await ref.read(storageRepositoryProvider).uploadTeamPhoto(
          UploadBytes(bytes: bytes, filename: file.name),
        );
    uploaded.when(
      success: (id) => setState(() => _photoId = id),
      failure: (error) => setState(() => _error = error.userMessage),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(catalogRepositoryProvider);
    final result = _isNew
        ? await repo.createTeamMember(
            TeamMember(
              id: '',
              name: form.value['name']?.toString() ?? '',
              role: form.value['role']?.toString() ?? '',
              bio: form.value['bio']?.toString(),
              photoId: _photoId,
              email: form.value['email']?.toString(),
              linkedin: form.value['linkedin']?.toString(),
              sortOrder: int.tryParse(form.value['sortOrder']?.toString() ?? ''),
              isActive: form.value['isActive'] == true,
            ),
          )
        : await repo.updateTeamMember(widget.memberId!, {
            'name': form.value['name']?.toString() ?? '',
            'role': form.value['role']?.toString() ?? '',
            'bio': form.value['bio']?.toString(),
            'photoId': _photoId,
            'email': form.value['email']?.toString(),
            'linkedin': form.value['linkedin']?.toString(),
            'sortOrder': int.tryParse(form.value['sortOrder']?.toString() ?? ''),
            'isActive': form.value['isActive'] == true,
          });
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminTeamProvider);
        ref.invalidate(publicTeamProvider);
        context.go('/admin/catalog');
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
