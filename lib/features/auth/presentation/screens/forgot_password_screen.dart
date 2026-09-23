import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _sent = false;
  var _busy = false;
  var _cooldown = 0;
  String? _error;
  String? _hint;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthShell(
        title: 'Check your inbox',
        subtitle: 'If that email is on this firm, a reset link is on its way.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPrimaryButton(
              label: _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend link',
              loading: _busy,
              onPressed: _cooldown > 0 || _busy ? null : _send,
            ),
            AppTextButton(label: 'Back to sign in', onPressed: () => context.go('/login')),
          ],
        ),
      );
    }

    return AuthShell(
      title: 'Reset password',
      subtitle: 'We will email a one-time link. The link opens this app.',
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBanner(message: _error!),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_hint!, style: Theme.of(context).textTheme.bodySmall),
              ),
            FormBuilderTextField(
              name: 'email',
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.email(),
              ]),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(label: 'Send reset link', loading: _busy, onPressed: _busy ? null : _send),
            AppTextButton(label: 'Back to sign in', onPressed: () => context.go('/login')),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final form = _formKey.currentState;
    final email = form?.instantValue['email']?.toString() ??
        form?.fields['email']?.value?.toString() ??
        '';
    if (form != null && !form.saveAndValidate()) return;
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
    final backend = await validator.validateWithBackend(email);
    backend.when(
      success: (result) {
        final block = validator.hardBlockMessage(result);
        if (block != null) {
          setState(() {
            _busy = false;
            _error = block;
          });
          return;
        }
        _hint = validator.warningMessage(result);
      },
      failure: (error) {
        setState(() => _hint = error.userMessage);
      },
    );
    if (_error != null) return;
    final sent = await ref.read(authRepositoryProvider).sendPasswordReset(email);
    if (!mounted) return;
    sent.when(
      success: (_) {
        setState(() {
          _busy = false;
          _sent = true;
          _cooldown = 60;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_cooldown <= 1) {
            timer.cancel();
            setState(() => _cooldown = 0);
          } else {
            setState(() => _cooldown--);
          }
        });
      },
      failure: (error) {
        setState(() {
          _busy = false;
          _error = error.userMessage;
        });
      },
    );
  }
}
