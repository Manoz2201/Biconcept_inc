import '../../features/rbac/domain/permission.dart';
import '../../features/rbac/domain/role_permissions.dart';
import '../../features/rbac/domain/user_role.dart';

export 'app_router.dart';

bool guardAllows({required UserRole? role, required Permission permission}) {
  if (role == null) return false;
  return hasPermission(role, permission);
}
