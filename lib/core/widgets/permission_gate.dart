import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../features/rbac/domain/permission.dart';
import '../../features/rbac/presentation/rbac_provider.dart';

class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final Permission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(rbacProvider).allows(permission);
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
