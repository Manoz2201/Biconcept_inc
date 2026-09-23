import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../platform/presentation/widgets/platform_widgets.dart';
import '../../../rbac/domain/permission.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue = ref.watch(revenueAnalyticsProvider);
    final funnel = ref.watch(funnelAnalysisProvider('lead_to_project'));
    final kpis = ref.watch(kpiMetricsProvider('monthly'));
    return PermissionGate(
      permission: Permission.analyticsView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final csv = await ref.read(analyticsRepositoryProvider).exportAnalyticsReport(reportType: 'overview');
                final text = csv.dataOrNull;
                if (text != null) await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied')));
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(kpiRepositoryProvider).computeKPIs();
            ref.invalidate(kpiMetricsProvider);
            ref.invalidate(revenueAnalyticsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  revenue.maybeWhen(
                    data: (item) => MetricCard(label: 'Revenue', value: item.totalRevenue.toStringAsFixed(0), onTap: () => context.push('/admin/analytics/revenue')),
                    orElse: () => const MetricCard(label: 'Revenue', value: '…'),
                  ),
                  revenue.maybeWhen(
                    data: (item) => MetricCard(label: 'Avg invoice', value: item.avgInvoiceValue.toStringAsFixed(0)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  revenue.maybeWhen(
                    data: (item) => MetricCard(label: 'Outstanding', value: item.outstanding.toStringAsFixed(0)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  kpis.maybeWhen(
                    data: (items) => MetricCard(label: 'KPIs', value: '${items.length}', onTap: () => context.push('/admin/analytics/kpis')),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: () => context.push('/admin/analytics/cohorts'), child: const Text('Cohorts')),
                  OutlinedButton(onPressed: () => context.push('/admin/analytics/funnels/lead_to_project'), child: const Text('Lead funnel')),
                  OutlinedButton(onPressed: () => context.push('/admin/analytics/users'), child: const Text('Users')),
                ],
              ),
              const SizedBox(height: 16),
              revenue.maybeWhen(
                data: (item) => SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      titlesData: const FlTitlesData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (final entry in item.byPeriod.entries.toList().asMap().entries)
                              FlSpot(entry.key.toDouble(), entry.value.value),
                          ],
                          isCurved: true,
                        ),
                      ],
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              funnel.maybeWhen(data: (item) => FunnelList(data: item), orElse: () => const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class KPIDashboardScreen extends ConsumerWidget {
  const KPIDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(kpiMetricsProvider('monthly'));
    return PermissionGate(
      permission: Permission.kpiView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('KPIs'),
          actions: [
            IconButton(
              onPressed: () async {
                await ref.read(kpiRepositoryProvider).computeKPIs();
                ref.invalidate(kpiMetricsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  leading: KpiStatusDot(status: item.status),
                  title: Text(item.metricName),
                  subtitle: Text('${item.metricValue} ${item.metricUnit ?? ''} · ${item.changePercent?.toStringAsFixed(1) ?? '—'}%'),
                  trailing: PermissionGate(
                    permission: Permission.kpiConfigure,
                    child: IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: () async {
                        final controller = TextEditingController(text: '${item.target ?? item.metricValue}');
                        final target = await showDialog<double>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Set target'),
                            content: TextField(controller: controller, keyboardType: TextInputType.number),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text)), child: const Text('Save')),
                            ],
                          ),
                        );
                        if (target == null) return;
                        await ref.read(kpiRepositoryProvider).setKPITarget(item.metricName, target);
                        ref.invalidate(kpiMetricsProvider);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CohortAnalysisScreen extends ConsumerWidget {
  const CohortAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(cohortAnalysisProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cohorts')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text(item.cohortName),
                subtitle: Text('Size ${item.size} · LTV ${item.revenueLTV.toStringAsFixed(0)}'),
                trailing: Text('${((item.retentionRates[1] ?? 0) * 100).toStringAsFixed(0)}%'),
              ),
          ],
        ),
      ),
    );
  }
}

class FunnelAnalysisScreen extends ConsumerWidget {
  const FunnelAnalysisScreen({super.key, required this.funnelName});

  final String funnelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(funnelAnalysisProvider(funnelName));
    return Scaffold(
      appBar: AppBar(title: Text(funnelName.replaceAll('_', ' '))),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Conversion ${(item.conversionRate * 100).toStringAsFixed(1)}%'),
            FunnelList(data: item),
          ],
        ),
      ),
    );
  }
}

class RevenueAnalyticsScreen extends ConsumerWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(revenueAnalyticsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Revenue')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MetricCard(label: 'Total', value: item.totalRevenue.toStringAsFixed(0)),
            MetricCard(label: 'Outstanding', value: item.outstanding.toStringAsFixed(0)),
            const SizedBox(height: 12),
            for (final entry in item.topClients.entries) ListTile(title: Text(entry.key), trailing: Text(entry.value.toStringAsFixed(0))),
          ],
        ),
      ),
    );
  }
}

class UserAnalyticsScreen extends ConsumerWidget {
  const UserAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(userAnalyticsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('User analytics')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (item) => ListView(
          children: [
            ListTile(title: const Text('DAU'), trailing: Text('${item.dau}')),
            ListTile(title: const Text('WAU'), trailing: Text('${item.wau}')),
            ListTile(title: const Text('MAU'), trailing: Text('${item.mau}')),
            for (final entry in item.featureUsage.entries) ListTile(title: Text(entry.key), trailing: Text('${entry.value}')),
          ],
        ),
      ),
    );
  }
}
