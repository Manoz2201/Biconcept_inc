import 'dart:convert';

import '../models/company_profile.dart';
import 'local_cache.dart';

const backupCsvFormat = 'biconcept-localcache-v1';

class CacheBackupData {
  const CacheBackupData({required this.prefs, required this.overlay});

  final AppPrefsCache prefs;
  final Map<String, dynamic> overlay;
}

String encodeCacheBackupCsv({
  required AppPrefsCache prefs,
  required Map<String, dynamic> overlay,
  DateTime? exportedAt,
}) {
  final rows = <List<String>>[
    ['section', 'key', 'value'],
    ['meta', 'format', backupCsvFormat],
    ['meta', 'exportedAt', (exportedAt ?? DateTime.now()).toIso8601String()],
    ['prefs', 'brand', prefs.brand],
    ['prefs', 'companyAddress', prefs.companyAddress],
    ['prefs', 'companyPhone', prefs.companyPhone],
    ['prefs', 'gstPercent', prefs.gstPercent.toString()],
    ['prefs', 'hvacGstPercent', prefs.hvacGstPercent.toString()],
    ['prefs', 'lastClient', prefs.lastClient],
    ['prefs', 'lastProject', prefs.lastProject],
    ['prefs', 'lastCarpetArea', prefs.lastCarpetArea?.toString() ?? ''],
    ['prefs', 'recentAreaNames', prefs.recentAreaNames.join('|')],
    ['prefs', 'recentWorkTypeIds', prefs.recentWorkTypeIds.join('|')],
    ['prefs', 'recentScopeIds', prefs.recentScopeIds.join('|')],
  ];

  void addJsonRows(String section, Object? list) {
    if (list is! List) return;
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final key = map['id']?.toString() ?? '';
      rows.add([section, key, jsonEncode(map)]);
    }
  }

  addJsonRows('area', overlay['areas']);
  addJsonRows('workType', overlay['workTypes']);
  addJsonRows('scope', overlay['scopes']);

  return '${rows.map(_csvRow).join('\n')}\n';
}

CacheBackupData decodeCacheBackupCsv(String raw) {
  final text = raw.replaceFirst(RegExp(r'^\uFEFF'), '');
  final table = parseCsv(text);
  if (table.isEmpty) {
    throw const FormatException('Backup CSV is empty');
  }
  final header = table.first.map((cell) => cell.trim().toLowerCase()).toList();
  final sectionIdx = header.indexOf('section');
  final keyIdx = header.indexOf('key');
  final valueIdx = header.indexOf('value');
  if (sectionIdx < 0 || keyIdx < 0 || valueIdx < 0) {
    throw const FormatException('Backup CSV must have section, key and value columns');
  }

  final prefsMap = <String, String>{};
  final areas = <Map<String, dynamic>>[];
  final workTypes = <Map<String, dynamic>>[];
  final scopes = <Map<String, dynamic>>[];
  var sawFormat = false;

  for (var i = 1; i < table.length; i++) {
    final row = table[i];
    if (row.every((cell) => cell.trim().isEmpty)) continue;
    final section = (sectionIdx < row.length ? row[sectionIdx] : '').trim();
    final key = (keyIdx < row.length ? row[keyIdx] : '').trim();
    final value = valueIdx < row.length ? row[valueIdx] : '';
    switch (section) {
      case 'meta':
        if (key == 'format' && value.trim().isNotEmpty) {
          if (value.trim() != backupCsvFormat) {
            throw FormatException('Unsupported backup format: $value');
          }
          sawFormat = true;
        }
      case 'prefs':
        prefsMap[key] = value;
      case 'area':
        areas.add(_decodeJsonMap(value));
      case 'workType':
        workTypes.add(_decodeJsonMap(value));
      case 'scope':
        scopes.add(_decodeJsonMap(value));
    }
  }

  if (!sawFormat) {
    throw const FormatException('This CSV is not a BiConcept LocalCache backup');
  }

  return CacheBackupData(
    prefs: AppPrefsCache(
      brand: _pref(prefsMap, 'brand', defaultCompanyBrand),
      companyAddress: _pref(prefsMap, 'companyAddress', defaultCompanyAddress),
      companyPhone: _pref(prefsMap, 'companyPhone', defaultCompanyPhone),
      gstPercent: double.tryParse(prefsMap['gstPercent'] ?? '') ?? 18,
      hvacGstPercent: double.tryParse(prefsMap['hvacGstPercent'] ?? '') ?? 28,
      lastClient: prefsMap['lastClient'] ?? '',
      lastProject: prefsMap['lastProject'] ?? '',
      lastCarpetArea: double.tryParse(prefsMap['lastCarpetArea'] ?? ''),
      recentAreaNames: _splitList(prefsMap['recentAreaNames']),
      recentWorkTypeIds: _splitList(prefsMap['recentWorkTypeIds']),
      recentScopeIds: _splitList(prefsMap['recentScopeIds']),
    ),
    overlay: {
      'areas': areas,
      'workTypes': workTypes,
      'scopes': scopes,
    },
  );
}

Future<CacheBackupData> loadCacheBackup() async {
  return CacheBackupData(
    prefs: await LocalCache.instance.loadPrefs(),
    overlay: await LocalCache.instance.loadCatalogOverlay(),
  );
}

Future<void> restoreCacheBackup(CacheBackupData data) async {
  await LocalCache.instance.savePrefs(data.prefs);
  await LocalCache.instance.saveCatalogOverlay(data.overlay);
}

List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        quoted = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      quoted = true;
      i++;
      continue;
    }
    if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
      i++;
      continue;
    }
    if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((item) => item.isNotEmpty)) rows.add(row);
      row = <String>[];
      i++;
      continue;
    }
    cell.write(ch);
    i++;
  }
  if (quoted) {
    throw const FormatException('Backup CSV has an unclosed quote');
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((item) => item.isNotEmpty)) rows.add(row);
  }
  return rows;
}

String _csvRow(List<String> cells) => cells.map(_csvCell).join(',');

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Map<String, dynamic> _decodeJsonMap(String value) {
  final decoded = jsonDecode(value);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('Backup CSV has a value that is not a JSON object');
}

String _pref(Map<String, String> prefs, String key, String fallback) {
  final value = prefs[key]?.trim();
  return (value == null || value.isEmpty) ? fallback : value;
}

List<String> _splitList(String? value) {
  if (value == null || value.trim().isEmpty) return [];
  return [
    for (final item in value.split('|'))
      if (item.trim().isNotEmpty) item.trim(),
  ];
}
