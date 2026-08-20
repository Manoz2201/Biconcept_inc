import 'dart:convert';

import '../data/analytics.dart';
import '../data/catalog_repository.dart';
import '../data/draft_store.dart';
import '../data/local_cache.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';

class AgentActions {
  const AgentActions({
    this.onNavigate,
    this.onOpenQuotation,
    this.onEstimatesChanged,
    this.onAppDataChanged,
  });

  final void Function(String screen)? onNavigate;
  final Future<void> Function(EstimateDraft draft)? onOpenQuotation;
  final Future<void> Function()? onEstimatesChanged;
  final Future<void> Function()? onAppDataChanged;
}

class CatalogTools {
  CatalogTools({
    required this.catalog,
    this.draft,
    this.actions,
  });

  final EstimateCatalog catalog;
  EstimateDraft? draft;
  final AgentActions? actions;
  final CatalogRepository _repo = CatalogRepository.instance;
  final DraftStore _store = DraftStore();

  static const definitions = <Map<String, dynamic>>[
    {
      'type': 'function',
      'function': {
        'name': 'search_rate_card',
        'description': 'Find work scopes in the catalog by work type and/or free-text query.',
        'parameters': {
          'type': 'object',
          'properties': {
            'workType': {'type': 'string'},
            'query': {'type': 'string'},
            'limit': {'type': 'integer'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_work_types',
        'description': 'List catalog work types with serial numbers and scope counts.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_scope',
        'description': 'Get one work scope: description, unit, suggested/min/max rate, typical areas.',
        'parameters': {
          'type': 'object',
          'properties': {
            'scopeId': {'type': 'string'},
          },
          'required': ['scopeId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'similar_line_items',
        'description': 'Historical quantity and rate samples for a scope.',
        'parameters': {
          'type': 'object',
          'properties': {
            'scopeId': {'type': 'string'},
          },
          'required': ['scopeId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_catalog_scope',
        'description': 'Add a work scope to the rate card and local cache.',
        'parameters': {
          'type': 'object',
          'properties': {
            'workType': {'type': 'string', 'description': 'Work type id or name'},
            'name': {'type': 'string'},
            'description': {'type': 'string'},
            'unit': {'type': 'string'},
            'unitRate': {'type': 'number'},
            'code': {'type': 'string'},
          },
          'required': ['workType', 'name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'dashboard_summary',
        'description': 'Pipeline counts and values across saved estimates.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_estimates',
        'description': 'List saved quotations with client, status, line count and total.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'open_estimate',
        'description': 'Load a saved quotation as the current draft the agent can edit.',
        'parameters': {
          'type': 'object',
          'properties': {
            'estimateId': {'type': 'string'},
            'client': {'type': 'string', 'description': 'Used if estimateId is omitted'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_estimate',
        'description':
            'Create a quotation for a client. Ask the user which client and which work scope first. Pass workTypes and/or workScope/scopes from the catalog.',
        'parameters': {
          'type': 'object',
          'properties': {
            'client': {'type': 'string'},
            'project': {'type': 'string'},
            'carpetArea': {'type': 'number'},
            'workTypes': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Work type names or ids',
            },
            'workScope': {
              'type': 'string',
              'description': 'Free-text work the user asked to quote, e.g. gypsum partition, painting, HVAC',
            },
            'scopes': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Scope names from the catalog',
            },
            'estimateType': {
              'type': 'string',
              'description': 'Interior Estimate, Design, Construction TurnKey Estimate, or a custom label',
            },
          },
          'required': ['client'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_estimate_meta',
        'description': 'Update client, project, carpet area, status, or terms and conditions on the current quotation.',
        'parameters': {
          'type': 'object',
          'properties': {
            'client': {'type': 'string'},
            'project': {'type': 'string'},
            'carpetArea': {'type': 'number'},
            'status': {'type': 'string', 'description': 'drafted, completed, or finalized'},
            'estimateType': {
              'type': 'string',
              'description': 'Interior Estimate, Design, Construction TurnKey Estimate, or a custom label',
            },
            'termsAndConditions': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Full OTHER TERMS AND CONDITIONS clauses for the quotation',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'save_estimate',
        'description': 'Save the current quotation to disk.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_estimate',
        'description': 'Permanently delete a saved estimate by id, or the currently open quotation if id is omitted.',
        'parameters': {
          'type': 'object',
          'properties': {
            'estimateId': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'suggest_quantities',
        'description': 'Suggest a quantity for a draft line from samples and carpet area. Does not write the draft.',
        'parameters': {
          'type': 'object',
          'properties': {
            'lineId': {'type': 'string'},
          },
          'required': ['lineId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'apply_line',
        'description':
            'Write description, optional quantity, and unit rate onto a quotation line. Amount is calculated in Dart.',
        'parameters': {
          'type': 'object',
          'properties': {
            'lineId': {'type': 'string'},
            'description': {'type': 'string'},
            'quantity': {'type': 'number'},
            'unitRate': {'type': 'number'},
            'unit': {'type': 'string'},
            'reason': {'type': 'string'},
          },
          'required': ['lineId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_quotation_line',
        'description': 'Add a scope line to the current quotation and keep it on that work type in the catalog.',
        'parameters': {
          'type': 'object',
          'properties': {
            'workType': {'type': 'string'},
            'name': {'type': 'string'},
            'description': {'type': 'string'},
            'unit': {'type': 'string'},
            'unitRate': {'type': 'number'},
            'quantity': {'type': 'number'},
            'code': {'type': 'string'},
          },
          'required': ['workType', 'name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_quotation_line',
        'description': 'Remove a scope line from the current quotation.',
        'parameters': {
          'type': 'object',
          'properties': {
            'lineId': {'type': 'string'},
          },
          'required': ['lineId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'fill_from_catalog',
        'description': 'Apply catalog rates and suggested quantities to current quotation lines.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'recalc_totals',
        'description': 'Return current subtotal, GST split, and grand total for the open quotation.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'navigate',
        'description': 'Open an app screen: dashboard, estimates, clients, calendar, rate_card, settings, or quotation.',
        'parameters': {
          'type': 'object',
          'properties': {
            'screen': {'type': 'string'},
          },
          'required': ['screen'],
        },
      },
    },
  ];

  /// Rate-card reminder appended to the full app-operator prompt.
  static String workersAiToolPrompt() {
    final names = [
      for (final item in definitions)
        if (item['function'] is Map) (item['function'] as Map)['name']?.toString() ?? '',
    ].where((name) => name.isNotEmpty).join(', ');
    return '''
Quotation / rate-card tools: $names.
Never invent unit rates. Stay within minRate and maxRate when those exist. Do not compute GST yourself.
Ask which client and which work scope before create_estimate. Open or create an estimate before editing lines. After edits, mention totals from tools.
''';
  }

  Future<String> execute(String name, String argumentsJson) async {
    Map<String, dynamic> args = {};
    try {
      final decoded = jsonDecode(argumentsJson);
      if (decoded is Map<String, dynamic>) args = decoded;
    } catch (_) {}
    try {
      switch (name) {
        case 'search_rate_card':
          return _search(args);
        case 'list_work_types':
          return _workTypes();
        case 'get_scope':
          return _getScope(args);
        case 'similar_line_items':
          return _similar(args);
        case 'add_catalog_scope':
          return await _addCatalogScope(args);
        case 'dashboard_summary':
          return await _dashboard();
        case 'list_estimates':
          return await _listEstimates();
        case 'open_estimate':
          return await _openEstimate(args);
        case 'create_estimate':
          return await _createEstimate(args);
        case 'set_estimate_meta':
          return _setMeta(args);
        case 'save_estimate':
          return await _save();
        case 'delete_estimate':
          return await _deleteEstimate(args);
        case 'suggest_quantities':
          return _suggest(args);
        case 'apply_line':
          return _apply(args);
        case 'add_quotation_line':
          return await _addLine(args);
        case 'delete_quotation_line':
          return _deleteLine(args);
        case 'fill_from_catalog':
          return _fillFromCatalog();
        case 'recalc_totals':
          return _totals();
        case 'navigate':
          return _navigate(args);
        default:
          return jsonEncode({'error': 'Unknown tool $name'});
      }
    } catch (error) {
      return jsonEncode({'error': error.toString()});
    }
  }

  String _search(Map<String, dynamic> args) {
    final scopes = _repo.searchScopes(
      catalog,
      workType: args['workType']?.toString(),
      query: args['query']?.toString(),
      limit: (args['limit'] as num?)?.toInt() ?? 8,
    );
    return jsonEncode({
      'results': [
        for (final scope in scopes)
          {
            'id': scope.id,
            'workType': scope.workType,
            'name': scope.name,
            'unit': scope.unit,
            'suggestedRate': scope.suggestedRate,
            'minRate': scope.minRate,
            'maxRate': scope.maxRate,
          },
      ],
    });
  }

  String _workTypes() {
    return jsonEncode({
      'workTypes': [
        for (final type in catalog.workTypes)
          {
            'id': type.id,
            'serialNo': type.serialNo,
            'name': type.name,
            'scopeCount': type.scopeCount,
          },
      ],
    });
  }

  String _getScope(Map<String, dynamic> args) {
    final scope = catalog.scopeById(args['scopeId']?.toString() ?? '');
    if (scope == null) return jsonEncode({'error': 'Scope not found'});
    return jsonEncode(_repo.scopePayload(scope));
  }

  String _similar(Map<String, dynamic> args) {
    return jsonEncode({'samples': _repo.similarLineItems(args['scopeId']?.toString() ?? '')});
  }

  Future<String> _addCatalogScope(Map<String, dynamic> args) async {
    final type = _findType(args['workType']?.toString());
    if (type == null) return jsonEncode({'error': 'Work type not found'});
    final name = args['name']?.toString().trim() ?? '';
    if (name.isEmpty) return jsonEncode({'error': 'Enter a scope name'});
    final rate = (args['unitRate'] as num?)?.toDouble();
    final scope = await _repo.addScope(
      workTypeId: type.id,
      name: name,
      description: args['description']?.toString() ?? '',
      unit: args['unit']?.toString() ?? 'sqft',
      suggestedRate: rate,
      minRate: rate,
      maxRate: rate,
      code: args['code']?.toString(),
    );
    return jsonEncode({'ok': true, 'scope': _repo.scopePayload(scope)});
  }

  Future<String> _dashboard() async {
    final drafts = await _store.list();
    final analytics = EstimateAnalytics.from(drafts);
    return jsonEncode({
      'total': analytics.total,
      'drafted': analytics.drafted,
      'completed': analytics.completed,
      'finalized': analytics.finalized,
      'pipelineValue': analytics.pipelineValue,
      'finalizedValue': analytics.finalizedValue,
      'thisMonthValue': analytics.thisMonthValue,
    });
  }

  Future<String> _listEstimates() async {
    final drafts = await _store.list();
    return jsonEncode({
      'estimates': [
        for (final item in drafts)
          {
            'id': item.id,
            'client': item.client,
            'project': item.project,
            'estimateType': item.estimateType,
            'status': item.status.name,
            'lines': item.lines.length,
            'grandTotal': item.totals.grandTotal,
            'date': item.date.toIso8601String(),
          },
      ],
    });
  }

  Future<String> _openEstimate(Map<String, dynamic> args) async {
    final id = args['estimateId']?.toString().trim();
    final client = args['client']?.toString().trim().toLowerCase();
    EstimateDraft? found;
    if (id != null && id.isNotEmpty) {
      found = await _store.load(id);
    } else if (client != null && client.isNotEmpty) {
      final drafts = await _store.list();
      for (final item in drafts) {
        if (item.client.toLowerCase().contains(client)) {
          found = item;
          break;
        }
      }
    }
    if (found == null) return jsonEncode({'error': 'Estimate not found'});
    draft = found;
    draft!.normalizeScopeSeries();
    await actions?.onOpenQuotation?.call(found);
    return jsonEncode({
      'ok': true,
      'estimate': appSnapshot(),
    });
  }

  Future<String> _createEstimate(Map<String, dynamic> args) async {
    final client = args['client']?.toString().trim() ?? '';
    if (client.isEmpty) {
      return jsonEncode({
        'error': 'Ask the user which client this estimate is for',
        'need': 'client',
      });
    }
    final project = args['project']?.toString().trim() ?? '';
    final carpet = (args['carpetArea'] as num?)?.toDouble();
    final typeNames = [
      for (final item in args['workTypes'] as List? ?? const []) item.toString(),
    ];
    final scopeQueries = _scopeQueries(args);
    final types = <WorkTypeSummary>[];
    for (final name in typeNames) {
      final type = _findType(name);
      if (type != null) types.add(type);
    }

    final matchedScopes = <WorkScope>[];
    final seen = <String>{};
    for (final query in scopeQueries) {
      for (final scope in _repo.searchScopes(catalog, query: query, limit: 8)) {
        if (seen.add(scope.id)) matchedScopes.add(scope);
      }
    }

    if (types.isEmpty && matchedScopes.isEmpty) {
      return jsonEncode({
        'error': 'Ask the user which work scope to quote (gypsum, painting, HVAC, electrical, …)',
        'need': 'workScope',
      });
    }

    final lines = <EstimateLine>[];
    if (matchedScopes.isNotEmpty) {
      for (final scope in matchedScopes) {
        final type = catalog.workTypeById(scope.workTypeId) ?? _findType(scope.workType);
        if (type == null) continue;
        final qty = suggestQuantity(scope: scope, carpetArea: carpet) ?? 1;
        lines.add(EstimateLine.fromScope(type: type, scope: scope, quantity: qty));
      }
    } else {
      for (final type in types) {
        final scopes = catalog.typicalScopes(type: type);
        for (final scope in scopes) {
          final qty = suggestQuantity(scope: scope, carpetArea: carpet) ?? 1;
          lines.add(EstimateLine.fromScope(type: type, scope: scope, quantity: qty));
        }
      }
    }
    if (lines.isEmpty) {
      return jsonEncode({
        'error': 'No matching catalog scopes. Ask the user to name the work more specifically.',
        'need': 'workScope',
      });
    }

    final prefs = await LocalCache.instance.loadPrefs();
    final created = EstimateDraft(
      client: client,
      project: project,
      carpetArea: carpet,
      brand: prefs.brand.trim().isEmpty ? defaultCompanyBrand : prefs.brand.trim(),
      companyAddress: resolveCompanyAddress(prefsAddress: prefs.companyAddress),
      companyPhone: resolveCompanyPhone(prefsPhone: prefs.companyPhone),
      estimateType: normalizeEstimateType(args['estimateType']?.toString()),
      gstPercent: prefs.gstPercent,
      hvacGstPercent: prefs.hvacGstPercent,
      paymentTerms: [...catalog.defaults.paymentTerms],
      exclusions: [...catalog.defaults.exclusions],
      notes: [...catalog.defaults.notes],
      termsAndConditions: [...catalog.defaults.effectiveTerms],
      lines: lines,
    );
    created.normalizeScopeSeries();
    await _store.save(created);
    draft = created;
    await actions?.onEstimatesChanged?.call();
    await actions?.onOpenQuotation?.call(created);
    return jsonEncode({'ok': true, 'estimate': appSnapshot()});
  }

  String _setMeta(Map<String, dynamic> args) {
    final current = _requireDraft();
    if (current is String) return current;
    final item = draft!;
    final client = args['client']?.toString();
    if (client != null) item.client = client.trim();
    final project = args['project']?.toString();
    if (project != null) item.project = project.trim();
    if (args.containsKey('carpetArea')) {
      item.carpetArea = (args['carpetArea'] as num?)?.toDouble();
    }
    final status = args['status']?.toString();
    if (status != null && status.trim().isNotEmpty) {
      item.setStatus(EstimateStatus.fromName(status));
    } else {
      item.markChanged();
    }
    if (args.containsKey('estimateType')) {
      item.setEstimateType(args['estimateType']?.toString() ?? defaultEstimateType);
    }
    if (args.containsKey('termsAndConditions')) {
      final raw = args['termsAndConditions'];
      if (raw is List) {
        item.setTermsAndConditions([for (final term in raw) term.toString()]);
      }
    }
    return jsonEncode({'ok': true, 'estimate': appSnapshot()});
  }

  Future<String> _save() async {
    final current = _requireDraft();
    if (current is String) return current;
    await _store.save(draft!);
    await actions?.onEstimatesChanged?.call();
    return jsonEncode({'ok': true, 'id': draft!.id, 'status': draft!.status.name});
  }

  Future<String> _deleteEstimate(Map<String, dynamic> args) async {
    var id = args['estimateId']?.toString().trim() ?? '';
    if (id.isEmpty) id = draft?.id ?? '';
    if (id.isEmpty) return jsonEncode({'error': 'No estimate id'});
    await _store.delete(id);
    if (draft?.id == id) draft = null;
    await actions?.onEstimatesChanged?.call();
    return jsonEncode({'ok': true, 'deletedId': id});
  }

  EstimateLine? _line(String? id) {
    final current = draft;
    if (current == null || id == null) return null;
    for (final line in current.lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  String _suggest(Map<String, dynamic> args) {
    final current = _requireDraft();
    if (current is String) return current;
    final line = _line(args['lineId']?.toString());
    if (line == null) return jsonEncode({'error': 'Line not found'});
    final scope = catalog.scopeById(line.scopeId);
    if (scope == null) return jsonEncode({'error': 'Scope not found'});
    final qty = suggestQuantity(scope: scope, carpetArea: draft!.carpetArea, area: line.area);
    return jsonEncode({
      'lineId': line.id,
      'unit': scope.unit,
      'suggestedQuantity': qty,
      'note': qty == null ? 'Leave quantity empty for the user.' : 'Suggestion only; user must confirm.',
    });
  }

  String _apply(Map<String, dynamic> args) {
    final current = _requireDraft();
    if (current is String) return current;
    final lineId = args['lineId']?.toString();
    final line = _line(lineId);
    if (line == null) return jsonEncode({'error': 'Line not found'});
    final scope = catalog.scopeById(line.scopeId);
    final unit = args['unit']?.toString();
    if (unit != null && unit.trim().isNotEmpty) {
      draft!.updateLine(line.id, (item) => item.unit = unit.trim());
    }
    draft!.applyProposal(
      LineProposal(
        lineId: line.id,
        description: args['description']?.toString(),
        quantity: (args['quantity'] as num?)?.toDouble(),
        unitRate: (args['unitRate'] as num?)?.toDouble(),
        reason: args['reason']?.toString(),
        applyQuantity: args['quantity'] != null,
      ),
      scope: scope,
    );
    final updated = _line(line.id)!;
    return jsonEncode({
      'ok': true,
      'lineId': updated.id,
      'unitRate': updated.unitRate,
      'quantity': updated.effectiveQuantity,
      'amount': updated.amount,
    });
  }

  Future<String> _addLine(Map<String, dynamic> args) async {
    final current = _requireDraft();
    if (current is String) return current;
    final type = _findType(args['workType']?.toString());
    if (type == null) return jsonEncode({'error': 'Work type not found'});
    final name = args['name']?.toString().trim() ?? '';
    if (name.isEmpty) return jsonEncode({'error': 'Enter a description'});
    final unit = args['unit']?.toString().trim().isNotEmpty == true ? args['unit'].toString().trim() : 'sqft';
    final rate = (args['unitRate'] as num?)?.toDouble();
    final qty = (args['quantity'] as num?)?.toDouble() ?? 1;
    final code = args['code']?.toString().trim();
    final scope = await _repo.addScope(
      workTypeId: type.id,
      name: name,
      description: args['description']?.toString() ?? name,
      unit: unit,
      suggestedRate: rate,
      code: code,
    );
    draft!.addLine(
      EstimateLine(
        id: 'line_${DateTime.now().microsecondsSinceEpoch}',
        workTypeId: type.id,
        workType: type.name,
        serialNo: type.serialNo,
        scopeId: scope.id,
        workScopeCode: (code == null || code.isEmpty) ? scope.code : code,
        name: name,
        description: args['description']?.toString().trim().isNotEmpty == true
            ? args['description'].toString().trim()
            : name,
        unit: unit,
        quantity: qty,
        suggestedQuantity: qty,
        quantityConfirmed: true,
        unitRate: rate ?? scope.suggestedRate,
        source: LineSource.user,
        custom: scope.userAdded,
      ),
    );
    return jsonEncode({'ok': true, 'estimate': appSnapshot()});
  }

  String _deleteLine(Map<String, dynamic> args) {
    final current = _requireDraft();
    if (current is String) return current;
    final id = args['lineId']?.toString();
    if (_line(id) == null) return jsonEncode({'error': 'Line not found'});
    draft!.removeLine(id!);
    return jsonEncode({'ok': true, 'estimate': appSnapshot()});
  }

  String _fillFromCatalog() {
    final current = _requireDraft();
    if (current is String) return current;
    for (final line in draft!.lines) {
      if (line.custom) continue;
      final scope = catalog.scopeById(line.scopeId);
      if (scope == null) continue;
      if (scope.description.isNotEmpty) line.description = scope.description;
      if (scope.unit.isNotEmpty) line.unit = scope.unit;
      line.unitRate = scope.suggestedRate ?? line.unitRate;
      final qty = suggestQuantity(scope: scope, carpetArea: draft!.carpetArea, area: line.area);
      line.suggestedQuantity = qty;
      line.quantity ??= qty;
      line.quantityConfirmed = false;
      line.source = LineSource.agent;
    }
    draft!.markChanged();
    return jsonEncode({'ok': true, 'estimate': appSnapshot()});
  }

  String _totals() {
    final current = _requireDraft();
    if (current is String) return current;
    final totals = draft!.totals;
    return jsonEncode({
      'otherTaxable': totals.otherTaxable,
      'hvacTaxable': totals.hvacTaxable,
      'gst18': totals.gst18,
      'gst28': totals.gst28,
      'grandTotal': totals.grandTotal,
      'formula': 'amount = quantity * unitRate',
    });
  }

  String _navigate(Map<String, dynamic> args) {
    final screen = args['screen']?.toString().trim().toLowerCase() ?? '';
    if (screen.isEmpty) return jsonEncode({'error': 'Provide a screen name'});
    actions?.onNavigate?.call(screen);
    if (screen == 'quotation' && draft != null) {
      actions?.onOpenQuotation?.call(draft!);
    }
    return jsonEncode({'ok': true, 'screen': screen});
  }

  Object? _requireDraft() {
    if (draft == null) {
      return jsonEncode({'error': 'No quotation is open. Use open_estimate or create_estimate first.'});
    }
    return null;
  }

  WorkTypeSummary? _findType(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final direct = catalog.workTypeById(value);
    if (direct != null) return direct;
    final needle = value.trim().toLowerCase();
    for (final type in catalog.workTypes) {
      if (type.name.toLowerCase().contains(needle)) return type;
    }
    return null;
  }

  List<String> _scopeQueries(Map<String, dynamic> args) {
    final raw = <String>[
      for (final item in args['scopes'] as List? ?? const []) item.toString(),
      if ((args['workScope'] ?? args['scope'])?.toString().trim().isNotEmpty ?? false)
        (args['workScope'] ?? args['scope']).toString(),
    ];
    final queries = <String>[];
    for (final value in raw) {
      for (final part in value.split(RegExp(r',|/|&|\band\b', caseSensitive: false))) {
        final bit = part.trim();
        if (bit.isNotEmpty) queries.add(bit);
      }
    }
    return queries;
  }

  Map<String, dynamic> appSnapshot() {
    final item = draft;
    if (item == null) {
      return {'openEstimate': null};
    }
    return {
      'id': item.id,
      'client': item.client,
      'project': item.project,
      'estimateType': item.estimateType,
      'carpetArea': item.carpetArea,
      'status': item.status.name,
      'grandTotal': item.totals.grandTotal,
      'termsAndConditions': item.effectiveTerms,
      'lines': [
        for (final line in item.lines)
          {
            'lineId': line.id,
            'workType': line.workType,
            'sNo': line.workScopeCode,
            'name': line.name,
            'unit': line.unit,
            'quantity': line.effectiveQuantity,
            'unitRate': line.unitRate,
            'amount': line.amount,
          },
      ],
    };
  }

  Map<String, dynamic> draftSnapshot() => appSnapshot();
}
