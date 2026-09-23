import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_widgets.dart';

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'No access',
      subtitle: 'This screen is limited to another role in the firm.',
      child: FilledButton(
        onPressed: () => context.go('/'),
        child: const Text('Back home'),
      ),
    );
  }
}
