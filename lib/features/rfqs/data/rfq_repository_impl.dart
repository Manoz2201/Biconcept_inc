import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../vendors/data/vendor_workspace.dart';
import '../../vendors/data/vendor_workspace_store.dart';
import '../../vendors/domain/line_items.dart';
import '../domain/rfq.dart';
import '../domain/rfq_repository.dart';
import '../domain/vendor_quote.dart';

class RFQRepositoryImpl implements RFQRepository, VendorQuoteRepository {
  RFQRepositoryImpl({
    TablesDB? tables,
    Functions? functions,
    AuditRepository? audit,
    RfqWorkspaceStore? rfqs,
    VendorWorkspaceStore? vendors,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _functions = functions ?? AppwriteService.functions,
        _audit = audit ?? AuditRepository(),
        _rfqs = rfqs ?? RfqWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _vendors = vendors ?? VendorWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown');

  final TablesDB _tables;
  final Functions _functions;
  final AuditRepository _audit;
  final RfqWorkspaceStore _rfqs;
  final VendorWorkspaceStore _vendors;
  final String _databaseId;
  final String Function() _actorId;

  @override
  Future<AppResult<List<RFQ>>> getRFQs({String? projectId, RFQStatus? status, String? category, String? createdBy}) {
    return AppwriteService.guard(() async {
      final rows = await _rfqs.list(
        projectId: projectId,
        status: status?.toAppwriteString(),
        category: category,
        createdBy: createdBy,
      );
      return [for (final row in rows) row.rfq];
    });
  }

  @override
  Future<AppResult<RFQ>> getRFQById(String id) {
    return AppwriteService.guard(() async => (await _rfqs.getById(id)).rfq);
  }

  @override
  Future<AppResult<List<RFQRecipient>>> getRecipients(String rfqId) {
    return AppwriteService.guard(() async => (await _rfqs.getById(rfqId)).workspace.recipients);
  }

  @override
  Future<AppResult<RFQ>> createRFQ({
    required String projectId,
    required String title,
    required String description,
    required String category,
    required List<CatalogLine> items,
    required DateTime dueDate,
    List<String>? vendorIds,
  }) {
    return AppwriteService.guard(() async {
      if (items.isEmpty) throw AppwriteException('Add at least one item', 400);
      final invited = vendorIds ?? const <String>[];
      final userIds = await _vendorUserIds(invited);
      final draft = await _nextNumber(AppwriteService.generateRfqNumberFn, 'RFQ');
      final now = DateTime.now().toUtc();
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.rfqsCol,
        rowId: ID.unique(),
        data: {
          'projectId': projectId,
          'rfqNumber': draft,
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'itemsJson': encodeJsonList([for (final item in items) item.toJson()]),
          'dueDate': dueDate.toUtc().toIso8601String(),
          'status': RFQStatus.draft.value,
          'createdBy': _actorId(),
          'attachments': const <String>[],
          'workspaceJson': RfqWorkspace(
            recipients: [
              for (final vendorId in invited)
                RFQRecipient(
                  id: ID.unique(),
                  rfqId: 'pending',
                  vendorId: vendorId,
                  invitedAt: now,
                  status: RFQRecipientStatus.invited,
                  createdAt: now,
                ),
            ],
          ).encode(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        permissions: rfqRowPermissions(userIds),
      );
      final numbered = _fromSequence(row.$sequence, prefix: 'RFQ', fallback: draft);
      models.Row saved = row;
      if (numbered != draft) {
        saved = await _tables.updateRow(
          databaseId: _databaseId,
          tableId: AppwriteService.rfqsCol,
          rowId: row.$id,
          data: {'rfqNumber': numbered},
        );
      }
      final workspace = RfqWorkspace.decode(saved.data['workspaceJson']?.toString());
      for (final recipient in workspace.recipients) {
        workspace.recipients[workspace.recipients.indexOf(recipient)] = RFQRecipient(
          id: recipient.id,
          rfqId: saved.$id,
          vendorId: recipient.vendorId,
          invitedAt: recipient.invitedAt,
          respondedAt: recipient.respondedAt,
          status: recipient.status,
          createdAt: recipient.createdAt,
        );
      }
      final next = await _rfqs.saveWorkspace(saved.$id, workspace);
      await _audit.log(userId: _actorId(), action: 'rfq_created', metadata: {'id': saved.$id, 'rfqNumber': numbered});
      return next.rfq;
    });
  }

  @override
  Future<AppResult<RFQ>> updateRFQ(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final current = await _rfqs.getById(id);
      if (!current.rfq.status.canEdit) throw AppwriteException('Only draft RFQs can be edited', 400);
      final payload = Map<String, dynamic>.from(data)..['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.rfqsCol,
        rowId: id,
        data: payload,
      );
      return RFQ.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<RFQ>> sendRFQ(String id) {
    return AppwriteService.guard(() async {
      final current = await _rfqs.getById(id);
      if (!current.rfq.status.canTransitionTo(RFQStatus.sent)) {
        throw AppwriteException('Cannot send this RFQ', 400);
      }
      final next = await _rfqs.saveWorkspace(id, current.workspace, rfqPatch: {'status': RFQStatus.sent.value});
      await _audit.log(userId: _actorId(), action: 'rfq_sent', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'RFQ sent', body: current.rfq.rfqNumber);
      return next.rfq;
    });
  }

  @override
  Future<AppResult<RFQ>> inviteVendors(String id, List<String> vendorIds) {
    return AppwriteService.guard(() async {
      final current = await _rfqs.getById(id);
      final existing = {for (final item in current.workspace.recipients) item.vendorId};
      final now = DateTime.now().toUtc();
      for (final vendorId in vendorIds) {
        if (existing.contains(vendorId)) continue;
        current.workspace.recipients.add(
          RFQRecipient(
            id: ID.unique(),
            rfqId: id,
            vendorId: vendorId,
            invitedAt: now,
            status: RFQRecipientStatus.invited,
            createdAt: now,
          ),
        );
      }
      final userIds = await _vendorUserIds([for (final item in current.workspace.recipients) item.vendorId]);
      return (await _rfqs.saveWorkspace(id, current.workspace, permissions: rfqRowPermissions(userIds))).rfq;
    });
  }

  @override
  Future<AppResult<RFQ>> awardRFQ(String id, String vendorId, String vendorQuoteId) {
    return AppwriteService.guard(() async {
      final current = await _rfqs.getById(id);
      if (!current.rfq.status.canTransitionTo(RFQStatus.awarded) && current.rfq.status != RFQStatus.receiving) {
        if (current.rfq.status != RFQStatus.underReview && current.rfq.status != RFQStatus.receiving && current.rfq.status != RFQStatus.sent) {
          throw AppwriteException('This RFQ cannot be awarded', 400);
        }
      }
      final vendors = await _vendors.list();
      for (final snap in vendors) {
        var changed = false;
        for (var i = 0; i < snap.workspace.quotes.length; i++) {
          final quote = snap.workspace.quotes[i];
          if (quote.rfqId != id || quote.status == VendorQuoteStatus.draft) continue;
          snap.workspace.quotes[i] = VendorQuote(
            id: quote.id,
            rfqId: quote.rfqId,
            vendorId: quote.vendorId,
            quoteNumber: quote.quoteNumber,
            items: quote.items,
            subtotal: quote.subtotal,
            taxRate: quote.taxRate,
            taxAmount: quote.taxAmount,
            total: quote.total,
            validUntil: quote.validUntil,
            deliveryDays: quote.deliveryDays,
            notes: quote.notes,
            status: quote.id == vendorQuoteId ? VendorQuoteStatus.accepted : VendorQuoteStatus.rejected,
            submittedAt: quote.submittedAt,
            createdAt: quote.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
          changed = true;
        }
        if (changed) await _vendors.saveWorkspace(snap.vendor.id, snap.workspace);
      }
      final next = await _rfqs.saveWorkspace(
        id,
        current.workspace,
        rfqPatch: {
          'status': RFQStatus.awarded.value,
          'awardedVendorId': vendorId,
          'awardedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'rfq_awarded',
        metadata: {'id': id, 'vendorId': vendorId, 'vendorQuoteId': vendorQuoteId},
      );
      await AppNotifications.instance.showImmediate(title: 'RFQ awarded', body: current.rfq.rfqNumber);
      return next.rfq;
    });
  }

  @override
  Future<AppResult<RFQ>> cancelRFQ(String id) {
    return AppwriteService.guard(() async {
      final current = await _rfqs.getById(id);
      if (!current.rfq.status.canTransitionTo(RFQStatus.cancelled) && current.rfq.status != RFQStatus.sent && current.rfq.status != RFQStatus.receiving) {
        if (current.rfq.status.isOpen || current.rfq.status == RFQStatus.draft) {
          // allowed
        } else {
          throw AppwriteException('This RFQ cannot be cancelled', 400);
        }
      }
      final next = await _rfqs.saveWorkspace(id, current.workspace, rfqPatch: {'status': RFQStatus.cancelled.value});
      await _audit.log(userId: _actorId(), action: 'rfq_cancelled', metadata: {'id': id});
      return next.rfq;
    });
  }

  @override
  Future<AppResult<List<VendorQuote>>> getVendorQuotes(String rfqId) {
    return AppwriteService.guard(() async {
      final vendors = await _vendors.list();
      return [
        for (final snap in vendors)
          for (final quote in snap.workspace.quotes)
            if (quote.rfqId == rfqId) quote,
      ]..sort((a, b) => a.total.compareTo(b.total));
    });
  }

  @override
  Future<AppResult<VendorQuote>> getVendorQuoteById(String id) {
    return AppwriteService.guard(() async {
      final host = await _vendors.findQuoteHost(id);
      if (host == null) throw AppwriteException('Quote not found', 404);
      return host.workspace.quotes.firstWhere((item) => item.id == id);
    });
  }

  @override
  Future<AppResult<List<VendorQuote>>> getMyQuotes(String vendorId) {
    return AppwriteService.guard(() async => (await _vendors.getById(vendorId)).workspace.quotes);
  }

  @override
  Future<AppResult<VendorQuote>> createVendorQuote({
    required String rfqId,
    required String vendorId,
    required List<PricedLine> items,
    double taxRate = 18,
    required DateTime validUntil,
    int? deliveryDays,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final rfq = await _rfqs.getById(rfqId);
      if (!rfq.workspace.recipients.any((item) => item.vendorId == vendorId)) {
        throw AppwriteException('You were not invited to this RFQ', 403);
      }
      final snap = await _vendors.getById(vendorId);
      final totals = pricedTotals([for (final item in items) (quantity: item.quantity, rate: item.rate)], taxRate);
      final quote = VendorQuote(
        id: ID.unique(),
        rfqId: rfqId,
        vendorId: vendorId,
        quoteNumber: 'VQ-${DateTime.now().year}-${(snap.workspace.quotes.length + 1).toString().padLeft(4, '0')}',
        items: items,
        subtotal: totals.subtotal,
        taxRate: taxRate,
        taxAmount: totals.taxAmount,
        total: totals.total,
        validUntil: validUntil,
        deliveryDays: deliveryDays,
        notes: notes?.trim(),
        status: VendorQuoteStatus.draft,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.quotes.add(quote);
      await _vendors.saveWorkspace(vendorId, snap.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_quote_created', metadata: {'id': quote.id, 'rfqId': rfqId});
      return quote;
    });
  }

  @override
  Future<AppResult<VendorQuote>> updateVendorQuote(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final host = await _vendors.findQuoteHost(id);
      if (host == null) throw AppwriteException('Quote not found', 404);
      final index = host.workspace.quotes.indexWhere((item) => item.id == id);
      final current = host.workspace.quotes[index];
      if (current.status != VendorQuoteStatus.draft) throw AppwriteException('Only draft quotes can be edited', 400);
      final items = data['items'] is List ? pricedLinesFrom(data['items']) : current.items;
      final taxRate = (data['taxRate'] as num?)?.toDouble() ?? current.taxRate;
      final totals = pricedTotals([for (final item in items) (quantity: item.quantity, rate: item.rate)], taxRate);
      final next = VendorQuote(
        id: current.id,
        rfqId: current.rfqId,
        vendorId: current.vendorId,
        quoteNumber: current.quoteNumber,
        items: items,
        subtotal: totals.subtotal,
        taxRate: taxRate,
        taxAmount: totals.taxAmount,
        total: totals.total,
        validUntil: DateTime.tryParse(data['validUntil']?.toString() ?? '') ?? current.validUntil,
        deliveryDays: (data['deliveryDays'] as num?)?.toInt() ?? current.deliveryDays,
        notes: data['notes']?.toString() ?? current.notes,
        status: current.status,
        submittedAt: current.submittedAt,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.quotes[index] = next;
      await _vendors.saveWorkspace(host.vendor.id, host.workspace);
      return next;
    });
  }

  @override
  Future<AppResult<VendorQuote>> submitVendorQuote(String id) {
    return AppwriteService.guard(() async {
      final host = await _vendors.findQuoteHost(id);
      if (host == null) throw AppwriteException('Quote not found', 404);
      final index = host.workspace.quotes.indexWhere((item) => item.id == id);
      final current = host.workspace.quotes[index];
      if (current.status != VendorQuoteStatus.draft) throw AppwriteException('Quote already submitted', 400);
      final next = VendorQuote(
        id: current.id,
        rfqId: current.rfqId,
        vendorId: current.vendorId,
        quoteNumber: current.quoteNumber,
        items: current.items,
        subtotal: current.subtotal,
        taxRate: current.taxRate,
        taxAmount: current.taxAmount,
        total: current.total,
        validUntil: current.validUntil,
        deliveryDays: current.deliveryDays,
        notes: current.notes,
        status: VendorQuoteStatus.submitted,
        submittedAt: DateTime.now().toUtc(),
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.quotes[index] = next;
      await _vendors.saveWorkspace(host.vendor.id, host.workspace);
      final rfq = await _rfqs.getById(current.rfqId);
      final rIndex = rfq.workspace.recipients.indexWhere((item) => item.vendorId == current.vendorId);
      if (rIndex >= 0) {
        final recipient = rfq.workspace.recipients[rIndex];
        rfq.workspace.recipients[rIndex] = RFQRecipient(
          id: recipient.id,
          rfqId: recipient.rfqId,
          vendorId: recipient.vendorId,
          invitedAt: recipient.invitedAt,
          respondedAt: DateTime.now().toUtc(),
          status: RFQRecipientStatus.responded,
          createdAt: recipient.createdAt,
        );
      }
      final status = rfq.rfq.status == RFQStatus.sent ? RFQStatus.receiving : rfq.rfq.status;
      await _rfqs.saveWorkspace(current.rfqId, rfq.workspace, rfqPatch: {'status': status.value});
      await _audit.log(userId: _actorId(), action: 'vendor_quote_submitted', metadata: {'id': id, 'rfqId': current.rfqId});
      await AppNotifications.instance.showImmediate(title: 'Quote submitted', body: current.quoteNumber);
      return next;
    });
  }

  Future<List<String>> _vendorUserIds(List<String> vendorIds) async {
    final ids = <String>[];
    for (final vendorId in vendorIds) {
      try {
        final vendor = (await _vendors.getById(vendorId)).vendor;
        if (vendor.userId != null && vendor.userId!.isNotEmpty) ids.add(vendor.userId!);
      } catch (_) {}
    }
    return ids;
  }

  Future<String> _nextNumber(String functionId, String prefix) async {
    try {
      final execution = await _functions.createExecution(functionId: functionId);
      final body = execution.responseBody.trim();
      final match = RegExp('$prefix-\\d{4}-\\d+').firstMatch(body);
      if (match != null) return match.group(0)!;
    } catch (_) {}
    return '$prefix-${DateTime.now().year}-draft';
  }

  String _fromSequence(String sequence, {required String prefix, required String fallback}) {
    final parsed = int.tryParse(sequence);
    if (parsed == null || parsed <= 0) return fallback;
    return '$prefix-${DateTime.now().year}-${parsed.toString().padLeft(4, '0')}';
  }
}
