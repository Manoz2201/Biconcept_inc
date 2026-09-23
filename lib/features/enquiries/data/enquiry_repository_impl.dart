import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../domain/enquiry.dart';
import '../domain/enquiry_repository.dart';

class EnquiryRepositoryImpl implements EnquiryRepository {
  EnquiryRepositoryImpl({
    TablesDB? tables,
    AuditRepository? audit,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _audit = audit ?? AuditRepository(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'public');

  final TablesDB _tables;
  final AuditRepository _audit;
  final String _databaseId;
  final String Function() _actorId;

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<AppResult<Enquiry>> submitEnquiry({
    required String name,
    required String email,
    String? phone,
    String? serviceId,
    required String message,
    String? source,
  }) {
    return AppwriteService.guard(() async {
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: ID.unique(),
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': ?phone,
          'serviceId': ?serviceId,
          'message': message.trim(),
          'status': EnquiryStatus.newLead.value,
          'source': source ?? 'website',
          'createdAt': _now,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'enquiry_submitted',
        metadata: {'id': row.$id, 'email': email.trim()},
      );
      return Enquiry.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<List<Enquiry>>> getEnquiries({
    EnquiryStatus? status,
    String? assignedTo,
  }) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        queries: [
          if (status != null) Query.equal('status', status.value),
          if (assignedTo != null && assignedTo.isNotEmpty) Query.equal('assignedTo', assignedTo),
          Query.orderDesc('createdAt'),
          Query.limit(100),
        ],
      );
      return [for (final row in page.rows) Enquiry.fromRow(row.$id, row.data)];
    });
  }

  @override
  Future<AppResult<Enquiry>> getEnquiryById(String id) {
    return AppwriteService.guard(() async {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: id,
      );
      return Enquiry.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Enquiry>> updateEnquiryStatus(String id, EnquiryStatus status) {
    return AppwriteService.guard(() async {
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: id,
        data: {
          'status': status.value,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'enquiry_status_changed',
        metadata: {'id': id, 'status': status.value},
      );
      return Enquiry.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Enquiry>> assignEnquiry(String id, String userId) {
    return AppwriteService.guard(() async {
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: id,
        data: {
          'assignedTo': userId,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'enquiry_assigned',
        metadata: {'id': id, 'assignedTo': userId},
      );
      return Enquiry.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Enquiry>> addEnquiryNote(String id, String note) {
    return AppwriteService.guard(() async {
      final current = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: id,
      );
      final existing = current.data['notes']?.toString() ?? '';
      final stamp = _now;
      final next = existing.trim().isEmpty ? '[$stamp] $note' : '${existing.trim()}\n[$stamp] $note';
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: id,
        data: {
          'notes': next,
          'updatedAt': stamp,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'enquiry_note_added',
        metadata: {'id': id},
      );
      return Enquiry.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<List<EnquiryAuditEvent>>> listEnquiryAudit(String enquiryId) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.auditCol,
        queries: [
          Query.contains('metadata', enquiryId),
          Query.orderDesc('timestamp'),
          Query.limit(30),
        ],
      );
      return [
        for (final row in page.rows)
          EnquiryAuditEvent(
            id: row.$id,
            action: row.data['action']?.toString() ?? '',
            metadata: row.data['metadata']?.toString(),
            timestamp: DateTime.tryParse(row.data['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
      ];
    });
  }
}
