import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/draft_store.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'estimate_type_picker.dart';
import 'quotation_editor.dart';

class EstimatesPage extends StatelessWidget {
  const EstimatesPage({
    super.key,
    required this.drafts,
    required this.catalog,
    required this.compact,
    required this.statusFilter,
    required this.onStatusFilter,
    required this.onCreate,
    required this.onChanged,
  });

  final List<EstimateDraft> drafts;
  final EstimateCatalog catalog;
  final bool compact;
  final EstimateStatus? statusFilter;
  final ValueChanged<EstimateStatus?> onStatusFilter;
  final VoidCallback onCreate;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return _EstimatesBody(
      drafts: drafts,
      catalog: catalog,
      compact: compact,
      statusFilter: statusFilter,
      onStatusFilter: onStatusFilter,
      onCreate: onCreate,
      onChanged: onChanged,
    );
  }
}

class _EstimatesBody extends StatefulWidget {
  const _EstimatesBody({
    required this.drafts,
    required this.catalog,
    required this.compact,
    required this.statusFilter,
    required this.onStatusFilter,
    required this.onCreate,
    required this.onChanged,
  });

  final List<EstimateDraft> drafts;
  final EstimateCatalog catalog;
  final bool compact;
  final EstimateStatus? statusFilter;
  final ValueChanged<EstimateStatus?> onStatusFilter;
  final VoidCallback onCreate;
  final Future<void> Function() onChanged;

  @override
  State<_EstimatesBody> createState() => _EstimatesBodyState();
}

