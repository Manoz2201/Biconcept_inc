import 'terms_and_conditions.dart';

double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> asStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  return [];
}

const catalogUnits = ['sqft', 'pcs', 'lumpsum', 'seat', 'rft', 'mtr', 'step'];

String catalogSlug(String name) {
  var slug = name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  slug = slug.replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? 'item' : slug;
}

String uniqueCatalogId({
  required String prefix,
  required String name,
  required bool Function(String id) exists,
}) {
  final slug = catalogSlug(name);
  var id = '${prefix}_$slug';
  var n = 2;
  while (exists(id)) {
    id = '${prefix}_${slug}_$n';
    n++;
  }
  return id;
}

class EstimateDefaults {
  const EstimateDefaults({
    required this.gstPercent,
    required this.hvacGstPercent,
    required this.currency,
    required this.amountFormula,
    required this.paymentTerms,
    required this.exclusions,
    required this.notes,
    this.termsAndConditions = const [],
  });

  final double gstPercent;
  final double hvacGstPercent;
  final String currency;
  final String amountFormula;
  final List<String> paymentTerms;
  final List<String> exclusions;
  final List<String> notes;
  final List<String> termsAndConditions;

  List<String> get effectiveTerms => effectiveTermsAndConditions(
        termsAndConditions: termsAndConditions,
        paymentTerms: paymentTerms,
        exclusions: exclusions,
        notes: notes,
      );

  factory EstimateDefaults.fromJson(Map<String, dynamic> json) {
    return EstimateDefaults(
      gstPercent: asDouble(json['gstPercent']) ?? 18,
      hvacGstPercent: asDouble(json['hvacGstPercent']) ?? 28,
      currency: json['currency']?.toString() ?? 'INR',
      amountFormula: json['amountFormula']?.toString() ?? 'quantity * unitRate',
      paymentTerms: asStringList(json['paymentTerms']),
      exclusions: asStringList(json['exclusions']),
      notes: asStringList(json['notes']),
      termsAndConditions: asStringList(json['termsAndConditions']),
    );
  }

  Map<String, dynamic> toJson() => {
        'gstPercent': gstPercent,
        'hvacGstPercent': hvacGstPercent,
        'currency': currency,
        'amountFormula': amountFormula,
        'paymentTerms': paymentTerms,
        'exclusions': exclusions,
        'notes': notes,
        'termsAndConditions': termsAndConditions,
      };
}

class ScopeSample {
  const ScopeSample({
    required this.quotationId,
    this.area,
    this.quantity,
    this.unitRate,
    this.amount,
  });

  final String quotationId;
  final String? area;
  final double? quantity;
  final double? unitRate;
  final double? amount;

