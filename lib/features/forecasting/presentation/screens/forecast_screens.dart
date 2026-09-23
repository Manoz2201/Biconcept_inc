import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../gst_audit/presentation/providers/compliance_providers.dart';
import '../../../gst_audit/presentation/widgets/compliance_widgets.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/budget.dart';

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final rows = ref.watch(budgetsProvider(ItcQuery(financialYear: fy)));
    final vs = ref.watch(budgetVsActualProvider(fy));
    return PermissionGate(
      permission: Permission.budgetView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Budgets'),
          actions: [
            TextButton(onPressed: () => context.push('/admin/budgets/vs-actual'), child: const Text('Vs actual')),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: () => context.push('/admin/budgets/new'), child: const Icon(Icons.add)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            vs.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (item) => Wrap(
                spacing: 8,
                children: [
                  ComplianceSummaryCard(label: 'Budgeted', value: formatMoney(item.budgeted)),
                  ComplianceSummaryCard(label: 'Actual', value: formatMoney(item.actual)),
                  ComplianceSummaryCard(label: 'Variance', value: formatMoney(item.variance)),
                ],
              ),
            ),
            rows.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('${item.category.label}${item.subCategory == null ? '' : ' · ${item.subCategory}'}'),
                      subtitle: Text('${item.status.label} · ${formatMoney(item.budgetedAmount)}'),
                      trailing: Text(
                        formatMoney(item.variance ?? 0),
                        style: TextStyle(color: (item.variance ?? 0) < 0 ? Colors.red : Colors.green),
                      ),
                      onTap: () => context.push('/admin/budgets/${item.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key, this.budgetId});

  final String? budgetId;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  BudgetCategory _category = BudgetCategory.expense;
  String _sub = 'salaries';

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.budgetId == null ? 'New budget' : 'Edit budget')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<BudgetCategory>(
            initialValue: _category,
            items: [for (final item in BudgetCategory.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: (value) => setState(() => _category = value ?? _category),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _sub,
            items: const [
              DropdownMenuItem(value: 'material', child: Text('Material')),
              DropdownMenuItem(value: 'labour', child: Text('Labour')),
              DropdownMenuItem(value: 'overhead', child: Text('Overhead')),
              DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
              DropdownMenuItem(value: 'salaries', child: Text('Salaries')),
              DropdownMenuItem(value: 'rent', child: Text('Rent')),
              DropdownMenuItem(value: 'software', child: Text('Software')),
            ],
            onChanged: (value) => setState(() => _sub = value ?? _sub),
            decoration: const InputDecoration(labelText: 'Sub-category'),
          ),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Budgeted amount'), keyboardType: TextInputType.number),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
          FilledButton(
            onPressed: () async {
              if (widget.budgetId == null) {
                await ref.read(budgetRepositoryProvider).createBudget(
                      financialYear: currentFinancialYear(),
                      category: _category,
                      budgetedAmount: double.tryParse(_amount.text) ?? 0,
                      subCategory: _sub,
                      notes: _notes.text.trim(),
                    );
              } else {
                await ref.read(budgetRepositoryProvider).updateBudget(widget.budgetId!, {
                  'category': _category.value,
                  'subCategory': _sub,
                  'budgetedAmount': double.tryParse(_amount.text) ?? 0,
                  'notes': _notes.text.trim(),
                });
              }
              if (!context.mounted) return;
              context.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(budgetByIdProvider(budgetId));
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: row.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.category.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Budgeted ${formatMoney(item.budgetedAmount)} · Actual ${formatMoney(item.actualAmount)}'),
            StatusChip(label: item.status.label),
            if (item.status == BudgetStatus.draft)
              FilledButton(
                onPressed: () async {
                  final user = ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';
                  await ref.read(budgetRepositoryProvider).approveBudget(item.id, user);
                  ref.invalidate(budgetByIdProvider(budgetId));
                },
                child: const Text('Approve'),
              ),
            if (item.status == BudgetStatus.approved)
              OutlinedButton(
                onPressed: () async {
                  await ref.read(budgetRepositoryProvider).activateBudget(item.id);
                  ref.invalidate(budgetByIdProvider(budgetId));
                },
                child: const Text('Activate'),
              ),
            TextButton(onPressed: () => context.push('/admin/budgets/${item.id}/edit'), child: const Text('Edit')),
          ],
        ),
      ),
    );
  }
}