class _EstimatesBodyState extends State<_EstimatesBody> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<EstimateDraft> get _items {
    final q = _search.text.trim().toLowerCase();
    return widget.drafts.where((draft) {
      final statusOk = widget.statusFilter == null || draft.status == widget.statusFilter;
      final queryOk = q.isEmpty ||
          draft.client.toLowerCase().contains(q) ||
          draft.project.toLowerCase().contains(q) ||
          draft.estimateType.toLowerCase().contains(q) ||
          estimateDisplayCode(draft).toLowerCase().contains(q);
      return statusOk && queryOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = EstimateAnalytics.from(widget.drafts);
    final items = _items;
    final pad = widget.compact ? 16.0 : 24.0;
    final now = DateTime.now();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, widget.compact ? 4 : 8, pad, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Hero(compact: widget.compact, quarterLabel: 'q$quarter.${now.year}'),
                      const SizedBox(height: 20),
                      _SearchFilters(
                        controller: _search,
                        statusFilter: widget.statusFilter,
                        onQuery: (_) => setState(() {}),
                        onStatusFilter: widget.onStatusFilter,
                      ),
                      const SizedBox(height: 20),
                      _StatsRow(analytics: analytics, drafts: widget.drafts),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    noneAtAll: widget.drafts.isEmpty,
                    onCreate: widget.onCreate,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width >= 1100 ? 3 : width >= 700 ? 2 : 1;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 204,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final draft = items[index];
                            return _EstimateCard(
                              draft: draft,
                              onOpen: () => _open(draft),
                              onMenu: (value) => _onMenu(draft, value),
                            );
                          },
                          childCount: items.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _open(EstimateDraft draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuotationEditorPage(catalog: widget.catalog, draft: draft),
      ),
    );
    await widget.onChanged();
  }

  Future<void> _onMenu(EstimateDraft draft, String value) async {
    switch (value) {
      case 'type':
        final next = await showEstimateTypePicker(context, current: draft.estimateType);
        if (next == null || !mounted) return;
        draft.setEstimateType(next);
        await DraftStore().save(draft);
        await widget.onChanged();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete estimate'),
            content: Text(
              'Delete the estimate for ${draft.client.isEmpty ? 'this client' : draft.client}? This cannot be undone.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await DraftStore().delete(draft.id);
        await widget.onChanged();
      default:
        if (value.startsWith('status:')) {
          draft.setStatus(EstimateStatus.fromName(value.substring(7)));
          await DraftStore().save(draft);
          await widget.onChanged();
        }
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.compact, required this.quarterLabel});

  final bool compact;
  final String quarterLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'estimates',
              style: TextStyle(
                color: AppColors.text,
                fontSize: compact ? 32 : 48,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  quarterLabel.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'review, manage, and dispatch architectural proposals. tracked across their lifecycle from conception to execution.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 14 : 16, height: 1.4),
        ),
      ],
    );
  }
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.controller,
    required this.statusFilter,
    required this.onQuery,
    required this.onStatusFilter,
  });

  final TextEditingController controller;
  final EstimateStatus? statusFilter;
  final ValueChanged<String> onQuery;
  final ValueChanged<EstimateStatus?> onStatusFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wrap = constraints.maxWidth < 720;
          final search = SizedBox(
            width: wrap ? double.infinity : 360,
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'search client or project',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.up, width: 1),
                ),
              ),
            ),
          );
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'all', selected: statusFilter == null, onTap: () => onStatusFilter(null)),
              _FilterChip(
                label: 'drafted',
                selected: statusFilter == EstimateStatus.drafted,
                onTap: () => onStatusFilter(EstimateStatus.drafted),
              ),
              _FilterChip(
                label: 'completed',
                selected: statusFilter == EstimateStatus.completed,
                onTap: () => onStatusFilter(EstimateStatus.completed),
              ),
              _FilterChip(
                label: 'finalized',
                selected: statusFilter == EstimateStatus.finalized,
                onTap: () => onStatusFilter(EstimateStatus.finalized),
              ),
            ],
          );
          if (wrap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), chips],
            );
          }
          return Row(
            children: [
              search,
              const SizedBox(width: 16),
              Expanded(child: chips),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.primarySoft.withValues(alpha: 0.18), blurRadius: 12)]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primarySoft : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.analytics, required this.drafts});

  final EstimateAnalytics analytics;
  final List<EstimateDraft> drafts;

  @override
  Widget build(BuildContext context) {
    final conversion = analytics.total == 0
        ? 0.0
        : ((analytics.completed + analytics.finalized) / analytics.total) * 100;
    final conversionDelta = _conversionDelta(drafts);
    final valueDelta = analytics.valueDelta();
    final draftedShare = analytics.total == 0 ? 0.0 : analytics.drafted / analytics.total;
    final completedShare = analytics.total == 0 ? 0.0 : analytics.completed / analytics.total;
    final finalizedShare = analytics.total == 0 ? 0.0 : analytics.finalized / analytics.total;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        final children = [
          _StatTile(
            label: 'Total Value',
            value: inrCompact(analytics.pipelineValue),
            delta: '${valueDelta >= 0 ? '+' : ''}${valueDelta.toStringAsFixed(0)}%',
            up: valueDelta >= 0,
          ),
          _StatTile(
            label: 'Conversion',
            value: '${conversion.toStringAsFixed(0)}%',
            delta: '${conversionDelta >= 0 ? '+' : ''}${conversionDelta.toStringAsFixed(0)}%',
            up: conversionDelta >= 0,
          ),
          _PipelineHealth(
            drafted: draftedShare,
            completed: completedShare,
            finalized: finalizedShare,
          ),
        ];
        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  double _conversionDelta(List<EstimateDraft> drafts) {
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month);
    final lastStart = DateTime(now.year, now.month - 1);
    double rate(DateTime start, DateTime end) {
      final items = drafts.where((d) => !d.date.isBefore(start) && d.date.isBefore(end)).toList();
      if (items.isEmpty) return 0;
      final won = items.where((d) => d.status != EstimateStatus.drafted).length;
      return won / items.length * 100;
    }

    return rate(thisStart, DateTime(now.year, now.month + 1)) - rate(lastStart, thisStart);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.delta,
    required this.up,
  });

  final String label;
  final String value;
  final String delta;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? AppColors.up : AppColors.down;
    return Container(
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: IgnorePointer(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (up ? AppColors.primary : AppColors.up).withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: color),
                        const SizedBox(width: 2),
                        Text(delta, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PipelineHealth extends StatelessWidget {
  const _PipelineHealth({
    required this.drafted,
    required this.completed,
    required this.finalized,
  });

  final double drafted;
  final double completed;
  final double finalized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PIPELINE HEALTH',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (drafted > 0) Expanded(flex: _flex(drafted), child: const ColoredBox(color: AppColors.drafted)),
                  if (completed > 0) Expanded(flex: _flex(completed), child: const ColoredBox(color: AppColors.completed)),
                  if (finalized > 0) Expanded(flex: _flex(finalized), child: const ColoredBox(color: AppColors.primary)),
                  if (drafted + completed + finalized == 0)
                    const Expanded(child: ColoredBox(color: AppColors.outline)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Drafted', style: TextStyle(color: AppColors.muted, fontSize: 10)),
              Text('Completed', style: TextStyle(color: AppColors.muted, fontSize: 10)),
              Text('Finalized', style: TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  int _flex(double share) => ((share * 100).round()).clamp(1, 100);
}

class _EstimateCard extends StatefulWidget {
  const _EstimateCard({
    required this.draft,
    required this.onOpen,
    required this.onMenu,
  });

  final EstimateDraft draft;
  final VoidCallback onOpen;
  final ValueChanged<String> onMenu;

  @override
  State<_EstimateCard> createState() => _EstimateCardState();
}

class _EstimateCardState extends State<_EstimateCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final drafted = draft.status == EstimateStatus.drafted;
    final glow = switch (draft.status) {
      EstimateStatus.finalized => AppColors.primary.withValues(alpha: _hover ? 0.08 : 0),
      EstimateStatus.completed => AppColors.completed.withValues(alpha: _hover ? 0.08 : 0),
      EstimateStatus.drafted => AppColors.cardHover.withValues(alpha: _hover ? 0.55 : 0),
    };
    final arrowTint = switch (draft.status) {
      EstimateStatus.finalized => AppColors.primarySoft,
      EstimateStatus.completed => AppColors.completed,
      EstimateStatus.drafted => AppColors.text,
    };
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: Offset(0, _hover ? -0.03 : 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _hover ? 0.32 : 0.14),
                    blurRadius: _hover ? 22 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        decoration: BoxDecoration(
                          color: glow,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    estimateDisplayCode(draft),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    draft.project.isEmpty ? draft.estimateType : draft.project,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    draft.client.isEmpty ? 'Untitled client' : draft.client,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StatusBadge(status: draft.status),
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                iconSize: 18,
                                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
                                onSelected: widget.onMenu,
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'type', child: Text('Change type')),
                                  const PopupMenuDivider(),
                                  for (final status in EstimateStatus.values)
                                    PopupMenuItem(
                                      value: 'status:${status.name}',
                                      child: Text('Mark ${status.label}'),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete estimate')),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    drafted ? 'EST. TOTAL' : 'GRAND TOTAL',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    inr(draft.totals.grandTotal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.text.withValues(alpha: drafted ? 0.6 : 1),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: _hover
                                  ? arrowTint.withValues(alpha: 0.12)
                                  : AppColors.background,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: widget.onOpen,
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: _hover ? arrowTint : AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EstimateStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      EstimateStatus.finalized => (AppColors.primary, const Color(0xFF191210), Icons.done_all_rounded),
      EstimateStatus.completed => (AppColors.completed.withValues(alpha: 0.2), AppColors.completed, Icons.check_rounded),
      EstimateStatus.drafted => (AppColors.cardHover, AppColors.muted, Icons.edit_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label.toLowerCase(),
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.noneAtAll, required this.onCreate});

  final bool noneAtAll;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 72, color: AppColors.muted.withValues(alpha: 0.45)),
          const SizedBox(height: 16),
          const Text(
            'no estimates found',
            style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            noneAtAll
                ? 'There are no estimates matching your current criteria. Create a new proposal to begin the architectural journey.'
                : 'No estimates match this filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('create estimate'),
          ),
        ],
      ),
    );
  }
}

String estimateDisplayCode(EstimateDraft draft) {
  final yy = (draft.date.year % 100).toString().padLeft(2, '0');
  final digits = draft.id.replaceAll(RegExp(r'[^0-9]'), '');
  final tail = digits.length >= 3 ? digits.substring(digits.length - 3) : digits.padLeft(3, '0');
  return 'EST-$yy-$tail';
}
