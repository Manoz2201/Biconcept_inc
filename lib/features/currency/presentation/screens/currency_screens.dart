import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../currency/domain/currency.dart';
import '../../../currency/domain/money.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../rbac/domain/permission.dart';

class CurrencyListScreen extends ConsumerWidget {
  const CurrencyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(currenciesProvider(null));
    return PermissionGate(
      permission: Permission.currencyView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Currencies'),
          actions: [
            TextButton(onPressed: () => context.push('/admin/currency-converter'), child: const Text('Converter')),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.currencyCreate,
          child: FloatingActionButton(
            onPressed: () => context.push('/admin/currencies/new'),
            child: const Icon(Icons.add),
          ),
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text('${item.code} · ${item.name}'),
                  subtitle: Text('Rate ${item.exchangeRate}${item.isBaseCurrency ? ' · base' : ''}'),
                  trailing: Text(item.symbol),
                  onTap: () => context.push('/admin/currencies/${item.code}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CurrencyFormScreen extends ConsumerStatefulWidget {
  const CurrencyFormScreen({super.key});

  @override
  ConsumerState<CurrencyFormScreen> createState() => _CurrencyFormScreenState();
}

class _CurrencyFormScreenState extends ConsumerState<CurrencyFormScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  final _rate = TextEditingController(text: '1');
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _symbol.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.currencyCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('New currency')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'ISO code')),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _symbol, decoration: const InputDecoration(labelText: 'Symbol')),
            TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Rate to base'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final result = await ref.read(currencyRepositoryProvider).createCurrency(
                            code: _code.text.trim(),
                            name: _name.text.trim(),
                            symbol: _symbol.text.trim(),
                            exchangeRate: double.tryParse(_rate.text) ?? 1,
                          );
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      result.when(
                        success: (_) => context.pop(),
                        failure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.userMessage))),
                      );
                      ref.invalidate(currenciesProvider);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class CurrencyDetailScreen extends ConsumerWidget {
  const CurrencyDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyByCodeProvider(code));
    return PermissionGate(
      permission: Permission.currencyView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(code)),
        body: currency.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${item.name} ${item.symbol}', style: Theme.of(context).textTheme.titleLarge),
              Text('Rate ${item.exchangeRate} · ${item.isActive ? 'Active' : 'Inactive'}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: () => context.push('/admin/currencies/$code/history'), child: const Text('Rate history')),
                  PermissionGate(
                    permission: Permission.exchangeRateUpdate,
                    child: FilledButton(
                      onPressed: () async {
                        final controller = TextEditingController(text: '${item.exchangeRate}');
                        final rate = await showDialog<double>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Update rate'),
                            content: TextField(controller: controller, keyboardType: TextInputType.number),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text)), child: const Text('Save')),
                            ],
                          ),
                        );
                        if (rate == null) return;
                        await ref.read(currencyRepositoryProvider).updateExchangeRate(code, rate, 'manual');
                        ref.invalidate(currencyByCodeProvider(code));
                        ref.invalidate(currenciesProvider);
                      },
                      child: const Text('Update rate'),
                    ),
                  ),
                  PermissionGate(
                    permission: Permission.currencyEdit,
                    child: OutlinedButton(
                      onPressed: item.isBaseCurrency
                          ? null
                          : () async {
                              await ref.read(currencyRepositoryProvider).setBaseCurrency(item.id);
                              ref.invalidate(currenciesProvider);
                              ref.invalidate(baseCurrencyProvider);
                            },
                      child: const Text('Set as base'),
                    ),
                  ),
                  PermissionGate(
                    permission: Permission.currencyEdit,
                    child: TextButton(
                      onPressed: item.isBaseCurrency
                          ? null
                          : () async {
                              await ref.read(currencyRepositoryProvider).deactivateCurrency(item.id);
                              ref.invalidate(currenciesProvider);
                            },
                      child: const Text('Deactivate'),
                    ),
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

class ExchangeRateHistoryScreen extends ConsumerWidget {
  const ExchangeRateHistoryScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(exchangeRateHistoryProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text('$code history')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text('${item.rate}'),
                subtitle: Text('${item.source ?? 'manual'} · ${item.effectiveDate.toLocal()}'),
              ),
          ],
        ),
      ),
    );
  }
}

class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends ConsumerState<CurrencyConverterScreen> {
  final _amount = TextEditingController(text: '100');
  String? _from;
  String? _to;
  String _result = '';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencies = ref.watch(currenciesProvider(true));
    return Scaffold(
      appBar: AppBar(title: const Text('Currency converter')),
      body: currencies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) {
          _from ??= items.firstWhere((item) => item.isBaseCurrency, orElse: () => items.first).code;
          _to ??= items.firstWhere((item) => item.code == 'USD', orElse: () => items.last).code;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
              DropdownButtonFormField<String>(
                initialValue: _from,
                items: [for (final item in items) DropdownMenuItem(value: item.code, child: Text(item.code))],
                onChanged: (value) => setState(() => _from = value),
                decoration: const InputDecoration(labelText: 'From'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _to,
                items: [for (final item in items) DropdownMenuItem(value: item.code, child: Text(item.code))],
                onChanged: (value) => setState(() => _to = value),
                decoration: const InputDecoration(labelText: 'To'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final from = items.firstWhere((item) => item.code == _from);
                  final to = items.firstWhere((item) => item.code == _to);
                  final converted = Money(double.tryParse(_amount.text) ?? 0, from).convertTo(to);
                  setState(() => _result = converted.format());
                },
                child: const Text('Convert'),
              ),
              if (_result.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_result, style: Theme.of(context).textTheme.headlineSmall)),
            ],
          );
        },
      ),
    );
  }
}

Currency? currencyOf(List<Currency> rows, String code) {
  for (final item in rows) {
    if (item.code == code) return item;
  }
  return null;
}
