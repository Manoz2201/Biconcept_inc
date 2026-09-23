import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../data/crm_lead_sync.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../enquiries/domain/enquiry.dart';
import '../domain/service_request.dart';
import '../domain/service_request_repository.dart';

class ServiceRequestRepositoryImpl implements ServiceRequestRepository {
  ServiceRequestRepositoryImpl({
    TablesDB? tables,
    Storage? storage,
    Teams? teams,
    AuditRepository? audit,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _storage = storage ?? AppwriteService.storage,
        _teams = teams ?? AppwriteService.teams,
        _audit = audit ?? AuditRepository(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown');

  final TablesDB _tables;
  final Storage _storage;
  final Teams _teams;
  final AuditRepository _audit;
  final String _databaseId;
  final String Function() _actorId;

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<AppResult<List<ServiceRequest>>> getServiceRequests({
    String? clientId,
    ServiceRequestStatus? status,
    String? assignedTo,
  }) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        queries: [
          if (clientId != null && clientId.isNotEmpty) Query.equal('clientId', clientId),
          if (status != null) Query.equal('status', status.toAppwriteString()),
          if (assignedTo != null && assignedTo.isNotEmpty) Query.equal('assignedTo', assignedTo),
          Query.orderDesc('createdAt'),
          Query.limit(100),
        ],
      );
      return [for (final row in page.rows) ServiceRequest.fromRow(row.$id, row.data)];
    });
  }

  @override
  Future<AppResult<ServiceRequest>> getServiceRequestById(String id) {
    return AppwriteService.guard(() async {
      return _get(id);
    });
  }

  @override
  Future<AppResult<ServiceRequest>> createServiceRequest({
    required String clientId,
    required String title,
    required String description,
    String? serviceId,
    String? enquiryId,
    List<String>? attachments,
    ServiceRequestPriority? priority,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) {
    return AppwriteService.guard(() async {
      final now = _now;
      final leadId = enquiryId ??
          await _createClientLead(
            clientId: clientId,
            title: title,
            description: description,
            serviceId: serviceId,
            clientName: clientName,
            clientEmail: clientEmail,
            clientPhone: clientPhone,
          );
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: ID.unique(),
        data: {
          'clientId': clientId,
          'enquiryId': ?leadId,
          'title': title.trim(),
          'description': description.trim(),
          'serviceId': ?serviceId,
          'status': ServiceRequestStatus.submitted.value,
          'priority': ?priority?.value,
          'attachments': attachments ?? const <String>[],
          'createdAt': now,
          'updatedAt': now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_request_created',
        metadata: {'id': row.$id, 'clientId': clientId, 'enquiryId': ?leadId},
      );
      await _upsertCrmLead(
        clientId: clientId,
        title: title,
        description: description,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
      );
      return ServiceRequest.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<ServiceRequest>> updateServiceRequest(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final current = await _get(id);
      final payload = Map<String, dynamic>.from(data);
      if (payload['status'] != null) {
        final next = ServiceRequestStatus.fromString(payload['status'].toString());
        payload['status'] = next.value;
        if (current.status != next && !current.status.canTransitionTo(next)) {
          throw AppwriteException(
            'Cannot change status from ${current.status.value} to ${next.value}',
            400,
          );
        }
      }
      payload['updatedAt'] = _now;
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: id,
        data: payload,
      );
      if (payload['status'] != null && payload['status'] != current.status.value) {
        await _audit.log(
          userId: _actorId(),
          action: 'service_request_status_changed',
          metadata: {
            'id': id,
            'from': current.status.value,
            'to': payload['status'],
          },
        );
      }
      return ServiceRequest.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<ServiceRequest>> assignTo(String id, String userId) {
    return AppwriteService.guard(() async {
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: id,
        data: {
          'assignedTo': userId,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_request_assigned',
        metadata: {'id': id, 'assignedTo': userId},
      );
      return ServiceRequest.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<ServiceRequest>> convertFromEnquiry(String enquiryId) {
    return AppwriteService.guard(() async {
      final enquiryRow = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: enquiryId,
      );
      final enquiry = Enquiry.fromRow(enquiryRow.$id, enquiryRow.data);
      final clientId = await _clientIdForEmail(enquiry.email, name: enquiry.name);
      final now = _now;
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: ID.unique(),
        data: {
          'clientId': clientId,
          'enquiryId': enquiry.id,
          'title': enquiry.name,
          'description': enquiry.message,
          'serviceId': ?enquiry.serviceId,
          'status': ServiceRequestStatus.submitted.value,
          'attachments': const <String>[],
          'createdAt': now,
          'updatedAt': now,
        },
        permissions: clientDocumentPermissions(clientId),
      );
      await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: enquiry.id,
        data: {
          'status': EnquiryStatus.converted.value,
          'updatedAt': now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'enquiry_converted_to_request',
        metadata: {
          'enquiryId': enquiry.id,
          'serviceRequestId': row.$id,
          'clientId': clientId,
        },
      );
      return ServiceRequest.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<ServiceRequest>> uploadAttachment(String requestId, UploadBytes file) {
    return AppwriteService.guard(() async {
      final current = await _get(requestId);
      final filename = sanitizeUploadName(file.filename);
      validateUpload(file.bytes, filename);
      final created = await _storage.createFile(
        bucketId: AppwriteService.clientUploadsBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: Uint8List.fromList(file.bytes),
          filename: filename,
        ),
      );
      final attachments = [...current.attachments, created.$id];
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: requestId,
        data: {
          'attachments': attachments,
          'updatedAt': _now,
        },
      );
      return ServiceRequest.fromRow(row.$id, row.data);
    });
  }

  Future<ServiceRequest> _get(String id) async {
    final row = await _tables.getRow(
      databaseId: _databaseId,
      tableId: AppwriteService.serviceRequestsCol,
      rowId: id,
    );
    return ServiceRequest.fromRow(row.$id, row.data);
  }

  Future<void> _upsertCrmLead({
    required String clientId,
    required String title,
    required String description,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) async {
    try {
      var name = clientName?.trim() ?? '';
      var email = clientEmail?.trim() ?? '';
      var phone = clientPhone?.trim();
      if (email.isEmpty || name.isEmpty) {
        final page = await _tables.listRows(
          databaseId: _databaseId,
          tableId: AppwriteService.usersCol,
          queries: [
            Query.equal('accountId', clientId),
            Query.limit(1),
          ],
        );
        if (page.rows.isNotEmpty) {
          final data = page.rows.first.data;
          if (name.isEmpty) name = data['name']?.toString() ?? '';
          if (email.isEmpty) email = data['email']?.toString() ?? '';
          phone ??= data['phone']?.toString();
        }
      }
      if (email.isEmpty && name.isEmpty) return;
      await CrmLeadSync(tables: _tables, databaseId: _databaseId).upsertPortalLead(
        clientRecordFromPortal(
          accountId: clientId,
          name: name,
          email: email,
          phone: phone,
          title: title,
          description: description,
        ),
      );
    } catch (_) {}
  }

  Future<String?> _createClientLead({
    required String clientId,
    required String title,
    required String description,
    String? serviceId,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) async {
    try {
      var name = clientName?.trim() ?? '';
      var email = clientEmail?.trim() ?? '';
      var phone = clientPhone?.trim();
      if (email.isEmpty || name.isEmpty) {
        final page = await _tables.listRows(
          databaseId: _databaseId,
          tableId: AppwriteService.usersCol,
          queries: [
            Query.equal('accountId', clientId),
            Query.limit(1),
          ],
        );
        if (page.rows.isNotEmpty) {
          final data = page.rows.first.data;
          if (name.isEmpty) name = data['name']?.toString() ?? '';
          if (email.isEmpty) email = data['email']?.toString() ?? '';
          phone ??= data['phone']?.toString();
        }
      }
      if (email.isEmpty) return null;
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        rowId: ID.unique(),
        data: {
          'name': name.isEmpty ? email : name,
          'email': email,
          'phone': ?phone,
          'serviceId': ?serviceId,
          'message': '${title.trim()}\n\n${description.trim()}',
          'status': EnquiryStatus.newLead.value,
          'source': 'client_portal',
          'createdAt': _now,
          'updatedAt': _now,
        },
      );
      return row.$id;
    } catch (_) {
      return null;
    }
  }

  Future<String> _clientIdForEmail(String email, {String? name}) async {
    final existing = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.usersCol,
      queries: [
        Query.equal('email', email.trim()),
        Query.limit(1),
      ],
    );
    if (existing.rows.isNotEmpty) {
      final accountId = existing.rows.first.data['accountId']?.toString() ?? '';
      if (accountId.isNotEmpty) return accountId;
    }
    final membership = await _teams.createMembership(
      teamId: AppwriteService.teamClients,
      roles: const ['client'],
      email: email.trim(),
      name: name,
      url: Env.inviteUrl,
    );
    if (membership.userId.isNotEmpty) return membership.userId;
    throw AppwriteException(
      'Invite sent to ${email.trim()}. Convert again after the client registers.',
      409,
    );
  }
}
