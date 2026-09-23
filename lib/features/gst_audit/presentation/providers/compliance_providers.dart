import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../e_invoice/domain/e_invoice.dart';
import '../../../e_invoice/domain/e_invoice_repository.dart';
import '../../../e_way_bill/domain/e_way_bill.dart';
import '../../../e_way_bill/domain/e_way_bill_repository.dart';
import '../../../forecasting/domain/budget.dart';
import '../../../forecasting/domain/budget_repository.dart';
import '../../../gst/domain/gst_math.dart';
import '../../../tds/domain/tds_deduction.dart';
import '../../../tds/domain/tds_repository.dart';
import '../../data/gst_audit_repository_impl.dart';
import '../../domain/gstr2b_import.dart';
import '../../domain/gstr2b_repository.dart';
import '../../domain/gstr9_repository.dart';
import '../../domain/gstr9_return.dart';
import '../../domain/itc_ledger_entry.dart';
import '../../domain/itc_repository.dart';
import '../../domain/itc_reversal.dart';
import '../../domain/reconciliation_result.dart';

T _unwrap<T>(dynamic result) => result.when(
      success: (data) => data as T,
      failure: (error) => throw Exception(error.userMessage),
    );

final complianceRepositoryProvider = Provider<ComplianceRepositoryImpl>((ref) {
  return ComplianceRepositoryImpl(actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown');
});

final itcRepositoryProvider = Provider<ITCRepository>((ref) => ref.watch(complianceRepositoryProvider));
final itcReversalRepositoryProvider = Provider<ITCReversalRepository>((ref) => ref.watch(complianceRepositoryProvider));
final gstr2bRepositoryProvider = Provider<GSTR2BRepository>((ref) => ref.watch(complianceRepositoryProvider));
final gstr9RepositoryProvider = Provider<GSTR9Repository>((ref) => ref.watch(complianceRepositoryProvider));
final gstr9cRepositoryProvider = Provider<GSTR9CRepository>((ref) => ref.watch(complianceRepositoryProvider));
final tdsRepositoryProvider = Provider<TDSRepository>((ref) => ref.watch(complianceRepositoryProvider));
final gstTdsRepositoryProvider = Provider<GSTTDSRepository>((ref) => ref.watch(complianceRepositoryProvider));
final eInvoiceRepositoryProvider = Provider<EInvoiceRepository>((ref) => ref.watch(complianceRepositoryProvider));
final eWayBillRepositoryProvider = Provider<EWayBillRepository>((ref) => ref.watch(complianceRepositoryProvider));
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => ref.watch(complianceRepositoryProvider));
final forecastRepositoryProvider = Provider<ForecastRepository>((ref) => ref.watch(complianceRepositoryProvider));

String currentFinancialYear() => financialYearLabel(DateTime.now());

class ItcQuery {
  const ItcQuery({this.financialYear, this.period, this.supplierGstin, this.status, this.matchStatus});

  final String? financialYear;
  final String? period;
  final String? supplierGstin;
  final ITCStatus? status;
  final MatchStatus? matchStatus;

  @override
  bool operator ==(Object other) =>
      other is ItcQuery &&
      other.financialYear == financialYear &&
      other.period == period &&
      other.supplierGstin == supplierGstin &&
      other.status == status &&
      other.matchStatus == matchStatus;

  @override
  int get hashCode => Object.hash(financialYear, period, supplierGstin, status, matchStatus);
}

final itcLedgerProvider = FutureProvider.family<List<ITCLedgerEntry>, ItcQuery>((ref, query) async {
  return _unwrap(await ref.watch(itcRepositoryProvider).getITCLedger(
        financialYear: query.financialYear,
        period: query.period,
        supplierGstin: query.supplierGstin,
        status: query.status,
        matchStatus: query.matchStatus,
      ));
});

final itcEntryByIdProvider = FutureProvider.family<ITCLedgerEntry, String>((ref, id) async {
  return _unwrap(await ref.watch(itcRepositoryProvider).getITCEntryById(id));
});

final itcSummaryProvider = FutureProvider.family<ITCSummary, ({String fy, String period})>((ref, key) async {
  return _unwrap(await ref.watch(itcRepositoryProvider).getITCSummary(key.fy, key.period));
});

final itcReversalsProvider = FutureProvider.family<List<ITCReversal>, ItcQuery>((ref, query) async {
  return _unwrap(await ref.watch(itcReversalRepositoryProvider).getITCReversals(
        financialYear: query.financialYear,
        period: query.period,
      ));
});

final gstr2bImportsProvider = FutureProvider.family<List<GSTR2BImport>, ItcQuery>((ref, query) async {
  return _unwrap(await ref.watch(gstr2bRepositoryProvider).getGSTR2BImports(
        financialYear: query.financialYear,
        period: query.period,
      ));
});

final gstr2bImportByIdProvider = FutureProvider.family<GSTR2BImport, String>((ref, id) async {
  return _unwrap(await ref.watch(gstr2bRepositoryProvider).getGSTR2BImportById(id));
});

