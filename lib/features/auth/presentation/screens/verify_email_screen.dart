import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/home_location.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_widgets.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  var _cooldown = 0;
  var _busy = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLink());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(sessionControllerProvider).user?.email ?? 'your email';
    return AuthShell(
      title: 'Verify your email',
      subtitle: 'We sent a verification link to $email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ErrorBanner(message: _error!),
          AppPrimaryButton(
            label: _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend link',
            loading: _busy,
            onPressed: _cooldown > 0 || _busy ? null : _resend,
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Continue to the app',
            onPressed: () => context.go(homeLocationFor(ref.read(sessionControllerProvider).user?.role)),
          ),
          const SizedBox(height: 16),
          Text(
            'Open the link on this device. Appwrite appends userId and secret automatically.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _consumeDeepLink() async {
    if (GoRouter.maybeOf(context) == null) return;
    final uri = GoRouterState.of(context).uri;
    final userId = uri.queryParameters['userId'];
    final secret = uri.queryParameters['secret'];
    if (userId == null || userId.isEmpty || secret == null || secret.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authRepositoryProvider).verifyEmail(userId: userId, secret: secret);
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.read(sessionControllerProvider.notifier).restore();
        context.go(homeLocationFor(ref.read(sessionControllerProvider).user?.role));
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authRepositoryProvider).sendEmailVerification();
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() {
          _busy = false;
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
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
