import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../data/draft_store.dart';
import '../data/local_cache.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
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

  static const _stepLabels = ['Project', 'Areas', 'Types', 'Scopes', 'Terms'];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _flowHeader(compact: compact),
            Expanded(child: _stepBody(compact: compact)),
            _flowFooter(compact: compact),
          ],
        ),
      ),
    );
  }

  Widget _flowHeader({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 8, compact ? 16 : 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            visualDensity: VisualDensity.compact,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'new estimate',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 28 : 32,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Text(
                'STEP ${_step + 1} OF 5',
                style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (_step + 1) / 5,
              minHeight: 8,
              backgroundColor: AppColors.card,
              color: AppColors.primary,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < _stepLabels.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: i <= _step ? () => setState(() => _step = i) : null,
                      child: Text(
                        _stepLabels[i].toUpperCase(),
                        textAlign: i == 0
                            ? TextAlign.left
                            : i == _stepLabels.length - 1
                                ? TextAlign.right
                                : TextAlign.center,
                        style: TextStyle(
                          color: i == _step ? AppColors.primary : AppColors.muted,
                          fontSize: 11,
                          letterSpacing: 1.3,
                          fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _flowFooter({required bool compact}) {
    final nextLabel = _step == 4 ? 'Build quotation' : 'Next: ${_stepLabels[_step + 1]}';
    return Material(
      color: AppColors.sidebar.withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 28, 10, compact ? 12 : 28, 10),
          child: compact
              ? Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Back',
                      onPressed: _step == 0 ? () => Navigator.of(context).maybePop() : () => setState(() => _step -= 1),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.completed,
                        side: BorderSide(color: AppColors.completed.withValues(alpha: 0.45)),
                      ),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    TextButton(
                      onPressed: _saveDraft,
                      child: const Text('SAVE', style: TextStyle(letterSpacing: 1.2, color: AppColors.completed)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _step == 4 ? 'BUILD' : 'NEXT',
                                style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _step == 0 ? () => Navigator.of(context).maybePop() : () => setState(() => _step -= 1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.completed,
                        side: BorderSide(color: AppColors.completed.withValues(alpha: 0.45)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('BACK', style: TextStyle(letterSpacing: 1.3)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _saveDraft,
                      child: const Text('SAVE DRAFT', style: TextStyle(letterSpacing: 1.3, color: AppColors.completed)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(nextLabel.toUpperCase(), style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _stepBody({required bool compact}) {
    final pad = EdgeInsets.fromLTRB(compact ? 16 : 28, 8, compact ? 16 : 28, 16);
    switch (_step) {
      case 0:
        return _projectStep(pad: pad);
      case 1:
        return _areasStep(pad: pad);
      case 2:
        return _workTypesStep(pad: pad);
      case 3:
        return _scopePicker(compact: compact, pad: pad);
      default:
        return _termsStep(pad: pad);
    }
  }

  Widget _stepIntro({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(body, style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint, String? helper, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      filled: true,
      fillColor: AppColors.background,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF5ADACE)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(label.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3)),
        ),
        child,
      ],
    );
  }

  Widget _projectStep({required EdgeInsets pad}) {
    return ListView(
      padding: pad,
      children: [
        _stepIntro(
          title: 'project details',
          body: 'Name the client and site. Carpet area is optional and can scale sqft quantities from similar jobs.',
        ),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labeled('Client', TextField(controller: _client, decoration: _fieldDecoration())),
              const SizedBox(height: 16),
              _labeled('Project / location', TextField(controller: _project, decoration: _fieldDecoration())),
              const SizedBox(height: 16),
              _labeled(
                'Carpet area (sqft)',
                TextField(
                  controller: _carpet,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDecoration(helper: 'Used to scale sqft quantities from similar jobs'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('ESTIMATE TYPE', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3)),
              const SizedBox(height: 10),
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
                    label: Text(presetEstimateTypes.contains(_estimateType) ? 'Custom' : _estimateType),
                    selected: !presetEstimateTypes.contains(_estimateType),
                    onSelected: (_) async {
                      final next = await showEstimateTypePicker(context, current: _estimateType);
                      if (next != null && mounted) setState(() => _estimateType = next);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(
                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                ),
                trailing: const Icon(Icons.calendar_today, color: AppColors.muted),
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
          ),
        ),
      ],
    );
  }

  Widget _areasStep({required EdgeInsets pad}) {
    return ListView(
      padding: pad,
      children: [
        _stepIntro(
          title: 'select areas',
          body: 'Select area types from past jobs, or type a new name.',
        ),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labeled(
                'Area type name',
                TextField(
                  controller: _areaInput,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    hint: 'e.g. Server room, Director cabin',
                    suffix: IconButton(
                      tooltip: 'Add area',
                      onPressed: _addAreaFromInput,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  onSubmitted: (_) => _addAreaFromInput(),
                ),
              ),
              const SizedBox(height: 18),
              const Text('SUGGESTIONS', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3)),
              const SizedBox(height: 10),
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
                Text('${_selectedAreas.length} selected', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _workTypesStep({required EdgeInsets pad}) {
    return ListView(
      padding: pad,
      children: [
        _stepIntro(
          title: 'work types',
          body: 'Select work types for this estimate, or add a new one.',
        ),
        for (final type in catalog.workTypes) ...[
          _TypePickCard(
            type: type,
            selected: _selectedTypes.contains(type.id),
            onChanged: (value) {
              setState(() {
                if (value) {
                  _selectedTypes.add(type.id);
                } else {
                  _selectedTypes.remove(type.id);
                }
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: _addWorkType,
            borderRadius: BorderRadius.circular(24),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.add, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add work type', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Name, S.No., then add its scopes in the next step', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scopePicker({required bool compact, required EdgeInsets pad}) {
    final types = catalog.workTypes.where((type) => _selectedTypes.contains(type.id)).toList();
    final intro = _stepIntro(
      title: 'define work scopes',
      body: 'Select the specific tasks and materials required for this estimate phase. Quantities can be adjusted inline.',
    );
    final sections = <Widget>[
      for (var i = 0; i < types.length; i++) ...[
        if (_selectedAreas.isNotEmpty && catalog.usesAreas(types[i]))
          for (final area in _selectedAreas) ...[
            _scopeSection(types[i], area: area, expanded: i == 0),
            const SizedBox(height: 12),
          ]
        else ...[
          _scopeSection(types[i], expanded: i == 0),
          const SizedBox(height: 12),
        ],
      ],
    ];
    if (compact) {
      return ListView(
        padding: pad,
        children: [intro, ...sections, const SizedBox(height: 12), _runningEstimate()],
      );
    }
    return Padding(
      padding: pad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 8,
            child: ListView(
              children: [intro, ...sections],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 320,
            child: SingleChildScrollView(child: _runningEstimate()),
          ),
        ],
      ),
    );
  }

  Widget _runningEstimate() {
    final types = catalog.workTypes.where((type) => _selectedTypes.contains(type.id)).toList();
    final rows = [
      for (final type in types) (type.name, _amountForType(type)),
    ];
    final total = rows.fold<double>(0, (sum, row) => sum + row.$2);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.cardHover, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('running estimate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const Text('Select work types and scopes to see a live total.', style: TextStyle(color: AppColors.muted))
          else
            for (final row in rows) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1, style: const TextStyle(color: AppColors.muted))),
                    Text(inr(row.$2), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
            ],
          const Text('SUBTOTAL', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text(inrCompact(total), style: const TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(value: 0.28, minHeight: 4, backgroundColor: AppColors.card, color: AppColors.completed),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Excludes GST', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  double _amountForType(WorkTypeSummary type) {
    var total = 0.0;
    void add(WorkScope scope, String? area) {
      final key = _scopeKey(type, scope, area);
      if (!_selectedScopes.contains(key)) return;
      final qty = _quantities[key] ?? 0;
      final rate = scope.suggestedRate ?? 0;
      total += qty * rate;
    }

    if (_selectedAreas.isNotEmpty && catalog.usesAreas(type)) {
      for (final area in _selectedAreas) {
        for (final scope in type.scopes) {
          add(scope, area);
        }
      }
    } else {
      for (final scope in type.scopes) {
        add(scope, null);
      }
    }
    return total;
  }

  Widget _termsStep({required EdgeInsets pad}) {
    return ListView(
      padding: pad,
      children: [
        TermsAndConditionsForm(
          templates: catalog.termsTemplates,
          terms: _terms,
          showHero: true,
          onChanged: (next) => setState(() => _terms = next),
        ),
      ],
    );
  }

  Widget _scopeSection(WorkTypeSummary type, {String? area, bool expanded = false}) {
    final typical = catalog.typicalScopes(type: type, area: area);
    final scopes = type.scopes.toList();
    final selectedCount = scopes.where((scope) => _selectedScopes.contains(_scopeKey(type, scope, area))).length;
    final title = (area == null ? type.name : '${type.name} · $area').toLowerCase();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          tilePadding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          leading: CircleAvatar(
            backgroundColor: AppColors.background,
            child: Icon(_workTypeIcon(type.name), color: _workTypeIconColor(type.name), size: 22),
          ),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '$selectedCount items selected',
            style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2),
          ),
          children: [
            if (scopes.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No scopes yet. Add one below.', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            for (final scope in scopes)
              _scopeRow(type, scope, area: area, typical: typical.contains(scope)),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('Add scope'),
              onTap: () => _addScope(type, area: area),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeRow(WorkTypeSummary type, WorkScope scope, {String? area, bool typical = false}) {
    final key = _scopeKey(type, scope, area);
    final selected = _selectedScopes.contains(key);
    final rate = scope.suggestedRate;
    final unit = scope.unit.isEmpty ? 'unit' : scope.unit;
    final rateLabel = [
      if (rate != null) '${inr(rate)} / $unit' else unit,
      if (typical) 'typical',
      if (scope.userAdded) 'added',
    ].join(' · ').toUpperCase();
    return Opacity(
      opacity: selected ? 1 : 0.6,
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _selectedScopes.remove(key);
            } else {
              _selectScope(type, scope, area);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectScope(type, scope, area);
                    } else {
                      _selectedScopes.remove(key);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scope.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(rateLabel, style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.1)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  enabled: selected,
                  controller: _qtyCtrl(key),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setState(() => _quantities[key] = parseNumber(value) ?? 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  unit.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _saveDraft() async {
    if (_client.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a client name')));
      return;
    }
    _ensureTerms();
    final draft = _buildDraft();
    await DraftStore().save(draft);
    _rememberSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
  }

  void _rememberSelection() {
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
    _rememberSelection();
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

IconData _workTypeIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('hvac')) return Icons.ac_unit;
  if (n.contains('electr')) return Icons.electrical_services;
  if (n.contains('plumb')) return Icons.plumbing;
  if (n.contains('civil') || n.contains('struct')) return Icons.foundation;
  if (n.contains('furn')) return Icons.chair_outlined;
  return Icons.architecture_outlined;
}

Color _workTypeIconColor(String name) {
  final n = name.toLowerCase();
  if (n.contains('electr')) return const Color(0xFF5ADACE);
  if (n.contains('hvac') || n.contains('plumb')) return AppColors.completed;
  return AppColors.primary;
}

class _TypePickCard extends StatelessWidget {
  const _TypePickCard({
    required this.type,
    required this.selected,
    required this.onChanged,
  });

  final WorkTypeSummary type;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.cardHover : AppColors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(_workTypeIcon(type.name), color: _workTypeIconColor(type.name), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name.toLowerCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${type.serialNo.toString().padLeft(2, '0')}  ·  ${type.scopeCount} scopes${type.userAdded ? ' · added' : ''}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
