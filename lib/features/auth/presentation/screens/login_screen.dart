import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/home_location.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _obscure = true;
  var _submitting = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    return AuthShell(
      title: 'Sign in',
      subtitle: 'Staff, vendors, and clients use the same firm login.',
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session.error != null) ErrorBanner(message: session.error!.userMessage),
            FormBuilderTextField(
              name: 'email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(errorText: 'Email is required'),
                FormBuilderValidators.email(errorText: 'Enter a valid email'),
              ]),
            ),
            const SizedBox(height: AppSpacing.sm),
            FormBuilderTextField(
              name: 'password',
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: FormBuilderValidators.required(errorText: 'Password is required'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AppTextButton(
                label: 'Forgot password?',
                onPressed: () => context.go('/forgot-password'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppPrimaryButton(
              key: const Key('login-submit'),
              label: 'Sign in',
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextButton(
              label: 'New client? Create an account',
              onPressed: () => context.go('/register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() => _submitting = true);
    final email = form.value['email']?.toString() ?? '';
    final password = form.value['password']?.toString() ?? '';
    final result = await ref.read(sessionControllerProvider.notifier).login(email, password);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      success: (user) => context.go(homeLocationFor(user.role)),
      failure: (error) {
        if (error.code == 401) {
          // Banner is bound to session.error.
        } else if (error.type == AppErrorType.permission) {
          context.go('/403');
        }
      },
    );
  }
}
