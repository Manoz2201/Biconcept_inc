import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../auth/domain/user.dart';

class AuditRepository {
  AuditRepository({
    TablesDB? tables,
    String? databaseId,
  })  : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<void> log({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
    String? ipAddress,
  }) async {
    try {
      await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.auditCol,
        rowId: ID.unique(),
        data: {
          'userId': userId,
          'action': action,
          'metadata': metadata == null ? null : jsonEncode(_redact(metadata)),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'ipAddress': ?ipAddress,
        },
      );
    } catch (_) {
      // Audit must never break the calling flow.
    }
  }

  Map<String, dynamic> _redact(Map<String, dynamic> metadata) {
    const blocked = {
      'password',
      'secret',
      'token',
      'session',
      'sessionId',
      'apiKey',
      'key',
    };
    return {
      for (final entry in metadata.entries)
        if (!blocked.contains(entry.key)) entry.key: entry.value,
    };
  }
}

User userFromRow(String id, Map<String, dynamic> data) {
  return User(
    id: id,
    accountId: data['accountId']?.toString() ?? '',
    name: data['name']?.toString() ?? '',
    email: data['email']?.toString() ?? '',
    phone: data['phone']?.toString(),
    role: UserRoleConverter().fromJson(data['role']?.toString() ?? 'client'),
    clientId: data['clientId']?.toString(),
    vendorId: data['vendorId']?.toString(),
    emailVerified: data['emailVerified'] == true,
    isActive: data['isActive'] != false,
    createdAt: _parseTime(data['createdAt']),
    updatedAt: _parseTime(data['updatedAt']),
  );
}

DateTime? _parseTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
