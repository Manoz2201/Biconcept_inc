import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../core/storage/secure_storage.dart';
import '../../rbac/domain/user_role.dart';
import '../domain/auth_repository.dart';
import '../domain/team_mapping.dart';
import '../domain/user.dart';
import 'audit_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    Account? account,
    TablesDB? tables,
    Teams? teams,
    AuditRepository? audit,
    SecureStore? secureStore,
    String? databaseId,
  })  : _account = account ?? AppwriteService.account,
        _tables = tables ?? AppwriteService.tables,
        _teams = teams ?? AppwriteService.teams,
        _audit = audit ?? AuditRepository(),
        _secureStore = secureStore ?? SecureStore(),
        _databaseId = databaseId ?? AppwriteService.dbId;

  final Account _account;
  final TablesDB _tables;
  final Teams _teams;
  final AuditRepository _audit;
  final SecureStore _secureStore;
  final String _databaseId;

  @override
  Future<AppResult<User>> login(String email, String password) {
    return AppwriteService.guard(() async {
      try {
        final session = await _account.createEmailPasswordSession(
          email: email.trim(),
          password: password,
        );
        await _secureStore.writeSessionId(session.$id);
        final user = await _profileForAccount(session.userId);
        if (!user.isActive) {
          await _account.deleteSession(sessionId: 'current');
          await _secureStore.clear();
          throw AppwriteException(
            'This account has been deactivated',
            403,
            'general_forbidden',
          );
        }
        await _audit.log(userId: user.accountId, action: 'login_success');
        return user;
      } catch (error) {
        await _audit.log(
          userId: 'anonymous',
          action: 'login_failed',
          metadata: {'email': email.trim()},
        );
        rethrow;
      }
    });
  }

  @override
  Future<AppResult<void>> logout() {
    return AppwriteService.guard(() async {
      String userId = 'anonymous';
      try {
        final account = await _account.get();
        userId = account.$id;
      } catch (_) {}
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      await _secureStore.clear();
      await _audit.log(userId: userId, action: 'logout');
    });
  }

  @override
  Future<AppResult<User>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? teamId,
    String? membershipId,
    String? userId,
    String? secret,
    String? clientId,
    String? vendorId,
  }) {
    return AppwriteService.guard(() async {
      final created = await _account.create(
        userId: ID.unique(),
        email: email.trim(),
        password: password,
        name: name.trim(),
      );
      final session = await _account.createEmailPasswordSession(
        email: email.trim(),
        password: password,
      );
      await _secureStore.writeSessionId(session.$id);

      final now = DateTime.now().toUtc().toIso8601String();
      final mobile = _normalizePhone(phone);
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        rowId: ID.unique(),
        data: {
          'accountId': created.$id,
          'name': name.trim(),
          'email': email.trim(),
          'phone': ?mobile,
          'role': UserRole.client.value,
          'clientId': ?clientId?.trim(),
          'vendorId': ?vendorId?.trim(),
          'emailVerified': false,
          'isActive': true,
          'createdAt': now,
          'updatedAt': now,
        },
      );

      var role = UserRole.client;
      if (teamId != null &&
          membershipId != null &&
          userId != null &&
          secret != null &&
          teamId.isNotEmpty &&
          membershipId.isNotEmpty &&
          userId.isNotEmpty &&
          secret.isNotEmpty) {
        await _teams.updateMembershipStatus(
          teamId: teamId,
          membershipId: membershipId,
          userId: userId,
          secret: secret,
        );
        try {
          final membership = await _teams.getMembership(
            teamId: teamId,
            membershipId: membershipId,
          );
          role = roleFromTeamRoles(membership.roles);
        } catch (_) {
          role = switch (teamId) {
            Env.teamStaff => UserRole.architect,
            Env.teamVendors => UserRole.vendor,
            _ => UserRole.client,
          };
        }
      }

      if (role != UserRole.client) {
        await _tables.updateRow(
          databaseId: _databaseId,
          tableId: AppwriteService.usersCol,
          rowId: row.$id,
          data: {
            'role': role.value,
            'updatedAt': now,
          },
        );
      }

      if (teamId == null || teamId.isEmpty) {
        try {
          await _teams.createMembership(
            teamId: Env.teamClients,
            roles: const ['client'],
            userId: created.$id,
          );
        } catch (_) {}
      }

      await _audit.log(userId: created.$id, action: 'register');
      try {
        await _account.createEmailVerification(url: Env.verifyUrl);
      } catch (_) {}
      final data = Map<String, dynamic>.from(row.data)..['role'] = role.value;
      return userFromRow(row.$id, data);
    });
  }

  @override
  Future<AppResult<void>> sendPasswordReset(String email) {
    return AppwriteService.guard(() async {
      await _account.createRecovery(email: email.trim(), url: Env.resetUrl);
      await _audit.log(
        userId: 'anonymous',
        action: 'password_reset_requested',
        metadata: {'email': email.trim()},
      );
    });
  }

  @override
  Future<AppResult<void>> completePasswordReset({
    required String userId,
    required String secret,
    required String password,
  }) {
    return AppwriteService.guard(() async {
      await _account.updateRecovery(
        userId: userId,
        secret: secret,
        password: password,
      );
      await _audit.log(userId: userId, action: 'password_reset_completed');
    });
  }

  @override
  Future<AppResult<void>> sendEmailVerification() {
    return AppwriteService.guard(() async {
      await _account.createEmailVerification(url: Env.verifyUrl);
      final account = await _account.get();
      await _audit.log(userId: account.$id, action: 'email_verification_sent');
    });
  }

  @override
  Future<AppResult<void>> verifyEmail({
    required String userId,
    required String secret,
  }) {
    return AppwriteService.guard(() async {
      await _account.updateEmailVerification(userId: userId, secret: secret);
      final profile = await _findByAccountId(userId);
      if (profile != null) {
        await _tables.updateRow(
          databaseId: _databaseId,
          tableId: AppwriteService.usersCol,
          rowId: profile.$id,
          data: {
            'emailVerified': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }
      await _audit.log(userId: userId, action: 'email_verified');
    });
  }

  @override
  Future<AppResult<User?>> getCurrentUser() {
    return AppwriteService.guard(() async {
      final account = await _account.get();
      return _profileForAccount(account.$id, account: account);
    });
  }

  @override
  Future<AppResult<void>> refreshSession() {
    return AppwriteService.guard(() async {
      await _account.getSession(sessionId: 'current');
    });
  }

  @override
  Future<AppResult<User>> updateProfile({required String name, String? phone}) {
    return AppwriteService.guard(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw AppwriteException('Name is required', 400);
      }
      await _account.updateName(name: trimmed);
      final account = await _account.get();
      final profile = await _findByAccountId(account.$id);
      if (profile == null) return _profileForAccount(account.$id, account: account);
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        rowId: profile.$id,
        data: {
          'name': trimmed,
          'phone': ?phone,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return userFromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<void>> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return AppwriteService.guard(() async {
      await _account.updatePassword(password: newPassword, oldPassword: oldPassword);
      final account = await _account.get();
      await _audit.log(userId: account.$id, action: 'password_changed');
    });
  }

  Future<User> _profileForAccount(String accountId, {models.User? account}) async {
    final existing = await _findByAccountId(accountId);
    if (existing != null) {
      return userFromRow(existing.$id, existing.data);
    }
    final created = account ?? await _account.get();
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _tables.createRow(
      databaseId: _databaseId,
      tableId: AppwriteService.usersCol,
      rowId: ID.unique(),
      data: {
        'accountId': created.$id,
        'name': created.name,
        'email': created.email,
        'role': UserRole.client.value,
        'emailVerified': created.emailVerification,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
    );
    return userFromRow(row.$id, row.data);
  }

  static String? _normalizePhone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.isEmpty) return null;
    return raw.trim();
  }

  Future<models.Row?> _findByAccountId(String accountId) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.usersCol,
      queries: [
        Query.equal('accountId', accountId),
        Query.limit(1),
      ],
    );
    if (page.rows.isEmpty) return null;
    return page.rows.first;
  }

}

/// Exposed for tests that assert storage writes without spinning up Appwrite.
String teamIdForInviteRole(UserRole role) => teamIdForRole(role);