  factory ScopeSample.fromJson(Map<String, dynamic> json) {
    return ScopeSample(
      quotationId: json['quotationId']?.toString() ?? '',
      area: json['area']?.toString(),
      quantity: asDouble(json['quantity']),
      unitRate: asDouble(json['unitRate']),
      amount: asDouble(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'quotationId': quotationId,
        'area': area,
        'quantity': quantity,
        'unitRate': unitRate,
        'amount': amount,
      };
}

class WorkScope {
  const WorkScope({
    required this.id,
    required this.workTypeId,
    required this.workType,
    required this.name,
    required this.description,
    required this.unit,
    required this.suggestedRate,
    required this.minRate,
    required this.maxRate,
    required this.sampleCount,
    required this.typicalAreas,
    required this.aliases,
    required this.makes,
    required this.samples,
    this.code,
    this.userAdded = false,
    this.userEdited = false,
  });

  final String id;
  final String workTypeId;
  final String workType;
  final String? code;
  final String name;
  final String description;
  final String unit;
  final double? suggestedRate;
  final double? minRate;
  final double? maxRate;
  final int sampleCount;
  final List<String> typicalAreas;
  final List<String> aliases;
  final List<String> makes;
  final List<ScopeSample> samples;
  final bool userAdded;
  final bool userEdited;

  bool get isPriced => suggestedRate != null;

  bool get persistInCache => userAdded || userEdited;

  bool matches(String query) {
    final q = query.toLowerCase();
    return workType.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        aliases.any((alias) => alias.toLowerCase().contains(q)) ||
        typicalAreas.any((area) => area.toLowerCase().contains(q));
  }

  factory WorkScope.fromJson(Map<String, dynamic> json) {
    return WorkScope(
      id: json['id']?.toString() ?? '',
      workTypeId: json['workTypeId']?.toString() ?? '',
      workType: json['workType']?.toString() ?? '',
      code: json['code']?.toString(),
      name: (json['name'] ?? json['workScope'])?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      suggestedRate: asDouble(json['suggestedRate']),
      minRate: asDouble(json['minRate']),
      maxRate: asDouble(json['maxRate']),
      sampleCount: asInt(json['sampleCount']),
      typicalAreas: asStringList(json['typicalAreas']),
      aliases: asStringList(json['aliases']),
      makes: asStringList(json['makes']),
      samples: [
        for (final item in json['samples'] as List? ?? const [])
          if (item is Map) ScopeSample.fromJson(Map<String, dynamic>.from(item)),
      ],
      userAdded: json['userAdded'] == true,
      userEdited: json['userEdited'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workTypeId': workTypeId,
        'workType': workType,
        'code': code,
        'name': name,
        'description': description,
        'unit': unit,
        'suggestedRate': suggestedRate,
        'minRate': minRate,
        'maxRate': maxRate,
        'sampleCount': sampleCount,
        'typicalAreas': typicalAreas,
        'aliases': aliases,
        'makes': makes,
        'samples': [for (final sample in samples) sample.toJson()],
        'userAdded': userAdded,
        'userEdited': userEdited,
      };

  WorkScope copyWith({
    String? unit,
    String? description,
    double? suggestedRate,
    double? minRate,
    double? maxRate,
    bool? userAdded,
    bool? userEdited,
  }) {
    return WorkScope(
      id: id,
      workTypeId: workTypeId,
      workType: workType,
      code: code,
      name: name,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      suggestedRate: suggestedRate ?? this.suggestedRate,
      minRate: minRate ?? this.minRate,
      maxRate: maxRate ?? this.maxRate,
      sampleCount: sampleCount,
      typicalAreas: typicalAreas,
      aliases: aliases,
      makes: makes,
      samples: samples,
      userAdded: userAdded ?? this.userAdded,
      userEdited: userEdited ?? this.userEdited,
    );
  }

  RateCardItem toRateCardItem() => RateCardItem(
        id: id,
        workType: workType,
        workScope: name,
        description: description,
        unit: unit,
        suggestedRate: suggestedRate,
        minRate: minRate,
        maxRate: maxRate,
        sampleCount: sampleCount,
        typicalAreas: typicalAreas,
        aliases: aliases,
        makes: makes,
      );
}

class RateCardItem {
  const RateCardItem({
    required this.id,
    required this.workType,
    required this.workScope,
    required this.description,
    required this.unit,
    required this.suggestedRate,
    required this.minRate,
    required this.maxRate,
    required this.sampleCount,
    required this.typicalAreas,
    required this.aliases,
    required this.makes,
  });

  final String id;
  final String workType;
  final String workScope;
  final String description;
  final String unit;
  final double? suggestedRate;
  final double? minRate;
  final double? maxRate;
  final int sampleCount;
  final List<String> typicalAreas;
  final List<String> aliases;
  final List<String> makes;

  factory RateCardItem.fromJson(Map<String, dynamic> json) {
    return RateCardItem(
      id: json['id']?.toString() ?? '',
      workType: json['workType']?.toString() ?? '',
      workScope: (json['workScope'] ?? json['name'])?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      suggestedRate: asDouble(json['suggestedRate']),
      minRate: asDouble(json['minRate']),
      maxRate: asDouble(json['maxRate']),
      sampleCount: asInt(json['sampleCount']),
      typicalAreas: asStringList(json['typicalAreas']),
      aliases: asStringList(json['aliases']),
      makes: asStringList(json['makes']),
    );
  }

  bool matches(String query) {
    final q = query.toLowerCase();
    return workType.toLowerCase().contains(q) ||
        workScope.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        aliases.any((alias) => alias.toLowerCase().contains(q)) ||
        typicalAreas.any((area) => area.toLowerCase().contains(q));
  }
}

class CatalogArea {
  const CatalogArea({
    required this.id,
    required this.name,
    required this.typicalWorkTypes,
    required this.typicalScopes,
    this.userAdded = false,
  });

  final String id;
  final String name;
  final List<String> typicalWorkTypes;
  final List<String> typicalScopes;
  final bool userAdded;

  factory CatalogArea.fromJson(Map<String, dynamic> json) {
    return CatalogArea(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      typicalWorkTypes: asStringList(json['typicalWorkTypes']),
      typicalScopes: asStringList(json['typicalScopes']),
      userAdded: json['userAdded'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'typicalWorkTypes': typicalWorkTypes,
        'typicalScopes': typicalScopes,
        'userAdded': userAdded,
      };
}

class WorkTypeSummary {
  const WorkTypeSummary({
    required this.id,
    required this.serialNo,
    required this.name,
    required this.areas,
    required this.scopes,
    this.userAdded = false,
  });

  final String id;
  final int serialNo;
  final String name;
  final List<String> areas;
  final List<WorkScope> scopes;
  final bool userAdded;

  int get scopeCount => scopes.length;

  bool get isFurniture => name.toLowerCase() == 'furniture';

  bool get isHvac => name.toLowerCase() == 'hvac';

  factory WorkTypeSummary.fromJson(Map<String, dynamic> json) {
    final scopes = [
      for (final item in json['scopes'] as List? ?? const [])
        if (item is Map) WorkScope.fromJson(Map<String, dynamic>.from(item)),
    ];
    return WorkTypeSummary(
      id: json['id']?.toString() ?? '',
      serialNo: asInt(json['serialNo']),
      name: json['name']?.toString() ?? '',
      areas: asStringList(json['areas']),
      scopes: scopes,
      userAdded: json['userAdded'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serialNo': serialNo,
        'name': name,
        'scopeCount': scopeCount,
        'areas': areas,
        'scopes': [for (final scope in scopes) scope.toJson()],
        'userAdded': userAdded,
      };
}

class QuotationSummary {
  const QuotationSummary({
    required this.id,
    required this.sourceSheet,
    required this.kind,
    required this.client,
    required this.project,
    required this.date,
    required this.itemCount,
    required this.grandTotal,
  });

  final String id;
  final String sourceSheet;
  final String kind;
  final String client;
  final String project;
  final String date;
  final int itemCount;
  final double? grandTotal;

  factory QuotationSummary.fromJson(Map<String, dynamic> json) {
    return QuotationSummary(
      id: json['id']?.toString() ?? '',
      sourceSheet: json['sourceSheet']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      client: json['client']?.toString() ?? '',
      project: json['project']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      itemCount: asInt(json['itemCount']),
      grandTotal: asDouble(json['grandTotal']),
    );
  }
}

class EstimateCatalog {
  EstimateCatalog({
    required this.defaults,
    required this.workTypes,
    required this.areas,
    required this.rateCard,
    required this.quotations,
    List<TermsTemplate>? termsTemplates,
  }) : termsTemplates = termsTemplates ?? List<TermsTemplate>.from(builtInTermsTemplates);

  final EstimateDefaults defaults;
  final List<WorkTypeSummary> workTypes;
  final List<CatalogArea> areas;
  final List<RateCardItem> rateCard;
  final List<QuotationSummary> quotations;
  List<TermsTemplate> termsTemplates;

  factory EstimateCatalog.fromJson(Map<String, dynamic> json) {
    final defaultsJson = json['defaults'];
    final workTypes = [
      for (final item in json['workTypes'] as List? ?? const [])
        if (item is Map<String, dynamic>) WorkTypeSummary.fromJson(item),
    ]..sort((a, b) => a.serialNo.compareTo(b.serialNo));

    var rateCard = [
      for (final item in json['rateCard'] as List? ?? const [])
        if (item is Map<String, dynamic>) RateCardItem.fromJson(item),
    ];
    if (rateCard.isEmpty) {
      rateCard = [
        for (final type in workTypes)
          for (final scope in type.scopes) scope.toRateCardItem(),
      ];
    }

    return EstimateCatalog(
      defaults: defaultsJson is Map<String, dynamic>
          ? EstimateDefaults.fromJson(defaultsJson)
          : EstimateDefaults.fromJson(<String, dynamic>{}),
      workTypes: workTypes,
      areas: [
        for (final item in json['areas'] as List? ?? const [])
          if (item is Map<String, dynamic>) CatalogArea.fromJson(item),
      ],
      rateCard: rateCard,
      quotations: [
        for (final item in json['quotations'] as List? ?? const [])
          if (item is Map<String, dynamic>) QuotationSummary.fromJson(item),
      ],
    );
  }

  List<String> get workTypeNames => [
        'All',
        ...{for (final item in workTypes) item.name},
      ];

  WorkTypeSummary? workTypeById(String id) {
    for (final type in workTypes) {
      if (type.id == id || type.name == id) return type;
    }
    return null;
  }

  WorkScope? scopeById(String id) {
    for (final type in workTypes) {
      for (final scope in type.scopes) {
        if (scope.id == id) return scope;
      }
    }
    return null;
  }

  List<WorkScope> allScopes() => [
        for (final type in workTypes) ...type.scopes,
      ];

  List<WorkScope> typicalScopes({
    required WorkTypeSummary type,
    String? area,
    int limit = 8,
  }) {
    var scopes = type.scopes.where((scope) => scope.isPriced || scope.userAdded).toList();
    if (area != null) {
      final matched = scopes
          .where((scope) => scope.typicalAreas.any((name) => name == area))
          .toList();
      if (matched.isNotEmpty) scopes = matched;
    }
    scopes.sort((a, b) => b.sampleCount.compareTo(a.sampleCount));
    if (scopes.length > limit) return scopes.take(limit).toList();
    return scopes;
  }

  bool usesAreas(WorkTypeSummary type) {
    if (type.isFurniture) return true;
    return type.scopes.any((scope) => scope.typicalAreas.isNotEmpty);
  }

  CatalogArea? areaByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final area in areas) {
      if (area.name.toLowerCase() == needle) return area;
    }
    return null;
  }

  void rebuildRateCard() {
    rateCard
      ..clear()
      ..addAll([
        for (final type in workTypes)
          for (final scope in type.scopes) scope.toRateCardItem(),
      ]);
  }

  void applyOverlay(Map<String, dynamic> overlay) {
    for (final item in overlay['areas'] as List? ?? const []) {
      if (item is! Map) continue;
      final area = CatalogArea.fromJson({...Map<String, dynamic>.from(item), 'userAdded': true});
      if (area.name.trim().isEmpty) continue;
      if (areaByName(area.name) != null) continue;
      if (areas.any((existing) => existing.id == area.id)) continue;
      areas.add(area);
    }

    for (final item in overlay['workTypes'] as List? ?? const []) {
      if (item is! Map) continue;
      final type = WorkTypeSummary.fromJson({...Map<String, dynamic>.from(item), 'userAdded': true});
      if (type.name.trim().isEmpty) continue;
      final existing = workTypeById(type.id);
      if (existing != null) {
        for (final scope in type.scopes) {
          _upsertScopeOnType(existing, scope);
        }
        continue;
      }
      workTypes.add(type);
    }
    workTypes.sort((a, b) => a.serialNo.compareTo(b.serialNo));

    for (final item in overlay['scopes'] as List? ?? const []) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final scope = WorkScope.fromJson({
        ...mapped,
        'userEdited': mapped['userEdited'] == true || mapped['userAdded'] == true,
      });
      final type = workTypeById(scope.workTypeId) ?? workTypeById(scope.workType);
      if (type == null) continue;
      _upsertScopeOnType(type, scope);
    }
    rebuildRateCard();
  }

  void _upsertScopeOnType(WorkTypeSummary type, WorkScope scope) {
    final index = type.scopes.indexWhere(
      (existing) => existing.id == scope.id || existing.name.toLowerCase() == scope.name.toLowerCase(),
    );
    if (index >= 0) {
      final current = type.scopes[index];
      type.scopes[index] = current.copyWith(
        unit: scope.unit.isEmpty ? current.unit : scope.unit,
        description: scope.description.isEmpty ? current.description : scope.description,
        suggestedRate: scope.suggestedRate ?? current.suggestedRate,
        minRate: scope.minRate ?? current.minRate,
        maxRate: scope.maxRate ?? current.maxRate,
        userAdded: current.userAdded || scope.userAdded,
        userEdited: current.userEdited || scope.userEdited || scope.userAdded,
      );
    } else {
      type.scopes.add(scope);
    }
    for (final area in scope.typicalAreas) {
      if (!type.areas.contains(area)) type.areas.add(area);
    }
  }

  Map<String, dynamic> overlayJson() => {
        'areas': [
          for (final area in areas)
            if (area.userAdded) area.toJson(),
        ],
        'workTypes': [
          for (final type in workTypes)
            if (type.userAdded) type.toJson(),
        ],
        'scopes': [
          for (final type in workTypes)
            for (final scope in type.scopes)
              if (scope.persistInCache) scope.toJson(),
        ],
      };

  CatalogArea addArea({
    required String name,
    List<String> typicalWorkTypes = const [],
  }) {
    final trimmed = name.trim();
    final existing = areaByName(trimmed);
    if (existing != null) return existing;
    final area = CatalogArea(
      id: uniqueCatalogId(
        prefix: 'area',
        name: trimmed,
        exists: (id) => areas.any((item) => item.id == id),
      ),
      name: trimmed,
      typicalWorkTypes: [...typicalWorkTypes],
      typicalScopes: [],
      userAdded: true,
    );
    areas.add(area);
    return area;
  }

  WorkTypeSummary addWorkType({
    required String name,
    int? serialNo,
  }) {
    final trimmed = name.trim();
    final existing = workTypeById(trimmed);
    if (existing != null) return existing;
    final nextSerial = serialNo ??
        (workTypes.isEmpty ? 1 : workTypes.map((type) => type.serialNo).reduce((a, b) => a > b ? a : b) + 1);
    final type = WorkTypeSummary(
      id: uniqueCatalogId(
        prefix: 'wt',
        name: trimmed,
        exists: (id) => workTypeById(id) != null,
      ),
      serialNo: nextSerial,
      name: trimmed,
      areas: [],
      scopes: [],
      userAdded: true,
    );
    workTypes.add(type);
    workTypes.sort((a, b) => a.serialNo.compareTo(b.serialNo));
    rebuildRateCard();
    return type;
  }

  WorkScope addScope({
    required String workTypeId,
    required String name,
    String description = '',
    String unit = 'sqft',
    double? suggestedRate,
    double? minRate,
    double? maxRate,
    String? code,
    List<String> typicalAreas = const [],
  }) {
    final type = workTypeById(workTypeId);
    if (type == null) {
      throw ArgumentError('Unknown work type: $workTypeId');
    }
    final trimmed = name.trim();
    for (final scope in type.scopes) {
      if (scope.name.toLowerCase() == trimmed.toLowerCase()) return scope;
    }
    final resolvedMin = minRate ?? suggestedRate;
    final resolvedMax = maxRate ?? suggestedRate;
    final scope = WorkScope(
      id: uniqueCatalogId(
        prefix: 'ws',
        name: trimmed,
        exists: (id) => scopeById(id) != null,
      ),
      workTypeId: type.id,
      workType: type.name,
      code: (code == null || code.trim().isEmpty) ? _nextScopeCode(type) : code.trim(),
      name: trimmed,
      description: description.trim(),
      unit: unit.trim().isEmpty ? 'sqft' : unit.trim(),
      suggestedRate: suggestedRate,
      minRate: resolvedMin,
      maxRate: resolvedMax,
      sampleCount: 0,
      typicalAreas: [...typicalAreas],
      aliases: [],
      makes: [],
      samples: [],
      userAdded: true,
    );
    type.scopes.add(scope);
    for (final area in typicalAreas) {
      if (!type.areas.contains(area)) type.areas.add(area);
    }
    rebuildRateCard();
    return scope;
  }

  WorkScope updateScope({
    required String scopeId,
    String? unit,
    double? suggestedRate,
    double? minRate,
    double? maxRate,
    String? description,
  }) {
    for (final type in workTypes) {
      final index = type.scopes.indexWhere((scope) => scope.id == scopeId);
      if (index < 0) continue;
      final current = type.scopes[index];
      var nextMin = minRate ?? current.minRate;
      var nextMax = maxRate ?? current.maxRate;
      if (suggestedRate != null) {
        if (nextMin == null || suggestedRate < nextMin) nextMin = suggestedRate;
        if (nextMax == null || suggestedRate > nextMax) nextMax = suggestedRate;
      }
      final updated = current.copyWith(
        unit: unit?.trim().isEmpty == true ? current.unit : (unit ?? current.unit),
        description: description,
        suggestedRate: suggestedRate ?? current.suggestedRate,
        minRate: nextMin,
        maxRate: nextMax,
        userEdited: true,
      );
      type.scopes[index] = updated;
      rebuildRateCard();
      return updated;
    }
    throw ArgumentError('Unknown scope: $scopeId');
  }

  String? _nextScopeCode(WorkTypeSummary type) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final used = {
      for (final scope in type.scopes)
        if (scope.code != null && scope.code!.isNotEmpty) scope.code!.toUpperCase(),
    };
    for (var i = 0; i < letters.length; i++) {
      final letter = letters[i];
      if (!used.contains(letter)) return letter;
    }
    return null;
  }
}
