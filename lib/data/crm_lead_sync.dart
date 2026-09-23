import 'package:appwrite/appwrite.dart';

import '../core/appwrite/appwrite_client.dart';
import '../features/enquiries/domain/enquiry.dart';
import '../models/client_record.dart';
import 'appwrite_sync.dart';

String portalLeadRowId(String accountId) {
  final cleaned = accountId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final id = 'lead_$cleaned';
  return id.length <= 36 ? id : id.substring(0, 36);
}

ClientRecord clientRecordFromPortal({
  required String accountId,
  required String name,
  required String email,
  String? phone,
  required String title,
  required String description,
}) {
  return ClientRecord(
    id: portalLeadRowId(accountId),
    name: name.trim().isEmpty ? email.trim() : name.trim(),
    email: email.trim(),
    phone: phone?.trim() ?? '',
    project: title.trim(),
    source: 'client_portal',
    stage: CrmStage.lead,
    notes: description.trim(),
  );
}

class CrmLeadSync {
  CrmLeadSync({TablesDB? tables, String? databaseId})
      : _tables = tables ?? AppwriteService.tables,
        _databaseId = databaseId ?? AppwriteService.dbId;

  final TablesDB _tables;
  final String _databaseId;

  Future<void> upsertPortalLead(ClientRecord lead) async {
    try {
      await _tables.createRow(
        databaseId: _databaseId,
        tableId: appwriteClientsTableId,
        rowId: lead.id,
        data: clientToAppwriteRow(lead),
      );
    } on AppwriteException catch (error) {
      if (error.code != 409) rethrow;
    }
  }

  Future<List<ClientRecord>> pullStaffLeads() async {
    final byKey = <String, ClientRecord>{};
    void add(ClientRecord client) {
      if (client.name.trim().isEmpty && client.email.trim().isEmpty) return;
      final key = client.email.trim().isNotEmpty
          ? 'e:${client.email.trim().toLowerCase()}'
          : client.phone.trim().isNotEmpty
              ? 'p:${client.phone.trim()}'
              : 'i:${client.id}';
      byKey.putIfAbsent(key, () => client);
    }

    try {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: appwriteClientsTableId,
        queries: [Query.limit(100), Query.orderDesc('updatedAt')],
      );
      for (final row in page.rows) {
        add(clientFromAppwriteRow(row.data, rowId: row.$id));
      }
    } catch (_) {}

    try {
      final users = <String, Map<String, dynamic>>{};
      final userPage = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.usersCol,
        queries: [Query.equal('role', 'client'), Query.limit(100)],
      );
      for (final row in userPage.rows) {
        final accountId = row.data['accountId']?.toString() ?? '';
        if (accountId.isNotEmpty) users[accountId] = row.data;
      }
      final requests = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        queries: [Query.limit(100), Query.orderDesc('createdAt')],
      );
      for (final row in requests.rows) {
        final clientId = row.data['clientId']?.toString() ?? '';
        final profile = users[clientId];
        add(
          clientRecordFromPortal(
            accountId: clientId.isEmpty ? row.$id : clientId,
            name: profile?['name']?.toString() ?? '',
            email: profile?['email']?.toString() ?? '',
            phone: profile?['phone']?.toString(),
            title: row.data['title']?.toString() ?? '',
            description: row.data['description']?.toString() ?? '',
          ),
        );
      }
    } catch (_) {}

    try {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.enquiriesCol,
        queries: [Query.limit(100), Query.orderDesc('createdAt')],
      );
      for (final row in page.rows) {
        final enquiry = Enquiry.fromRow(row.$id, row.data);
        add(
          ClientRecord(
            id: 'enq_${enquiry.id}',
            name: enquiry.name,
            email: enquiry.email,
            phone: enquiry.phone ?? '',
            project: enquiry.message.split('\n').first.trim(),
            source: enquiry.source ?? 'website',
            stage: CrmStage.lead,
            notes: enquiry.message,
            createdAt: enquiry.createdAt,
            updatedAt: enquiry.updatedAt ?? enquiry.createdAt,
          ),
        );
      }
    } catch (_) {}

    return byKey.values.toList();
  }
}
