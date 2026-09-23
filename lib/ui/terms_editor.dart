import 'package:flutter/material.dart';

import '../models/terms_and_conditions.dart';
import '../theme/app_theme.dart';

class TermsAndConditionsForm extends StatefulWidget {
  const TermsAndConditionsForm({
    super.key,
    required this.templates,
    required this.terms,
    required this.onChanged,
    this.compact = false,
    this.showHero = false,
    this.fillViewport = false,
  });

  final List<TermsTemplate> templates;
  final List<String> terms;
  final ValueChanged<List<String>> onChanged;
  final bool compact;
  final bool showHero;
  final bool fillViewport;

  @override
  State<TermsAndConditionsForm> createState() => _TermsAndConditionsFormState();
}

class _TermsAndConditionsFormState extends State<TermsAndConditionsForm> {
  final _custom = TextEditingController();
  String? _templateId;
  static const _customId = '__custom__';

  List<TermsTemplate> get _templates =>
      widget.templates.isEmpty ? builtInTermsTemplates : widget.templates;

  @override
  void initState() {
    super.initState();
    _templateId = _matchingTemplateId(widget.terms) ?? _customId;
  }

  @override
  void didUpdateWidget(covariant TermsAndConditionsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTerms(oldWidget.terms, widget.terms)) {
      _templateId = _matchingTemplateId(widget.terms) ?? _customId;
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String? _matchingTemplateId(List<String> terms) {
    for (final template in _templates) {
      if (_sameTerms(template.termsAndConditions, terms)) return template.id;
    }
    return null;
  }

  bool _sameTerms(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].trim() != b[i].trim()) return false;
    }
    return true;
  }

  void _emit(List<String> next) => widget.onChanged(sanitizeTerms(next));

  void _applyTemplate(TermsTemplate template) {
    _templateId = template.id;
    _emit(template.termsAndConditions);
  }

  void _applyCustomDraft() {
    _templateId = _customId;
    _emit(const []);
  }

  Future<void> _editTerm(int index) async {
    final controller = TextEditingController(text: widget.terms[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('edit term ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Terms and conditions clause',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    final next = [...widget.terms];
    next[index] = result;
    _emit(next);
  }

  void _addCustom() {
    final text = _custom.text.trim();
    if (text.isEmpty) return;
    _custom.clear();
    _emit([...widget.terms, text]);
  }

  String _chipLabel(TermsTemplate template) {
    final name = template.name.trim();
    final cut = name.indexOf('(');
    return (cut > 0 ? name.substring(0, cut) : name).trim();
  }

  @override
  Widget build(BuildContext context) {
    final list = _clauseList();
    return Column(
      mainAxisSize: widget.fillViewport ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHero) _hero(),
        _templateChips(),
        const SizedBox(height: 20),
        if (widget.fillViewport) Expanded(child: list) else list,
        _composer(),
      ],
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'terms & conditions',
        style: TextStyle(
          color: AppColors.primarySoft,
          fontSize: widget.compact ? 28 : 32,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _templateChips() {
    final selected = _templateId ?? _customId;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final template in _templates) ...[
            _TemplateChip(
              label: _chipLabel(template),
              selected: selected == template.id,
              onTap: () => _applyTemplate(template),
            ),
            const SizedBox(width: 10),
          ],
          _TemplateChip(
            label: 'Custom Draft',
            selected: selected == _customId,
            onTap: _applyCustomDraft,
          ),
        ],
      ),
    );
  }

  Widget _clauseList() {
    if (widget.terms.isEmpty) {
      return _emptyState();
    }
    final children = [
      for (var i = 0; i < widget.terms.length; i++) ...[
        _ClauseCard(
          index: i,
          text: widget.terms[i],
          onEdit: () => _editTerm(i),
          onDelete: () {
            final next = [...widget.terms]..removeAt(i);
            _emit(next);
          },
        ),
        if (i < widget.terms.length - 1) const SizedBox(height: 12),
      ],
    ];
    if (widget.fillViewport) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: children,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _emptyState() {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.cardHover, shape: BoxShape.circle),
            child: Icon(Icons.gavel, color: AppColors.muted, size: 28),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'No terms yet. Pick a template above or add a custom clause below to build your contract framework.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ),
        ],
      ),
    );
    if (widget.fillViewport) return Center(child: body);
    return body;
  }

  Widget _composer() {
    final size = widget.compact ? 72.0 : 88.0;
    return Padding(
      padding: EdgeInsets.only(top: widget.fillViewport ? 12 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'add clause',
                    style: TextStyle(color: AppColors.primarySoft, fontSize: 12, letterSpacing: 1.4),
                  ),
                ),
                TextField(
                  controller: _custom,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type new condition here...',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _addCustom(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: size,
            height: size,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _addCustom,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.onPrimary),
                    const SizedBox(height: 2),
                    Text(
                      'INSERT',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.cardHover : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.outline : AppColors.outline.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: selected ? AppColors.text : AppColors.muted,
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClauseCard extends StatelessWidget {
  const _ClauseCard({
    required this.index,
    required this.text,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final String text;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.cardHover,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: AppColors.primarySoft, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(text, style: const TextStyle(height: 1.45, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TermsEditorPage extends StatefulWidget {
  const TermsEditorPage({
    super.key,
    required this.terms,
    required this.templates,
  });

  final List<String> terms;
  final List<TermsTemplate> templates;

  @override
  State<TermsEditorPage> createState() => _TermsEditorPageState();
}

class _TermsEditorPageState extends State<TermsEditorPage> {
  late List<String> _terms;

  @override
  void initState() {
    super.initState();
    _terms = sanitizeTerms(widget.terms);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 4, compact ? 16 : 24, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_terms),
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    child: const Text('SAVE TERMS', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 8, compact ? 16 : 28, compact ? 16 : 20),
                child: TermsAndConditionsForm(
                  templates: widget.templates,
                  terms: _terms,
                  compact: compact,
                  showHero: true,
                  fillViewport: true,
                  onChanged: (next) => setState(() => _terms = next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<List<String>?> showTermsAndConditionsEditor(
  BuildContext context, {
  required List<String> terms,
  required List<TermsTemplate> templates,
}) {
  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (context) => TermsEditorPage(terms: terms, templates: templates),
    ),
  );
}
