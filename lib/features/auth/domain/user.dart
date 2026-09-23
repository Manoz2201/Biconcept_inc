import '../../rbac/domain/user_role.dart';

class User {
  const User({
    required this.id,
    required this.accountId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.clientId,
    this.vendorId,
    this.emailVerified = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String accountId;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final String? clientId;
  final String? vendorId;
  final bool emailVerified;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? json[r'$id']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: UserRoleConverter().fromJson(json['role']?.toString() ?? 'client'),
      clientId: json['clientId']?.toString(),
      vendorId: json['vendorId']?.toString(),
      emailVerified: json['emailVerified'] == true,
      isActive: json['isActive'] != false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'name': name,
        'email': email,
        'phone': phone,
        'role': UserRoleConverter().toJson(role),
        'clientId': clientId,
        'vendorId': vendorId,
        'emailVerified': emailVerified,
        'isActive': isActive,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  User copyWith({
    String? id,
    String? accountId,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? clientId,
    String? vendorId,
    bool? emailVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      clientId: clientId ?? this.clientId,
      vendorId: vendorId ?? this.vendorId,
      emailVerified: emailVerified ?? this.emailVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserRoleConverter {
  const UserRoleConverter();

  UserRole fromJson(String json) => UserRole.fromString(json);

  String toJson(UserRole object) => object.value;
}
