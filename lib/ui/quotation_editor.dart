import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent/catalog_tools.dart';
import '../agent/estimate_agent.dart';
import '../core/config/env.dart';
import '../data/catalog_repository.dart';
import '../data/draft_store.dart';
import '../data/local_cache.dart';
import '../data/schedule.dart';
import '../export/excel_exporter.dart';
import '../export/quotation_layout.dart';
import '../export/quotation_pdf.dart';
import '../features/catalog/data/storage_repository.dart';
import '../features/catalog/domain/storage_repository.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/save_export.dart';
import 'agent_panel.dart';
import 'estimate_type_picker.dart';
import 'terms_editor.dart';

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
  final _storage = StorageRepositoryImpl();
  final _uploadingPictures = <String>{};
  bool _saving = false;
  bool _showAgent = true;
  String _companyAddress = '';
  String _companyPhone = '';
  final _hScroll = ScrollController();
  final _agentKey = GlobalKey<CollapsibleAgentPanelState>();

  EstimateDraft get draft => widget.draft;
  EstimateCatalog get catalog => widget.catalog;

  AgentActions get _agentActions => AgentActions(
        onEstimatesChanged: () async {
          if (mounted) setState(() {});
        },
        onAppDataChanged: () async {
          if (mounted) setState(() {});
        },
      );

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.wide;
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _editorShell(compact: compact, wide: wide)),
                if (!compact) ...[
                  const VerticalDivider(width: 1),
                  CollapsibleAgentPanel(
                    key: _agentKey,
                    catalog: catalog,
                    draft: draft,
                    initiallyExpanded: _showAgent,
                    onExpandedChanged: (value) => setState(() => _showAgent = value),
                    actions: _agentActions,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _editorShell({required bool compact, required bool wide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _editorTopBar(compact: compact, wide: wide),
        Expanded(child: _document(compact: compact)),
      ],
    );
  }

  Widget _editorTopBar({required bool compact, required bool wide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 8, compact ? 8 : 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _quotationCode(),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: compact ? 24 : 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    _StatusPulse(status: draft.status),
                  ],
                ),
              ),
              if (!compact) ...[
                _ExportPdfButton(onPressed: _exportPdf),
                const SizedBox(width: 8),
                _ExportXlsxButton(onPressed: _exportExcel),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: 'Save',
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_circle_outline),
              ),
              if (compact)
                AgentLauncherButton(onPressed: _openAgentSheet),
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
                    case 'schedule':
                      _createPaymentSchedule();
                    case 'type':
                      _editEstimateType();
                    case 'delete':
                      _deleteEstimate();
                    default:
                      if (value.startsWith('status:')) {
                        _saveAs(EstimateStatus.fromName(value.substring(7)));
                      }
                  }
                },
                itemBuilder: (context) => [
                  if (compact) ...[
                    const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                    const PopupMenuItem(value: 'excel', child: Text('Export Excel')),
                  ],
                  const PopupMenuItem(value: 'save', child: Text('Save')),
                  const PopupMenuItem(value: 'fill', child: Text('Catalog fill')),
                  const PopupMenuItem(value: 'confirm', child: Text('Confirm quantities')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'status:drafted', child: Text('Save as Drafted')),
                  const PopupMenuItem(value: 'status:completed', child: Text('Save as Completed')),
                  const PopupMenuItem(value: 'status:finalized', child: Text('Save as Finalized')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'terms', child: Text('Terms and conditions')),
                  const PopupMenuItem(value: 'schedule', child: Text('Payment schedule from T&C')),
                  const PopupMenuItem(value: 'type', child: Text('Change estimate type')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete estimate')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _quotationCode() {
    final yy = (draft.date.year % 100).toString().padLeft(2, '0');
    final digits = draft.id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length >= 3 ? digits.substring(digits.length - 3) : digits.padLeft(3, '0');
    return 'qt-$yy-$tail';
  }

  Widget _document({required bool compact}) {
    final sections = groupQuotation(draft);
    final totals = draft.totals;
    final pad = compact ? 16.0 : 24.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = compact ? constraints.maxWidth - pad * 2 : math.max(constraints.maxWidth - pad * 2, 1180.0);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.raised(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _documentLetterhead(compact: compact),
                  Scrollbar(
                    controller: _hScroll,
                    thumbVisibility: tableWidth > constraints.maxWidth - pad * 2,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(compact ? 16 : 36, 20, compact ? 16 : 36, 12),
                          child: Column(
                            children: [
                              if (!compact) _headerRow(),
                              if (sections.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Text(
                                    'Add a scope to this quotation',
                                    style: TextStyle(color: AppColors.muted.withValues(alpha: 0.8)),
                                  ),
                                )
                              else
                                for (var i = 0; i < sections.length; i++) _sectionBlock(sections[i], i, compact: compact),
                              const SizedBox(height: 20),
                              _addLineButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _documentFooter(totals, sections),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _documentLetterhead({required bool compact}) {
    final address = resolveCompanyAddress(
      prefsAddress: _companyAddress,
      draftAddress: draft.companyAddress,
    );
    final phone = resolveCompanyPhone(
      prefsPhone: _companyPhone,
      draftPhone: draft.companyPhone,
    );
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ColoredBox(
            color: Colors.white,
            child: Image.asset(
              estimateCompanyLogoAsset,
              height: compact ? 56 : 72,
              width: compact ? 200 : 280,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          [address, if (phone.isNotEmpty) phone].join('\n'),
          style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 15, height: 1.45),
        ),
      ],
    );
    final clientCard = Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: _editEstimateType,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: compact ? double.infinity : 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENT DETAILS',
                  style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.cardHover,
                      child: Text(
                        _initials(draft.client),
                        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.client.isEmpty ? 'Untitled client' : draft.client,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'attn: ${draft.estimateType.isEmpty ? 'quotation' : draft.estimateType.toLowerCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.45)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Project:', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        draft.project.isEmpty ? '—' : draft.project,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.text, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Container(
      color: const Color(0xFF3C3331),
      padding: EdgeInsets.fromLTRB(compact ? 20 : 40, 28, compact ? 20 : 40, 28),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [brand, const SizedBox(height: 20), clientCard])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: brand),
                const SizedBox(width: 24),
                clientCard,
              ],
            ),
    );
  }

  Widget _documentFooter(EstimateTotals totals, List<QuotationSection> sections) {
    final sum = sections.fold<double>(0, (value, section) => value + section.total);
    return Container(
      color: const Color(0xFF3C3331),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 720;
          final budget = _budgetBar(sections, sum);
          final calc = _totalsBlock(totals);
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [budget, const SizedBox(height: 24), calc],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(width: 240, child: budget),
              const Spacer(),
              SizedBox(width: 340, child: calc),
            ],
          );
        },
      ),
    );
  }

  Widget _budgetBar(List<QuotationSection> sections, double sum) {
    final top = sections.take(3).toList();
    if (top.isEmpty || sum <= 0) {
      return const SizedBox.shrink();
    }
    final palette = [AppColors.completed, AppColors.primary, AppColors.primary];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUDGET ALLOCATION',
          style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < top.length; i++)
                  Expanded(
                    flex: math.max(1, ((top[i].total / sum) * 100).round()),
                    child: ColoredBox(color: palette[i % palette.length]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < top.length; i++)
              Flexible(
                child: Text(
                  '${((top[i].total / sum) * 100).toStringAsFixed(1)}% ${_shortWorkType(top[i].workType)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette[i % palette.length], fontSize: 10, fontFamily: 'Consolas'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _totalsBlock(EstimateTotals totals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moneyRow('Subtotal', inr(totals.subtotal)),
        const SizedBox(height: 8),
        _moneyRow(
          'Taxes (GST)',
          inr(totals.gst18),
          badge: '${draft.gstPercent.toStringAsFixed(0)}%',
        ),
        if (totals.hvacTaxable > 0) ...[
          const SizedBox(height: 8),
          _moneyRow(
            'HVAC GST',
            inr(totals.gst28),
            badge: '${draft.hvacGstPercent.toStringAsFixed(0)}%',
          ),
        ],
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.35)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.sidebar,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAND TOTAL',
                      style: TextStyle(color: AppColors.primarySoft, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text('INR · incl. GST', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  inr(totals.grandTotal),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    fontFamily: 'Consolas',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _editTerms,
            child: Text(
              draft.effectiveTerms.isEmpty
                  ? 'Add terms and conditions'
                  : '${draft.effectiveTerms.length} terms and conditions',
            ),
          ),
        ),
      ],
    );
  }

  Widget _moneyRow(String label, String value, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 15)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
              child: Text(badge, style: TextStyle(color: AppColors.muted, fontSize: 10, fontFamily: 'Consolas')),
            ),
          ],
          const Spacer(),
          Text(value, style: TextStyle(color: AppColors.text, fontSize: 15, fontFamily: 'Consolas')),
        ],
      ),
    );
  }

  Widget _addLineButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addScope(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.45), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 20, color: AppColors.muted),
              SizedBox(width: 8),
              Text(
                'ADD LINE ITEM',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionBlock(QuotationSection section, int index, {required bool compact}) {
    final style = _sectionStyle(section.workType, index);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: style.$2, borderRadius: BorderRadius.circular(8)),
                child: Icon(style.$1, size: 18, color: style.$3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.workType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Add scope to ${section.workType}',
                visualDensity: VisualDensity.compact,
                onPressed: () => _addScope(workTypeId: section.lines.isEmpty ? null : section.lines.first.workTypeId),
                icon: Icon(Icons.add, size: 18, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < section.lines.length; i++) _scopeRow(section, section.lines[i], i, compact: compact),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${section.workType} subtotal:'.toUpperCase(),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  inr(section.total),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.text, fontSize: 15, fontFamily: 'Consolas', fontWeight: FontWeight.w600),
                ),
                if (!compact) const SizedBox(width: 40),
              ],
            ),
          ),
          Divider(height: 16, color: AppColors.outline.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  Widget _headerRow() {
    final style = TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _columns(
        children: [
          Text('S.NO', style: style),
          Text('SCOPE / DESCRIPTION', style: style),
          Text('PICTURE', style: style, textAlign: TextAlign.center),
          Text('UNIT', style: style, textAlign: TextAlign.center),
          Text('UNIT RATE', style: style, textAlign: TextAlign.right),
          Text('QTY', style: style, textAlign: TextAlign.center),
          Text('PRICE', style: style, textAlign: TextAlign.right),
          Text('DISCOUNT %', style: style, textAlign: TextAlign.right),
          Text('NET PRICE', style: style, textAlign: TextAlign.right),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _scopeRow(QuotationSection section, EstimateLine line, int index, {required bool compact}) {
    if (compact) return _compactScopeRow(section, line, index);
    final editor = _editorFor(line);
    final pending = !line.quantityConfirmed && line.effectiveQuantity != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _columns(
        children: [
          _cellField(
            controller: editor.sno,
            focusNode: editor.snoFocus,
            hintText: _lineCode(section, index),
            style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 14),
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
                style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w500),
                onChanged: (value) => _patch(line.id, (item) {
                  if (item.description.trim() == item.name.trim()) {
                    item.description = '';
                  }
                  item.name = value;
                }),
              ),
              _cellField(
                controller: editor.details,
                focusNode: editor.detailsFocus,
                hintText: 'Description',
                maxLines: 2,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
                onChanged: (value) => _patch(line.id, (item) {
                  item.description = value;
                }),
              ),
            ],
          ),
          _linePicture(line),
          _unitDropdown(line),
          _cellField(
            controller: editor.unitRate,
            focusNode: editor.unitRateFocus,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AppColors.muted, fontSize: 14, fontFamily: 'Consolas'),
            onChanged: (value) {
              _patch(line.id, (item) {
                item.unitRate = parseNumber(value);
                item.source = LineSource.user;
              });
            },
          ),
          _qtyField(line, editor, pending),
          _computedMoney(line.price, pending: pending, empty: line.unitRate == null),
          _cellField(
            controller: editor.discount,
            focusNode: editor.discountFocus,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hintText: '0',
            style: TextStyle(color: AppColors.muted, fontSize: 14, fontFamily: 'Consolas'),
            onChanged: (value) {
              _patch(line.id, (item) {
                item.discountPercent = (parseNumber(value) ?? 0).clamp(0, 100).toDouble();
              });
            },
          ),
          _computedMoney(line.netPrice, pending: pending, empty: line.unitRate == null),
          IconButton(
            tooltip: 'Delete scope',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
            onPressed: () => _deleteScope(line),
          ),
        ],
      ),
    );
  }

  Widget _compactScopeRow(QuotationSection section, EstimateLine line, int index) {
    final editor = _editorFor(line);
    final pending = !line.quantityConfirmed && line.effectiveQuantity != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                child: _cellField(
                  controller: editor.sno,
                  focusNode: editor.snoFocus,
                  hintText: _lineCode(section, index),
                  style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 13),
                  onChanged: (value) => _patch(line.id, (item) {
                    item.workScopeCode = value.trim().isEmpty ? null : value.trim();
                  }),
                ),
              ),
              Expanded(
                child: _cellField(
                  controller: editor.name,
                  focusNode: editor.nameFocus,
                  hintText: 'Scope name',
                  style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w500),
                  onChanged: (value) => _patch(line.id, (item) {
                    if (item.description.trim() == item.name.trim()) {
                      item.description = '';
                    }
                    item.name = value;
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Delete scope',
                onPressed: () => _deleteScope(line),
                icon: Icon(Icons.delete_outline, color: AppColors.muted),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _cellField(
                  controller: editor.details,
                  focusNode: editor.detailsFocus,
                  hintText: 'Description',
                  maxLines: 2,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                  onChanged: (value) => _patch(line.id, (item) {
                    item.description = value;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              _linePicture(line),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _unitDropdown(line)),
              const SizedBox(width: 8),
              Expanded(
                child: _cellField(
                  controller: editor.unitRate,
                  focusNode: editor.unitRateFocus,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hintText: 'Rate',
                  style: TextStyle(color: AppColors.muted, fontSize: 14, fontFamily: 'Consolas'),
                  onChanged: (value) {
                    _patch(line.id, (item) {
                      item.unitRate = parseNumber(value);
                      item.source = LineSource.user;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 84, child: _qtyField(line, editor, pending)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _labeledValue('PRICE', line.unitRate == null ? '—' : inr(line.price), pending: pending),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cellField(
                  controller: editor.discount,
                  focusNode: editor.discountFocus,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hintText: 'Discount %',
                  style: TextStyle(color: AppColors.muted, fontSize: 14, fontFamily: 'Consolas'),
                  onChanged: (value) {
                    _patch(line.id, (item) {
                      item.discountPercent = (parseNumber(value) ?? 0).clamp(0, 100).toDouble();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeledValue('NET PRICE', line.unitRate == null ? '—' : inr(line.netPrice), pending: pending),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyField(EstimateLine line, _LineEditors editor, bool pending) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          controller: editor.quantity,
          focusNode: editor.quantityFocus,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: TextStyle(
            color: pending ? AppColors.down : AppColors.text,
            fontSize: 14,
            fontFamily: 'Consolas',
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: pending ? AppColors.down.withValues(alpha: 0.12) : AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pending ? AppColors.down.withValues(alpha: 0.55) : AppColors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pending ? AppColors.down.withValues(alpha: 0.55) : AppColors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pending ? AppColors.down : AppColors.up, width: 1.4),
            ),
          ),
          onChanged: (value) {
            _patch(line.id, (item) {
              item.quantity = parseNumber(value);
              item.quantityConfirmed = item.quantity != null;
              item.source = LineSource.user;
            });
          },
        ),
        if (pending)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.down,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _columns({required List<Widget> children}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 56, child: children[0]),
        const SizedBox(width: 12),
        Expanded(child: children[1]),
        const SizedBox(width: 8),
        SizedBox(width: 56, child: children[2]),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: children[3]),
        const SizedBox(width: 8),
        SizedBox(width: 88, child: children[4]),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: children[5]),
        const SizedBox(width: 8),
        SizedBox(width: 100, child: children[6]),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: children[7]),
        const SizedBox(width: 8),
        SizedBox(width: 110, child: children[8]),
        SizedBox(width: 40, child: children[9]),
      ],
    );
  }

  Widget _computedMoney(double value, {required bool pending, required bool empty}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        empty ? '—' : inr(value),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: pending ? AppColors.down : AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Consolas',
        ),
      ),
    );
  }

  Widget _labeledValue(String label, String value, {required bool pending}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: pending ? AppColors.down : AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Consolas',
          ),
        ),
      ],
    );
  }

  Widget _linePicture(EstimateLine line) {
    final fileId = line.imageFileId?.trim();
    final uploading = _uploadingPictures.contains(line.id);
    final url = fileId == null || fileId.isEmpty
        ? null
        : _storage.getFilePreviewUrl(Env.portfolioImagesBucket, fileId, width: 96, height: 96);
    return Tooltip(
      message: url == null ? 'Add picture' : 'Change picture. Long-press to remove.',
      child: InkWell(
        onTap: uploading ? null : () => _pickLinePicture(line),
        onLongPress: uploading || url == null ? null : () => _clearLinePicture(line),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: uploading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : url == null
                  ? Icon(Icons.add_photo_alternate_outlined, size: 20, color: AppColors.muted)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, size: 20, color: AppColors.muted),
                    ),
        ),
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
    TextStyle? style,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: textAlign,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: keyboardType == null ? null : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: style ?? Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: hintText,
        hintStyle: (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(color: AppColors.muted.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.up, width: 1)),
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
        for (final unit in units) DropdownMenuItem(value: unit, child: Text(unit, textAlign: TextAlign.center)),
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
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        isDense: true,
        isExpanded: true,
        value: value,
        items: items,
        onChanged: onChanged,
        style: TextStyle(color: AppColors.muted, fontSize: 13),
        dropdownColor: AppColors.cardHover,
      ),
    );
  }

  (IconData, Color, Color) _sectionStyle(String workType, int index) {
    final name = workType.toLowerCase();
    final icon = name.contains('electr') || name.contains('hvac') || name.contains('ac')
        ? Icons.bolt_rounded
        : name.contains('plumb') || name.contains('water')
            ? Icons.water_drop_outlined
            : name.contains('paint') || name.contains('finish')
                ? Icons.format_paint_outlined
                : name.contains('wood') || name.contains('carpent')
                    ? Icons.carpenter_outlined
                    : Icons.architecture_outlined;
    final palettes = [
      (const Color(0xFF4EB397), const Color(0xFF00382B)),
      (const Color(0xFF01A89D), const Color(0xFF003531)),
      (AppColors.primary, AppColors.onPrimary),
    ];
    final colors = palettes[index % palettes.length];
    return (icon, colors.$1, colors.$2);
  }

  String _lineCode(QuotationSection section, int index) {
    return '${section.serialNo.toString().padLeft(2, '0')}.${index + 1}';
  }

  String _shortWorkType(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return name;
    return parts.first;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final value = parts.first;
      return (value.length >= 2 ? value.substring(0, 2) : value).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _patch(String lineId, void Function(EstimateLine line) update) {
    draft.updateLine(lineId, (item) {
      update(item);
      item.source = LineSource.user;
    });
  }

  Future<void> _pickLinePicture(EstimateLine line) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    setState(() => _uploadingPictures.add(line.id));
    final uploaded = await _storage.uploadPortfolioImage(
      UploadBytes(bytes: bytes, filename: file.name),
    );
    if (!mounted) return;
    setState(() => _uploadingPictures.remove(line.id));
    uploaded.when(
      success: (id) => _patch(line.id, (item) => item.imageFileId = id),
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.userMessage)),
        );
      },
    );
  }

  void _clearLinePicture(EstimateLine line) {
    _patch(line.id, (item) => item.imageFileId = null);
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

    final scope = await CatalogRepository.instance.addScope(
      workTypeId: type.id,
      name: result.name,
      description: result.details,
      unit: result.unit,
      suggestedRate: result.rate,
      code: result.code.isEmpty ? null : result.code,
    );

    draft.addLine(
      EstimateLine(
        id: 'line_${DateTime.now().microsecondsSinceEpoch}',
        workTypeId: type.id,
        workType: type.name,
        serialNo: type.serialNo,
        scopeId: scope.id,
        workScopeCode: result.code.isEmpty ? scope.code : result.code,
        name: result.name,
        description: result.details,
        unit: result.unit,
        quantity: result.quantity,
        suggestedQuantity: result.quantity,
        quantityConfirmed: true,
        unitRate: result.rate ?? scope.suggestedRate,
        discountPercent: result.discountPercent,
        imageFileId: result.imageFileId,
        source: LineSource.user,
        custom: scope.userAdded,
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

  Future<void> _createPaymentSchedule() async {
    await _save();
    if (!mounted) return;
    final plans = await ScheduleService.instance.createPaymentPlan(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          plans.isEmpty
              ? 'No payment percentages found in T&C'
              : 'Scheduled ${plans.length} collections totalling ${inr(draft.totals.grandTotal)}',
        ),
      ),
    );
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
      final saved = await saveAndOpenExport(
        bytes: await _pdf.buildBytes(draft),
        filename: QuotationPdf.fileName(draft),
        mime: 'application/pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kIsWeb ? 'PDF downloaded' : 'Exported $saved')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  Future<void> _exportExcel() async {
    try {
      final saved = await saveAndOpenExport(
        bytes: await _excel.buildBytes(draft),
        filename: ExcelExporter.fileName(draft),
        mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kIsWeb ? 'Excel downloaded' : 'Exported $saved')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel export failed: $error')));
    }
  }

  Future<void> _openAgentSheet() async {
    await showAgentSheet(
      context: context,
      panel: AgentPanel(
        catalog: catalog,
        draft: draft,
        onCollapse: () => Navigator.pop(context),
        actions: _agentActions,
      ),
    );
  }
}

class _StatusPulse extends StatelessWidget {
  const _StatusPulse({required this.status});

  final EstimateStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EstimateStatus.drafted => ('drafting', AppColors.primarySoft),
      EstimateStatus.completed => ('completed', AppColors.completed),
      EstimateStatus.finalized => ('finalized', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.cardHover,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ExportPdfButton extends StatelessWidget {
  const _ExportPdfButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.up,
        side: BorderSide(color: AppColors.up.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: const Text('export pdf', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}

class _ExportXlsxButton extends StatelessWidget {
  const _ExportXlsxButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: const Icon(Icons.table_view_outlined, size: 18),
      label: const Text('export xlsx', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
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
    this.discountPercent = 0,
    this.imageFileId,
  });

  final String typeId;
  final String code;
  final String name;
  final String details;
  final String unit;
  final double quantity;
  final double? rate;
  final double discountPercent;
  final String? imageFileId;
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
  late final TextEditingController _discount;
  late String _typeId;
  late String _unit;
  String? _imageFileId;
  bool _uploadingPicture = false;

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
    _discount = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _sno.dispose();
    _name.dispose();
    _details.dispose();
    _unitRate.dispose();
    _quantity.dispose();
    _discount.dispose();
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
        discountPercent: (parseNumber(_discount.text) ?? 0).clamp(0, 100).toDouble(),
        imageFileId: _imageFileId,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _uploadingPicture ? null : _pickPicture,
                    icon: _uploadingPicture
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_imageFileId == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_outline),
                    label: Text(_imageFileId == null ? 'Add picture' : 'Picture added'),
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
                      child: TextFormField(
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Discount %',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: Listenable.merge([_unitRate, _quantity, _discount]),
                  builder: (context, _) {
                    final qty = parseNumber(_quantity.text) ?? 0;
                    final rate = parseNumber(_unitRate.text);
                    final price = rate == null ? null : qty * rate;
                    final disc = (parseNumber(_discount.text) ?? 0).clamp(0, 100);
                    final net = price == null ? null : price * (1 - disc / 100);
                    return Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(price == null ? '—' : inr(price)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Net Price',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(net == null ? '—' : inr(net)),
                          ),
                        ),
                      ],
                    );
                  },
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

  Future<void> _pickPicture() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    setState(() => _uploadingPicture = true);
    final uploaded = await StorageRepositoryImpl().uploadPortfolioImage(
      UploadBytes(bytes: bytes, filename: file.name),
    );
    if (!mounted) return;
    setState(() => _uploadingPicture = false);
    uploaded.when(
      success: (id) => setState(() => _imageFileId = id),
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.userMessage)),
        );
      },
    );
  }
}

