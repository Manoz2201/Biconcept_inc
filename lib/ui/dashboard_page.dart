import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/schedule.dart';
import '../models/estimate_document.dart';
import '../models/office_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.drafts,
    this.onOpenEstimates,
    this.onOpenStatus,
    this.onOpenCalendar,
  });

  final List<EstimateDraft> drafts;
  final VoidCallback? onOpenEstimates;
  final ValueChanged<EstimateStatus>? onOpenStatus;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final analytics = EstimateAnalytics.from(drafts);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final pad = compact ? 16.0 : 24.0;
    return ListenableBuilder(
      listenable: ScheduleService.instance.store,
      builder: (context, _) {
        final followUps = [
          for (final event in ScheduleService.instance.store.events)
            if (event.kind == CalendarKind.followUp && !event.done) event,
        ];
        final overdue = followUps.where((event) {
          final day = DateTime(event.start.year, event.start.month, event.start.day);
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          return !day.isAfter(today);
        }).length;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, compact ? 4 : 8, pad, compact ? 96 : 32),
          children: [
            _DashboardHero(compact: compact),
            const SizedBox(height: 20),
            _KpiGrid(
              analytics: analytics,
              pendingFollowUps: followUps.length,
              overdueFollowUps: overdue,
              compact: compact,
              onOpenEstimates: onOpenEstimates,
              onOpenWon: () => onOpenStatus?.call(EstimateStatus.finalized),
              onOpenCalendar: onOpenCalendar,
            ),
            const SizedBox(height: 20),
            _ChartsRow(analytics: analytics, compact: compact),
            const SizedBox(height: 20),
            _LowerRow(
              analytics: analytics,
              compact: compact,
            ),
          ],
        );
      },
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'dashboard',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 32 : 48,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Overview of active estimating pipeline and recent project performance metrics.',
                style: TextStyle(color: AppColors.muted, fontSize: compact ? 14 : 16, height: 1.4),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'LAST UPDATED:',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Just Now',
                style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.analytics,
    required this.pendingFollowUps,
    required this.overdueFollowUps,
    required this.compact,
    this.onOpenEstimates,
    this.onOpenWon,
    this.onOpenCalendar,
  });

  final EstimateAnalytics analytics;
  final int pendingFollowUps;
  final int overdueFollowUps;
  final bool compact;
  final VoidCallback? onOpenEstimates;
  final VoidCallback? onOpenWon;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final valueDelta = analytics.valueDelta();
    final wonDelta = analytics.quarterWonDelta();
    final cards = [
      _KpiCard(
        label: 'Total Pipeline Value',
        value: inrCompact(analytics.pipelineValue),
        icon: Icons.account_balance_rounded,
        pill: '${valueDelta >= 0 ? '+' : ''}${valueDelta.toStringAsFixed(1)}%',
        caption: 'vs last month',
        positive: valueDelta >= 0,
        onTap: onOpenEstimates,
      ),
      _KpiCard(
        label: 'Active Estimates',
        value: '${analytics.total}',
        icon: Icons.description_rounded,
        pill: '+${analytics.thisWeekCount}',
        caption: 'new this week',
        positive: true,
        onTap: onOpenEstimates,
      ),
      _KpiCard(
        label: 'Won Projects (YTD)',
        value: '${analytics.ytdWon}',
        icon: Icons.military_tech_rounded,
        pill: '${wonDelta >= 0 ? '+' : ''}$wonDelta',
        caption: 'vs previous quarter',
        positive: wonDelta >= 0,
        onTap: onOpenWon,
      ),
      _KpiCard(
        label: 'Pending Follow-ups',
        value: '$pendingFollowUps',
        icon: Icons.notification_important_rounded,
        pill: overdueFollowUps == 0 ? '0' : '-$overdueFollowUps',
        caption: overdueFollowUps == 0 ? 'all clear' : 'action required',
        positive: overdueFollowUps == 0,
        danger: overdueFollowUps > 0,
        onTap: onOpenCalendar,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: compact ? 168 : 176,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.pill,
    required this.caption,
    required this.positive,
    this.danger = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String pill;
  final String caption;
  final bool positive;
  final bool danger;
  final VoidCallback? onTap;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? AppColors.down : AppColors.primary;
    final pillColor = widget.danger
        ? AppColors.down
        : widget.positive
            ? AppColors.up
            : AppColors.down;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: Offset(0, _hover ? -0.02 : 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _hover ? 0.28 : 0.16),
                    blurRadius: _hover ? 22 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _hover ? 1 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.label.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedScale(
                            duration: const Duration(milliseconds: 400),
                            scale: _hover ? 1.08 : 1,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(widget.icon, color: accent, size: 24),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pillColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.positive && !widget.danger
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 16,
                                  color: pillColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.pill,
                                  style: TextStyle(
                                    color: pillColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ),
                        ],
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.height, this.dashed = false});

  final Widget child;
  final double? height;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: dashed ? 0.45 : 0.55),
        ),
      ),
      child: child,
    );
  }
}

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.analytics, required this.compact});

  final EstimateAnalytics analytics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final line = _Panel(
      height: compact ? 340 : 400,
      child: _MonthlyChart(points: analytics.monthly),
    );
    final donut = _Panel(
      height: compact ? 340 : 400,
      child: _StatusChart(analytics: analytics),
    );
    if (compact) {
      return Column(children: [line, const SizedBox(height: 16), donut]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: line),
        const SizedBox(width: 16),
        Expanded(child: donut),
      ],
    );
  }
}

