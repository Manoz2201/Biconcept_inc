import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../messaging/domain/service_request_message.dart';
import '../../service_requests/domain/service_request.dart';
import '../domain/quotation.dart';
import '../domain/quotation_repository.dart';

class QuotationRepositoryImpl implements QuotationRepository {
  QuotationRepositoryImpl({
    TablesDB? tables,
    AuditRepository? audit,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _audit = audit ?? AuditRepository(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown');

  final TablesDB _tables;
  final AuditRepository _audit;
  final String _databaseId;
  final String Function() _actorId;

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<AppResult<List<Quotation>>> getQuotations({
    String? clientId,
    String? serviceRequestId,
    QuotationStatus? status,
  }) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        queries: [
          Query.equal('senderRole', ServiceRequestMessage.quotationRecordRole),
          if (serviceRequestId != null && serviceRequestId.isNotEmpty)
            Query.equal('serviceRequestId', serviceRequestId),
          Query.orderDesc('createdAt'),
          Query.limit(100),
        ],
      );
      final items = [
        for (final row in page.rows)
          ?Quotation.tryParseMessage(
            row.$id,
            row.data['message']?.toString() ?? '',
            sequence: row.$sequence,
          ),
      ];
      return items.where((item) {
        if (clientId != null && clientId.isNotEmpty && item.clientId != clientId) return false;
        if (status != null && item.effectiveStatus != status && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<Quotation>> getQuotationById(String id) {
    return AppwriteService.guard(() async => _get(id));
  }

  @override
  Future<AppResult<Quotation>> createQuotation({
    required String serviceRequestId,
    required String clientId,
    required String title,
    required List<QuotationLineItem> items,
    double taxRate = 18,
    required DateTime validUntil,
    String? internalNotes,
  }) {
    return AppwriteService.guard(() async {
      if (items.isEmpty) {
        throw AppwriteException('Add at least one line item', 400);
      }
      final totals = QuotationTotals.fromItems(items, taxRate: taxRate);
      final createdAt = DateTime.now().toUtc();
      final draft = Quotation(
        id: '',
        serviceRequestId: serviceRequestId,
        clientId: clientId,
        quotationNumber: 'QT-DRAFT',
        title: title.trim(),
        items: items,
        subtotal: totals.subtotal,
        taxRate: totals.taxRate,
        taxAmount: totals.taxAmount,
        total: totals.total,
        validUntil: validUntil,
        status: QuotationStatus.draft,
        internalNotes: internalNotes,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        rowId: ID.unique(),
        data: {
          'serviceRequestId': serviceRequestId,
          'senderId': _actorId(),
          'senderRole': ServiceRequestMessage.quotationRecordRole,
          'senderName': 'QT-DRAFT',
          'message': _encode(draft.copyWith(id: 'pending')),
          'isRead': false,
          'createdAt': createdAt.toIso8601String(),
        },
        permissions: clientDocumentPermissions(clientId),
      );
      final number = Quotation.numberFromSequence(row.$sequence, createdAt);
      final stored = draft.copyWith(id: row.$id, quotationNumber: number, sequence: row.$sequence);
      final updated = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        rowId: row.$id,
        data: {
          'senderName': number,
          'message': _encode(stored),
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'quotation_created',
        metadata: {
          'id': row.$id,
          'quotationNumber': number,
          'serviceRequestId': serviceRequestId,
        },
      );
      return _fromRow(updated);
    });
  }

  @override
  Future<AppResult<Quotation>> updateQuotation(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final current = await _get(id);
      if (current.status != QuotationStatus.draft) {
        throw AppwriteException('Sent quotations are immutable. Create a revision instead.', 400);
      }
      var next = current;
      if (data['title'] is String) next = next.copyWith(title: data['title'] as String);
      if (data['items'] is List<QuotationLineItem>) {
        next = next.copyWith(items: data['items'] as List<QuotationLineItem>);
      }
      if (data['taxRate'] is num) next = next.copyWith(taxRate: (data['taxRate'] as num).toDouble());
      if (data['validUntil'] is DateTime) next = next.copyWith(validUntil: data['validUntil'] as DateTime);
      if (data.containsKey('internalNotes')) {
        next = next.copyWith(internalNotes: data['internalNotes'] as String?);
      }
      final totals = QuotationTotals.fromItems(next.items, taxRate: next.taxRate);
      next = next.copyWith(
        subtotal: totals.subtotal,
        taxAmount: totals.taxAmount,
        total: totals.total,
        updatedAt: DateTime.now().toUtc(),
      );
      return _save(next, auditAction: null);
    });
  }

  @override
  Future<AppResult<Quotation>> sendQuotation(String id) {
    return AppwriteService.guard(() async {
      final current = await _get(id);
      if (current.status != QuotationStatus.draft) {
        throw AppwriteException('Only draft quotations can be sent', 400);
      }
      final sent = current.copyWith(
        status: QuotationStatus.sent,
        updatedAt: DateTime.now().toUtc(),
      );
      final saved = await _save(sent, auditAction: 'quotation_sent');
      await _setRequestStatus(current.serviceRequestId, ServiceRequestStatus.quoted);
      return saved;
    });
  }

  @override
  Future<AppResult<Quotation>> markViewed(String id) {
    return AppwriteService.guard(() async {
      final current = await _get(id);
      if (current.status != QuotationStatus.sent) return current;
      final viewed = current.copyWith(
        status: QuotationStatus.viewed,
        updatedAt: DateTime.now().toUtc(),
      );
      return _save(viewed, auditAction: 'quotation_viewed');
    });
  }

  @override
  Future<AppResult<Quotation>> clientRespond(String id, {required bool approved, String? notes}) {
    return AppwriteService.guard(() async {
      final current = await _get(id);
      if (current.status != QuotationStatus.sent && current.status != QuotationStatus.viewed) {
        throw AppwriteException('This quotation cannot be answered right now', 400);
      }
      final trimmed = notes?.trim();
      late final QuotationStatus nextStatus;
      late final String action;
      if (approved) {
        nextStatus = QuotationStatus.approved;
        action = 'quotation_approved';
      } else if (trimmed != null && trimmed.isNotEmpty) {
        nextStatus = QuotationStatus.revisionRequested;
        action = 'quotation_revision_requested';
      } else {
        nextStatus = QuotationStatus.rejected;
        action = 'quotation_rejected';
      }
      final saved = await _save(
        current.copyWith(
          status: nextStatus,
          clientNotes: trimmed,
          updatedAt: DateTime.now().toUtc(),
        ),
        auditAction: action,
      );
      if (approved) {
        await _setRequestStatus(current.serviceRequestId, ServiceRequestStatus.approved);
      } else if (nextStatus == QuotationStatus.rejected) {
        await _setRequestStatus(current.serviceRequestId, ServiceRequestStatus.rejected);
      }
      return saved;
    });
  }

  @override
  Future<AppResult<Quotation>> createRevision(String id) {
    return AppwriteService.guard(() async {
      final current = await _get(id);
      if (current.status != QuotationStatus.revisionRequested && current.status != QuotationStatus.rejected) {
        throw AppwriteException('Revisions are only created after the client requests changes', 400);
      }
      final createdAt = DateTime.now().toUtc();
      final draft = current.copyWith(
        id: '',
        quotationNumber: 'QT-DRAFT',
        status: QuotationStatus.draft,
        revisionNumber: current.revisionNumber + 1,
        clientNotes: current.clientNotes,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        rowId: ID.unique(),
        data: {
          'serviceRequestId': current.serviceRequestId,
          'senderId': _actorId(),
          'senderRole': ServiceRequestMessage.quotationRecordRole,
          'senderName': 'QT-DRAFT',
          'message': _encode(draft.copyWith(id: 'pending')),
          'isRead': false,
          'createdAt': createdAt.toIso8601String(),
        },
        permissions: clientDocumentPermissions(current.clientId),
      );
      final number = Quotation.numberFromSequence(row.$sequence, createdAt);
      final stored = draft.copyWith(id: row.$id, quotationNumber: number, sequence: row.$sequence);
      final updated = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.messagesCol,
        rowId: row.$id,
        data: {
          'senderName': number,
          'message': _encode(stored),
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'quotation_revision_created',
        metadata: {
          'id': row.$id,
          'sourceId': id,
          'quotationNumber': number,
          'revisionNumber': stored.revisionNumber,
        },
      );
      return _fromRow(updated);
    });
  }

  Future<Quotation> _get(String id) async {
    final row = await _tables.getRow(
      databaseId: _databaseId,
      tableId: AppwriteService.messagesCol,
      rowId: id,
    );
    return _fromRow(row);
  }

  Quotation _fromRow(dynamic row) {
    final quotation = Quotation.tryParseMessage(
      row.$id as String,
      row.data['message']?.toString() ?? '',
      sequence: row.$sequence as String?,
    );
    if (quotation == null) {
      throw AppwriteException('Quotation record is unreadable', 500);
    }
    return quotation;
  }

  String _encode(Quotation quotation) {
    final raw = jsonEncode(quotation.toJson());
    if (raw.length > 3900) {
      throw AppwriteException('Quotation is too large to store. Reduce line items.', 400);
    }
    return raw;
  }

  Future<Quotation> _save(Quotation quotation, {required String? auditAction}) async {
    final row = await _tables.updateRow(
      databaseId: _databaseId,
      tableId: AppwriteService.messagesCol,
      rowId: quotation.id,
      data: {
        'senderName': quotation.quotationNumber,
        'message': _encode(quotation),
      },
    );
    if (auditAction != null) {
      await _audit.log(
        userId: _actorId(),
        action: auditAction,
        metadata: {
          'id': quotation.id,
          'quotationNumber': quotation.quotationNumber,
          'status': quotation.status.value,
        },
      );
    }
    return _fromRow(row);
  }

  Future<void> _setRequestStatus(String requestId, ServiceRequestStatus status) async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: requestId,
      );
      final current = ServiceRequest.fromRow(row.$id, row.data);
      if (current.status == status || !current.status.canTransitionTo(status)) return;
      await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: requestId,
        data: {
          'status': status.value,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_request_status_changed',
        metadata: {'id': requestId, 'from': current.status.value, 'to': status.value},
      );
    } catch (_) {}
  }
}
