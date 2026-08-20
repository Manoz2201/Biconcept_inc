import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../data/local_cache.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../util/format.dart';
import 'catalog_forms.dart';
import 'estimate_type_picker.dart';
import 'quotation_editor.dart';
import 'terms_editor.dart';

class NewEstimateFlow extends StatefulWidget {
  const NewEstimateFlow({
    super.key,
    required this.catalog,
    this.initialClient,
    this.initialProject,
  });

  final EstimateCatalog catalog;
  final String? initialClient;
  final String? initialProject;

  @override
  State<NewEstimateFlow> createState() => _NewEstimateFlowState();
}

class _NewEstimateFlowState extends State<NewEstimateFlow> {
  final _client = TextEditingController();
  final _project = TextEditingController();
  final _carpet = TextEditingController();
  final _areaInput = TextEditingController();
  DateTime _date = DateTime.now();
  int _step = 0;
  final _selectedTypes = <String>{};
  final _selectedAreas = <String>{};
  final _selectedScopes = <String>{};
  final _quantities = <String, double>{};
  final _qtyCtrls = <String, TextEditingController>{};
  AppPrefsCache? _prefs;
  List<String> _terms = [];
  bool _termsReady = false;
  String _estimateType = defaultEstimateType;

  EstimateCatalog get catalog => widget.catalog;

  @override
  void initState() {
    super.initState();
    final client = widget.initialClient?.trim() ?? '';
    final project = widget.initialProject?.trim() ?? '';
    if (client.isNotEmpty) _client.text = client;
    if (project.isNotEmpty) _project.text = project;
    _restoreFromCache();
  }