final reconciliationResultProvider = FutureProvider.family<ReconciliationResult, String>((ref, id) async {
  return _unwrap(await ref.watch(gstr2bRepositoryProvider).getReconciliationResult(id));
});

final mismatchedEntriesProvider = FutureProvider.family<List<ITCLedgerEntry>, String>((ref, id) async {
  return _unwrap(await ref.watch(gstr2bRepositoryProvider).getMismatchedEntries(id));
});

final gstr9ReturnsProvider = FutureProvider.family<List<GSTR9Return>, String?>((ref, fy) async {
  return _unwrap(await ref.watch(gstr9RepositoryProvider).getGSTR9Returns(financialYear: fy));
});

final gstr9ByIdProvider = FutureProvider.family<GSTR9Return, String>((ref, id) async {
  return _unwrap(await ref.watch(gstr9RepositoryProvider).getGSTR9ById(id));
});

final gstr9cProvider = FutureProvider.family<List<GSTR9CReconciliation>, String?>((ref, fy) async {
  return _unwrap(await ref.watch(gstr9cRepositoryProvider).getGSTR9CReconciliations(financialYear: fy));
});

class TdsQuery {
  const TdsQuery({this.financialYear, this.quarter, this.section, this.status});

  final String? financialYear;
  final String? quarter;
  final TdsSection? section;
  final TDSStatus? status;

  @override
  bool operator ==(Object other) =>
      other is TdsQuery && other.financialYear == financialYear && other.quarter == quarter && other.section == section && other.status == status;

  @override
  int get hashCode => Object.hash(financialYear, quarter, section, status);
}

final tdsDeductionsProvider = FutureProvider.family<List<TDSDeduction>, TdsQuery>((ref, query) async {
  return _unwrap(await ref.watch(tdsRepositoryProvider).getTDSDeductions(
        financialYear: query.financialYear,
        quarter: query.quarter,
        section: query.section,
        status: query.status,
      ));
});

final tdsDeductionByIdProvider = FutureProvider.family<TDSDeduction, String>((ref, id) async {
  return _unwrap(await ref.watch(tdsRepositoryProvider).getTDSDeductionById(id));
});

final tdsSummaryProvider = FutureProvider.family<TDSSummary, ({String fy, String quarter})>((ref, key) async {
  return _unwrap(await ref.watch(tdsRepositoryProvider).getTDSSummary(key.fy, key.quarter));
});

final gstTdsProvider = FutureProvider.family<List<GSTTDS>, ItcQuery>((ref, query) async {
  return _unwrap(await ref.watch(gstTdsRepositoryProvider).getGSTTDS(financialYear: query.financialYear, period: query.period));
});

final eInvoicesProvider = FutureProvider.family<List<EInvoice>, EInvoiceStatus?>((ref, status) async {
  return _unwrap(await ref.watch(eInvoiceRepositoryProvider).getEInvoices(status: status));
});

final eInvoiceByIdProvider = FutureProvider.family<EInvoice, String>((ref, id) async {
  return _unwrap(await ref.watch(eInvoiceRepositoryProvider).getEInvoiceById(id));
});

final eWayBillsProvider = FutureProvider.family<List<EWayBill>, EWayBillStatus?>((ref, status) async {
  return _unwrap(await ref.watch(eWayBillRepositoryProvider).getEWayBills(status: status));
});

final eWayBillByIdProvider = FutureProvider.family<EWayBill, String>((ref, id) async {
  return _unwrap(await ref.watch(eWayBillRepositoryProvider).getEWayBillById(id));
});

final budgetsProvider = FutureProvider.family<List<Budget>, ItcQuery>((ref, query) async {
  return _unwrap(await ref.watch(budgetRepositoryProvider).getBudgets(financialYear: query.financialYear, projectId: query.supplierGstin));
});

final budgetByIdProvider = FutureProvider.family<Budget, String>((ref, id) async {
  return _unwrap(await ref.watch(budgetRepositoryProvider).getBudgetById(id));
});

final budgetVsActualProvider = FutureProvider.family<BudgetVsActual, String>((ref, fy) async {
  return _unwrap(await ref.watch(budgetRepositoryProvider).getBudgetVsActual(fy));
});

final forecastsProvider = FutureProvider.family<List<FinancialForecast>, ForecastType?>((ref, type) async {
  return _unwrap(await ref.watch(forecastRepositoryProvider).getForecasts(forecastType: type));
});

final forecastByIdProvider = FutureProvider.family<FinancialForecast, String>((ref, id) async {
  return _unwrap(await ref.watch(forecastRepositoryProvider).getForecastById(id));
});

final cashflowProjectionProvider = FutureProvider.family<CashflowProjection, int>((ref, months) async {
  return _unwrap(await ref.watch(forecastRepositoryProvider).getCashflowProjection(months));
});

final irpSettingsProvider = FutureProvider<IrpSettings>((ref) async {
  return _unwrap(await ref.watch(eInvoiceRepositoryProvider).getIrpSettings());
});
