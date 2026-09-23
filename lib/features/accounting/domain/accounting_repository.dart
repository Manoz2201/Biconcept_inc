import '../../../core/result/app_result.dart';
import '../../gst/domain/gst_settings.dart';
import 'financial_summary.dart';

abstract class AccountingRepository {
  Future<AppResult<FinancialSummary>> getFinancialSummary();

  Future<AppResult<AgeingReport>> getAgeingReport({required String type});

  Future<AppResult<List<CashflowMonth>>> getCashflow(DateTime from, DateTime to);

  Future<AppResult<List<NamedTotal>>> getMonthlyRevenueTrend(int months);

  Future<AppResult<List<NamedTotal>>> getTopClients({int limit = 10});

  Future<AppResult<List<NamedTotal>>> getTopVendors({int limit = 10});

  Future<AppResult<BankReconciliation>> getBankReconciliation({required DateTime from, required DateTime to});

  Future<AppResult<BankStatementLine>> addBankStatementLine({
    required DateTime entryDate,
    required String description,
    required double amount,
  });

  Future<AppResult<void>> matchBankLine(String lineId, String referenceId);

  Future<AppResult<FinancialYearClosing>> getFinancialYearClosing(String financialYear);

  Future<AppResult<FinancialYearClosing>> closeFinancialYear(String financialYear);
}
