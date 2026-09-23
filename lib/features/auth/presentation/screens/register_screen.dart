import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_inputs.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _busy = false;
  var _accepted = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final email = uri.queryParameters['email'] ?? '';
    final userId = uri.queryParameters['userId'] ?? '';
    final secret = uri.queryParameters['secret'] ?? '';
    final invited = userId.isNotEmpty && secret.isNotEmpty;

    return AuthShell(
      title: invited ? 'Join the firm' : 'Create your account',
      subtitle: invited
          ? 'Finish creating your account from the invitation email.'
          : 'Clients can sign up here. Staff and vendors still need an invitation.',
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBanner(message: _error!),
            FormBuilderTextField(
              name: 'email',
              initialValue: email,
              readOnly: invited && email.isNotEmpty,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(errorText: 'Email is required'),
                FormBuilderValidators.email(errorText: 'Enter a valid email'),
              ]),
            ),
            const SizedBox(height: 12),
            FormBuilderTextField(
              name: 'name',
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: FormBuilderValidators.required(),
            ),
            const SizedBox(height: 12),
            FormBuilderTextField(
              name: 'phone',
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Mobile number'),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                final local = digits.length == 12 && digits.startsWith('91') ? digits.substring(2) : digits;
                if (local.isEmpty) return 'Mobile number is required';
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(local)) {
                  return 'Enter a 10-digit Indian mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            FormBuilderTextField(
              name: 'password',
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
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
                if (value != _formKey.currentState?.instantValue['password']) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            AppCheckbox(
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value),
              label: 'I agree to keep client drawings and quotations confidential',
            ),
            const SizedBox(height: 8),
            AppPrimaryButton(
              key: const Key('register-submit'),
              label: 'Create account',
              loading: _busy,
              onPressed: _busy || !_accepted ? null : () => _submit(uri),
            ),
            AppTextButton(
              label: 'Already have an account? Sign in',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(Uri uri) async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(sessionControllerProvider.notifier).register(
          email: form.value['email'].toString(),
          password: form.value['password'].toString(),
          name: form.value['name'].toString(),
          phone: form.value['phone']?.toString(),
          teamId: uri.queryParameters['teamId'],
          membershipId: uri.queryParameters['membershipId'],
          userId: uri.queryParameters['userId'],
          secret: uri.queryParameters['secret'],
        );
    if (!mounted) return;
    result.when(
      success: (_) => context.go('/verify-email'),
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
