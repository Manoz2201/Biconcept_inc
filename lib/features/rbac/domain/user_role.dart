enum UserRole {
  superAdmin('super_admin'),
  admin('admin'),
  architect('architect'),
  accountant('accountant'),
  vendor('vendor'),
  client('client');

  const UserRole(this.value);

  final String value;

  static UserRole fromString(String s) => values.firstWhere(
        (role) => role.value == s,
        orElse: () => UserRole.client,
      );

  String get label => switch (this) {
        UserRole.superAdmin => 'Super admin',
        UserRole.admin => 'Admin',
        UserRole.architect => 'Architect',
        UserRole.accountant => 'Accountant',
        UserRole.vendor => 'Vendor',
        UserRole.client => 'Client',
      };

  bool get isStaff =>
      this == UserRole.superAdmin ||
      this == UserRole.admin ||
      this == UserRole.architect ||
      this == UserRole.accountant;
}
