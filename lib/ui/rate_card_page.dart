import 'package:flutter/material.dart';

import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'catalog_forms.dart';

class RateCardPage extends StatefulWidget {
  const RateCardPage({
    super.key,
    required this.catalog,
    this.query = '',
    this.compact = false,
  });

  final EstimateCatalog catalog;
  final String query;
  final bool compact;

  @override
  State<RateCardPage> createState() => _RateCardPageState();
}

class _RateCardPageState extends State<RateCardPage> {
  final _search = TextEditingController();
  String _workType = 'All';

  EstimateCatalog get catalog => widget.catalog;

  @override
  void didUpdateWidget(covariant RateCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && widget.query.isNotEmpty) {
      _search.text = widget.query;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_CatalogRow> get _rows {
    final q = _search.text.trim().isEmpty ? widget.query.trim() : _search.text.trim();
    final rows = <_CatalogRow>[];
    for (final type in catalog.workTypes) {
      if (_workType != 'All' && type.name != _workType) continue;
      for (var i = 0; i < type.scopes.length; i++) {
        final scope = type.scopes[i];
        final item = scope.toRateCardItem();
        if (q.isNotEmpty && !item.matches(q)) continue;
        rows.add(_CatalogRow(type: type, scope: scope, index: i, item: item));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact || MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final pad = compact ? 16.0 : 24.0;
    final rows = _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, compact ? 4 : 8, pad, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(compact: compact),
                      const SizedBox(height: 20),
                      _searchField(),
                      const SizedBox(height: 16),
                      _filters(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, compact ? AppBreakpoints.navClearance : 32),
                sliver: SliverToBoxAdapter(
                  child: _tableCard(rows: rows, compact: compact),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero({required bool compact}) {
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _GhostAction(icon: Icons.add, label: 'Area', onTap: _addArea),
        _GhostAction(icon: Icons.category_outlined, label: 'Type', onTap: _addWorkType),
        _FilledAction(icon: Icons.add_task, label: 'Scope', onTap: _addScope),
      ],
    );
    final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                const TextSpan(
                  text: 'rate catalog',
                  children: [TextSpan(text: '.', style: TextStyle(color: AppColors.primary))],
                ),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 32 : 48,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  'Manage standard scopes, measurement units, and baseline rates for accurate project estimation.',
                  style: TextStyle(color: AppColors.muted, fontSize: compact ? 14 : 16, height: 1.4),
                ),
              ),
            ],
          );
    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        if (compact) title else Expanded(child: title),
        if (compact) const SizedBox(height: 16) else const SizedBox(width: 16),
        actions,
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search work type, scope or area',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF5ADACE)),
        ),
      ),
    );
  }

  Widget _filters() {
    final names = catalog.workTypeNames;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'FILTERS',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.55), fontSize: 10, letterSpacing: 1.6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < names.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _TypeChip(
                    label: names[i] == 'All' ? 'All Types' : names[i],
                    selected: _workType == names[i],
                    onTap: () => setState(() => _workType = names[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCard({required List<_CatalogRow> rows, required bool compact}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, Color(0xFF5ADACE), Colors.transparent],
                ),
              ),
              child: SizedBox(width: 3),
            ),
          ),
          Column(
            children: [
              if (!compact) const _TableHeader(),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No scopes yet. Add a work type, then a scope. Tap a row to edit unit and rate.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else
                for (var i = 0; i < rows.length; i++)
                  _ScopeRow(
                    row: rows[i],
                    compact: compact,
                    last: i == rows.length - 1,
                    onEdit: () => _editItem(rows[i].item),
                  ),
            ],
          ),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a work type first')));
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

class _CatalogRow {
  const _CatalogRow({
    required this.type,
    required this.scope,
    required this.index,
    required this.item,
  });

  final WorkTypeSummary type;
  final WorkScope scope;
  final int index;
  final RateCardItem item;

  bool get custom => scope.userEdited || scope.userAdded;

  String get ref {
    final sno = type.serialNo.toString().padLeft(2, '0');
    final code = (scope.code ?? '').trim().toUpperCase();
    if (code.isNotEmpty) return '$sno.$code';
    return '$sno.${(index + 1).toString().padLeft(2, '0')}';
  }

  Color get dot {
    if (custom) return AppColors.outline;
    if (type.isHvac) return AppColors.completed;
    return const Color(0xFF5ADACE);
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF5ADACE),
        side: BorderSide(color: const Color(0xFF5ADACE).withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label.toUpperCase(), style: const TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w600)),
    );
  }
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF1A1010),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label.toUpperCase(), style: const TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.cardHover,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_circle, size: 14, color: Color(0xFF1A1010)),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: selected ? const Color(0xFF1A1010) : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
      color: AppColors.cardHover.withValues(alpha: 0.45),
      child: const Row(
        children: [
          SizedBox(
            width: 56,
            child: Text('REF', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4)),
          ),
          Expanded(
            flex: 5,
            child: Text('SCOPE DESCRIPTION', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'BASE UNIT',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'TYPICAL RATE',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              'ACT',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.row,
    required this.compact,
    required this.last,
    required this.onEdit,
  });

  final _CatalogRow row;
  final bool compact;
  final bool last;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final unit = row.scope.unit.trim().isEmpty ? '—' : row.scope.unit;
    final rate = row.item.suggestedRate == null ? '—' : inr(row.item.suggestedRate);
    final name = Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: row.dot, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.scope.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (row.custom) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cached, size: 12, color: AppColors.primary),
                SizedBox(width: 4),
                Text('CUSTOM', style: TextStyle(color: AppColors.primary, fontSize: 10, letterSpacing: 0.8)),
              ],
            ),
          ),
        ],
      ],
    );
    final unitChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Text(unit, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
    );
    final rateText = Text(
      rate,
      style: TextStyle(
        color: AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: row.custom ? [Shadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10)] : null,
      ),
    );
    final edit = IconButton(
      tooltip: 'Edit unit and price',
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: EdgeInsets.fromLTRB(22, compact ? 14 : 16, 8, compact ? 14 : 16),
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: AppColors.outline.withValues(alpha: 0.45))),
          ),
          child: compact
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          const SizedBox(height: 6),
                          Text(
                            '${row.ref}  ·  $unit  ·  $rate',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    edit,
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(row.ref, style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4)),
                    ),
                    Expanded(flex: 5, child: name),
                    Expanded(
                      flex: 2,
                      child: Align(alignment: Alignment.centerRight, child: unitChip),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(alignment: Alignment.centerRight, child: rateText),
                    ),
                    SizedBox(width: 48, child: edit),
                  ],
                ),
        ),
      ),
    );
  }
}
