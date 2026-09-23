import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../e_invoice/domain/e_invoice.dart';
import '../../e_invoice/domain/e_invoice_repository.dart';
import '../../e_way_bill/domain/e_way_bill.dart';
import '../../e_way_bill/domain/e_way_bill_repository.dart';
import '../../forecasting/domain/budget.dart';
import '../../forecasting/domain/budget_repository.dart';
import '../../gst/data/finance_workspace_store.dart';
import '../../gst/domain/gst_math.dart';
import '../../gst/domain/gst_settings.dart';
import '../../invoices/data/invoice_workspace_store.dart';
import '../../invoices/domain/invoice.dart';
import '../../tds/data/tds_certificate_service.dart';
import '../../tds/domain/tds_deduction.dart';
import '../../tds/domain/tds_repository.dart';
import '../../vendors/data/vendor_workspace_store.dart';
import '../domain/compliance_math.dart';
import '../domain/gstr2b_import.dart';
import '../domain/gstr2b_repository.dart';
import '../domain/gstr9_repository.dart';
import '../domain/gstr9_return.dart';
import '../domain/itc_ledger_entry.dart';
import '../domain/itc_repository.dart';
import '../domain/itc_reversal.dart';
import '../domain/reconciliation_result.dart';
import 'compliance_workspace.dart';
import 'compliance_workspace_store.dart';
import 'gst_audit_storage_service.dart';

