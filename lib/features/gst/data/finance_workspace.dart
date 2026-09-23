import 'dart:convert';

import '../../expenses/domain/expense.dart';
import '../../ledger/domain/ledger_entry.dart';
import '../domain/gst_settings.dart';

class FinanceWorkspace {
  FinanceWorkspace({
    List<TaxRate>? taxRates,
    List<Expense>? expenses,
    List<LedgerEntry>? ledger,
    List<GSTReturn>? gstReturns,
    List<BankStatementLine>? bankLines,
    Map<String, int>? series,
  })  : taxRates = taxRates ?? [],
        expenses = expenses ?? [],
        ledger = ledger ?? [],
        gstReturns = gstReturns ?? [],
        bankLines = bankLines ?? [],
        series = series ?? {};

  final List<TaxRate> taxRates;
  final List<Expense> expenses;
  final List<LedgerEntry> ledger;
  final List<GSTReturn> gstReturns;
  final List<BankStatementLine> bankLines;
  final Map<String, int> series;

  String encode() => jsonEncode({
        'taxRates': [for (final item in taxRates) item.toJson()],
        'expenses': [for (final item in expenses) item.toJson()],
        'ledger': [for (final item in ledger) item.toJson()],
        'gstReturns': [for (final item in gstReturns) item.toJson()],
        'bankLines': [for (final item in bankLines) item.toJson()],
        'series': series,
      });

  factory FinanceWorkspace.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return FinanceWorkspace();
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return FinanceWorkspace();
      List<Map<String, dynamic>> maps(Object? value) => [
            if (value is List)
              for (final item in value)
                if (item is Map) Map<String, dynamic>.from(item),
          ];
      final seriesRaw = data['series'];
      return FinanceWorkspace(
        taxRates: [for (final item in maps(data['taxRates'])) TaxRate.fromJson(item)],
        expenses: [for (final item in maps(data['expenses'])) Expense.fromJson(item)],
        ledger: [for (final item in maps(data['ledger'])) LedgerEntry.fromJson(item)],
        gstReturns: [for (final item in maps(data['gstReturns'])) GSTReturn.fromJson(item)],
        bankLines: [for (final item in maps(data['bankLines'])) BankStatementLine.fromJson(item)],
        series: {
          if (seriesRaw is Map)
            for (final entry in seriesRaw.entries) entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
        },
      );
    } catch (_) {
      return FinanceWorkspace();
    }
  }

  static List<TaxRate> defaultRates() {
    final now = DateTime.now().toUtc();
    return [
      TaxRate(id: 'hsn-9983', hsnSacCode: '9983', description: 'Interior design services', taxRate: 18, type: TaxRateType.services, createdAt: now, updatedAt: now),
      TaxRate(id: 'hsn-9954', hsnSacCode: '9954', description: 'Construction services', taxRate: 18, type: TaxRateType.services, createdAt: now, updatedAt: now),
      TaxRate(id: 'hsn-9972', hsnSacCode: '9972', description: 'Real estate services', taxRate: 18, type: TaxRateType.services, createdAt: now, updatedAt: now),
    ];
  }
}
