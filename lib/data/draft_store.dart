import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/estimate_document.dart';

class DraftStore {
  Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/biconcept/estimates');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String id) async {
    final dir = await _dir();
    return File('${dir.path}/$id.json');
  }

  Future<void> save(EstimateDraft draft) async {
    final file = await _file(draft.id);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(draft.toJson()));
  }

  Future<EstimateDraft?> load(String id) async {
    final file = await _file(id);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return null;
    return EstimateDraft.fromJson(decoded);
  }

  Future<List<EstimateDraft>> list() async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().where((file) => file.path.endsWith('.json'));
    final drafts = <EstimateDraft>[];
    for (final file in files) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          drafts.add(EstimateDraft.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {}
    }
    drafts.sort((a, b) => b.date.compareTo(a.date));
    return drafts;
  }

  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