class ComplianceRepositoryImpl
    implements
        ITCRepository,
        ITCReversalRepository,
        GSTR2BRepository,
        GSTR9Repository,
        GSTR9CRepository,
        TDSRepository,
        GSTTDSRepository,
        EInvoiceRepository,
        EWayBillRepository,
        BudgetRepository,
        ForecastRepository {
  ComplianceRepositoryImpl({
    ComplianceWorkspaceStore? store,
    FinanceWorkspaceStore? finance,
    InvoiceWorkspaceStore? invoices,
    VendorWorkspaceStore? vendors,
    GstAuditStorageService? files,
    TdsCertificateService? certificates,
    Functions? functions,
    AuditRepository? audit,
    String Function()? actorId,
  })  : _store = store ?? ComplianceWorkspaceStore(),
        _finance = finance ?? FinanceWorkspaceStore(),
        _invoices = invoices ?? InvoiceWorkspaceStore(),
        _vendors = vendors ?? VendorWorkspaceStore(),
        _files = files ?? GstAuditStorageService(),
        _certificates = certificates ?? TdsCertificateService(),
        _functions = functions ?? AppwriteService.functions,
        _audit = audit ?? AuditRepository(),
        _actorId = actorId ?? (() => 'unknown');

  final ComplianceWorkspaceStore _store;
  final FinanceWorkspaceStore _finance;
  final InvoiceWorkspaceStore _invoices;
  final VendorWorkspaceStore _vendors;
  final GstAuditStorageService _files;
  final TdsCertificateService _certificates;
  final Functions _functions;
  final AuditRepository _audit;
  final String Function() _actorId;

  Future<ComplianceWorkspace> _ws() async => (await _store.ensure()).workspace;

  Future<ComplianceWorkspace> _save(ComplianceWorkspace workspace) async =>
      (await _store.save(workspace)).workspace;

  Future<void> _log(String action, [Map<String, dynamic>? metadata]) async {
    await _audit.log(userId: _actorId(), action: action, metadata: metadata);
  }

  Future<void> _ping(String title, String body) =>
      AppNotifications.instance.showImmediate(title: title, body: body);

  T _require<T>(T? item, String label) {
    if (item == null) throw AppwriteException('$label not found', 404);
    return item;
  }

  @override
  Future<AppResult<List<ITCLedgerEntry>>> getITCLedger({
    String? financialYear,
    String? period,
    String? supplierGstin,
    ITCStatus? status,
    MatchStatus? matchStatus,
  }) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).itcLedger.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (period != null && item.period != period) return false;
        if (supplierGstin != null && item.supplierGstin != supplierGstin) return false;
        if (status != null && item.itcStatus != status) return false;
        if (matchStatus != null && item.matchStatus != matchStatus) return false;
        return true;
      }).toList()
        ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      return rows;
    });
  }

  @override
  Future<AppResult<ITCLedgerEntry>> getITCEntryById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).itcLedger.cast<ITCLedgerEntry?>().firstWhere((item) => item?.id == id, orElse: () => null), 'ITC entry');
    });
  }

  @override
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
  }) {
    return AppwriteService.guard(() async {
      if (!isValidGstin(supplierGstin) || (supplierGstin.isEmpty)) {
        throw AppwriteException('Enter a valid 15-character GSTIN', 400);
      }
      final now = DateTime.now().toUtc();
      final entry = ITCLedgerEntry(
        id: ID.unique(),
        financialYear: financialYear ?? financialYearLabel(invoiceDate),
        period: period ?? gstPeriodFromDate(invoiceDate),
        supplierGstin: supplierGstin.toUpperCase(),
        supplierName: supplierName,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        taxableValue: taxableValue,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        igstAmount: igstAmount,
        cessAmount: cessAmount,
        totalTax: money(cgstAmount + sgstAmount + igstAmount + cessAmount),
        itcEligible: itcEligible,
        itcStatus: ITCStatus.pending,
        matchStatus: MatchStatus.matched,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(itcLedger: [...ws.itcLedger, entry]));
      await _log('itc_entry_created', {'id': entry.id, 'invoiceNumber': invoiceNumber});
      return entry;
    });
  }

  @override
  Future<AppResult<ITCLedgerEntry>> updateITCEntry(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.itcLedger.cast<ITCLedgerEntry?>().firstWhere((item) => item?.id == id, orElse: () => null), 'ITC entry');
      final next = ITCLedgerEntry.fromJson({...current.toJson(), ...data, 'id': id, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(itcLedger: [for (final item in ws.itcLedger) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<ITCLedgerEntry>> markITCClaimed(String id, double claimedAmount, String gstr3bPeriod) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.itcLedger.cast<ITCLedgerEntry?>().firstWhere((item) => item?.id == id, orElse: () => null), 'ITC entry');
      if (current.matchStatus == MatchStatus.missingIn2b) {
        throw AppwriteException('ITC can only be claimed when the invoice is in GSTR-2B', 400);
      }
      final next = current.copyWith(itcClaimed: claimedAmount, itcStatus: ITCStatus.claimed, updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(itcLedger: [for (final item in ws.itcLedger) item.id == id ? next : item]));
      await _log('itc_claimed', {'id': id, 'period': gstr3bPeriod, 'amount': claimedAmount});
      return next;
    });
  }

  @override
  Future<AppResult<ITCLedgerEntry>> markITCReversed(String id, double reversedAmount, ReversalReason reason) {
    return AppwriteService.guard(() async {
      final result = await createITCReversal(
        itcLedgerId: id,
        supplierGstin: '',
        invoiceNumber: '',
        reversalAmount: reversedAmount,
        reversalReason: reason,
      );
      return result.when(
        success: (_) async {
          final ws = await _ws();
          return _require(ws.itcLedger.cast<ITCLedgerEntry?>().firstWhere((item) => item?.id == id, orElse: () => null), 'ITC entry');
        },
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  @override
  Future<AppResult<ITCSummary>> getITCSummary(String financialYear, String period) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).itcLedger.where((item) => item.financialYear == financialYear && item.period == period);
      final bySupplier = <String, double>{};
      var eligible = 0.0, claimed = 0.0, reversed = 0.0, pending = 0.0;
      for (final item in rows) {
        eligible += item.itcEligible;
        claimed += item.itcClaimed;
        reversed += item.itcReversed;
        if (item.itcStatus == ITCStatus.pending) pending += item.itcEligible;
        bySupplier[item.supplierGstin] = (bySupplier[item.supplierGstin] ?? 0) + item.itcEligible;
      }
      return ITCSummary(eligible: eligible, claimed: claimed, reversed: reversed, pending: pending, bySupplier: bySupplier);
    });
  }

  @override
  Future<AppResult<List<ITCLedgerEntry>>> getITCBySupplier(String supplierGstin, {String? financialYear}) {
    return getITCLedger(supplierGstin: supplierGstin, financialYear: financialYear);
  }

  @override
  Future<AppResult<String>> exportITCLedgerToCsv({String? financialYear, String? period}) {
    return AppwriteService.guard(() async {
      final rows = await getITCLedger(financialYear: financialYear, period: period);
      return rows.when(
        success: (items) => [
          csvEscape(['Supplier', 'GSTIN', 'Invoice', 'Date', 'Taxable', 'Tax', 'Status', 'Match']),
          for (final item in items)
            csvEscape([item.supplierName, item.supplierGstin, item.invoiceNumber, item.invoiceDate.toIso8601String(), item.taxableValue, item.totalTax, item.itcStatus.label, item.matchStatus.label]),
        ].join('\n'),
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  @override
  Future<AppResult<List<ITCReversal>>> getITCReversals({String? financialYear, String? period, ReversalStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).itcReversals.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (period != null && item.period != period) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<ITCReversal>> createITCReversal({
    required String itcLedgerId,
    required String supplierGstin,
    required String invoiceNumber,
    required double reversalAmount,
    required ReversalReason reversalReason,
    String? reversalRule,
    bool interestApplicable = false,
    double interestAmount = 0,
  }) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final entry = _require(ws.itcLedger.cast<ITCLedgerEntry?>().firstWhere((item) => item?.id == itcLedgerId, orElse: () => null), 'ITC entry');
      final now = DateTime.now().toUtc();
      final share = entry.totalTax == 0 ? 0.0 : reversalAmount / entry.totalTax;
      final reversal = ITCReversal(
        id: ID.unique(),
        financialYear: entry.financialYear,
        period: entry.period,
        itcLedgerId: itcLedgerId,
        supplierGstin: supplierGstin.isEmpty ? entry.supplierGstin : supplierGstin,
        invoiceNumber: invoiceNumber.isEmpty ? entry.invoiceNumber : invoiceNumber,
        reversalAmount: reversalAmount,
        cgstReversed: money(entry.cgstAmount * share),
        sgstReversed: money(entry.sgstAmount * share),
        igstReversed: money(entry.igstAmount * share),
        reversalReason: reversalReason,
        reversalRule: reversalRule,
        interestApplicable: interestApplicable,
        interestAmount: interestAmount,
        status: ReversalStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      final nextEntry = entry.copyWith(
        itcReversed: entry.itcReversed + reversalAmount,
        itcStatus: ITCStatus.reversed,
        reversalReason: reversalReason.value,
        updatedAt: now,
      );
      await _save(ws.copyWith(
        itcLedger: [for (final item in ws.itcLedger) item.id == entry.id ? nextEntry : item],
        itcReversals: [...ws.itcReversals, reversal],
      ));
      await _log('itc_reversal_created', {'id': reversal.id, 'reason': reversalReason.value});
      await _log('itc_reversed', {'id': entry.id, 'amount': reversalAmount});
      await _ping('ITC reversal required', '${entry.invoiceNumber} reversed ${formatMoney(reversalAmount)}');
      return reversal;
    });
  }

  @override
  Future<AppResult<ITCReversal>> reportITCReversal(String id, String gstr3bPeriod) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.itcReversals.cast<ITCReversal?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Reversal');
      final next = ITCReversal.fromJson({
        ...current.toJson(),
        'status': ReversalStatus.reported.value,
        'reportedInReturn': gstr3bPeriod,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(itcReversals: [for (final item in ws.itcReversals) item.id == id ? next : item]));
      await _log('itc_reversal_reported', {'id': id, 'period': gstr3bPeriod});
      return next;
    });
  }

  @override
  Future<AppResult<Map<String, double>>> getReversalSummary(String financialYear) {
    return AppwriteService.guard(() async {
      final map = <String, double>{};
      for (final item in (await _ws()).itcReversals.where((row) => row.financialYear == financialYear)) {
        map[item.reversalReason.label] = (map[item.reversalReason.label] ?? 0) + item.reversalAmount;
      }
      return map;
    });
  }

  @override
  Future<AppResult<List<GSTR2BImport>>> getGSTR2BImports({String? financialYear, String? period, GSTR2BStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).gstr2bImports.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (period != null && item.period != period) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<GSTR2BImport>> getGSTR2BImportById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).gstr2bImports.cast<GSTR2BImport?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-2B import');
    });
  }

  @override
  Future<AppResult<GSTR2BImport>> importGSTR2B({
    required String financialYear,
    required String period,
    required UploadBytes jsonFile,
  }) {
    return AppwriteService.guard(() async {
      final fileId = await _files.upload(jsonFile);
      final decoded = jsonDecode(utf8.decode(jsonFile.bytes));
      final lines = parseGstr2bJson(decoded);
      final now = DateTime.now().toUtc();
      final record = GSTR2BImport(
        id: ID.unique(),
        financialYear: financialYear,
        period: period,
        importDate: now,
        fileName: jsonFile.filename,
        fileId: fileId,
        totalRecords: lines.length,
        totalTaxableValue: lines.fold<double>(0, (sum, line) => sum + line.taxableValue),
        totalCgst: lines.fold<double>(0, (sum, line) => sum + line.cgst),
        totalSgst: lines.fold<double>(0, (sum, line) => sum + line.sgst),
        totalIgst: lines.fold<double>(0, (sum, line) => sum + line.igst),
        status: GSTR2BStatus.imported,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(gstr2bImports: [...ws.gstr2bImports, record]));
      await _log('gstr2b_imported', {'id': record.id, 'period': period, 'records': lines.length});
      await _ping('GSTR-2B imported', '${lines.length} records for $period');
      await reconcileGSTR2B(record.id);
      return (await _ws()).gstr2bImports.firstWhere((item) => item.id == record.id);
    });
  }

  @override
  Future<AppResult<ReconciliationResult>> reconcileGSTR2B(String importId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final import = _require(ws.gstr2bImports.cast<GSTR2BImport?>().firstWhere((item) => item?.id == importId, orElse: () => null), 'GSTR-2B import');
      final bytes = await _files.download(import.fileId);
      final lines = parseGstr2bJson(jsonDecode(utf8.decode(bytes)));
      final vendors = await _vendors.list();
      final books = <PurchaseRegisterLine>[
        for (final snap in vendors)
          for (final bill in snap.workspace.bills)
            if (dateInPeriod(bill.billDate, import.period) && dateInFinancialYear(bill.billDate, import.financialYear))
              PurchaseRegisterLine(
                billId: bill.id,
                supplierGstin: snap.vendor.gstin ?? '',
                supplierName: snap.vendor.companyName,
                invoiceNumber: bill.billNumber,
                invoiceDate: bill.billDate,
                taxableValue: bill.subtotal,
                taxAmount: bill.taxAmount,
              ),
      ];
      final matched = classifyGstr2bMatches(
        financialYear: import.financialYear,
        period: import.period,
        importId: importId,
        gstr2b: lines,
        books: books,
      );
      final remaining = [for (final item in ws.itcLedger) if (item.gstr2bId != importId) item];
      final updatedImport = GSTR2BImport.fromJson({
        ...import.toJson(),
        'matchedRecords': matched.result.exactMatches + matched.result.suggestedMatches,
        'mismatchedRecords': matched.result.mismatched,
        'missingInBooks': matched.result.missingInBooks,
        'missingIn2b': matched.result.missingIn2b,
        'status': GSTR2BStatus.reconciled.value,
        'reconciledAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(
        itcLedger: [...remaining, ...matched.entries],
        gstr2bImports: [for (final item in ws.gstr2bImports) item.id == importId ? updatedImport : item],
      ));
      await _log('gstr2b_reconciled', matched.result.toJson());
      await _ping('ITC reconciliation completed', '${matched.result.matchPercentage.toStringAsFixed(1)}% matched');
      if (matched.result.mismatched + matched.result.missingIn2b + matched.result.missingInBooks > 0) {
        await _ping('ITC mismatch detected', '${matched.result.mismatched + matched.result.missingIn2b + matched.result.missingInBooks} rows need review');
      }
      return matched.result;
    });
  }

  @override
  Future<AppResult<ReconciliationResult>> getReconciliationResult(String importId) {
    return AppwriteService.guard(() async {
      final import = _require((await _ws()).gstr2bImports.cast<GSTR2BImport?>().firstWhere((item) => item?.id == importId, orElse: () => null), 'GSTR-2B import');
      return ReconciliationResult(
        exactMatches: import.matchedRecords,
        suggestedMatches: 0,
        mismatched: import.mismatchedRecords,
        missingIn2b: import.missingIn2b,
        missingInBooks: import.missingInBooks,
        totalProcessed: import.totalRecords + import.missingIn2b,
      );
    });
  }

  @override
  Future<AppResult<List<ITCLedgerEntry>>> getMismatchedEntries(String importId) {
    return getITCLedger(matchStatus: MatchStatus.mismatched);
  }

  @override
  Future<AppResult<ITCLedgerEntry>> resolveMismatch(String itcLedgerId, MatchStatus newStatus, String reason) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.itcLedger.cast<ITCLedgerEntry?>().firstWhere((item) => item?.id == itcLedgerId, orElse: () => null), 'ITC entry');
      final next = current.copyWith(matchStatus: newStatus, mismatchReason: reason, updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(itcLedger: [for (final item in ws.itcLedger) item.id == itcLedgerId ? next : item]));
      await _log('mismatch_resolved', {'id': itcLedgerId, 'status': newStatus.value, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<String>> exportReconciliationReport(String importId) {
    return AppwriteService.guard(() async {
      final result = await getReconciliationResult(importId);
      final rows = (await _ws()).itcLedger.where((item) => item.gstr2bId == importId);
      return result.when(
        success: (summary) => [
          'Reconciliation $importId',
          'Exact ${summary.exactMatches}, suggested ${summary.suggestedMatches}, mismatched ${summary.mismatched}',
          'Missing in 2B ${summary.missingIn2b}, missing in books ${summary.missingInBooks}',
          csvEscape(['Supplier', 'Invoice', 'Taxable', 'Match', 'Reason']),
          for (final item in rows)
            csvEscape([item.supplierName, item.invoiceNumber, item.taxableValue, item.matchStatus.label, item.mismatchReason]),
        ].join('\n'),
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  @override
  Future<AppResult<List<GSTR9Return>>> getGSTR9Returns({String? financialYear, GSTR9Status? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).gstr9Returns.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<GSTR9Return>> getGSTR9ById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).gstr9Returns.cast<GSTR9Return?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9');
    });
  }

  @override
  Future<AppResult<GSTR9Return>> prepareGSTR9(String financialYear) {
    return AppwriteService.guard(() async {
      final settings = (await _finance.ensure()).settings;
      final finance = await _finance.ensure();
      final invoices = await _invoices.list(status: InvoiceStatus.issued.value);
      final paid = await _invoices.list(status: InvoiceStatus.paid.value);
      final all = [...invoices, ...paid].where((row) => dateInFinancialYear(row.invoice.invoiceDate, financialYear));
      var taxable = 0.0, cgst = 0.0, sgst = 0.0, igst = 0.0, cess = 0.0, turnover = 0.0;
      for (final row in all) {
        taxable += row.invoice.subtotal;
        cgst += row.invoice.totalCgst;
        sgst += row.invoice.totalSgst;
        igst += row.invoice.totalIgst;
        cess += row.invoice.totalCess;
        turnover += row.invoice.grandTotal;
      }
      final returns = finance.workspace.gstReturns.where((item) => item.financialYear == financialYear);
      final itcClaimed = (await _ws()).itcLedger.where((item) => item.financialYear == financialYear).fold<double>(0, (sum, item) => sum + item.itcClaimed);
      final itcReversed = (await _ws()).itcLedger.where((item) => item.financialYear == financialYear).fold<double>(0, (sum, item) => sum + item.itcReversed);
      final now = DateTime.now().toUtc();
      final prepared = GSTR9Return(
        id: ID.unique(),
        financialYear: financialYear,
        gstin: settings.firmGstin ?? '',
        legalName: settings.firmName,
        tradeName: settings.firmName,
        part1BasicDetails: jsonEncode({'gstin': settings.firmGstin, 'legalName': settings.firmName, 'fy': financialYear}),
        part2OutwardSupplies: jsonEncode({'taxable': taxable, 'cgst': cgst, 'sgst': sgst, 'igst': igst, 'cess': cess, 'exports': 0, 'exempt': 0, 'nilRated': 0}),
        part3ITC: jsonEncode({'claimed': itcClaimed, 'reversed': itcReversed, 'ineligible': 0, 'transition': 0}),
        part4TaxPaid: jsonEncode({'cgst': cgst, 'sgst': sgst, 'igst': igst, 'cess': cess, 'interest': 0, 'lateFee': 0}),
        part5Transactions: jsonEncode({'demands': 0, 'refunds': 0, 'deemedSupply': 0}),
        part6Other: jsonEncode({'amendments': 0, 'gstr1Count': returns.where((item) => item.returnType == GSTReturnType.gstr1).length, 'gstr3bCount': returns.where((item) => item.returnType == GSTReturnType.gstr3b).length}),
        totalTurnover: money(turnover),
        totalTaxableValue: money(taxable),
        totalCgst: money(cgst),
        totalSgst: money(sgst),
        totalIgst: money(igst),
        totalCess: money(cess),
        totalItcClaimed: money(itcClaimed),
        totalItcReversed: money(itcReversed),
        netTaxPayable: money(cgst + sgst + igst + cess - itcClaimed + itcReversed),
        status: GSTR9Status.draft,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(gstr9Returns: [...ws.gstr9Returns, prepared]));
      await _log('gstr9_prepared', {'id': prepared.id, 'financialYear': financialYear});
      await _ping('GSTR-9 preparation ready', 'Draft prepared for $financialYear');
      return prepared;
    });
  }

  @override
  Future<AppResult<GSTR9Return>> updateGSTR9(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstr9Returns.cast<GSTR9Return?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9');
      if (current.status == GSTR9Status.filed || current.status == GSTR9Status.acknowledged) {
        throw AppwriteException('Filed GSTR-9 cannot be edited', 400);
      }
      final next = GSTR9Return.fromJson({...current.toJson(), ...data, 'id': id, 'status': GSTR9Status.prepared.value});
      await _save(ws.copyWith(gstr9Returns: [for (final item in ws.gstr9Returns) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<GSTR9Return>> fileGSTR9(String id, String acknowledgementNumber) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstr9Returns.cast<GSTR9Return?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9');
      final next = GSTR9Return.fromJson({
        ...current.toJson(),
        'status': GSTR9Status.filed.value,
        'acknowledgementNumber': acknowledgementNumber,
        'filedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(gstr9Returns: [for (final item in ws.gstr9Returns) item.id == id ? next : item]));
      await _log('gstr9_filed', {'id': id, 'acknowledgementNumber': acknowledgementNumber});
      await _ping('GSTR-9 filed', 'Acknowledgement $acknowledgementNumber');
      return next;
    });
  }

  @override
  Future<AppResult<String>> exportGSTR9(String id) {
    return AppwriteService.guard(() async => jsonEncode((await getGSTR9ById(id)).when(success: (item) => item.toJson(), failure: (error) => throw AppwriteException(error.userMessage, 400))));
  }

  @override
  Future<AppResult<List<GSTR9CReconciliation>>> getGSTR9CReconciliations({String? financialYear, GSTR9CStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).gstr9c.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<GSTR9CReconciliation>> prepareGSTR9C(String gstr9Id) {
    return AppwriteService.guard(() async {
      final gstr9 = (await getGSTR9ById(gstr9Id)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400));
      final now = DateTime.now().toUtc();
      final rec = GSTR9CReconciliation(
        id: ID.unique(),
        financialYear: gstr9.financialYear,
        gstr9Id: gstr9Id,
        reconciliationData: jsonEncode({'tables': 'turnover,taxable,itc'}),
        turnoverAsPerAudited: gstr9.totalTurnover,
        turnoverAsPerReturns: gstr9.totalTurnover,
        difference: 0,
        taxableTurnoverAudited: gstr9.totalTaxableValue,
        taxableTurnoverReturns: gstr9.totalTaxableValue,
        itcAsPerAudited: gstr9.totalItcClaimed,
        itcAsPerReturns: gstr9.totalItcClaimed,
        itcDifference: 0,
        status: GSTR9CStatus.draft,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(gstr9c: [...ws.gstr9c, rec]));
      await _log('gstr9c_prepared', {'id': rec.id, 'gstr9Id': gstr9Id});
      return rec;
    });
  }

  @override
  Future<AppResult<GSTR9CReconciliation>> updateGSTR9C(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstr9c.cast<GSTR9CReconciliation?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9C');
      if (current.status == GSTR9CStatus.filed) throw AppwriteException('Filed GSTR-9C cannot be edited', 400);
      final next = GSTR9CReconciliation.fromJson({...current.toJson(), ...data, 'id': id, 'status': GSTR9CStatus.prepared.value});
      await _save(ws.copyWith(gstr9c: [for (final item in ws.gstr9c) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<GSTR9CReconciliation>> selfCertifyGSTR9C(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstr9c.cast<GSTR9CReconciliation?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9C');
      if (current.turnoverAsPerReturns > kGstr9cTurnoverThreshold && current.status == GSTR9CStatus.draft) {
        // Self-certification is mandatory above ₹5 crore.
      }
      final next = GSTR9CReconciliation.fromJson({
        ...current.toJson(),
        'status': GSTR9CStatus.selfCertified.value,
        'certifiedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(gstr9c: [for (final item in ws.gstr9c) item.id == id ? next : item]));
      await _log('gstr9c_certified', {'id': id});
      await _ping('GSTR-9C self-certified', current.financialYear);
      return next;
    });
  }

  @override
  Future<AppResult<GSTR9CReconciliation>> fileGSTR9C(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstr9c.cast<GSTR9CReconciliation?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9C');
      final next = GSTR9CReconciliation.fromJson({...current.toJson(), 'status': GSTR9CStatus.filed.value});
      await _save(ws.copyWith(gstr9c: [for (final item in ws.gstr9c) item.id == id ? next : item]));
      await _log('gstr9c_filed', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<String>> exportGSTR9C(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstr9c.cast<GSTR9CReconciliation?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GSTR-9C');
      return jsonEncode(current.toJson());
    });
  }

  @override
  Future<AppResult<List<TDSDeduction>>> getTDSDeductions({
    String? financialYear,
    String? quarter,
    TdsSection? section,
    TDSStatus? status,
  }) {
    return AppwriteService.guard(() async {
      return (await _ws()).tdsDeductions.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (quarter != null && item.quarter != quarter) return false;
        if (section != null && item.section != section) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<TDSDeduction>> getTDSDeductionById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).tdsDeductions.cast<TDSDeduction?>().firstWhere((item) => item?.id == id, orElse: () => null), 'TDS deduction');
    });
  }

  @override
  Future<AppResult<TDSDeduction>> createTDSDeduction({
    required TdsSection section,
    required String deducteeName,
    required String deducteePan,
    required TdsDeducteeType deducteeType,
    required DateTime invoiceDate,
    required double grossAmount,
    String? deducteeId,
    String? billId,
    String? paymentId,
    DateTime? paymentDate,
    Tds194JKind? kind194j,
    Tds194IKind? kind194i,
  }) {
    return AppwriteService.guard(() async {
      if (!isValidPan(deducteePan) || deducteePan.isEmpty) {
        throw AppwriteException('PAN must match ABCDE1234F', 400);
      }
      final fy = financialYearLabel(invoiceDate);
      final annual = (await _ws()).tdsDeductions
          .where((item) => item.deducteePan == deducteePan.toUpperCase() && item.financialYear == fy && item.section == section)
          .fold<double>(0, (sum, item) => sum + item.grossAmount);
      final calc = computeTds(
        section: section,
        deducteeType: deducteeType,
        grossAmount: grossAmount,
        annualGross: annual,
        kind194j: kind194j,
        kind194i: kind194i,
      );
      final now = DateTime.now().toUtc();
      final row = TDSDeduction(
        id: ID.unique(),
        section: section,
        financialYear: fy,
        quarter: gstQuarterFromDate(invoiceDate),
        deducteeId: deducteeId,
        deducteeName: deducteeName,
        deducteePan: deducteePan.toUpperCase(),
        deducteeType: deducteeType,
        billId: billId,
        paymentId: paymentId,
        invoiceDate: invoiceDate,
        paymentDate: paymentDate,
        grossAmount: grossAmount,
        tdsRate: calc.rate,
        tdsAmount: calc.tdsAmount,
        netPayable: calc.netPayable,
        thresholdLimit: calc.thresholdLimit,
        thresholdCrossed: calc.thresholdCrossed,
        status: TDSStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(tdsDeductions: [...ws.tdsDeductions, row]));
      await _log('tds_deduction_created', {'id': row.id, 'section': section.value});
      if (calc.thresholdCrossed) await _ping('TDS deduction due', '${section.value} ${formatMoney(calc.tdsAmount)}');
      return row;
    });
  }

  @override
  Future<AppResult<TDSDeduction>> markTDSDeducted(String id) {
    return _patchTds(id, {'status': TDSStatus.deducted.value}, 'tds_deducted');
  }

  @override
  Future<AppResult<TDSDeduction>> depositTDS(String id, String challanNumber, DateTime challanDate) {
    return _patchTds(id, {
      'status': TDSStatus.deposited.value,
      'challanNumber': challanNumber,
      'challanDate': challanDate.toIso8601String(),
    }, 'tds_deposited');
  }

  Future<AppResult<TDSDeduction>> _patchTds(String id, Map<String, dynamic> data, String action) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.tdsDeductions.cast<TDSDeduction?>().firstWhere((item) => item?.id == id, orElse: () => null), 'TDS deduction');
      final next = TDSDeduction.fromJson({...current.toJson(), ...data, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(tdsDeductions: [for (final item in ws.tdsDeductions) item.id == id ? next : item]));
      await _log(action, {'id': id});
      if (action == 'tds_deposited') await _ping('TDS deposited', next.challanNumber ?? next.deducteeName);
      return next;
    });
  }

  @override
  Future<AppResult<Uint8List>> generateTDSCertificate(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.tdsDeductions.cast<TDSDeduction?>().firstWhere((item) => item?.id == id, orElse: () => null), 'TDS deduction');
      if (current.status != TDSStatus.deposited && current.status != TDSStatus.certificateIssued) {
        throw AppwriteException('Deposit TDS before issuing Form 16A', 400);
      }
      final settings = (await _finance.ensure()).settings;
      final number = current.certificateNumber ?? '16A/${current.financialYear}/${id.substring(0, 6).toUpperCase()}';
      final next = TDSDeduction.fromJson({
        ...current.toJson(),
        'status': TDSStatus.certificateIssued.value,
        'certificateNumber': number,
        'certificateDate': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(tdsDeductions: [for (final item in ws.tdsDeductions) item.id == id ? next : item]));
      await _log('tds_certificate_generated', {'id': id, 'certificateNumber': number});
      await _ping('TDS certificate generated', '${next.deducteeName} $number');
      return _certificates.form16A(tds: next, firmName: settings.firmName, firmPan: settings.firmPan);
    });
  }

  @override
  Future<AppResult<TDSSummary>> getTDSSummary(String financialYear, String quarter) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).tdsDeductions.where((item) => item.financialYear == financialYear && item.quarter == quarter);
      final bySection = <String, double>{};
      var gross = 0.0, tds = 0.0, net = 0.0;
      for (final item in rows) {
        gross += item.grossAmount;
        tds += item.tdsAmount;
        net += item.netPayable;
        bySection[item.section.value] = (bySection[item.section.value] ?? 0) + item.tdsAmount;
      }
      return TDSSummary(gross: gross, tds: tds, net: net, bySection: bySection);
    });
  }

  @override
  Future<AppResult<Map<String, dynamic>>> getTDSReturnData(String financialYear, String quarter) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).tdsDeductions.where((item) => item.financialYear == financialYear && item.quarter == quarter);
      return {
        'form': '26Q',
        'financialYear': financialYear,
        'quarter': quarter,
        'deductees': [for (final item in rows) item.toJson()],
      };
    });
  }

  @override
  Future<AppResult<String>> exportTDSRegisterToCsv({String? financialYear, String? quarter}) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).tdsDeductions.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (quarter != null && item.quarter != quarter) return false;
        return true;
      });
      return [
        csvEscape(['Deductee', 'PAN', 'Section', 'Gross', 'Rate', 'TDS', 'Status']),
        for (final item in rows)
          csvEscape([item.deducteeName, item.deducteePan, item.section.value, item.grossAmount, item.tdsRate, item.tdsAmount, item.status.label]),
      ].join('\n');
    });
  }

  @override
  Future<AppResult<List<GSTTDS>>> getGSTTDS({String? financialYear, String? period, GSTTDSStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).gstTds.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (period != null && item.period != period) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<GSTTDS?>> createGSTTDS({
    required String vendorId,
    required String vendorGstin,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double taxableValue,
    required double contractValue,
    required bool interState,
    String? financialYear,
    String? period,
  }) {
    return AppwriteService.guard(() async {
      if (!isValidGstin(vendorGstin) || vendorGstin.isEmpty) {
        throw AppwriteException('Enter a valid vendor GSTIN', 400);
      }
      final calc = computeGstTds(taxableValue: taxableValue, contractValue: contractValue, interState: interState);
      if (!calc.applicable) return null;
      final now = DateTime.now().toUtc();
      final row = GSTTDS(
        id: ID.unique(),
        financialYear: financialYear ?? financialYearLabel(invoiceDate),
        period: period ?? gstPeriodFromDate(invoiceDate),
        vendorId: vendorId,
        vendorGstin: vendorGstin.toUpperCase(),
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        taxableValue: taxableValue,
        contractValue: contractValue,
        tdsRate: calc.tdsRate,
        cgstTds: calc.cgstTds,
        sgstTds: calc.sgstTds,
        igstTds: calc.igstTds,
        totalTds: calc.totalTds,
        status: GSTTDSStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(gstTds: [...ws.gstTds, row]));
      await _log('gst_tds_created', {'id': row.id, 'invoiceNumber': invoiceNumber});
      await _ping('GST TDS deducted', '${formatMoney(row.totalTds)} on $invoiceNumber');
      return row;
    });
  }

  @override
  Future<AppResult<GSTTDS>> markGSTTDSDeducted(String id) => _patchGstTds(id, {'status': GSTTDSStatus.deducted.value}, 'gst_tds_deducted');

  @override
  Future<AppResult<GSTTDS>> depositGSTTDS(String id, String challanNumber, DateTime challanDate) {
    return _patchGstTds(id, {
      'status': GSTTDSStatus.deposited.value,
      'challanNumber': challanNumber,
      'challanDate': challanDate.toIso8601String(),
    }, 'gst_tds_deposited');
  }

  @override
  Future<AppResult<GSTTDS>> fileGSTR7(String id, String gstr7Period) {
    return _patchGstTds(id, {
      'status': GSTTDSStatus.returnFiled.value,
      'gstr7Filed': true,
      'gstr7Period': gstr7Period,
    }, 'gstr7_filed');
  }

  Future<AppResult<GSTTDS>> _patchGstTds(String id, Map<String, dynamic> data, String action) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.gstTds.cast<GSTTDS?>().firstWhere((item) => item?.id == id, orElse: () => null), 'GST TDS');
      final next = GSTTDS.fromJson({...current.toJson(), ...data, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(gstTds: [for (final item in ws.gstTds) item.id == id ? next : item]));
      await _log(action, {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Map<String, double>>> getGSTTDSSummary(String financialYear, String period) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).gstTds.where((item) => item.financialYear == financialYear && item.period == period);
      return {
        'total': rows.fold<double>(0, (sum, item) => sum + item.totalTds),
        'pending': rows.where((item) => item.status == GSTTDSStatus.pending).fold<double>(0, (sum, item) => sum + item.totalTds),
        'deposited': rows.where((item) => item.status == GSTTDSStatus.deposited || item.status == GSTTDSStatus.returnFiled).fold<double>(0, (sum, item) => sum + item.totalTds),
      };
    });
  }

  @override
  Future<AppResult<String>> exportGSTR7Data(String financialYear, String period) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).gstTds.where((item) => item.financialYear == financialYear && item.period == period);
      return jsonEncode({'form': 'GSTR-7', 'financialYear': financialYear, 'period': period, 'rows': [for (final item in rows) item.toJson()]});
    });
  }

  @override
  Future<AppResult<List<EInvoice>>> getEInvoices({String? financialYear, EInvoiceStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).eInvoices.where((item) {
        if (financialYear != null && financialYearLabel(item.invoiceDate) != financialYear) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<EInvoice>> getEInvoiceById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).eInvoices.cast<EInvoice?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-invoice');
    });
  }

  @override
  Future<AppResult<EInvoice?>> getEInvoiceByInvoiceId(String invoiceId) {
    return AppwriteService.guard(() async {
      for (final item in (await _ws()).eInvoices) {
        if (item.invoiceId == invoiceId) return item;
      }
      return null;
    });
  }

  @override
  Future<AppResult<EInvoice>> generateIRN(String invoiceId) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(invoiceId);
      final invoice = snap.invoice;
      if (invoice.status == InvoiceStatus.draft || invoice.status == InvoiceStatus.voided) {
        throw AppwriteException('Issue the invoice before generating an IRN', 400);
      }
      final settings = (await _finance.ensure()).settings;
      final payload = buildIrpPayload(
        invoice: invoice,
        sellerGstin: settings.firmGstin ?? '',
        sellerName: settings.firmName,
        sellerAddress: settings.firmAddress,
        sellerCity: settings.firmCity,
        sellerPincode: settings.firmPincode,
        sellerStateCode: settings.firmStateCode,
        buyerGstin: '',
        buyerName: invoice.clientId,
        buyerAddress: '',
        buyerCity: '',
        buyerPincode: '',
        buyerStateCode: invoice.placeOfSupplyCode,
      );
      Map<String, dynamic>? remote;
      try {
        final execution = await _functions.createExecution(
          functionId: AppwriteService.generateEinvoiceIrnFn,
          body: jsonEncode({'invoiceId': invoiceId, 'payload': payload}),
        );
        final body = jsonDecode(execution.responseBody);
        if (body is Map) remote = Map<String, dynamic>.from(body);
      } catch (_) {}
      final now = DateTime.now().toUtc();
      final success = remote?['success'] == true && remote?['irn'] != null;
      final existing = (await _ws()).eInvoices.cast<EInvoice?>().firstWhere((item) => item?.invoiceId == invoiceId, orElse: () => null);
      final row = EInvoice(
        id: existing?.id ?? ID.unique(),
        invoiceId: invoiceId,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.invoiceDate,
        irn: remote?['irn']?.toString(),
        ackNumber: remote?['ackNumber']?.toString(),
        ackDate: DateTime.tryParse(remote?['ackDate']?.toString() ?? ''),
        qrCode: remote?['qrCode']?.toString(),
        signedInvoice: remote?['signedInvoice']?.toString(),
        signedQrCode: remote?['qrCode']?.toString(),
        status: success ? EInvoiceStatus.generated : EInvoiceStatus.failed,
        errorMessage: success ? null : (remote?['error']?.toString() ?? 'Deploy generate-einvoice-irn and set IRP credentials in Function env'),
        retryCount: (existing?.retryCount ?? 0) + (success ? 0 : 1),
        irpResponse: remote == null ? null : jsonEncode(remote),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final ws = await _ws();
      final list = existing == null
          ? [...ws.eInvoices, row]
          : [for (final item in ws.eInvoices) item.invoiceId == invoiceId ? row : item];
      await _save(ws.copyWith(eInvoices: list));
      if (success) {
        await _log('einvoice_generated', {'id': row.id, 'irn': row.irn});
        await _ping('E-invoice IRN generated', invoice.invoiceNumber);
      } else {
        await _ping('E-invoice IRN failed', row.errorMessage ?? invoice.invoiceNumber);
      }
      return row;
    });
  }

  @override
  Future<AppResult<EInvoice>> cancelIRN(String id, String reason, String remarks) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.eInvoices.cast<EInvoice?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-invoice');
      final generatedAt = current.ackDate ?? current.updatedAt ?? current.createdAt ?? DateTime.now();
      if (!withinHours(generatedAt, kIrnCancelHours)) {
        throw AppwriteException('IRN can be cancelled only within 24 hours of generation', 400);
      }
      if (current.status != EInvoiceStatus.generated) {
        throw AppwriteException('Only a generated IRN can be cancelled', 400);
      }
      final next = EInvoice.fromJson({
        ...current.toJson(),
        'status': EInvoiceStatus.cancelled.value,
        'cancelReason': reason,
        'cancelRemarks': remarks,
        'cancelledAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(eInvoices: [for (final item in ws.eInvoices) item.id == id ? next : item]));
      await _log('einvoice_cancelled', {'id': id, 'reason': reason});
      await _ping('E-invoice IRN cancelled', current.invoiceNumber);
      return next;
    });
  }

  @override
  Future<AppResult<EInvoice>> retryIRNGeneration(String id) {
    return AppwriteService.guard(() async {
      final current = _require((await _ws()).eInvoices.cast<EInvoice?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-invoice');
      return (await generateIRN(current.invoiceId)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400));
    });
  }

  @override
  Future<AppResult<String>> exportEInvoicesToCsv({String? financialYear}) {
    return AppwriteService.guard(() async {
      final rows = (await getEInvoices(financialYear: financialYear)).when(success: (items) => items, failure: (error) => throw AppwriteException(error.userMessage, 400));
      return [
        csvEscape(['Invoice', 'IRN', 'Ack', 'Status']),
        for (final item in rows) csvEscape([item.invoiceNumber, item.irn, item.ackNumber, item.status.label]),
      ].join('\n');
    });
  }

  @override
  Future<AppResult<IrpSettings>> getIrpSettings() {
    return AppwriteService.guard(() async => (await _ws()).irpSettings);
  }

  @override
  Future<AppResult<IrpSettings>> saveIrpSettings(IrpSettings settings) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(irpSettings: settings));
      return settings;
    });
  }

  @override
  Future<AppResult<List<EWayBill>>> getEWayBills({String? financialYear, EWayBillStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).eWayBills.where((item) {
        if (financialYear != null && financialYearLabel(item.invoiceDate) != financialYear) return false;
        if (status != null && item.displayStatus != status && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<EWayBill>> getEWayBillById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).eWayBills.cast<EWayBill?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-way bill');
    });
  }

  @override
  Future<AppResult<EWayBill?>> generateEWayBill({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required EwbSupplyType supplyType,
    required EwbSubSupplyType subSupplyType,
    required EwbDocumentType documentType,
    required String fromGstin,
    required String fromAddress,
    required String fromPlace,
    required String fromPincode,
    required String fromStateCode,
    required String toAddress,
    required String toPlace,
    required String toPincode,
    required String toStateCode,
    required double totalValue,
    required double taxableValue,
    required String hsnCode,
    String? eInvoiceId,
    String? invoiceId,
    String? fromTradeName,
    String? toGstin,
    String? toTradeName,
    String? transporterId,
    String? transporterName,
    EwbTransportMode? transportMode,
    String? vehicleNumber,
    String? vehicleType,
    int? distance,
  }) {
    return AppwriteService.guard(() async {
      if (!ewayBillRequired(totalValue) && subSupplyType != EwbSubSupplyType.jobWork) {
        return null;
      }
      if (ewayBillGoodsTooOld(invoiceDate)) {
        throw AppwriteException('E-way bill cannot be generated for goods older than 180 days', 400);
      }
      if (!isValidGstin(fromGstin) || fromGstin.isEmpty) {
        throw AppwriteException('Enter a valid from GSTIN', 400);
      }
      final now = DateTime.now().toUtc();
      final odc = vehicleType == 'over_dimensional_cargo';
      final validUntil = ewayBillValidUntil(now, distanceKm: distance ?? 0, overDimensional: odc);
      var row = EWayBill(
        id: ID.unique(),
        eInvoiceId: eInvoiceId,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        supplyType: supplyType,
        subSupplyType: subSupplyType,
        documentType: documentType,
        fromGstin: fromGstin.toUpperCase(),
        fromTradeName: fromTradeName,
        fromAddress: fromAddress,
        fromPlace: fromPlace,
        fromPincode: fromPincode,
        fromStateCode: fromStateCode,
        toGstin: toGstin,
        toTradeName: toTradeName,
        toAddress: toAddress,
        toPlace: toPlace,
        toPincode: toPincode,
        toStateCode: toStateCode,
        totalValue: totalValue,
        taxableValue: taxableValue,
        hsnCode: hsnCode,
        transporterId: transporterId,
        transporterName: transporterName,
        transportMode: transportMode,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        distance: distance,
        status: EWayBillStatus.pending,
        validUntil: validUntil,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(eWayBills: [...ws.eWayBills, row]));
      try {
        final execution = await _functions.createExecution(
          functionId: AppwriteService.generateEwaybillFn,
          body: jsonEncode({'ewayBillId': row.id, 'payload': row.toJson()}),
        );
        final body = jsonDecode(execution.responseBody);
        if (body is Map && body['success'] == true && body['ewayBillNumber'] != null) {
          row = EWayBill.fromJson({
            ...row.toJson(),
            'ewayBillNumber': body['ewayBillNumber'],
            'ewayBillDate': DateTime.now().toUtc().toIso8601String(),
            'validUntil': body['validUntil'] ?? row.validUntil?.toIso8601String(),
            'status': EWayBillStatus.generated.value,
          });
          await _save((await _ws()).copyWith(eWayBills: [for (final item in (await _ws()).eWayBills) item.id == row.id ? row : item]));
          await _log('ewaybill_generated', {'id': row.id, 'number': row.ewayBillNumber});
          await _ping('E-way bill generated', row.ewayBillNumber ?? invoiceNumber);
        }
      } catch (_) {}
      return row;
    });
  }

  @override
  Future<AppResult<EWayBill>> cancelEWayBill(String id, String reason) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.eWayBills.cast<EWayBill?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-way bill');
      final generatedAt = current.ewayBillDate ?? current.createdAt ?? DateTime.now();
      if (!withinHours(generatedAt, kEwayBillCancelHours)) {
        throw AppwriteException('E-way bill can be cancelled only within 24 hours', 400);
      }
      final next = EWayBill.fromJson({...current.toJson(), 'status': EWayBillStatus.cancelled.value, 'errorMessage': reason});
      await _save(ws.copyWith(eWayBills: [for (final item in ws.eWayBills) item.id == id ? next : item]));
      await _log('ewaybill_cancelled', {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<EWayBill>> extendEWayBill(String id, int additionalDistance) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.eWayBills.cast<EWayBill?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-way bill');
      final extra = ewayBillValidityDays(distanceKm: additionalDistance, overDimensional: current.vehicleType == 'over_dimensional_cargo');
      final next = EWayBill.fromJson({
        ...current.toJson(),
        'distance': (current.distance ?? 0) + additionalDistance,
        'validUntil': (current.validUntil ?? DateTime.now()).add(Duration(days: extra)).toIso8601String(),
        'status': EWayBillStatus.extended.value,
      });
      await _save(ws.copyWith(eWayBills: [for (final item in ws.eWayBills) item.id == id ? next : item]));
      await _log('ewaybill_extended', {'id': id, 'distance': additionalDistance});
      return next;
    });
  }

  @override
  Future<AppResult<EWayBill>> updatePartB(String id, String vehicleNumber, String transporterId, int distance) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.eWayBills.cast<EWayBill?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-way bill');
      final partB = jsonEncode({'vehicleNumber': vehicleNumber, 'transporterId': transporterId, 'distance': distance});
      final next = EWayBill.fromJson({
        ...current.toJson(),
        'vehicleNumber': vehicleNumber,
        'transporterId': transporterId,
        'distance': distance,
        'partB': partB,
      });
      await _save(ws.copyWith(eWayBills: [for (final item in ws.eWayBills) item.id == id ? next : item]));
      await _log('ewaybill_part_b_updated', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<DateTime?>> getEWayBillValidity(String id) {
    return AppwriteService.guard(() async {
      final current = _require((await _ws()).eWayBills.cast<EWayBill?>().firstWhere((item) => item?.id == id, orElse: () => null), 'E-way bill');
      return current.validUntil;
    });
  }

  @override
  Future<AppResult<String>> exportEWayBillsToCsv({String? financialYear}) {
    return AppwriteService.guard(() async {
      final rows = (await getEWayBills(financialYear: financialYear)).when(success: (items) => items, failure: (error) => throw AppwriteException(error.userMessage, 400));
      return [
        csvEscape(['EWB', 'Invoice', 'From', 'To', 'Value', 'Status']),
        for (final item in rows) csvEscape([item.ewayBillNumber, item.invoiceNumber, item.fromPlace, item.toPlace, item.totalValue, item.displayStatus.label]),
      ].join('\n');
    });
  }

  @override
  Future<AppResult<List<Budget>>> getBudgets({String? financialYear, String? projectId, BudgetStatus? status}) {
    return AppwriteService.guard(() async {
      return (await _ws()).budgets.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (projectId != null && item.projectId != projectId) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<Budget>> getBudgetById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).budgets.cast<Budget?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Budget');
    });
  }

  @override
  Future<AppResult<Budget>> createBudget({
    required String financialYear,
    required BudgetCategory category,
    required double budgetedAmount,
    String? subCategory,
    String? projectId,
    String? period,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final now = DateTime.now().toUtc();
      final row = Budget(
        id: ID.unique(),
        financialYear: financialYear,
        projectId: projectId,
        category: category,
        subCategory: subCategory,
        period: period,
        budgetedAmount: budgetedAmount,
        notes: notes,
        status: BudgetStatus.draft,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(budgets: [...ws.budgets, row]));
      await _log('budget_created', {'id': row.id, 'category': category.value});
      return row;
    });
  }

  @override
  Future<AppResult<Budget>> updateBudget(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.budgets.cast<Budget?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Budget');
      if (data.containsKey('actualAmount')) {
        throw AppwriteException('Actuals update through the automated actuals process only', 400);
      }
      final next = Budget.fromJson({...current.toJson(), ...data, 'id': id});
      await _save(ws.copyWith(budgets: [for (final item in ws.budgets) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<Budget>> approveBudget(String id, String approverId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.budgets.cast<Budget?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Budget');
      final next = Budget.fromJson({
        ...current.toJson(),
        'status': BudgetStatus.approved.value,
        'approvedBy': approverId,
        'approvedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(budgets: [for (final item in ws.budgets) item.id == id ? next : item]));
      await _log('budget_approved', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Budget>> activateBudget(String id) => _patchBudgetStatus(id, BudgetStatus.active);

  @override
  Future<AppResult<Budget>> closeBudget(String id) => _patchBudgetStatus(id, BudgetStatus.closed);

  Future<AppResult<Budget>> _patchBudgetStatus(String id, BudgetStatus status) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.budgets.cast<Budget?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Budget');
      final next = Budget.fromJson({...current.toJson(), 'status': status.value});
      await _save(ws.copyWith(budgets: [for (final item in ws.budgets) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<Budget>> updateActuals(String id, double actualAmount) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.budgets.cast<Budget?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Budget');
      final variance = current.budgetedAmount - actualAmount;
      final percent = current.budgetedAmount == 0 ? 0.0 : (variance / current.budgetedAmount) * 100;
      final next = Budget.fromJson({
        ...current.toJson(),
        'actualAmount': actualAmount,
        'variance': variance,
        'variancePercent': percent,
      });
      await _save(ws.copyWith(budgets: [for (final item in ws.budgets) item.id == id ? next : item]));
      if (percent.abs() > 10) {
        await _ping('Budget variance alert', '${current.category.label} is ${percent.toStringAsFixed(1)}% off plan');
      }
      return next;
    });
  }

  @override
  Future<AppResult<BudgetVsActual>> getBudgetVsActual(String financialYear) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).budgets.where((item) => item.financialYear == financialYear).toList();
      final budgeted = rows.fold<double>(0, (sum, item) => sum + item.budgetedAmount);
      final actual = rows.fold<double>(0, (sum, item) => sum + item.actualAmount);
      return BudgetVsActual(rows: rows, budgeted: budgeted, actual: actual, variance: budgeted - actual);
    });
  }

  @override
  Future<AppResult<List<VarianceAlert>>> getVarianceAnalysis(String financialYear) {
    return AppwriteService.guard(() async {
      final rows = (await _ws()).budgets.where((item) => item.financialYear == financialYear);
      return [
        for (final item in rows)
          if ((item.variancePercent ?? 0).abs() > 10)
            VarianceAlert(budget: item, message: '${item.category.label} variance ${(item.variancePercent ?? 0).toStringAsFixed(1)}%'),
      ];
    });
  }

  @override
  Future<AppResult<List<FinancialForecast>>> getForecasts({String? financialYear, ForecastType? forecastType}) {
    return AppwriteService.guard(() async {
      return (await _ws()).forecasts.where((item) {
        if (financialYear != null && item.financialYear != financialYear) return false;
        if (forecastType != null && item.forecastType != forecastType) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<FinancialForecast>> getForecastById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).forecasts.cast<FinancialForecast?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Forecast');
    });
  }

  @override
  Future<AppResult<FinancialForecast>> createForecast({
    required String financialYear,
    required ForecastType forecastType,
    required String forecastPeriod,
    required String forecastData,
    String? assumptions,
    String? confidenceLevel,
    String? baseScenario,
    String? bestCaseScenario,
    String? worstCaseScenario,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      final now = DateTime.now().toUtc();
      final row = FinancialForecast(
        id: ID.unique(),
        financialYear: financialYear,
        forecastType: forecastType,
        forecastPeriod: forecastPeriod,
        forecastData: forecastData,
        assumptions: assumptions,
        confidenceLevel: confidenceLevel,
        baseScenario: baseScenario,
        bestCaseScenario: bestCaseScenario,
        worstCaseScenario: worstCaseScenario,
        notes: notes,
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(forecasts: [...ws.forecasts, row]));
      await _log('forecast_created', {'id': row.id, 'type': forecastType.value});
      return row;
    });
  }

  @override
  Future<AppResult<FinancialForecast>> updateForecast(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.forecasts.cast<FinancialForecast?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Forecast');
      final next = FinancialForecast.fromJson({...current.toJson(), ...data, 'id': id});
      await _save(ws.copyWith(forecasts: [for (final item in ws.forecasts) item.id == id ? next : item]));
      return next;
    });
  }

  Future<List<MonthlyPoint>> _invoiceHistory() async {
    final issued = await _invoices.list(status: InvoiceStatus.issued.value);
    final paid = await _invoices.list(status: InvoiceStatus.paid.value);
    final buckets = <String, double>{};
    for (final row in [...issued, ...paid]) {
      final key = gstPeriodFromDate(row.invoice.invoiceDate);
      buckets[key] = (buckets[key] ?? 0) + row.invoice.grandTotal;
    }
    final keys = buckets.keys.toList()..sort();
    return [for (final key in keys.take(12)) MonthlyPoint(period: key, amount: buckets[key] ?? 0)];
  }

  @override
  Future<AppResult<String>> generateRevenueForecast(int months, {double monthlyGrowth = 0.05}) {
    return AppwriteService.guard(() async {
      final history = await _invoiceHistory();
      return jsonEncode([for (final point in projectSeries(history: history, months: months, monthlyGrowth: monthlyGrowth)) point.toJson()]);
    });
  }

  @override
  Future<AppResult<String>> generateExpenseForecast(int months, {double annualInflation = 0.03}) {
    return AppwriteService.guard(() async {
      final finance = await _finance.ensure();
      final buckets = <String, double>{};
      for (final item in finance.workspace.expenses) {
        final date = item.expenseDate;
        final key = gstPeriodFromDate(date);
        buckets[key] = (buckets[key] ?? 0) + item.amount;
      }
      final keys = buckets.keys.toList()..sort();
      final history = [for (final key in keys.take(12)) MonthlyPoint(period: key, amount: buckets[key] ?? 0)];
      return jsonEncode([for (final point in projectSeries(history: history, months: months, monthlyGrowth: annualInflation / 12)) point.toJson()]);
    });
  }

  @override
  Future<AppResult<String>> generateCashflowForecast(int months) {
    return AppwriteService.guard(() async {
      final projection = (await getCashflowProjection(months)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400));
      return jsonEncode([
        for (final row in projection.rows) {'period': row.period, 'cashIn': row.cashIn, 'cashOut': row.cashOut, 'net': row.net, 'closing': row.closing},
      ]);
    });
  }

  @override
  Future<AppResult<String>> generateProfitForecast(int months) {
    return AppwriteService.guard(() async {
      final revenue = jsonDecode((await generateRevenueForecast(months)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400))) as List;
      final expense = jsonDecode((await generateExpenseForecast(months)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400))) as List;
      return jsonEncode([
        for (var i = 0; i < months; i++)
          {
            'period': (revenue[i] as Map)['period'],
            'amount': money(((revenue[i] as Map)['amount'] as num).toDouble() - ((expense[i] as Map)['amount'] as num).toDouble()),
          },
      ]);
    });
  }

  @override
  Future<AppResult<CashflowProjection>> getCashflowProjection(int months) {
    return AppwriteService.guard(() async {
      final revenue = jsonDecode((await generateRevenueForecast(months)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400))) as List;
      final expense = jsonDecode((await generateExpenseForecast(months)).when(success: (item) => item, failure: (error) => throw AppwriteException(error.userMessage, 400))) as List;
      var closing = 0.0;
      var negative = false;
      final rows = <CashflowProjectionRow>[];
      for (var i = 0; i < months; i++) {
        final cashIn = ((revenue[i] as Map)['amount'] as num).toDouble();
        final cashOut = ((expense[i] as Map)['amount'] as num).toDouble();
        final net = money(cashIn - cashOut);
        closing = money(closing + net);
        if (closing < 0) negative = true;
        rows.add(CashflowProjectionRow(period: (revenue[i] as Map)['period'].toString(), cashIn: cashIn, cashOut: cashOut, net: net, closing: closing));
      }
      if (negative) await _ping('Cashflow warning', 'A projected month closes below zero');
      return CashflowProjection(months: months, rows: rows, hasNegativeMonth: negative);
    });
  }
}
