import 'package:flutter/material.dart';

import '../models/estimate_models.dart';
import '../util/format.dart';
import 'catalog_forms.dart';

class RateCardPage extends StatefulWidget {
  const RateCardPage({super.key, required this.catalog, this.query = ''});

  final EstimateCatalog catalog;
  final String query;

  @override
  State<RateCardPage> createState() => _RateCardPageState();
}

class _RateCardPageState extends State<RateCardPage> {
  String _workType = 'All';

  EstimateCatalog get catalog => widget.catalog;

  @override
  Widget build(BuildContext context) {
    final items = catalog.rateCard.where((item) {
      final typeOk = _workType == 'All' || item.workType == _workType;
      final queryOk = widget.query.isEmpty || item.matches(widget.query);
      return typeOk && queryOk;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addArea,
                icon: const Icon(Icons.meeting_room_outlined, size: 18),
                label: const Text('Add area'),
              ),
              OutlinedButton.icon(
                onPressed: _addWorkType,
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('Add work type'),
              ),
              OutlinedButton.icon(
                onPressed: _addScope,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Add scope'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final name in catalog.workTypeNames)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: _workType == name,
                    onSelected: (_) => setState(() => _workType = name),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap a scope to edit unit and unit price. Changes are saved to local cache for new quotations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = items[index];
              final scope = catalog.scopeById(item.id);
              final edited = scope?.userEdited == true || scope?.userAdded == true;
              return ListTile(
                title: Text(item.workScope, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    item.workType,
                    if (item.unit.isNotEmpty) item.unit,
                    if (item.typicalAreas.isNotEmpty) item.typicalAreas.join(', '),
                    if (edited) 'cached',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.suggestedRate == null ? '—' : inr(item.suggestedRate),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    IconButton(
                      tooltip: 'Edit unit and price',
                      onPressed: () => _editItem(item),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
                onTap: () => _editItem(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addArea() async {
    final area = await showAddAreaDialog(context, catalog: catalog);
    if (!mounted || area == null) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved area “${area.name}” to local cache')));
  }

  Future<void> _addWorkType() async {
    final type = await showAddWorkTypeDialog(context, catalog: catalog);
    if (!mounted || type == null) return;
    setState(() => _workType = type.name);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved work type “${type.name}” to local cache')));
  }

  Future<void> _addScope() async {
    if (catalog.workTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a work type first')),
      );
      return;
    }
    final typeId = _workType == 'All' ? null : catalog.workTypeById(_workType)?.id;
    final scope = await showAddScopeDialog(context, catalog: catalog, workTypeId: typeId);
    if (!mounted || scope == null) return;
    setState(() => _workType = scope.workType);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved scope “${scope.name}” to local cache')));
  }

  Future<void> _editItem(RateCardItem item) async {
    final scope = catalog.scopeById(item.id);
    if (scope == null) return;
    final updated = await showEditScopePricingDialog(context, scope: scope);
    if (!mounted || updated == null) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${updated.unit} @ ${inr(updated.suggestedRate)} to local cache')),
    );
  }
}
