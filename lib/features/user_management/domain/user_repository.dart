import '../../../core/result/app_result.dart';
import '../../auth/domain/user.dart';
import '../../rbac/domain/user_role.dart';

class UserPage {
  const UserPage({required this.users, this.nextCursor});

  final List<User> users;
  final String? nextCursor;
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.userId,
    required this.action,
    this.metadata,
    required this.timestamp,
    this.ipAddress,
  });

  final String id;
  final String userId;
  final String action;
  final String? metadata;
  final DateTime timestamp;
  final String? ipAddress;
}

abstract class UserRepository {
  Future<AppResult<UserPage>> list({
    String? search,
    UserRole? role,
    bool? isActive,
    String? cursor,
    int limit = 25,
  });

  Future<AppResult<User>> getById(String id);

  Future<AppResult<List<AuditEvent>>> listAuditLogs(String userId, {int limit = 20});

  Future<AppResult<void>> invite({
    required String email,
    required UserRole role,
    String? name,
    String? clientId,
    String? vendorId,
  });

  Future<AppResult<User>> updateRole({
    required String userId,
    required UserRole role,
  });

  Future<AppResult<User>> setActive({
    required String userId,
    required bool isActive,
  });
}
