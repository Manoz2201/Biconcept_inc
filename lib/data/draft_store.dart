import 'dart:async';

import '../models/estimate_document.dart';
import 'cloud_hooks.dart';
import 'json_disk.dart';

class DraftStore {
  final _disk = JsonDisk(
    relativePath: 'biconcept/estimates',
    prefsPrefix: 'biconcept.estimates.',
  );

  Future<void> save(EstimateDraft draft, {bool syncToCloud = true}) async {
    await _disk.writeJson('${draft.id}.json', draft.toJson());
    if (syncToCloud) {
      unawaited(CloudHooks.afterEstimateSave?.call(draft) ?? Future<void>.value());
    }
  }

  Future<EstimateDraft?> load(String id) async {
    final decoded = await _disk.readJson('$id.json');
    if (decoded == null) return null;
    return EstimateDraft.fromJson(decoded);
  }

  Future<List<EstimateDraft>> list() async {
    final names = await _disk.listNames();
    final drafts = <EstimateDraft>[];
    for (final name in names) {
      try {
        final decoded = await _disk.readJson(name);
        if (decoded != null) drafts.add(EstimateDraft.fromJson(decoded));
      } catch (_) {}
    }
    drafts.sort((a, b) => b.date.compareTo(a.date));
    return drafts;
  }

  Future<void> delete(String id, {bool syncToCloud = true}) async {
    await _disk.delete('$id.json');
    if (syncToCloud) {
      unawaited(CloudHooks.afterEstimateDelete?.call(id) ?? Future<void>.value());
    }
  }
}