class _LineEditors {
  _LineEditors(EstimateLine line)
      : sno = TextEditingController(text: line.workScopeCode ?? ''),
        name = TextEditingController(text: line.name.isEmpty ? line.description : line.name),
        details = TextEditingController(text: scopeDetails(line)),
        unitRate = TextEditingController(text: formatQty(line.unitRate)),
        quantity = TextEditingController(text: formatQty(line.effectiveQuantity)),
        discount = TextEditingController(text: formatQty(line.discountPercent == 0 ? null : line.discountPercent));

  final snoFocus = FocusNode();
  final nameFocus = FocusNode();
  final detailsFocus = FocusNode();
  final unitRateFocus = FocusNode();
  final quantityFocus = FocusNode();
  final discountFocus = FocusNode();

  final TextEditingController sno;
  final TextEditingController name;
  final TextEditingController details;
  final TextEditingController unitRate;
  final TextEditingController quantity;
  final TextEditingController discount;

  void syncFrom(EstimateLine line) {
    _setIfUnfocused(sno, snoFocus, line.workScopeCode ?? '');
    _setIfUnfocused(name, nameFocus, line.name.isEmpty ? line.description : line.name);
    _setIfUnfocused(details, detailsFocus, scopeDetails(line));
    _setIfUnfocused(unitRate, unitRateFocus, formatQty(line.unitRate));
    _setIfUnfocused(quantity, quantityFocus, formatQty(line.effectiveQuantity));
    _setIfUnfocused(discount, discountFocus, formatQty(line.discountPercent == 0 ? null : line.discountPercent));
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
    discountFocus.dispose();
    sno.dispose();
    name.dispose();
    details.dispose();
    unitRate.dispose();
    quantity.dispose();
    discount.dispose();
  }
}