class _LowerRow extends StatelessWidget {
  const _LowerRow({
    required this.analytics,
    required this.compact,
  });

  final EstimateAnalytics analytics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final work = _Panel(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 280),
        child: _WorkTypeBars(shares: analytics.byWorkType),
      ),
    );
    final conversion = _Panel(
      dashed: analytics.completed < 3,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 280),
        child: _ConversionCard(
          analytics: analytics,
        ),
      ),
    );
    if (compact) {
      return Column(children: [work, const SizedBox(height: 16), conversion]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: work),
        const SizedBox(width: 16),
        Expanded(child: conversion),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.dimmed = false});

  final String text;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.text.withValues(alpha: dimmed ? 0.4 : 1),
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.points});

  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxY = points.map((item) => item.value).fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('estimate value over time')),
            Text(
              'YTD ${DateTime.now().year}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 18),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY <= 0 ? 1 : maxY * 1.15,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.cardHover,
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        inrCompact(spot.y),
                        const TextStyle(color: AppColors.text, fontSize: 12),
                      ),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length || i.isOdd) return const SizedBox.shrink();
                      return Text(
                        points[i].label.toUpperCase(),
                        style: const TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 0.6),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.outline.withValues(alpha: 0.55),
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: AppColors.primarySoft,
                  barWidth: 4,
                  shadow: Shadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      if (index != 3 && index != 6 && index != points.length - 1) {
                        return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0);
                      }
                      return FlDotCirclePainter(
                        radius: 5,
                        color: AppColors.card,
                        strokeWidth: 3,
                        strokeColor: AppColors.primarySoft,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(show: false),
                  spots: [
                    for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChart extends StatelessWidget {
  const _StatusChart({required this.analytics});

  final EstimateAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final slices = [
      (EstimateStatus.drafted, analytics.drafted, AppColors.drafted),
      (EstimateStatus.completed, analytics.completed, AppColors.completed),
      (EstimateStatus.finalized, analytics.finalized, AppColors.primarySoft),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('status mix'),
        const SizedBox(height: 12),
        Expanded(
          child: analytics.total == 0
              ? const Center(child: Text('No estimates yet', style: TextStyle(color: AppColors.muted)))
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              startDegreeOffset: -90,
                              sectionsSpace: 0,
                              centerSpaceRadius: 58,
                              sections: [
                                for (final slice in slices)
                                  if (slice.$2 > 0)
                                    PieChartSectionData(
                                      value: slice.$2.toDouble(),
                                      color: slice.$3,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${analytics.total}',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final slice in slices)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: slice.$3,
                                  shape: BoxShape.circle,
                                  boxShadow: slice.$1 == EstimateStatus.finalized
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primarySoft.withValues(alpha: 0.45),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                slice.$1.label,
                                style: TextStyle(
                                  color: slice.$1 == EstimateStatus.finalized ? AppColors.text : AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _WorkTypeBars extends StatelessWidget {
  const _WorkTypeBars({required this.shares});

  final List<WorkTypeShare> shares;

  @override
  Widget build(BuildContext context) {
    final top = shares.take(3).toList();
    final peak = top.isEmpty ? 1.0 : top.first.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('value by work type'),
        const SizedBox(height: 28),
        if (top.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No line items yet', style: TextStyle(color: AppColors.muted))),
          )
        else
          for (var i = 0; i < top.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    top[i].name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Text(
                  inrCompact(top[i].amount),
                  style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 12,
                child: Stack(
                  children: [
                    const ColoredBox(color: AppColors.background, child: SizedBox.expand()),
                    FractionallySizedBox(
                      widthFactor: peak <= 0 ? 0 : (top[i].amount / peak).clamp(0.08, 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 1 - (i * 0.18)),
                              AppColors.primarySoft.withValues(alpha: 0.85 - (i * 0.15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != top.length - 1) const SizedBox(height: 22),
          ],
      ],
    );
  }
}

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({required this.analytics});

  final EstimateAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final ready = analytics.completed >= 3 && analytics.total > 0;
    final rate = ready ? ((analytics.completed + analytics.finalized) / analytics.total) * 100 : 0.0;
    return Stack(
      children: [
        Positioned(
          right: -24,
          top: -24,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('conversion rates', dimmed: !ready),
            const SizedBox(height: 28),
            if (ready) ...[
              Center(
                child: Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Completed + finalized vs pipeline',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ] else ...[
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.cardHover,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: AppColors.muted, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Insufficient Data',
                  style: TextStyle(color: AppColors.muted, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'More completed estimates required to generate conversion trends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
