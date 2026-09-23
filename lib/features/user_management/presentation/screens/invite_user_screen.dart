import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../rbac/domain/user_role.dart';
import '../providers/user_providers.dart';

class InviteUserScreen extends ConsumerStatefulWidget {
  const InviteUserScreen({super.key});

  @override
  ConsumerState<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends ConsumerState<InviteUserScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  String? _error;
  String? _hint;

  static const _inviteRoles = [
    UserRole.architect,
    UserRole.accountant,
    UserRole.vendor,
    UserRole.client,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite user')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FormBuilder(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) ErrorBanner(message: _error!),
                if (_hint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_hint!, style: TextStyle(color: AppColors.primarySoft)),
                  ),
                FormBuilderTextField(
                  name: 'email',
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.email(),
                  ]),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'name',
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 12),
                FormBuilderDropdown<UserRole>(
                  name: 'role',
                  initialValue: UserRole.architect,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final role in _inviteRoles)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'clientId',
                  decoration: const InputDecoration(labelText: 'Client id (optional)'),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'vendorId',
                  decoration: const InputDecoration(labelText: 'Vendor id (optional)'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send invitation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    final email = form.value['email'].toString();
    final validator = ref.read(emailValidationServiceProvider);
    if (!validator.validateLocally(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _hint = null;
    });
    final checked = await validator.validateWithBackend(email);
    final blocked = checked.when(
      success: (result) {
        final hard = validator.hardBlockMessage(result);
        if (hard != null) {
          setState(() {
            _busy = false;
            _error = hard;
          });
          return true;
        }
        setState(() => _hint = validator.warningMessage(result));
        return false;
      },
      failure: (error) {
        setState(() => _hint = error.userMessage);
        return false;
      },
    );
    if (blocked) return;

    final role = form.value['role'] as UserRole? ?? UserRole.client;
    final result = await ref.read(userRepositoryProvider).invite(
          email: email,
          role: role,
          name: form.value['name']?.toString(),
          clientId: form.value['clientId']?.toString(),
          vendorId: form.value['vendorId']?.toString(),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(userListProvider);
        context.go('/users');
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
