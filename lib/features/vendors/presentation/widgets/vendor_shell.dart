import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/widgets/app_nav.dart';
import '../../../../ui/widgets/portal_shell.dart';

class VendorShell extends StatelessWidget {
  const VendorShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = location.startsWith('/vendor/profile') || location.startsWith('/vendor/rates')
        ? 4
        : location.startsWith('/vendor/bills') || location.startsWith('/vendor/payments')
            ? 3
            : location.startsWith('/vendor/pos')
                ? 2
                : location.startsWith('/vendor/rfqs')
                    ? 1
                    : 0;
    return AppPortalShell(
      selectedIndex: index,
      destinations: vendorNavDestinations,
      onSelect: (value) {
        switch (value) {
          case 0:
            context.go('/vendor/dashboard');
          case 1:
            context.go('/vendor/rfqs');
          case 2:
            context.go('/vendor/pos');
          case 3:
            context.go('/vendor/bills');
          case 4:
            context.go('/vendor/profile');
        }
      },
      child: child,
    );
  }
}
