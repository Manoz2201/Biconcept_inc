import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/company_profile.dart';
import '../widgets/auth_widgets.dart';

class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Session expired',
      subtitle: 'Sign in again to keep working on estimates and clients.',
      child: FilledButton(
        onPressed: () => context.go('/login'),
        child: const Text('Sign in'),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              companyLogoAsset,
              height: 80,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
