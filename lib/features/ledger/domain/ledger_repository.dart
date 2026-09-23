import '../../../core/result/app_result.dart';
import '../../accounting/domain/financial_summary.dart';
import 'ledger_entry.dart';

abstract class LedgerRepository {
  Future<AppResult<List<LedgerEntry>>> getLedgerEntries({
    AccountType? accountType,
    String? accountId,
    DateTime? from,
    DateTime? to,
    String? financialYear,
  });

  Future<AppResult<List<LedgerEntry>>> getClientLedger(String clientId, {DateTime? from, DateTime? to});

  Future<AppResult<List<LedgerEntry>>> getVendorLedger(String vendorId, {DateTime? from, DateTime? to});

  Future<AppResult<List<LedgerEntry>>> getGeneralLedger({DateTime? from, DateTime? to});

  Future<AppResult<LedgerEntry>> addEntry({
    required AccountType accountType,
    String? accountId,
    required String description,
    double debitAmount = 0,
    double creditAmount = 0,
    String? referenceType,
    String? referenceId,
  });

  Future<AppResult<TrialBalance>> getTrialBalance(DateTime asOfDate);

  Future<AppResult<ProfitAndLoss>> getProfitAndLoss(DateTime from, DateTime to);

  Future<AppResult<BalanceSheet>> getBalanceSheet(DateTime asOfDate);
}
