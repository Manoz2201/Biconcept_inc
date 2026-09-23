import 'dart:async';
import 'dart:io';

import '../models/client_record.dart';
import '../models/estimate_document.dart';
import 'cloud_hooks.dart';
import 'json_disk.dart';

class ClientStore {
  Directory? overrideDirectory;
  final _disk = JsonDisk(
    relativePath: 'biconcept/clients',
    prefsPrefix: 'biconcept.clients.',
  );

  void _bind() => _disk.overrideDataDir = overrideDirectory;

  Future<void> save(ClientRecord client, {bool touch = true, bool syncToCloud = true}) async {
    if (touch) client.updatedAt = DateTime.now();
    _bind();
    await _disk.writeJson('${client.id}.json', client.toJson());
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
    _bind();
    final names = await _disk.listNames();
    final clients = <ClientRecord>[];
    for (final name in names) {
      try {
        final json = await _disk.readJson(name);
        if (json == null) continue;
        json['id'] = clientIdFromJson(json) ?? _idFromName(name);
        clients.add(ClientRecord.fromJson(json));
      } catch (_) {}
    }
    clients.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return clients;
  }

  String _idFromName(String name) {
    return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
  }

  Future<void> delete(String id, {bool syncToCloud = true}) async {
    _bind();
    await _disk.delete('$id.json');
    if (syncToCloud) {
      unawaited(CloudHooks.afterClientDelete?.call(id) ?? Future<void>.value());
    }
  }

  Future<int> mergeRemoteLeads(List<ClientRecord> remote) async {
    if (remote.isEmpty) return 0;
    final existing = await list();
    final ids = {for (final client in existing) client.id};
    final emails = {
      for (final client in existing)
        if (client.email.trim().isNotEmpty) client.email.trim().toLowerCase(): client,
    };
    var added = 0;
    for (final lead in remote) {
      final email = lead.email.trim().toLowerCase();
      ClientRecord? match;
      if (ids.contains(lead.id)) {
        for (final item in existing) {
          if (item.id == lead.id) {
            match = item;
            break;
          }
        }
      } else if (email.isNotEmpty) {
        match = emails[email];
      }
      if (match != null) {
        var changed = false;
        if (match.phone.trim().isEmpty && lead.phone.trim().isNotEmpty) {
          match.phone = lead.phone.trim();
          changed = true;
        }
        if (match.email.trim().isEmpty && lead.email.trim().isNotEmpty) {
          match.email = lead.email.trim();
          changed = true;
        }
        if (match.project.trim().isEmpty && lead.project.trim().isNotEmpty) {
          match.project = lead.project.trim();
          changed = true;
        }
        if (changed) await save(match, touch: false, syncToCloud: false);
        continue;
      }
      await save(lead, syncToCloud: false);
      ids.add(lead.id);
      if (email.isNotEmpty) emails[email] = lead;
      added++;
    }
    return added;
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
