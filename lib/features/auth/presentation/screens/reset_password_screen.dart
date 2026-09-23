import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final userId = uri.queryParameters['userId'] ?? '';
    final secret = uri.queryParameters['secret'] ?? '';
    final valid = userId.isNotEmpty && secret.isNotEmpty;

    return AuthShell(
      title: 'Choose a new password',
      subtitle: valid ? null : 'This reset link is missing userId or secret.',
      child: !valid
          ? TextButton(onPressed: () => context.go('/forgot-password'), child: const Text('Request a new link'))
          : FormBuilder(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ErrorBanner(message: _error!),
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password'),
                    onChanged: (_) => setState(() {}),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.minLength(8),
                    ]),
                  ),
                  PasswordStrengthMeter(
                    password: _formKey.currentState?.instantValue['password']?.toString() ?? '',
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'confirm',
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                    validator: (value) {
                      final password = _formKey.currentState?.instantValue['password']?.toString();
                      if (value != password) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: 'Update password',
                    loading: _busy,
                    onPressed: _busy ? null : () => _submit(userId: userId, secret: secret),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _submit({required String userId, required String secret}) async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authRepositoryProvider).completePasswordReset(
          userId: userId,
          secret: secret,
          password: form.value['password'].toString(),
        );
    if (!mounted) return;
    result.when(
      success: (_) => context.go('/login'),
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
