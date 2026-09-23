import '../../../core/config/env.dart';
import '../../rbac/domain/user_role.dart';

String teamIdForRole(UserRole role) {
  return switch (role) {
    UserRole.vendor => Env.teamVendors,
    UserRole.client => Env.teamClients,
    UserRole.superAdmin ||
    UserRole.admin ||
    UserRole.architect ||
    UserRole.accountant =>
      Env.teamStaff,
  };
}

List<String> teamRolesFor(UserRole role) {
  return switch (role) {
    UserRole.superAdmin => ['admin', 'super_admin'],
    UserRole.admin => ['admin'],
    UserRole.architect => ['architect'],
    UserRole.accountant => ['accountant'],
    UserRole.vendor => ['vendor'],
    UserRole.client => ['client'],
  };
}

UserRole roleFromTeamRoles(List<String> roles) {
  if (roles.contains('super_admin')) return UserRole.superAdmin;
  if (roles.contains('admin')) return UserRole.admin;
  if (roles.contains('architect')) return UserRole.architect;
  if (roles.contains('accountant')) return UserRole.accountant;
  if (roles.contains('vendor')) return UserRole.vendor;
  return UserRole.client;
}
