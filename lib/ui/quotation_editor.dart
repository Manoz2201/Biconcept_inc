import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent/estimate_agent.dart';
import '../data/catalog_repository.dart';
import '../data/draft_store.dart';
import '../data/local_cache.dart';
import '../export/excel_exporter.dart';
import '../export/quotation_layout.dart';
import '../export/quotation_pdf.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/open_export.dart';
import 'agent_panel.dart';
import 'estimate_type_picker.dart';
import 'terms_editor.dart';
import 'widgets/quotation_letterhead.dart';
import 'widgets/ui_kit.dart';

class QuotationEditorPage extends StatefulWidget {
  const QuotationEditorPage({super.key, required this.catalog, required this.draft});

  final EstimateCatalog catalog;
  final EstimateDraft draft;

  @override
  State<QuotationEditorPage> createState() => _QuotationEditorPageState();
}

class _QuotationEditorPageState extends State<QuotationEditorPage> {
  final _store = DraftStore();
  final _pdf = QuotationPdf();
  final _excel = ExcelExporter();
  late final EstimateAgent _offlineAgent;
  final _editors = <String, _LineEditors>{};
  bool _saving = false;
  bool _showAgent = true;
  String _companyAddress = '';
  String _companyPhone = '';
  final _hScroll = ScrollController();
  final _agentKey = GlobalKey<CollapsibleAgentPanelState>();

  EstimateDraft get draft => widget.draft;
  EstimateCatalog get catalog => widget.catalog;

  @override
  void initState() {
    super.initState();
    draft.normalizeScopeSeries();
    _offlineAgent = EstimateAgent(catalog: catalog, draft: draft);
    draft.addListener(_onChanged);
    _loadCompanyAddress();
  }

  Future<void> _loadCompanyAddress() async {
    final prefs = await LocalCache.instance.loadPrefs();
    if (!mounted) return;
    setState(() {
      _companyAddress = resolveCompanyAddress(
        prefsAddress: prefs.companyAddress,
        draftAddress: draft.companyAddress,
      );
      _companyPhone = resolveCompanyPhone(
        prefsPhone: prefs.companyPhone,
        draftPhone: draft.companyPhone,
      );
      if (draft.companyAddress.trim().isEmpty) {
        draft.companyAddress = _companyAddress;
      }
      if (draft.companyPhone.trim().isEmpty) {
        draft.companyPhone = _companyPhone;
      }
    });
  }

