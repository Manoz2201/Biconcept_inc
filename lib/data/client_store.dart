import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/client_record.dart';
import '../models/estimate_document.dart';
import 'cloud_hooks.dart';

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

  Future<void> save(ClientRecord client, {bool touch = true, bool syncToCloud = true}) async {
    if (touch) client.updatedAt = DateTime.now();
    final file = await _file(client.id);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(client.toJson()));
    if (syncToCloud) {
      unawaited(CloudHooks.afterClientSave?.call(client) ?? Future<void>.value());
    }
  }

  Future<ClientRecord?> findByName(String name) async {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final client in await list()) {
      if (client.name.trim().toLowerCase() == needle) return client;
    }
    return null;
  }

  Future<List<ClientRecord>> list() async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().where((file) => file.path.endsWith('.json'));
    final clients = <ClientRecord>[];
    for (final file in files) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) continue;
        final json = Map<String, dynamic>.from(decoded);
        final fileId = _idFromFile(file);
        json['id'] = clientIdFromJson(json) ?? fileId;
        clients.add(ClientRecord.fromJson(json));
      } catch (_) {}
    }
    clients.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return clients;
  }

  String _idFromFile(File file) {
    final name = file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;
    return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
  }

  Future<void> delete(String id, {bool syncToCloud = true}) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
    if (syncToCloud) {
      unawaited(CloudHooks.afterClientDelete?.call(id) ?? Future<void>.value());
    }
  }

  Future<void> syncFromEstimates(List<EstimateDraft> drafts) async {
    final existing = await list();
    final byName = {
      for (final client in existing) client.name.trim().toLowerCase(): client,
    };
    for (final draft in drafts) {
      final name = draft.client.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final current = byName[key];
      if (current != null) {
        var changed = false;
        if (current.project.trim().isEmpty && draft.project.trim().isNotEmpty) {
          current.project = draft.project.trim();
          changed = true;
        }
        if (changed) await save(current, touch: false, syncToCloud: false);
        continue;
      }
      final created = ClientRecord(
        name: name,
        project: draft.project,
        stage: switch (draft.status) {
          EstimateStatus.finalized => CrmStage.won,
          EstimateStatus.completed => CrmStage.quotation,
          EstimateStatus.drafted => CrmStage.lead,
        },
      );
      byName[key] = created;
      await save(created);
    }
  }
}