  Future<void> _restoreFromCache() async {
    final prefs = await LocalCache.instance.loadPrefs();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      if (_project.text.isEmpty) _project.text = prefs.lastProject;
      if (_carpet.text.isEmpty && prefs.lastCarpetArea != null) {
        _carpet.text = formatQty(prefs.lastCarpetArea);
      }
      for (final name in prefs.recentAreaNames) {
        final area = catalog.areaByName(name);
        if (area != null) _selectedAreas.add(area.name);
      }
      for (final id in prefs.recentWorkTypeIds) {
        final type = catalog.workTypeById(id);
        if (type != null) _selectedTypes.add(type.id);
      }
    });
  }

  @override
  void dispose() {
    _client.dispose();
    _project.dispose();
    _carpet.dispose();
    _areaInput.dispose();
    for (final ctrl in _qtyCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New estimate')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Stepper(
              currentStep: _step,
              physics: const NeverScrollableScrollPhysics(),
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: [
                Step(title: const Text('Project'), content: const SizedBox.shrink(), isActive: _step >= 0),
                Step(title: const Text('Areas'), content: const SizedBox.shrink(), isActive: _step >= 1),
                Step(title: const Text('Work types'), content: const SizedBox.shrink(), isActive: _step >= 2),
                Step(title: const Text('Scopes'), content: const SizedBox.shrink(), isActive: _step >= 3),
                Step(title: const Text('Terms'), content: const SizedBox.shrink(), isActive: _step >= 4),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _stepBody()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_step == 4 ? 'Build quotation' : 'Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _projectStep();
      case 1:
        return _areasStep();
      case 2:
        return _workTypesStep();
      case 3:
        return _scopePicker();
      default:
        return _termsStep();
    }
  }

  Widget _projectStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _client,
          decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _project,
          decoration: const InputDecoration(labelText: 'Project / location', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _carpet,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Carpet area (sqft, optional)',
            border: OutlineInputBorder(),
            helperText: 'Used to scale sqft quantities from similar jobs',
          ),
        ),
        const SizedBox(height: 12),
        Text('Estimate type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in presetEstimateTypes)
              ChoiceChip(
                label: Text(type),
                selected: _estimateType == type,
                onSelected: (_) => setState(() => _estimateType = type),
              ),
            ChoiceChip(
              label: Text(
                presetEstimateTypes.contains(_estimateType) ? 'Custom' : _estimateType,
              ),
              selected: !presetEstimateTypes.contains(_estimateType),
              onSelected: (_) async {
                final next = await showEstimateTypePicker(context, current: _estimateType);
                if (next != null && mounted) setState(() => _estimateType = next);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date'),
          subtitle: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
      ],
    );
  }

  Widget _areasStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select area types from past jobs, or type a new name.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _areaInput,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Area type name',
            hintText: 'e.g. Server room, Director cabin',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Add area',
              onPressed: _addAreaFromInput,
              icon: const Icon(Icons.add),
            ),
          ),
          onSubmitted: (_) => _addAreaFromInput(),
        ),
        const SizedBox(height: 16),
        Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final area in catalog.areas)
              FilterChip(
                label: Text(area.name),
                selected: _selectedAreas.contains(area.name),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAreas.add(area.name);
                    } else {
                      _selectedAreas.remove(area.name);
                    }
                  });
                },
              ),
          ],
        ),
        if (_selectedAreas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${_selectedAreas.length} selected', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _workTypesStep() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Select work types for this estimate, or add a new one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        for (final type in catalog.workTypes)
          CheckboxListTile(
            value: _selectedTypes.contains(type.id),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedTypes.add(type.id);
                } else {
                  _selectedTypes.remove(type.id);
                }
              });
            },
            title: Text('${type.serialNo}. ${type.name}'),
            subtitle: Text('${type.scopeCount} scopes${type.userAdded ? ' · added' : ''}'),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add work type'),
          subtitle: const Text('Name, S.No., then add its scopes in the next step'),
          onTap: _addWorkType,
        ),
      ],
    );
  }

  Widget _scopePicker() {
    final types = catalog.workTypes.where((type) => _selectedTypes.contains(type.id)).toList();
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Select scopes, enter quantity to calculate amount, or add a new scope.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        for (final type in types) ...[
          if (_selectedAreas.isNotEmpty && catalog.usesAreas(type))
            for (final area in _selectedAreas) _scopeSection(type, area: area)
          else
            _scopeSection(type),
        ],
      ],
    );
  }

  Widget _scopeSection(WorkTypeSummary type, {String? area}) {
    final typical = catalog.typicalScopes(type: type, area: area);
    final scopes = type.scopes.toList();
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(area == null ? type.name : '${type.name} · $area'),
      children: [
        if (scopes.isEmpty)
          const ListTile(
            dense: true,
            title: Text('No scopes yet. Add one below.'),
          ),
        for (final scope in scopes)
          _scopeRow(type, scope, area: area, typical: typical.contains(scope)),
        ListTile(
          dense: true,
          leading: const Icon(Icons.add),
          title: const Text('Add scope'),
          onTap: () => _addScope(type, area: area),
        ),
      ],
    );
  }

  Widget _scopeRow(WorkTypeSummary type, WorkScope scope, {String? area, bool typical = false}) {
    final key = _scopeKey(type, scope, area);
    final selected = _selectedScopes.contains(key);
    final qty = _quantities[key];
    final rate = scope.suggestedRate;
    final amount = selected && qty != null && rate != null ? qty * rate : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            value: selected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectScope(type, scope, area);
                } else {
                  _selectedScopes.remove(key);
                }
              });
            },
            title: Text(scope.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (scope.unit.isNotEmpty) scope.unit,
                if (rate != null) inr(rate),
                if (typical) 'typical',
                if (scope.userAdded) 'added',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl(key),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity (${scope.unit.isEmpty ? 'unit' : scope.unit})',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _quantities[key] = parseNumber(value) ?? 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: Text(amount == null ? '—' : inr(amount), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextEditingController _qtyCtrl(String key) {
    return _qtyCtrls.putIfAbsent(
      key,
      () => TextEditingController(text: formatQty(_quantities[key])),
    );
  }

  double _defaultQty(WorkScope scope, String? area) {
    return suggestQuantity(scope: scope, carpetArea: parseNumber(_carpet.text), area: area) ?? 1;
  }

  void _selectScope(WorkTypeSummary type, WorkScope scope, String? area) {
    final key = _scopeKey(type, scope, area);
    _selectedScopes.add(key);
    _quantities[key] ??= _defaultQty(scope, area);
    _qtyCtrl(key).text = formatQty(_quantities[key]);
  }

  Future<void> _addAreaFromInput() async {
    final typed = _areaInput.text.trim();
    if (typed.isEmpty) {
      final area = await showAddAreaDialog(context, catalog: catalog);
      if (!mounted || area == null) return;
      setState(() => _selectedAreas.add(area.name));
      return;
    }
    final existing = catalog.areaByName(typed);
    if (existing != null) {
      setState(() {
        _selectedAreas.add(existing.name);
        _areaInput.clear();
      });
      return;
    }
    final area = await CatalogRepository.instance.addArea(name: typed);
    if (!mounted) return;
    setState(() {
      _selectedAreas.add(area.name);
      _areaInput.clear();
    });
  }

  Future<void> _addWorkType() async {
    final type = await showAddWorkTypeDialog(context, catalog: catalog);
    if (!mounted || type == null) return;
    setState(() => _selectedTypes.add(type.id));
  }

  Future<void> _addScope(WorkTypeSummary type, {String? area}) async {
    final scope = await showAddScopeDialog(
      context,
      catalog: catalog,
      workTypeId: type.id,
      presetAreas: [
        ?area,
        ..._selectedAreas,
      ],
    );
    if (!mounted || scope == null) return;
    setState(() => _selectScope(type, scope, area));
  }

  void _selectTypicalScopes() {
    for (final type in catalog.workTypes.where((item) => _selectedTypes.contains(item.id))) {
      if (_selectedAreas.isNotEmpty && catalog.usesAreas(type)) {
        for (final areaName in _selectedAreas) {
          for (final scope in catalog.typicalScopes(type: type, area: areaName)) {
            _selectScope(type, scope, areaName);
          }
        }
      } else {
        for (final scope in catalog.typicalScopes(type: type)) {
          _selectScope(type, scope, null);
        }
      }
      final recent = _prefs?.recentScopeIds ?? const <String>[];
      for (final scope in type.scopes) {
        if (!recent.contains(scope.id)) continue;
        if (_selectedAreas.isNotEmpty && catalog.usesAreas(type)) {
          for (final areaName in _selectedAreas) {
            _selectScope(type, scope, areaName);
          }
        } else {
          _selectScope(type, scope, null);
        }
      }
    }
  }

  String _scopeKey(WorkTypeSummary type, WorkScope scope, String? area) =>
      '${type.id}|${scope.id}|${area ?? ''}';

  void _ensureTerms() {
    if (_termsReady) return;
    _termsReady = true;
    _terms = [...catalog.defaults.effectiveTerms];
  }

  Widget _termsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Terms and conditions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TermsAndConditionsForm(
          templates: catalog.termsTemplates,
          terms: _terms,
          onChanged: (next) => setState(() => _terms = next),
        ),
      ],
    );
  }

  void _next() {
    if (_step == 0 && _client.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a client name')));
      return;
    }
    if (_step == 2 && _selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select or add at least one work type')));
      return;
    }
    if (_step < 3) {
      setState(() {
        _step += 1;
        if (_step == 3 && _selectedScopes.isEmpty) _selectTypicalScopes();
      });
      return;
    }
    if (_step == 3) {
      if (_selectedScopes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select or add at least one work scope')));
        return;
      }
      setState(() {
        _ensureTerms();
        _step = 4;
      });
      return;
    }
    if (_selectedScopes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select or add at least one work scope')));
      return;
    }
    final draft = _buildDraft();
    CatalogRepository.instance.rememberEstimateSelection(
      areaNames: _selectedAreas,
      workTypeIds: _selectedTypes,
      scopeIds: [
        for (final key in _selectedScopes)
          if (key.split('|').length > 1) key.split('|')[1],
      ],
      client: _client.text,
      project: _project.text,
      carpetArea: parseNumber(_carpet.text),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => QuotationEditorPage(catalog: catalog, draft: draft),
      ),
    );
  }

  EstimateDraft _buildDraft() {
    final defaults = catalog.defaults;
    final lines = <EstimateLine>[];
    for (final type in catalog.workTypes.where((type) => _selectedTypes.contains(type.id))) {
      if (_selectedAreas.isNotEmpty && catalog.usesAreas(type)) {
        for (final area in _selectedAreas) {
          for (final scope in type.scopes) {
            if (_selectedScopes.contains(_scopeKey(type, scope, area))) {
              final key = _scopeKey(type, scope, area);
              lines.add(EstimateLine.fromScope(
                type: type,
                scope: scope,
                area: area,
                quantity: _quantities[key] ?? _defaultQty(scope, area),
              ));
            }
          }
        }
      } else {
        for (final scope in type.scopes) {
          if (_selectedScopes.contains(_scopeKey(type, scope, null))) {
            final key = _scopeKey(type, scope, null);
            lines.add(EstimateLine.fromScope(
              type: type,
              scope: scope,
              quantity: _quantities[key] ?? _defaultQty(scope, null),
            ));
          }
        }
      }
    }
    final draft = EstimateDraft(
      client: _client.text.trim(),
      project: _project.text.trim(),
      date: _date,
      carpetArea: parseNumber(_carpet.text),
      brand: (_prefs?.brand.trim().isNotEmpty ?? false) ? _prefs!.brand.trim() : defaultCompanyBrand,
      companyAddress: resolveCompanyAddress(prefsAddress: _prefs?.companyAddress),
      companyPhone: resolveCompanyPhone(prefsPhone: _prefs?.companyPhone),
      estimateType: _estimateType,
      paymentTerms: [...defaults.paymentTerms],
      exclusions: [...defaults.exclusions],
      notes: [...defaults.notes],
      termsAndConditions: _terms.isEmpty ? [...defaults.effectiveTerms] : [..._terms],
      gstPercent: _prefs?.gstPercent ?? defaults.gstPercent,
      hvacGstPercent: _prefs?.hvacGstPercent ?? defaults.hvacGstPercent,
      lines: lines,
    );
    draft.replaceLines(List<EstimateLine>.from(lines));
    return draft;
  }
}
