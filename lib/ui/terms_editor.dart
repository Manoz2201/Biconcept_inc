import 'package:flutter/material.dart';

import '../models/terms_and_conditions.dart';

class TermsAndConditionsForm extends StatefulWidget {
  const TermsAndConditionsForm({
    super.key,
    required this.templates,
    required this.terms,
    required this.onChanged,
    this.compact = false,
  });

  final List<TermsTemplate> templates;
  final List<String> terms;
  final ValueChanged<List<String>> onChanged;
  final bool compact;

  @override
  State<TermsAndConditionsForm> createState() => _TermsAndConditionsFormState();
}

class _TermsAndConditionsFormState extends State<TermsAndConditionsForm> {
  final _custom = TextEditingController();
  String? _templateId;

  List<TermsTemplate> get _templates =>
      widget.templates.isEmpty ? builtInTermsTemplates : widget.templates;

  @override
  void initState() {
    super.initState();
    _templateId = _matchingTemplateId(widget.terms);
  }

  @override
  void didUpdateWidget(covariant TermsAndConditionsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTerms(oldWidget.terms, widget.terms)) {
      _templateId = _matchingTemplateId(widget.terms);
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

  Future<void> _editTerm(int index) async {
    final controller = TextEditingController(text: widget.terms[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit term ${index + 1}'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Terms and conditions clause',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'These print under OTHER TERMS AND CONDITIONS on the quotation.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final template in _templates)
              ChoiceChip(
                label: Text(template.name),
                selected: _templateId == template.id,
                onSelected: (_) => _applyTemplate(template),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.terms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No terms yet. Pick a template or add a custom clause.', style: theme.textTheme.bodyMedium),
          ),
        for (var i = 0; i < widget.terms.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 14,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
              ),
              title: Text(widget.terms[i]),
              onTap: () => _editTerm(i),
              trailing: IconButton(
                tooltip: 'Remove',
                onPressed: () {
                  final next = [...widget.terms]..removeAt(i);
                  _emit(next);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _custom,
                minLines: widget.compact ? 1 : 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Add a custom term',
                  hintText: 'e.g. Site measurements will govern final billing.',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonal(
                onPressed: _addCustom,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<List<String>?> showTermsAndConditionsEditor(
  BuildContext context, {
  required List<String> terms,
  required List<TermsTemplate> templates,
}) {
  var current = sanitizeTerms(terms);
  return showDialog<List<String>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Terms and conditions'),
        content: SizedBox(
          width: 640,
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: TermsAndConditionsForm(
                  templates: templates,
                  terms: current,
                  compact: true,
                  onChanged: (next) => setState(() => current = next),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, current),
            child: const Text('Save terms'),
          ),
        ],
      );
    },
  );
}