  @override
  void dispose() {
    draft.removeListener(_onChanged);
    draft.dispose();
    _hScroll.dispose();
    for (final editor in _editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    _pruneEditors();
    for (final line in draft.lines) {
      _editorFor(line).syncFrom(line);
    }
    setState(() {});
  }

  _LineEditors _editorFor(EstimateLine line) {
    return _editors.putIfAbsent(line.id, () => _LineEditors(line));
  }

  void _pruneEditors() {
    final ids = {for (final line in draft.lines) line.id};
    final stale = _editors.keys.where((id) => !ids.contains(id)).toList();
    for (final id in stale) {
      _editors.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = draft.totals;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.wide;
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              draft.client.isEmpty ? 'Quotation' : draft.client,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: StatusChip(status: draft.status, compact: true),
              ),
              PopupMenuButton<EstimateStatus>(
                tooltip: 'Save as',
                enabled: !_saving,
                onSelected: _saveAs,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: EstimateStatus.drafted, child: Text('Save as Drafted')),
                  const PopupMenuItem(value: EstimateStatus.completed, child: Text('Save as Completed')),
                  const PopupMenuItem(value: EstimateStatus.finalized, child: Text('Save as Finalized')),
                ],
                icon: const Icon(Icons.save_outlined),
              ),
              IconButton(
                tooltip: 'Terms and conditions',
                onPressed: _editTerms,
                icon: const Icon(Icons.gavel_outlined),
              ),
              IconButton(
                tooltip: 'Add scope',
                onPressed: () => _addScope(),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: (_agentKey.currentState?.expanded ?? _showAgent)
                    ? 'Collapse agent'
                    : 'Expand agent',
                onPressed: () {
                  if (wide) {
                    _agentKey.currentState?.toggle();
                    setState(() => _showAgent = _agentKey.currentState?.expanded ?? !_showAgent);
                  } else {
                    _openAgentSheet();
                  }
                },
                icon: Icon(
                  (_agentKey.currentState?.expanded ?? _showAgent)
                      ? Icons.smart_toy
                      : Icons.smart_toy_outlined,
                ),
              ),
              if (wide) ...[
                IconButton(
                  tooltip: 'Save',
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_circle_outline),
                ),
                TextButton(
                  onPressed: _offlineAgent.fillFromCatalog,
                  child: const Text('Catalog fill'),
                ),
                TextButton(
                  onPressed: draft.confirmAllQuantities,
                  child: const Text('Confirm qtys'),
                ),
              ],
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  switch (value) {
                    case 'save':
                      _save();
                    case 'fill':
                      _offlineAgent.fillFromCatalog();
                    case 'confirm':
                      draft.confirmAllQuantities();
                    case 'pdf':
                      _exportPdf();
                    case 'excel':
                      _exportExcel();
                    case 'terms':
                      _editTerms();
                    case 'type':
                      _editEstimateType();
                    case 'delete':
                      _deleteEstimate();
                  }
                },
                itemBuilder: (context) => [
                  if (!wide) ...[
                    const PopupMenuItem(value: 'save', child: Text('Save')),
                    const PopupMenuItem(value: 'fill', child: Text('Catalog fill')),
                    const PopupMenuItem(value: 'confirm', child: Text('Confirm quantities')),
                  ],
                    const PopupMenuItem(value: 'pdf', child: Text('Export PDF quotation')),
                    const PopupMenuItem(value: 'excel', child: Text('Export Excel')),
                    const PopupMenuItem(value: 'terms', child: Text('Terms and conditions')),
                    const PopupMenuItem(value: 'type', child: Text('Change estimate type')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete estimate')),
                ],
              ),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _table()),
              if (wide) ...[
                const VerticalDivider(width: 1),
                CollapsibleAgentPanel(
                  key: _agentKey,
                  catalog: catalog,
                  draft: draft,
                  initiallyExpanded: _showAgent,
                  onExpandedChanged: (value) => setState(() => _showAgent = value),
                ),
              ],
            ],
          ),
          bottomNavigationBar: Material(
            color: AppColors.card,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, compact ? 10 : 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _totalRow('Subtotal', totals.subtotal),
                    _totalRow('GST ${draft.gstPercent.toStringAsFixed(0)}%', totals.gst18),
                    if (totals.hvacTaxable > 0)
                      _totalRow('HVAC GST ${draft.hvacGstPercent.toStringAsFixed(0)}%', totals.gst28),
                    _totalRow('Total with GST', totals.grandTotal, emphasize: true),
                    if (compact) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportPdf,
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                              label: const Text('PDF'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportExcel,
                              icon: const Icon(Icons.table_chart_outlined, size: 18),
                              label: const Text('Excel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _editTerms,
                          icon: const Icon(Icons.gavel_outlined, size: 18),
                          label: Text(
                            draft.effectiveTerms.isEmpty
                                ? 'Add terms and conditions'
                                : '${draft.effectiveTerms.length} terms and conditions',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _totalRow(String label, double value, {bool emphasize = false}) {
    final style = emphasize ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Text(inr(value), style: style),
        ],
      ),
    );
  }

  Widget _table() {
    final sections = groupQuotation(draft);
    final rows = <_TableRow>[
      for (final section in sections) ...[
        _TableRow.header(section),
        for (final line in section.lines) _TableRow.line(line),
      ],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, 960.0);
        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: width > constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  QuotationLetterhead(
                    client: draft.client,
                    project: draft.project,
                    date: draft.date,
                    companyAddress: _companyAddress.isEmpty ? draft.companyAddress : _companyAddress,
                    companyPhone: _companyPhone.isEmpty ? draft.companyPhone : _companyPhone,
                    estimateType: draft.estimateType,
                    onEstimateTypeTap: _editEstimateType,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _addScope(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add scope'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Work type is a heading. Amount = Quantity × unitRate.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _headerRow(),
                  const Divider(height: 1),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: TextButton.icon(
                              onPressed: () => _addScope(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add a scope to this quotation'),
                            ),
                          )
                        : ListView.builder(
                            primary: false,
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              if (row.section != null) return _workTypeHeading(row.section!);
                              return _scopeRow(row.line!);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerRow() {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        );
    return ColoredBox(
      color: AppColors.card,
      child: _columns(
        children: [
          Text('S.No.', style: style),
          Text('Scope / Description', style: style),
          Text('Unit', style: style),
          Text('unitRate', style: style, textAlign: TextAlign.right),
          Text('Quantity', style: style, textAlign: TextAlign.right),
          Text('Amount', style: style, textAlign: TextAlign.right),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _workTypeHeading(QuotationSection section) {
    final typeId = section.lines.isEmpty ? null : section.lines.first.workTypeId;
    return ColoredBox(
      color: AppColors.cardHover,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '${section.serialNo}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: Text(
                section.workType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              inr(section.total),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Add scope to ${section.workType}',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addScope(workTypeId: typeId),
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeRow(EstimateLine line) {
    final editor = _editorFor(line);
    final pending = !line.quantityConfirmed && line.effectiveQuantity != null;
    return ColoredBox(
      color: pending ? AppColors.primaryDim : Colors.transparent,
      child: _columns(
        children: [
          _cellField(
            controller: editor.sno,
            focusNode: editor.snoFocus,
            onChanged: (value) => _patch(line.id, (item) {
              item.workScopeCode = value.trim().isEmpty ? null : value.trim();
            }),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cellField(
                controller: editor.name,
                focusNode: editor.nameFocus,
                hintText: 'Scope name',
                onChanged: (value) => _patch(line.id, (item) {
                  if (item.description.trim() == item.name.trim()) {
                    item.description = '';
                  }
                  item.name = value;
                }),
              ),
              const SizedBox(height: 6),
              _cellField(
                controller: editor.details,
                focusNode: editor.detailsFocus,
                hintText: 'Description',
                maxLines: 2,
                onChanged: (value) => _patch(line.id, (item) {
                  item.description = value;
                }),
              ),
            ],
          ),
          _unitDropdown(line),
          _cellField(
            controller: editor.unitRate,
            focusNode: editor.unitRateFocus,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              _patch(line.id, (item) {
                item.unitRate = parseNumber(value);
                item.source = LineSource.user;
              });
              editor.syncAmount(line);
            },
          ),
          _cellField(
            controller: editor.quantity,
            focusNode: editor.quantityFocus,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              _patch(line.id, (item) {
                item.quantity = parseNumber(value);
                item.quantityConfirmed = item.quantity != null;
                item.source = LineSource.user;
              });
              editor.syncAmount(line);
            },
          ),
          _cellField(
            controller: editor.amount,
            focusNode: editor.amountFocus,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => _onAmountEdited(line, editor, value),
          ),
          IconButton(
            tooltip: 'Delete scope',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _deleteScope(line),
          ),
        ],
      ),
    );
  }

  Widget _columns({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: children[0]),
          const SizedBox(width: 8),
          Expanded(child: children[1]),
          const SizedBox(width: 8),
          SizedBox(width: 108, child: children[2]),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: children[3]),
          const SizedBox(width: 8),
          SizedBox(width: 96, child: children[4]),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: children[5]),
          SizedBox(width: 40, child: children[6]),
        ],
      ),
    );
  }

  Widget _cellField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    TextAlign textAlign = TextAlign.left,
    TextInputType? keyboardType,
    String? hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: textAlign,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: keyboardType == null ? null : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _unitDropdown(EstimateLine line) {
    final units = {
      ...catalogUnits,
      if (line.unit.trim().isNotEmpty) line.unit.trim(),
    }.toList();
    final current = line.unit.trim().isEmpty ? catalogUnits.first : line.unit.trim();
    return _compactDropdown<String>(
      value: units.contains(current) ? current : units.first,
      items: [
        for (final unit in units) DropdownMenuItem(value: unit, child: Text(unit)),
      ],
      onChanged: (value) {
        if (value == null) return;
        _patch(line.id, (item) {
          item.unit = value;
        });
      },
    );
  }

  Widget _compactDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isDense: true,
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _patch(String lineId, void Function(EstimateLine line) update) {
    draft.updateLine(lineId, (item) {
      update(item);
      item.source = LineSource.user;
    });
  }

  void _onAmountEdited(EstimateLine line, _LineEditors editor, String value) {
    final amount = parseNumber(value);
    _patch(line.id, (item) {
      if (amount == null) {
        item.unitRate = null;
        return;
      }
      var qty = item.effectiveQuantity;
      if (qty == null || qty == 0) {
        qty = 1;
        item.quantity = 1;
        item.quantityConfirmed = true;
        editor.setQuantityIfUnfocused(formatQty(1));
      }
      item.unitRate = amount / qty;
      item.source = LineSource.user;
    });
    editor.setUnitRateIfUnfocused(formatQty(line.unitRate));
  }

  Future<void> _deleteScope(EstimateLine line) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scope'),
        content: Text('Remove "${line.name.isEmpty ? 'this scope' : line.name}" from the quotation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) draft.removeLine(line.id);
  }

  Future<void> _addScope({String? workTypeId}) async {
    if (catalog.workTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a work type in the rate card first')),
      );
      return;
    }

    final typeId = workTypeId != null && catalog.workTypeById(workTypeId) != null
        ? workTypeId
        : catalog.workTypes.first.id;
    final result = await showDialog<_AddScopeDraft>(
      context: context,
      builder: (context) => _AddScopeDialog(catalog: catalog, initialTypeId: typeId),
    );
    if (result == null || !mounted) return;

    final type = catalog.workTypeById(result.typeId);
    if (type == null || result.name.isEmpty) return;

    WorkScope? scope;
    if (result.saveToRateCard) {
      scope = await CatalogRepository.instance.addScope(
        workTypeId: type.id,
        name: result.name,
        description: result.details,
        unit: result.unit,
        suggestedRate: result.rate,
        code: result.code.isEmpty ? null : result.code,
      );
    }

    draft.addLine(
      EstimateLine(
        id: 'line_${DateTime.now().microsecondsSinceEpoch}',
        workTypeId: type.id,
        workType: type.name,
        serialNo: type.serialNo,
        scopeId: scope?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
        workScopeCode: result.code.isEmpty ? scope?.code : result.code,
        name: result.name,
        description: result.details,
        unit: result.unit,
        quantity: result.quantity,
        suggestedQuantity: result.quantity,
        quantityConfirmed: true,
        unitRate: result.rate ?? scope?.suggestedRate,
        source: LineSource.user,
        custom: scope?.userAdded ?? true,
      ),
    );
  }

  Future<void> _editTerms() async {
    final result = await showTermsAndConditionsEditor(
      context,
      terms: draft.effectiveTerms,
      templates: catalog.termsTemplates,
    );
    if (result == null || !mounted) return;
    draft.setTermsAndConditions(result);
  }

  Future<void> _editEstimateType() async {
    final result = await showEstimateTypePicker(context, current: draft.estimateType);
    if (result == null || !mounted) return;
    draft.setEstimateType(result);
  }

  Future<void> _deleteEstimate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete estimate'),
        content: Text(
          'Delete the estimate for ${draft.client.isEmpty ? 'this client' : draft.client}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _store.delete(draft.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveAs(EstimateStatus status) async {
    draft.setStatus(status);
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _store.save(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as ${draft.status.label}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final file = await _pdf.export(draft);
      await openExportedFile(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Platform.isWindows ? 'Exported ${file.path}' : 'PDF ready to share or save')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  Future<void> _exportExcel() async {
    try {
      final file = await _excel.export(draft);
      await openExportedFile(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Platform.isWindows ? 'Exported ${file.path}' : 'Excel ready to share or save')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel export failed: $error')));
    }
  }

  Future<void> _openAgentSheet() async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 380,
          height: 560,
          child: AgentPanel(
            catalog: catalog,
            draft: draft,
            onCollapse: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}

class _AddScopeDraft {
  const _AddScopeDraft({
    required this.typeId,
    required this.code,
    required this.name,
    required this.details,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.saveToRateCard,
  });

  final String typeId;
  final String code;
  final String name;
  final String details;
  final String unit;
  final double quantity;
  final double? rate;
  final bool saveToRateCard;
}

class _AddScopeDialog extends StatefulWidget {
  const _AddScopeDialog({required this.catalog, required this.initialTypeId});

  final EstimateCatalog catalog;
  final String initialTypeId;

  @override
  State<_AddScopeDialog> createState() => _AddScopeDialogState();
}

class _AddScopeDialogState extends State<_AddScopeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sno;
  late final TextEditingController _name;
  late final TextEditingController _details;
  late final TextEditingController _unitRate;
  late final TextEditingController _quantity;
  late String _typeId;
  late String _unit;
  var _saveToRateCard = true;

  @override
  void initState() {
    super.initState();
    _typeId = widget.initialTypeId;
    _unit = catalogUnits.first;
    _sno = TextEditingController();
    _name = TextEditingController();
    _details = TextEditingController();
    _unitRate = TextEditingController();
    _quantity = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _sno.dispose();
    _name.dispose();
    _details.dispose();
    _unitRate.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _AddScopeDraft(
        typeId: _typeId,
        code: _sno.text.trim(),
        name: _name.text.trim(),
        details: _details.text.trim(),
        unit: _unit,
        quantity: parseNumber(_quantity.text) ?? 1,
        rate: parseNumber(_unitRate.text),
        saveToRateCard: _saveToRateCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add scope'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _typeId,
                  decoration: const InputDecoration(
                    labelText: 'WorkType',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final type in widget.catalog.workTypes)
                      DropdownMenuItem(
                        value: type.id,
                        child: Text('${type.serialNo}. ${type.name}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _typeId = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sno,
                  decoration: const InputDecoration(
                    labelText: 'S.No.',
                    hintText: 'A, B, C…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Scope name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a scope name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Spec / details shown on PDF and Excel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final item in catalogUnits)
                            DropdownMenuItem(value: item, child: Text(item)),
                        ],
                        onChanged: (value) {
                          if (value != null) _unit = value;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitRate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'unitRate',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_unitRate, _quantity]),
                        builder: (context, _) {
                          final qty = parseNumber(_quantity.text) ?? 0;
                          final rate = parseNumber(_unitRate.text);
                          final amount = rate == null ? null : qty * rate;
                          return InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(amount == null ? '—' : inr(amount)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _saveToRateCard,
                  onChanged: (value) => setState(() => _saveToRateCard = value ?? true),
                  title: const Text('Also save to rate card'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _TableRow {
  const _TableRow.header(this.section) : line = null;
  const _TableRow.line(this.line) : section = null;

  final QuotationSection? section;
  final EstimateLine? line;
}

class _LineEditors {
  _LineEditors(EstimateLine line)
      : sno = TextEditingController(text: line.workScopeCode ?? ''),
        name = TextEditingController(text: line.name.isEmpty ? line.description : line.name),
        details = TextEditingController(text: scopeDetails(line)),
        unitRate = TextEditingController(text: formatQty(line.unitRate)),
        quantity = TextEditingController(text: formatQty(line.effectiveQuantity)),
        amount = TextEditingController(text: formatQty(line.amount == 0 && line.unitRate == null ? null : line.amount));

  final snoFocus = FocusNode();
  final nameFocus = FocusNode();
  final detailsFocus = FocusNode();
  final unitRateFocus = FocusNode();
  final quantityFocus = FocusNode();
  final amountFocus = FocusNode();

  final TextEditingController sno;
  final TextEditingController name;
  final TextEditingController details;
  final TextEditingController unitRate;
  final TextEditingController quantity;
  final TextEditingController amount;

  void syncFrom(EstimateLine line) {
    _setIfUnfocused(sno, snoFocus, line.workScopeCode ?? '');
    _setIfUnfocused(name, nameFocus, line.name.isEmpty ? line.description : line.name);
    _setIfUnfocused(details, detailsFocus, scopeDetails(line));
    _setIfUnfocused(unitRate, unitRateFocus, formatQty(line.unitRate));
    _setIfUnfocused(quantity, quantityFocus, formatQty(line.effectiveQuantity));
    syncAmount(line);
  }

  void syncAmount(EstimateLine line) {
    final text = formatQty(line.amount == 0 && line.unitRate == null ? null : line.amount);
    _setIfUnfocused(amount, amountFocus, text);
  }

  void setQuantityIfUnfocused(String value) => _setIfUnfocused(quantity, quantityFocus, value);

  void setUnitRateIfUnfocused(String value) => _setIfUnfocused(unitRate, unitRateFocus, value);

  void _setIfUnfocused(TextEditingController controller, FocusNode node, String value) {
    if (node.hasFocus) return;
    if (controller.text == value) return;
    controller.text = value;
  }

  void dispose() {
    snoFocus.dispose();
    nameFocus.dispose();
    detailsFocus.dispose();
    unitRateFocus.dispose();
    quantityFocus.dispose();
    amountFocus.dispose();
    sno.dispose();
    name.dispose();
    details.dispose();
    unitRate.dispose();
    quantity.dispose();
    amount.dispose();
  }
}
