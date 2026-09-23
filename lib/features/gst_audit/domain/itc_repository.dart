import '../../../core/result/app_result.dart';
import 'itc_ledger_entry.dart';
import 'itc_reversal.dart';

abstract class ITCRepository {
  Future<AppResult<List<ITCLedgerEntry>>> getITCLedger({
    String? financialYear,
    String? period,
    String? supplierGstin,
    ITCStatus? status,
    MatchStatus? matchStatus,
  });

  Future<AppResult<ITCLedgerEntry>> getITCEntryById(String id);

  Future<AppResult<ITCLedgerEntry>> createITCEntry({
    required String supplierGstin,
    required String supplierName,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double taxableValue,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    double cessAmount = 0,
    required double itcEligible,
    String? financialYear,
    String? period,
  });

  Future<AppResult<ITCLedgerEntry>> updateITCEntry(String id, Map<String, dynamic> data);

  Future<AppResult<ITCLedgerEntry>> markITCClaimed(String id, double claimedAmount, String gstr3bPeriod);

  Future<AppResult<ITCLedgerEntry>> markITCReversed(String id, double reversedAmount, ReversalReason reason);

  Future<AppResult<ITCSummary>> getITCSummary(String financialYear, String period);

  Future<AppResult<List<ITCLedgerEntry>>> getITCBySupplier(String supplierGstin, {String? financialYear});

  Future<AppResult<String>> exportITCLedgerToCsv({String? financialYear, String? period});
}

abstract class ITCReversalRepository {
  Future<AppResult<List<ITCReversal>>> getITCReversals({
    String? financialYear,
    String? period,
    ReversalStatus? status,
  });

  Future<AppResult<ITCReversal>> createITCReversal({
    required String itcLedgerId,
    required String supplierGstin,
    required String invoiceNumber,
    required double reversalAmount,
    required ReversalReason reversalReason,
    String? reversalRule,
    bool interestApplicable = false,
    double interestAmount = 0,
  });

  Future<AppResult<ITCReversal>> reportITCReversal(String id, String gstr3bPeriod);

  Future<AppResult<Map<String, double>>> getReversalSummary(String financialYear);
}
