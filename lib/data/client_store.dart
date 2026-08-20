import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/client_record.dart';
import '../models/estimate_document.dart';

class ClientStore {
  Directory? overrideDirectory;

  Future<Directory> _dir() async {
    final root = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/biconcept/clients');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String id) async {
    final dir = await _dir();
    return File('${dir.path}/$id.json');
  }

  Future<void> save(ClientRecord client, {bool touch = true}) async {
    if (touch) client.updatedAt = DateTime.now();
    final file = await _file(client.id);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(client.toJson()));
  }

  Future<List<ClientRecord>> list() async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().where((file) => file.path.endsWith('.json'));
    final clients = <ClientRecord>[];
    for (final file in files) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          clients.add(ClientRecord.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {}
    }
    clients.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return clients;
  }

  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }

  Future<void> syncFromEstimates(List<EstimateDraft> drafts) async {
    final existing = await list();
    final names = {
      for (final client in existing) client.name.trim().toLowerCase(),
    };
    for (final draft in drafts) {
      final name = draft.client.trim();
      if (name.isEmpty || names.contains(name.toLowerCase())) continue;
      names.add(name.toLowerCase());
      await save(
        ClientRecord(
          name: name,
          project: draft.project,
          stage: switch (draft.status) {
            EstimateStatus.finalized => CrmStage.won,
            EstimateStatus.completed => CrmStage.quotation,
            EstimateStatus.drafted => CrmStage.lead,
          },
        ),
      );
    }
  }
}
