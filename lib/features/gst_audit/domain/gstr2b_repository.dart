import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import 'gstr2b_import.dart';
import 'itc_ledger_entry.dart';
import 'reconciliation_result.dart';

abstract class GSTR2BRepository {
  Future<AppResult<List<GSTR2BImport>>> getGSTR2BImports({
    String? financialYear,
    String? period,
    GSTR2BStatus? status,
  });

  Future<AppResult<GSTR2BImport>> getGSTR2BImportById(String id);

  Future<AppResult<GSTR2BImport>> importGSTR2B({
    required String financialYear,
    required String period,
    required UploadBytes jsonFile,
  });

  Future<AppResult<ReconciliationResult>> reconcileGSTR2B(String importId);

  Future<AppResult<ReconciliationResult>> getReconciliationResult(String importId);

  Future<AppResult<List<ITCLedgerEntry>>> getMismatchedEntries(String importId);

  Future<AppResult<ITCLedgerEntry>> resolveMismatch(String itcLedgerId, MatchStatus newStatus, String reason);

  Future<AppResult<String>> exportReconciliationReport(String importId);
}
