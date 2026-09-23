import '../../features/rbac/domain/user_role.dart';

String homeLocationFor(UserRole? role) {
  if (role == UserRole.client) return '/client/dashboard';
  if (role == UserRole.vendor) return '/vendor/dashboard';
  return '/app';
}

String staffLocationFromClientRoute(UserRole? role) {
  if (role == UserRole.vendor) return '/vendor/dashboard';
  if (role == UserRole.accountant) return '/admin/quotations';
  if (role == UserRole.admin ||
      role == UserRole.superAdmin ||
      role == UserRole.architect) {
    return '/admin/requests';
  }
  return '/app';
}

bool isClientPortalLocation(String location) => location.startsWith('/client/');

bool isVendorPortalLocation(String location) => location.startsWith('/vendor/');

bool isStaffOnlyLocation(String location) {
  if (location == '/app' || location.startsWith('/app/')) return true;
  if (location.startsWith('/admin/')) return true;
  if (location == '/users' || location.startsWith('/users/')) return true;
  return false;
}