class BudgetVsActualScreen extends ConsumerWidget {
  const BudgetVsActualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final vs = ref.watch(budgetVsActualProvider(fy));
    return Scaffold(
      appBar: AppBar(title: const Text('Budget vs actual')),
      body: vs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) {
          if (item.rows.isEmpty) return const Center(child: Text('No budgets yet'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    barGroups: [
                      for (var i = 0; i < item.rows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(toY: item.rows[i].budgetedAmount, color: Colors.blueGrey),
                            BarChartRodData(toY: item.rows[i].actualAmount, color: Colors.teal),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              for (final row in item.rows)
                ListTile(
                  title: Text(row.category.label),
                  subtitle: Text('Budget ${formatMoney(row.budgetedAmount)} · Actual ${formatMoney(row.actualAmount)}'),
                  trailing: Text(
                    '${(row.variancePercent ?? 0).toStringAsFixed(1)}%',
                    style: TextStyle(color: (row.variance ?? 0) < 0 ? Colors.red : Colors.green),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ForecastDashboardScreen extends ConsumerWidget {
  const ForecastDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(forecastsProvider(null));
    final cash = ref.watch(cashflowProjectionProvider(6));
    return PermissionGate(
      permission: Permission.forecastView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Forecasts')),
        floatingActionButton: FloatingActionButton(onPressed: () => context.push('/admin/forecasts/new'), child: const Icon(Icons.add)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            cash.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.hasNegativeMonth) const StatusChip(label: 'Negative cash month', tone: Colors.red),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < item.rows.length; i++) FlSpot(i.toDouble(), item.rows[i].net),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(onPressed: () => context.push('/admin/forecasts/cashflow'), child: const Text('Cashflow projection')),
                ],
              ),
            ),
            rows.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item.forecastType.label),
                      subtitle: Text(item.forecastPeriod),
                      onTap: () => context.push('/admin/forecasts/${item.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForecastFormScreen extends ConsumerStatefulWidget {
  const ForecastFormScreen({super.key});

  @override
  ConsumerState<ForecastFormScreen> createState() => _ForecastFormScreenState();
}

class _ForecastFormScreenState extends ConsumerState<ForecastFormScreen> {
  ForecastType _type = ForecastType.revenue;
  int _months = 6;
  final _growth = TextEditingController(text: '5');

  @override
  void dispose() {
    _growth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New forecast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ForecastType>(
            initialValue: _type,
            items: [for (final item in ForecastType.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: (value) => setState(() => _type = value ?? _type),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          TextField(controller: _growth, decoration: const InputDecoration(labelText: 'Monthly growth %'), keyboardType: TextInputType.number),
          DropdownButtonFormField<int>(
            initialValue: _months,
            items: const [
              DropdownMenuItem(value: 3, child: Text('Next 3 months')),
              DropdownMenuItem(value: 6, child: Text('Next quarter+')),
              DropdownMenuItem(value: 12, child: Text('Next year')),
            ],
            onChanged: (value) => setState(() => _months = value ?? _months),
            decoration: const InputDecoration(labelText: 'Horizon'),
          ),
          FilledButton(
            onPressed: () async {
              final rate = (double.tryParse(_growth.text) ?? 5) / 100;
              final data = switch (_type) {
                ForecastType.revenue => await ref.read(forecastRepositoryProvider).generateRevenueForecast(_months, monthlyGrowth: rate),
                ForecastType.expense => await ref.read(forecastRepositoryProvider).generateExpenseForecast(_months),
                ForecastType.cashflow => await ref.read(forecastRepositoryProvider).generateCashflowForecast(_months),
                ForecastType.profit => await ref.read(forecastRepositoryProvider).generateProfitForecast(_months),
              };
              final json = data.dataOrNull ?? '[]';
              await ref.read(forecastRepositoryProvider).createForecast(
                    financialYear: currentFinancialYear(),
                    forecastType: _type,
                    forecastPeriod: 'next_$_months',
                    forecastData: json,
                    assumptions: jsonEncode({'growth': rate}),
                    confidenceLevel: 'medium',
                    baseScenario: json,
                  );
              if (!context.mounted) return;
              context.pop();
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}

class ForecastDetailScreen extends ConsumerWidget {
  const ForecastDetailScreen({super.key, required this.forecastId});

  final String forecastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(forecastByIdProvider(forecastId));
    return Scaffold(
      appBar: AppBar(title: const Text('Forecast')),
      body: row.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.forecastType.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(item.forecastPeriod),
            Text(item.assumptions ?? ''),
            Text(item.forecastData),
          ],
        ),
      ),
    );
  }
}

class CashflowProjectionScreen extends ConsumerWidget {
  const CashflowProjectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(cashflowProjectionProvider(12));
    return Scaffold(
      appBar: AppBar(title: const Text('Cashflow projection')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (item.hasNegativeMonth)
              const Card(color: Color(0xFFFFEBEE), child: ListTile(title: Text('A projected month closes below zero'))),
            for (final row in item.rows)
              ListTile(
                title: Text(row.period),
                subtitle: Text('In ${formatMoney(row.cashIn)} · Out ${formatMoney(row.cashOut)}'),
                trailing: Text(formatMoney(row.closing), style: TextStyle(color: row.closing < 0 ? Colors.red : null)),
              ),
          ],
        ),
      ),
    );
  }
}
