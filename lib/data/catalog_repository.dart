import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../models/terms_and_conditions.dart';
import 'local_cache.dart';

class CatalogRepository extends ChangeNotifier {
  CatalogRepository._();

  static final CatalogRepository instance = CatalogRepository._();

  EstimateCatalog? _cache;
  EstimateCatalog? get catalog => _cache;
  Map<String, List<ScopeSample>> _samplesByScope = {};
  DateTime? lastCatalogSave;
  String? lastCachePath;

  Future<EstimateCatalog> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/estimate_catalog.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('estimate_catalog.json is not an object');
    }
    final catalog = EstimateCatalog.fromJson(decoded);
    catalog.termsTemplates = await _loadTermsTemplates();
    await _mergeCache(catalog);
    _indexSamples(catalog);
    _cache = catalog;
    try {
      lastCachePath = await LocalCache.instance.catalogPath();
    } catch (_) {
      lastCachePath = null;
    }
    return catalog;
  }

  Future<List<TermsTemplate>> _loadTermsTemplates() async {
    try {
      final raw = await rootBundle.loadString('assets/data/terms_templates.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List<TermsTemplate>.from(builtInTermsTemplates);
      final templates = [
        for (final item in decoded)
          if (item is Map<String, dynamic>) TermsTemplate.fromJson(item),
      ].where((item) => item.id.isNotEmpty && item.termsAndConditions.isNotEmpty).toList();
      return templates.isEmpty ? List<TermsTemplate>.from(builtInTermsTemplates) : templates;
    } catch (_) {
      return List<TermsTemplate>.from(builtInTermsTemplates);
    }
  }

  Future<void> reload() async {
    _cache = null;
    await load();
    notifyListeners();
  }

  Future<void> _mergeCache(EstimateCatalog catalog) async {
    try {
      final overlay = await LocalCache.instance.loadCatalogOverlay();
      catalog.applyOverlay(overlay);
      final savedAt = DateTime.tryParse(overlay['savedAt']?.toString() ?? '');
      lastCatalogSave = savedAt;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final catalog = _cache;
    if (catalog == null) return;
    await LocalCache.instance.saveCatalogOverlay(catalog.overlayJson());
    lastCatalogSave = DateTime.now();
    try {
      lastCachePath = await LocalCache.instance.catalogPath();
    } catch (_) {}
  }

  void _indexSamples(EstimateCatalog catalog) {
    _samplesByScope = {
      for (final scope in catalog.allScopes()) scope.id: scope.samples,
    };
  }

  Map<String, List<ScopeSample>> get samplesByScope => _samplesByScope;

  List<ScopeSample> samplesFor(String scopeId) => _samplesByScope[scopeId] ?? const [];

  int get cachedAreaCount => _cache?.areas.where((item) => item.userAdded).length ?? 0;

  int get cachedWorkTypeCount => _cache?.workTypes.where((item) => item.userAdded).length ?? 0;

  int get cachedScopeCount =>
      _cache?.allScopes().where((item) => item.persistInCache).length ?? 0;

  List<CatalogArea> get cachedAreas => [
        if (_cache != null)
          for (final area in _cache!.areas)
            if (area.userAdded) area,
      ];

  List<WorkTypeSummary> get cachedWorkTypes => [
        if (_cache != null)
          for (final type in _cache!.workTypes)
            if (type.userAdded) type,
      ];

  List<WorkScope> get cachedScopes => [
        if (_cache != null)
          for (final scope in _cache!.allScopes())
            if (scope.persistInCache) scope,
      ];

  Future<CatalogArea> addArea({
    required String name,
    List<String> typicalWorkTypes = const [],
  }) async {
    final catalog = await load();
    final area = catalog.addArea(name: name, typicalWorkTypes: typicalWorkTypes);
    await LocalCache.instance.updatePrefs((prefs) {
      LocalCache.instance.rememberId(prefs.recentAreaNames, area.name);
    });
    await _persist();
    notifyListeners();
    return area;
  }

  Future<WorkTypeSummary> addWorkType({
    required String name,
    int? serialNo,
  }) async {
    final catalog = await load();
    final type = catalog.addWorkType(name: name, serialNo: serialNo);
    await LocalCache.instance.updatePrefs((prefs) {
      LocalCache.instance.rememberId(prefs.recentWorkTypeIds, type.id);
    });
    await _persist();
    notifyListeners();
    return type;
  }

  Future<WorkScope> addScope({
    required String workTypeId,
    required String name,
    String description = '',
    String unit = 'sqft',
    double? suggestedRate,
    double? minRate,
    double? maxRate,
    String? code,
    List<String> typicalAreas = const [],
  }) async {
    final catalog = await load();
    final scope = catalog.addScope(
      workTypeId: workTypeId,
      name: name,
      description: description,
      unit: unit,
      suggestedRate: suggestedRate,
      minRate: minRate,
      maxRate: maxRate,
      code: code,
      typicalAreas: typicalAreas,
    );
    _indexSamples(catalog);
    await LocalCache.instance.updatePrefs((prefs) {
      LocalCache.instance.rememberId(prefs.recentScopeIds, scope.id);
      for (final area in typicalAreas) {
        LocalCache.instance.rememberId(prefs.recentAreaNames, area);
      }
    });
    await _persist();
    notifyListeners();
    return scope;
  }

  Future<WorkScope> updateScope({
    required String scopeId,
    String? unit,
    double? suggestedRate,
    double? minRate,
    double? maxRate,
    String? description,
  }) async {
    final catalog = await load();
    final scope = catalog.updateScope(
      scopeId: scopeId,
      unit: unit,
      suggestedRate: suggestedRate,
      minRate: minRate,
      maxRate: maxRate,
      description: description,
    );
    await LocalCache.instance.updatePrefs((prefs) {
      LocalCache.instance.rememberId(prefs.recentScopeIds, scope.id);
    });
    await _persist();
    notifyListeners();
    return scope;
  }

  Future<void> rememberEstimateSelection({
    required Iterable<String> areaNames,
    required Iterable<String> workTypeIds,
    required Iterable<String> scopeIds,
    String? client,
    String? project,
    double? carpetArea,
  }) async {
    await LocalCache.instance.updatePrefs((prefs) {
      for (final area in areaNames) {
        LocalCache.instance.rememberId(prefs.recentAreaNames, area);
      }
      for (final id in workTypeIds) {
        LocalCache.instance.rememberId(prefs.recentWorkTypeIds, id);
      }
      for (final id in scopeIds) {
        LocalCache.instance.rememberId(prefs.recentScopeIds, id);
      }
      if (client != null && client.trim().isNotEmpty) prefs.lastClient = client.trim();
      if (project != null) prefs.lastProject = project.trim();
      if (carpetArea != null) prefs.lastCarpetArea = carpetArea;
    });
  }

  List<WorkScope> searchScopes(
    EstimateCatalog catalog, {
    String? workType,
    String? query,
    int limit = 8,
  }) {
    var scopes = catalog.allScopes();
    if (workType != null && workType.trim().isNotEmpty) {
      final needle = workType.toLowerCase();
      scopes = scopes
          .where(
            (scope) =>
                scope.workType.toLowerCase().contains(needle) ||
                scope.workTypeId.toLowerCase().contains(needle),
          )
          .toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      scopes = scopes.where((scope) => scope.matches(query)).toList();
    }
    scopes.sort((a, b) => b.sampleCount.compareTo(a.sampleCount));
    if (scopes.length > limit) return scopes.take(limit).toList();
    return scopes;
  }

  Map<String, dynamic> scopePayload(WorkScope scope) => {
        'id': scope.id,
        'workType': scope.workType,
        'code': scope.code,
        'name': scope.name,
        'description': scope.description,
        'unit': scope.unit,
        'suggestedRate': scope.suggestedRate,
        'minRate': scope.minRate,
        'maxRate': scope.maxRate,
        'sampleCount': scope.sampleCount,
        'typicalAreas': scope.typicalAreas,
        'aliases': scope.aliases,
      };

  List<Map<String, dynamic>> similarLineItems(String scopeId, {int limit = 6}) {
    final samples = samplesFor(scopeId).take(limit);
    return [
      for (final sample in samples)
        {
          'quotationId': sample.quotationId,
          'area': sample.area,
          'quantity': sample.quantity,
          'unitRate': sample.unitRate,
          'amount': sample.amount,
        },
    ];
  }

  double? suggestedQuantityFor(WorkScope scope, {double? carpetArea, String? area}) {
    return suggestQuantity(scope: scope, carpetArea: carpetArea, area: area);
  }
}
