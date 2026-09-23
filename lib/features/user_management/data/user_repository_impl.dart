import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../auth/domain/team_mapping.dart';
import '../../auth/domain/user.dart';
import '../../rbac/domain/user_role.dart';
import '../domain/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    TablesDB? tables,
    Teams? teams,
    AuditRepository? audit,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _teams = teams ?? AppwriteService.teams,
        _audit = audit ?? AuditRepository(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown');

  final TablesDB _tables;
  final Teams _teams;
  final AuditRepository _audit;
  final String _databaseId;
  final String Function() _actorId;

  @override
  Future<AppResult<UserPage>> list({
    String? search,
    UserRole? role,
    bool? isActive,
    String? cursor,
    int limit = 25,
  }) {
    return AppwriteService.guard(() async {
      final queries = <String>[
        Query.orderDesc('updatedAt'),
        Query.limit(limit),
        if (role != null) Query.equal('role', role.value),
        if (isActive != null) Query.equal('isActive', isActive),
        if (cursor != null && cursor.isNotEmpty) Query.cursorAfter(cursor),
      ];
      final q = search?.trim() ?? '';
      if (q.isNotEmpty) {
        queries.add(
          Query.or([
            Query.contains('name', q),
            Query.contains('email', q),
          ]),
        );
      }
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        queries: queries,
      );
      return UserPage(
        users: [
          for (final row in page.rows) userFromRow(row.$id, row.data),
        ],
        nextCursor: page.rows.length == limit ? page.rows.last.$id : null,
      );
    });
  }

  @override
  Future<AppResult<User>> getById(String id) {
    return AppwriteService.guard(() async {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        rowId: id,
      );
      return userFromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<List<AuditEvent>>> listAuditLogs(String userId, {int limit = 20}) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.auditCol,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('timestamp'),
          Query.limit(limit),
        ],
      );
      return [
        for (final row in page.rows)
          AuditEvent(
            id: row.$id,
            userId: row.data['userId']?.toString() ?? userId,
            action: row.data['action']?.toString() ?? '',
            metadata: row.data['metadata']?.toString(),
            timestamp: DateTime.tryParse(row.data['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            ipAddress: row.data['ipAddress']?.toString(),
          ),
      ];
    });
  }

  @override
  Future<AppResult<void>> invite({
    required String email,
    required UserRole role,
    String? name,
    String? clientId,
    String? vendorId,
  }) {
    return AppwriteService.guard(() async {
      final teamId = teamIdForRole(role);
      final url =
          '${Env.inviteUrl}?teamId=$teamId&role=${Uri.encodeQueryComponent(role.value)}';
      await _teams.createMembership(
        teamId: teamId,
        roles: teamRolesFor(role),
        email: email.trim(),
        name: name,
        url: url,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'user_invited',
        metadata: {
          'email': email.trim(),
          'role': role.value,
          'clientId': ?clientId,
          'vendorId': ?vendorId,
        },
      );
    });
  }

  @override
  Future<AppResult<User>> updateRole({
    required String userId,
    required UserRole role,
  }) {
    return AppwriteService.guard(() async {
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        rowId: userId,
        data: {
          'role': role.value,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'user_role_changed',
        metadata: {'targetUserId': userId, 'role': role.value},
      );
      return userFromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<User>> setActive({
    required String userId,
    required bool isActive,
  }) {
    return AppwriteService.guard(() async {
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        rowId: userId,
        data: {
          'isActive': isActive,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: isActive ? 'user_reactivated' : 'user_deactivated',
        metadata: {'targetUserId': userId},
      );
      return userFromRow(row.$id, row.data);
    });
  }
}
