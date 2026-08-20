import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/company_profile.dart';
import 'cloud_hooks.dart';

class AppPrefsCache {
  AppPrefsCache({
    this.brand = defaultCompanyBrand,
    this.companyAddress = defaultCompanyAddress,
    this.companyPhone = defaultCompanyPhone,
    this.gstPercent = 18,
    this.hvacGstPercent = 28,
    List<String>? recentAreaNames,
    List<String>? recentWorkTypeIds,
    List<String>? recentScopeIds,
    this.lastClient = '',
    this.lastProject = '',
    this.lastCarpetArea,
    this.cfAccountId = '',
    this.cfApiToken = '',
    this.githubRepo = '',
    this.githubToken = '',
    this.savedAt,
  })  : recentAreaNames = recentAreaNames ?? <String>[],
        recentWorkTypeIds = recentWorkTypeIds ?? <String>[],
        recentScopeIds = recentScopeIds ?? <String>[];

  String brand;
  String companyAddress;
  String companyPhone;
  double gstPercent;
  double hvacGstPercent;
  List<String> recentAreaNames;
  List<String> recentWorkTypeIds;
  List<String> recentScopeIds;
  String lastClient;
  String lastProject;
  double? lastCarpetArea;
  String cfAccountId;
  String cfApiToken;
  String githubRepo;
  String githubToken;
  DateTime? savedAt;

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'companyAddress': companyAddress,
        'companyPhone': companyPhone,
        'gstPercent': gstPercent,
        'hvacGstPercent': hvacGstPercent,
        'recentAreaNames': recentAreaNames,
        'recentWorkTypeIds': recentWorkTypeIds,
        'recentScopeIds': recentScopeIds,
        'lastClient': lastClient,
        'lastProject': lastProject,
        'lastCarpetArea': lastCarpetArea,
        'cfAccountId': cfAccountId,
        'cfApiToken': cfApiToken,
        'githubRepo': githubRepo,
        'githubToken': githubToken,
        'savedAt': savedAt?.toIso8601String(),
      };

  factory AppPrefsCache.fromJson(Map<String, dynamic> json) {
    return AppPrefsCache(
      brand: json['brand']?.toString() ?? defaultCompanyBrand,
      companyAddress: json['companyAddress']?.toString() ?? defaultCompanyAddress,
      companyPhone: json['companyPhone']?.toString() ?? defaultCompanyPhone,
      gstPercent: (json['gstPercent'] as num?)?.toDouble() ?? 18,
      hvacGstPercent: (json['hvacGstPercent'] as num?)?.toDouble() ?? 28,
      recentAreaNames: _strings(json['recentAreaNames']),
      recentWorkTypeIds: _strings(json['recentWorkTypeIds']),
      recentScopeIds: _strings(json['recentScopeIds']),
      lastClient: json['lastClient']?.toString() ?? '',
      lastProject: json['lastProject']?.toString() ?? '',
      lastCarpetArea: (json['lastCarpetArea'] as num?)?.toDouble(),
      cfAccountId: json['cfAccountId']?.toString() ?? '',
      cfApiToken: json['cfApiToken']?.toString() ?? '',
      githubRepo: json['githubRepo']?.toString() ?? '',
      githubToken: json['githubToken']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? ''),
    );
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return [];
    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString(),
    ];
  }
}

class LocalCache {
  LocalCache._();

  static final LocalCache instance = LocalCache._();

  Directory? overrideDirectory;
  AppPrefsCache? _prefs;

  static const _encoder = JsonEncoder.withIndent('  ');

  Future<Directory> directory() async {
    if (overrideDirectory != null) {
      if (!await overrideDirectory!.exists()) {
        await overrideDirectory!.create(recursive: true);
      }
      return overrideDirectory!;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/biconcept/cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> catalogFile() async => File('${(await directory()).path}/catalog_cache.json');

  Future<File> prefsFile() async => File('${(await directory()).path}/prefs_cache.json');

  Future<File> _legacyOverlayFile() async {
    final root = await getApplicationDocumentsDirectory();
    return File('${root.path}/biconcept/catalog_overlay.json');
  }

  Future<File> _documentsBackupFile() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/biconcept/cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/catalog_cache.json');
  }

  Future<void> _writeJson(File file, Map<String, dynamic> json) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(_encoder.convert(json), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await file.writeAsBytes(await tmp.readAsBytes(), flush: true);
      if (await tmp.exists()) await tmp.delete();
    }
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<Map<String, dynamic>> loadCatalogOverlay() async {
    final files = <File>[
      await catalogFile(),
      if (overrideDirectory == null) ...[
        await _documentsBackupFile(),
        await _legacyOverlayFile(),
      ],
    ];
    for (final file in files) {
      try {
        final json = await _readJson(file);
        if (json != null) return json;
      } catch (_) {}
    }
    return {'areas': [], 'workTypes': [], 'scopes': []};
  }

  Future<void> saveCatalogOverlay(Map<String, dynamic> overlay, {bool syncToCloud = true}) async {
    final payload = {
      ...overlay,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await _writeJson(await catalogFile(), payload);
    if (overrideDirectory != null) return;
    try {
      await _writeJson(await _documentsBackupFile(), payload);
    } catch (_) {}
    try {
      await _writeJson(await _legacyOverlayFile(), payload);
    } catch (_) {}
    if (syncToCloud) {
      unawaited(CloudHooks.afterCatalogSave?.call(payload) ?? Future<void>.value());
    }
  }

  Future<AppPrefsCache> loadPrefs() async {
    if (_prefs != null) return _prefs!;
    try {
      final json = await _readJson(await prefsFile());
      _prefs = json == null ? AppPrefsCache() : AppPrefsCache.fromJson(json);
    } catch (_) {
      _prefs = AppPrefsCache();
    }
    return _prefs!;
  }

  Future<void> savePrefs(AppPrefsCache prefs, {bool syncToCloud = true}) async {
    prefs.savedAt = DateTime.now();
    _prefs = prefs;
    await _writeJson(await prefsFile(), prefs.toJson());
    unawaited(CloudHooks.afterPrefsApplied?.call(prefs.toJson()) ?? Future<void>.value());
    if (syncToCloud) {
      unawaited(CloudHooks.afterPrefsSave?.call(prefs.toJson()) ?? Future<void>.value());
    }
  }

  Future<AppPrefsCache> updatePrefs(void Function(AppPrefsCache prefs) update) async {
    final prefs = await loadPrefs();
    update(prefs);
    await savePrefs(prefs);
    return prefs;
  }

  void rememberId(List<String> list, String value, {int limit = 24}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    if (list.length > limit) list.removeRange(limit, list.length);
  }

  Future<String> catalogPath() async => (await catalogFile()).path;

  void clearMemory() {
    _prefs = null;
  }
}
