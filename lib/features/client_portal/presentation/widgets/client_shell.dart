import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/widgets/app_nav.dart';
import '../../../../ui/widgets/portal_shell.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = location.startsWith('/client/profile')
        ? 5
        : location.startsWith('/client/messages') || location.startsWith('/client/chat')
            ? 4
            : location.startsWith('/client/quotations')
                ? 3
                : location.startsWith('/client/requests')
                    ? 2
                    : location.startsWith('/client/projects')
                        ? 1
                        : 0;
    return AppPortalShell(
      selectedIndex: index,
      destinations: clientNavDestinations,
      onSelect: (value) {
        switch (value) {
          case 0:
            context.go('/client/dashboard');
          case 1:
            context.go('/client/projects');
          case 2:
            context.go('/client/requests');
          case 3:
            context.go('/client/quotations');
          case 4:
            context.go('/client/chat');
          case 5:
            context.go('/client/profile');
        }
      },
      child: child,
    );
  }
}
