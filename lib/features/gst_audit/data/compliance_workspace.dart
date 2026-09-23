import 'dart:convert';

import '../../e_invoice/domain/e_invoice.dart';
import '../../e_way_bill/domain/e_way_bill.dart';
import '../../forecasting/domain/budget.dart';
import '../../tds/domain/tds_deduction.dart';
import '../domain/gstr2b_import.dart';
import '../domain/gstr9_return.dart';
import '../domain/itc_ledger_entry.dart';
import '../domain/itc_reversal.dart';

class ComplianceWorkspace {
  ComplianceWorkspace({
    List<ITCLedgerEntry>? itcLedger,
    List<ITCReversal>? itcReversals,
    List<GSTR2BImport>? gstr2bImports,
    List<TDSDeduction>? tdsDeductions,
    List<GSTTDS>? gstTds,
    List<EInvoice>? eInvoices,
    List<EWayBill>? eWayBills,
    List<GSTR9Return>? gstr9Returns,
    List<GSTR9CReconciliation>? gstr9c,
    List<Budget>? budgets,
    List<FinancialForecast>? forecasts,
    IrpSettings? irpSettings,
  })  : itcLedger = itcLedger ?? [],
        itcReversals = itcReversals ?? [],
        gstr2bImports = gstr2bImports ?? [],
        tdsDeductions = tdsDeductions ?? [],
        gstTds = gstTds ?? [],
        eInvoices = eInvoices ?? [],
        eWayBills = eWayBills ?? [],
        gstr9Returns = gstr9Returns ?? [],
        gstr9c = gstr9c ?? [],
        budgets = budgets ?? [],
        forecasts = forecasts ?? [],
        irpSettings = irpSettings ?? const IrpSettings();

  final List<ITCLedgerEntry> itcLedger;
  final List<ITCReversal> itcReversals;
  final List<GSTR2BImport> gstr2bImports;
  final List<TDSDeduction> tdsDeductions;
  final List<GSTTDS> gstTds;
  final List<EInvoice> eInvoices;
  final List<EWayBill> eWayBills;
  final List<GSTR9Return> gstr9Returns;
  final List<GSTR9CReconciliation> gstr9c;
  final List<Budget> budgets;
  final List<FinancialForecast> forecasts;
  final IrpSettings irpSettings;

  String encode() => jsonEncode({
        'itcLedger': [for (final item in itcLedger) item.toJson()],
        'itcReversals': [for (final item in itcReversals) item.toJson()],
        'gstr2bImports': [for (final item in gstr2bImports) item.toJson()],
        'tdsDeductions': [for (final item in tdsDeductions) item.toJson()],
        'gstTds': [for (final item in gstTds) item.toJson()],
        'eInvoices': [for (final item in eInvoices) item.toJson()],
        'eWayBills': [for (final item in eWayBills) item.toJson()],
        'gstr9Returns': [for (final item in gstr9Returns) item.toJson()],
        'gstr9c': [for (final item in gstr9c) item.toJson()],
        'budgets': [for (final item in budgets) item.toJson()],
        'forecasts': [for (final item in forecasts) item.toJson()],
        'irpSettings': irpSettings.toJson(),
      });

  factory ComplianceWorkspace.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ComplianceWorkspace();
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return ComplianceWorkspace();
      List<Map<String, dynamic>> maps(Object? value) => [
            if (value is List)
              for (final item in value)
                if (item is Map) Map<String, dynamic>.from(item),
          ];
      final settings = data['irpSettings'];
      return ComplianceWorkspace(
        itcLedger: [for (final item in maps(data['itcLedger'])) ITCLedgerEntry.fromJson(item)],
        itcReversals: [for (final item in maps(data['itcReversals'])) ITCReversal.fromJson(item)],
        gstr2bImports: [for (final item in maps(data['gstr2bImports'])) GSTR2BImport.fromJson(item)],
        tdsDeductions: [for (final item in maps(data['tdsDeductions'])) TDSDeduction.fromJson(item)],
        gstTds: [for (final item in maps(data['gstTds'])) GSTTDS.fromJson(item)],
        eInvoices: [for (final item in maps(data['eInvoices'])) EInvoice.fromJson(item)],
        eWayBills: [for (final item in maps(data['eWayBills'])) EWayBill.fromJson(item)],
        gstr9Returns: [for (final item in maps(data['gstr9Returns'])) GSTR9Return.fromJson(item)],
        gstr9c: [for (final item in maps(data['gstr9c'])) GSTR9CReconciliation.fromJson(item)],
        budgets: [for (final item in maps(data['budgets'])) Budget.fromJson(item)],
        forecasts: [for (final item in maps(data['forecasts'])) FinancialForecast.fromJson(item)],
        irpSettings: IrpSettings.fromJson(settings is Map ? Map<String, dynamic>.from(settings) : null),
      );
    } catch (_) {
      return ComplianceWorkspace();
    }
  }

  ComplianceWorkspace copyWith({
    List<ITCLedgerEntry>? itcLedger,
    List<ITCReversal>? itcReversals,
    List<GSTR2BImport>? gstr2bImports,
    List<TDSDeduction>? tdsDeductions,
    List<GSTTDS>? gstTds,
    List<EInvoice>? eInvoices,
    List<EWayBill>? eWayBills,
    List<GSTR9Return>? gstr9Returns,
    List<GSTR9CReconciliation>? gstr9c,
    List<Budget>? budgets,
    List<FinancialForecast>? forecasts,
    IrpSettings? irpSettings,
  }) =>
      ComplianceWorkspace(
        itcLedger: itcLedger ?? this.itcLedger,
        itcReversals: itcReversals ?? this.itcReversals,
        gstr2bImports: gstr2bImports ?? this.gstr2bImports,
        tdsDeductions: tdsDeductions ?? this.tdsDeductions,
        gstTds: gstTds ?? this.gstTds,
        eInvoices: eInvoices ?? this.eInvoices,
        eWayBills: eWayBills ?? this.eWayBills,
        gstr9Returns: gstr9Returns ?? this.gstr9Returns,
        gstr9c: gstr9c ?? this.gstr9c,
        budgets: budgets ?? this.budgets,
        forecasts: forecasts ?? this.forecasts,
        irpSettings: irpSettings ?? this.irpSettings,
      );
}
