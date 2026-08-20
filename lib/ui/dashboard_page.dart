import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../models/estimate_document.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'widgets/ui_kit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.drafts,
    this.onOpenEstimates,
    this.onOpenStatus,
  });

  final List<EstimateDraft> drafts;
  final VoidCallback? onOpenEstimates;
  final ValueChanged<EstimateStatus>? onOpenStatus;

  @override
  Widget build(BuildContext context) {
    final analytics = EstimateAnalytics.from(drafts);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < AppBreakpoints.compact ? 16 : 28,
        8,
        MediaQuery.sizeOf(context).width < AppBreakpoints.compact ? 16 : 28,
        32,
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            final cards = [
              StatCard(
                label: 'Estimates',
                value: analytics.total.toString(),
                delta: analytics.countDelta(),
                onTap: onOpenEstimates,
              ),
              StatCard(
                label: 'Pipeline',
                value: inrCompact(analytics.pipelineValue),
                delta: analytics.valueDelta(),
                onTap: onOpenEstimates,
              ),
              StatCard(
                label: 'Finalized',
                value: inrCompact(analytics.finalizedValue),
                onTap: () => onOpenStatus?.call(EstimateStatus.finalized),
              ),
              StatCard(
                label: 'Completed',
                value: '${analytics.completed}',
                onTap: () => onOpenStatus?.call(EstimateStatus.completed),
              ),
            ];
            final columns = wide ? 2 : (constraints.maxWidth >= 700 ? 2 : 1);
            const gap = 16.0;
            final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
            final scale = MediaQuery.textScalerOf(context).scale(1).clamp(0.85, 1.4);
            final targetAspect = wide ? 1.7 : (columns == 1 ? 1.55 : 2.2);
            final minHeight = 128.0 * scale;
            final tileHeight = (tileWidth / targetAspect).clamp(minHeight, 220.0 * scale);
            final stats = GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: tileHeight,
              ),
              children: cards,
            );
            final bar = _WorkTypeChart(shares: analytics.byWorkType);
            if (!wide) {
              return Column(
                children: [
                  stats,
                  const SizedBox(height: 16),
                  SizedBox(height: 280, child: bar),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: stats),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: SizedBox(height: 332, child: bar)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final line = _MonthlyChart(points: analytics.monthly);
            final donut = _StatusChart(analytics: analytics);
            if (!wide) {
              return Column(
                children: [
                  SizedBox(height: 280, child: line),
                  const SizedBox(height: 16),
                  SizedBox(height: 280, child: donut),
                ],
              );
            }
            return SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(flex: 3, child: line),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: donut),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WorkTypeChart extends StatelessWidget {
  const _WorkTypeChart({required this.shares});

  final List<WorkTypeShare> shares;

  @override
  Widget build(BuildContext context) {
    final peak = shares.isEmpty ? 0.0 : shares.map((item) => item.amount).reduce((a, b) => a > b ? a : b);
    final maxY = peak <= 0 ? 1.0 : peak * 1.2;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Value by work type', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Line amounts across saved estimates', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: shares.isEmpty
                ? const Center(child: Text('No line items yet', style: TextStyle(color: AppColors.muted)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.cardHover,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final item = shares[group.x];
                            return BarTooltipItem(
                              '${item.name}\n${inrCompact(item.amount)}',
                              const TextStyle(color: AppColors.text, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= shares.length) return const SizedBox.shrink();
                              final name = shares[i].name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  name.length > 8 ? '${name.substring(0, 8)}…' : name,
                                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        for (var i = 0; i < shares.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: shares[i].amount <= 0 ? 0.1 : shares[i].amount,
                                width: 18,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AppColors.primary, AppColors.primarySoft],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimate value over time', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Last 12 months', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
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
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        if (i % 2 != 0) return const SizedBox.shrink();
                        return Text(points[i].label, style: const TextStyle(color: AppColors.muted, fontSize: 10));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.outline, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.35),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    spots: [
                      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      (EstimateStatus.finalized, analytics.finalized, AppColors.finalized),
    ];
    final total = analytics.total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status mix', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Drafted · Completed · Finalized', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Expanded(
            child: total == 0
                ? const Center(child: Text('No estimates yet', style: TextStyle(color: AppColors.muted)))
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 42,
                            sections: [
                              for (final slice in slices)
                                if (slice.$2 > 0)
                                  PieChartSectionData(
                                    value: slice.$2.toDouble(),
                                    color: slice.$3,
                                    radius: 22,
                                    showTitle: false,
                                  ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final slice in slices)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: slice.$3, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${slice.$1.label}  ${slice.$2}',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
