import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/permission.dart';
import '../domain/role_permissions.dart';
import '../domain/user_role.dart';

class RbacState {
  const RbacState({this.role, this.permissions = const {}});

  final UserRole? role;
  final Set<Permission> permissions;

  bool allows(Permission permission) => permissions.contains(permission);
}

final rbacProvider = Provider<RbacState>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final user = session.user;
  if (!session.isAuthenticated || user == null) {
    return const RbacState();
  }
  return RbacState(
    role: user.role,
    permissions: kRolePermissions[user.role] ?? const {},
  );
});
