import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_repository.dart';
import '../../invoices/data/invoice_workspace_store.dart';
import '../../invoices/domain/invoice.dart';
import '../../ledger/domain/ledger_entry.dart';
import '../../ledger/domain/ledger_repository.dart';
import '../../accounting/domain/financial_summary.dart';
import '../domain/gst_math.dart';
import '../domain/gst_repository.dart';
import '../domain/gst_settings.dart';
import 'finance_workspace_store.dart';

class FinanceRepositoryImpl implements GSTRepository, ExpenseRepository, LedgerRepository {
  FinanceRepositoryImpl({
    Storage? storage,
    AuditRepository? audit,
    FinanceWorkspaceStore? finance,
    InvoiceWorkspaceStore? invoices,
    String Function()? actorId,
  })  : _storage = storage ?? AppwriteService.storage,
        _audit = audit ?? AuditRepository(),
        _finance = finance ?? FinanceWorkspaceStore(),
        _invoices = invoices ?? InvoiceWorkspaceStore(),
        _actorId = actorId ?? (() => 'unknown');

  final Storage _storage;
  final AuditRepository _audit;
  final FinanceWorkspaceStore _finance;
  final InvoiceWorkspaceStore _invoices;
  final String Function() _actorId;

  @override
  Future<AppResult<GSTSettings>> getGSTSettings() {
    return AppwriteService.guard(() async => (await _finance.ensure()).settings);
  }

  @override
  Future<AppResult<GSTSettings>> updateGSTSettings(Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      if (data['firmGstin'] != null && !isValidGstin(data['firmGstin']?.toString())) {
        throw AppwriteException('GSTIN must be a 15-character Indian GSTIN', 400);
      }
      if (data['firmPan'] != null && !isValidPan(data['firmPan']?.toString())) {
        throw AppwriteException('PAN must be a 10-character Indian PAN', 400);
      }
      final snap = await _finance.ensure();
      final saved = await _finance.save(snap.workspace, settingsPatch: data);
      await _audit.log(userId: _actorId(), action: 'gst_settings_updated', metadata: data);
      return saved.settings;
    });
  }

  @override
  Future<AppResult<List<TaxRate>>> getTaxRates({bool? isActive, String? type}) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      return [
        for (final item in snap.workspace.taxRates)
          if ((isActive == null || item.isActive == isActive) && (type == null || item.type.value == type)) item,
      ];
    });
  }

  @override
  Future<AppResult<TaxRate?>> getTaxRateByHsnSac(String hsnSac) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      for (final item in snap.workspace.taxRates) {
        if (item.hsnSacCode == hsnSac) return item;
      }
      return null;
    });
  }

  @override
  Future<AppResult<TaxRate>> createTaxRate({
    required String hsnSacCode,
    required String description,
    required double taxRate,
    double? cessRate,
    required TaxRateType type,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final now = DateTime.now().toUtc();
      final rate = TaxRate(
        id: ID.unique(),
        hsnSacCode: hsnSacCode.trim(),
        description: description.trim(),
        taxRate: taxRate,
        cessRate: cessRate,
        type: type,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.taxRates.add(rate);
      await _finance.save(snap.workspace);
      await _audit.log(userId: _actorId(), action: 'tax_rate_created', metadata: {'id': rate.id, 'hsnSacCode': hsnSacCode});
      return rate;
    });
  }

  @override
  Future<AppResult<TaxRate>> updateTaxRate(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final index = snap.workspace.taxRates.indexWhere((item) => item.id == id);
      if (index < 0) throw AppwriteException('Tax rate not found', 404);
      final current = snap.workspace.taxRates[index];
      final next = TaxRate(
        id: current.id,
        hsnSacCode: data['hsnSacCode']?.toString() ?? current.hsnSacCode,
        description: data['description']?.toString() ?? current.description,
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? current.taxRate,
        cessRate: (data['cessRate'] as num?)?.toDouble() ?? current.cessRate,
        type: data['type'] != null ? TaxRateType.fromString(data['type'].toString()) : current.type,
        isActive: data['isActive'] as bool? ?? current.isActive,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.taxRates[index] = next;
      await _finance.save(snap.workspace);
      await _audit.log(userId: _actorId(), action: 'tax_rate_updated', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteTaxRate(String id) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      snap.workspace.taxRates.removeWhere((item) => item.id == id);
      await _finance.save(snap.workspace);
      await _audit.log(userId: _actorId(), action: 'tax_rate_deleted', metadata: {'id': id});
    });
  }

  @override
  Future<AppResult<List<GSTReturn>>> getGSTReturns({
    GSTReturnType? returnType,
    String? financialYear,
    GSTReturnStatus? status,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      return [
        for (final item in snap.workspace.gstReturns)
          if ((returnType == null || item.returnType == returnType) &&
              (financialYear == null || item.financialYear == financialYear) &&
              (status == null || item.status == status))
            item,
      ];
    });
  }

  @override
  Future<AppResult<GSTReturn>> createGSTReturn({
    required GSTReturnType returnType,
    required String period,
    required String financialYear,
  }) {
    return AppwriteService.guard(() async {
      final export = returnType == GSTReturnType.gstr3b
          ? await exportGSTR3B(period, financialYear)
          : await exportGSTR1(period, financialYear);
      final payload = jsonDecode(export.dataOrNull ?? '{}');
      final now = DateTime.now().toUtc();
      final row = GSTReturn(
        id: ID.unique(),
        returnType: returnType,
        period: period,
        financialYear: financialYear,
        totalTaxableValue: (payload is Map ? payload['totalTaxableValue'] as num? : null)?.toDouble() ?? 0,
        totalCgst: (payload is Map ? payload['totalCgst'] as num? : null)?.toDouble() ?? 0,
        totalSgst: (payload is Map ? payload['totalSgst'] as num? : null)?.toDouble() ?? 0,
        totalIgst: (payload is Map ? payload['totalIgst'] as num? : null)?.toDouble() ?? 0,
        status: GSTReturnStatus.draft,
        data: export.dataOrNull,
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      final snap = await _finance.ensure();
      snap.workspace.gstReturns.add(row);
      await _finance.save(snap.workspace);
      return row;
    });
  }

  @override
  Future<AppResult<GSTReturn>> fileGSTReturn(String id, String acknowledgementNumber) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final index = snap.workspace.gstReturns.indexWhere((item) => item.id == id);
      if (index < 0) throw AppwriteException('GST return not found', 404);
      final current = snap.workspace.gstReturns[index];
      if (current.status == GSTReturnStatus.filed || current.status == GSTReturnStatus.acknowledged) {
        throw AppwriteException('Filed GST returns cannot be changed', 400);
      }
      final next = GSTReturn(
        id: current.id,
        returnType: current.returnType,
        period: current.period,
        financialYear: current.financialYear,
        totalTaxableValue: current.totalTaxableValue,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        totalCess: current.totalCess,
        status: GSTReturnStatus.filed,
        filedAt: DateTime.now().toUtc(),
        acknowledgementNumber: acknowledgementNumber,
        data: current.data,
        createdBy: current.createdBy,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.gstReturns[index] = next;
      await _finance.save(snap.workspace);
      await _audit.log(userId: _actorId(), action: 'gst_return_filed', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'GST return filed', body: current.period);
      return next;
    });
  }

  @override
  Future<AppResult<String>> exportGSTR1(String period, String financialYear) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list(status: 'issued');
      final paid = await _invoices.list(status: 'paid');
      final partial = await _invoices.list(status: 'partially_paid');
      final all = [...invoices, ...paid, ...partial];
      var taxable = 0.0, cgst = 0.0, sgst = 0.0, igst = 0.0;
      final b2b = <Map<String, dynamic>>[];
      for (final row in all) {
        final invoice = row.invoice;
        if (!_inPeriod(invoice.invoiceDate, period)) continue;
        if (financialYearLabel(invoice.invoiceDate) != financialYear) continue;
        taxable += invoice.subtotal;
        cgst += invoice.totalCgst;
        sgst += invoice.totalSgst;
        igst += invoice.totalIgst;
        b2b.add({
          'invoiceNumber': invoice.invoiceNumber,
          'invoiceDate': invoice.invoiceDate.toIso8601String(),
          'clientId': invoice.clientId,
          'placeOfSupply': invoice.placeOfSupplyCode,
          'taxableValue': invoice.subtotal,
          'cgst': invoice.totalCgst,
          'sgst': invoice.totalSgst,
          'igst': invoice.totalIgst,
        });
      }
      return jsonEncode({
        'returnType': 'GSTR1',
        'period': period,
        'financialYear': financialYear,
        'totalTaxableValue': taxable,
        'totalCgst': cgst,
        'totalSgst': sgst,
        'totalIgst': igst,
        'b2b': b2b,
      });
    });
  }

  @override
  Future<AppResult<String>> exportGSTR3B(String period, String financialYear) {
    return AppwriteService.guard(() async {
      final gstr1 = jsonDecode((await exportGSTR1(period, financialYear)).dataOrNull ?? '{}') as Map<String, dynamic>;
      return jsonEncode({
        ...gstr1,
        'returnType': 'GSTR3B',
        'inwardSupplies': 0,
        'itcClaimed': 0,
        'netTaxPayable': ((gstr1['totalCgst'] as num?) ?? 0) + ((gstr1['totalSgst'] as num?) ?? 0) + ((gstr1['totalIgst'] as num?) ?? 0),
      });
    });
  }

  @override
  Future<AppResult<List<Expense>>> getExpenses({
    String? projectId,
    ExpenseCategory? category,
    ExpenseStatus? status,
    DateTime? from,
    DateTime? to,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      return [
        for (final item in snap.workspace.expenses)
          if ((projectId == null || item.projectId == projectId) &&
              (category == null || item.category == category) &&
              (status == null || item.status == status) &&
              _inRange(item.expenseDate, from, to))
            item,
      ];
    });
  }

  @override
  Future<AppResult<Expense>> getExpenseById(String id) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      return snap.workspace.expenses.firstWhere(
        (item) => item.id == id,
        orElse: () => throw AppwriteException('Expense not found', 404),
      );
    });
  }

  @override
  Future<AppResult<Expense>> createExpense({
    required String description,
    required double amount,
    required DateTime expenseDate,
    required ExpenseCategory category,
    String? projectId,
    String? vendorId,
    double gstAmount = 0,
    String? paymentMethod,
    UploadBytes? receipt,
    String? notes,
  }) {
    return AppwriteService.guard(() async {
      String? receiptId;
      if (receipt != null) {
        final filename = sanitizeUploadName(receipt.filename);
        validateUpload(receipt.bytes, filename);
        final uploaded = await _storage.createFile(
          bucketId: Env.clientUploadsBucket,
          fileId: ID.unique(),
          file: InputFile.fromBytes(bytes: receipt.bytes, filename: filename),
          permissions: financeRowPermissions(),
        );
        receiptId = uploaded.$id;
      }
      final snap = await _finance.ensure();
      final fy = financialYearLabel(expenseDate, startMonth: snap.settings.financialYearStart);
      if (snap.settings.fyLockedYears.contains(fy)) throw AppwriteException('Financial year $fy is closed', 400);
      final key = 'EXP:$fy';
      final next = (snap.workspace.series[key] ?? 0) + 1;
      snap.workspace.series[key] = next;
      final now = DateTime.now().toUtc();
      final expense = Expense(
        id: ID.unique(),
        expenseNumber: formatSeriesNumber('EXP', fy, next),
        projectId: projectId,
        category: category,
        description: description.trim(),
        amount: amount,
        gstAmount: gstAmount,
        totalAmount: amount + gstAmount,
        expenseDate: expenseDate,
        vendorId: vendorId,
        paymentStatus: ExpensePaymentStatus.unpaid,
        paymentMethod: paymentMethod,
        receiptId: receiptId,
        status: ExpenseStatus.draft,
        createdBy: _actorId(),
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.expenses.add(expense);
      await _finance.save(snap.workspace);
      await _audit.log(userId: _actorId(), action: 'expense_created', metadata: {'id': expense.id});
      return expense;
    });
  }

  @override
  Future<AppResult<Expense>> updateExpense(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final index = snap.workspace.expenses.indexWhere((item) => item.id == id);
      if (index < 0) throw AppwriteException('Expense not found', 404);
      final current = snap.workspace.expenses[index];
      if (current.status != ExpenseStatus.draft) throw AppwriteException('Only draft expenses can be edited', 400);
      final amount = (data['amount'] as num?)?.toDouble() ?? current.amount;
      final gst = (data['gstAmount'] as num?)?.toDouble() ?? current.gstAmount;
      final next = Expense(
        id: current.id,
        expenseNumber: current.expenseNumber,
        projectId: data['projectId']?.toString() ?? current.projectId,
        category: data['category'] != null ? ExpenseCategory.fromString(data['category'].toString()) : current.category,
        description: data['description']?.toString() ?? current.description,
        amount: amount,
        gstAmount: gst,
        totalAmount: amount + gst,
        expenseDate: data['expenseDate'] is DateTime ? data['expenseDate'] as DateTime : current.expenseDate,
        vendorId: data['vendorId']?.toString() ?? current.vendorId,
        billId: current.billId,
        paymentStatus: current.paymentStatus,
        paymentMethod: data['paymentMethod']?.toString() ?? current.paymentMethod,
        receiptId: current.receiptId,
        status: current.status,
        createdBy: current.createdBy,
        notes: data['notes']?.toString() ?? current.notes,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.expenses[index] = next;
      await _finance.save(snap.workspace);
      return next;
    });
  }

  @override
  Future<AppResult<Expense>> submitExpense(String id) => _setExpenseStatus(id, ExpenseStatus.submitted, 'expense_submitted');

  @override
  Future<AppResult<Expense>> approveExpense(String id, String approverId) {
    return AppwriteService.guard(() async {
      final next = await _mutateExpense(id, (current) {
        if (current.status != ExpenseStatus.submitted) throw AppwriteException('Only submitted expenses can be approved', 400);
        return Expense(
          id: current.id,
          expenseNumber: current.expenseNumber,
          projectId: current.projectId,
          category: current.category,
          description: current.description,
          amount: current.amount,
          gstAmount: current.gstAmount,
          totalAmount: current.totalAmount,
          expenseDate: current.expenseDate,
          vendorId: current.vendorId,
          billId: current.billId,
          paymentStatus: current.paymentStatus,
          paymentMethod: current.paymentMethod,
          receiptId: current.receiptId,
          approvedBy: approverId,
          approvedAt: DateTime.now().toUtc(),
          status: ExpenseStatus.approved,
          createdBy: current.createdBy,
          notes: current.notes,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      });
      await addEntry(
        accountType: AccountType.expense,
        description: 'Expense ${next.expenseNumber}',
        debitAmount: next.totalAmount,
        referenceType: 'expense',
        referenceId: id,
      );
      await _audit.log(userId: _actorId(), action: 'expense_approved', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'Expense approved', body: next.expenseNumber);
      return next;
    });
  }

  @override
  Future<AppResult<Expense>> rejectExpense(String id, String reason) {
    return AppwriteService.guard(() async {
      final next = await _mutateExpense(id, (current) {
        return Expense(
          id: current.id,
          expenseNumber: current.expenseNumber,
          projectId: current.projectId,
          category: current.category,
          description: current.description,
          amount: current.amount,
          gstAmount: current.gstAmount,
          totalAmount: current.totalAmount,
          expenseDate: current.expenseDate,
          vendorId: current.vendorId,
          billId: current.billId,
          paymentStatus: current.paymentStatus,
          paymentMethod: current.paymentMethod,
          receiptId: current.receiptId,
          status: ExpenseStatus.rejected,
          createdBy: current.createdBy,
          notes: reason,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      });
      await _audit.log(userId: _actorId(), action: 'expense_rejected', metadata: {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<Expense>> reimburseExpense(String id) {
    return AppwriteService.guard(() async {
      final next = await _mutateExpense(id, (current) {
        if (current.status != ExpenseStatus.approved) throw AppwriteException('Only approved expenses can be reimbursed', 400);
        return Expense(
          id: current.id,
          expenseNumber: current.expenseNumber,
          projectId: current.projectId,
          category: current.category,
          description: current.description,
          amount: current.amount,
          gstAmount: current.gstAmount,
          totalAmount: current.totalAmount,
          expenseDate: current.expenseDate,
          vendorId: current.vendorId,
          billId: current.billId,
          paymentStatus: ExpensePaymentStatus.paid,
          paymentMethod: current.paymentMethod,
          receiptId: current.receiptId,
          approvedBy: current.approvedBy,
          approvedAt: current.approvedAt,
          status: ExpenseStatus.reimbursed,
          createdBy: current.createdBy,
          notes: current.notes,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      });
      await addEntry(
        accountType: AccountType.bank,
        description: 'Reimburse ${next.expenseNumber}',
        creditAmount: next.totalAmount,
        referenceType: 'expense',
        referenceId: id,
      );
      await _audit.log(userId: _actorId(), action: 'expense_reimbursed', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Map<ExpenseCategory, double>>> getExpenseSummary(DateTime from, DateTime to) {
    return AppwriteService.guard(() async {
      final items = (await getExpenses(from: from, to: to)).dataOrNull ?? const <Expense>[];
      final totals = <ExpenseCategory, double>{};
      for (final item in items.where((row) => row.status == ExpenseStatus.approved || row.status == ExpenseStatus.reimbursed)) {
        totals[item.category] = (totals[item.category] ?? 0) + item.totalAmount;
      }
      return totals;
    });
  }

  @override
  Future<AppResult<List<LedgerEntry>>> getLedgerEntries({
    AccountType? accountType,
    String? accountId,
    DateTime? from,
    DateTime? to,
    String? financialYear,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final rows = [
        for (final item in snap.workspace.ledger)
          if ((accountType == null || item.accountType == accountType) &&
              (accountId == null || item.accountId == accountId) &&
              (financialYear == null || item.financialYear == financialYear) &&
              _inRange(item.entryDate, from, to))
            item,
      ]..sort((a, b) => a.entryDate.compareTo(b.entryDate));
      return rows;
    });
  }

  @override
  Future<AppResult<List<LedgerEntry>>> getClientLedger(String clientId, {DateTime? from, DateTime? to}) =>
      getLedgerEntries(accountType: AccountType.client, accountId: clientId, from: from, to: to);

  @override
  Future<AppResult<List<LedgerEntry>>> getVendorLedger(String vendorId, {DateTime? from, DateTime? to}) =>
      getLedgerEntries(accountType: AccountType.vendor, accountId: vendorId, from: from, to: to);

  @override
  Future<AppResult<List<LedgerEntry>>> getGeneralLedger({DateTime? from, DateTime? to}) =>
      getLedgerEntries(from: from, to: to);

  @override
  Future<AppResult<LedgerEntry>> addEntry({
    required AccountType accountType,
    String? accountId,
    required String description,
    double debitAmount = 0,
    double creditAmount = 0,
    String? referenceType,
    String? referenceId,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final now = DateTime.now().toUtc();
      final fy = financialYearLabel(now, startMonth: snap.settings.financialYearStart);
      if (snap.settings.fyLockedYears.contains(fy)) throw AppwriteException('Financial year $fy is closed', 400);
      final matching = snap.workspace.ledger.where((item) => item.accountType == accountType && item.accountId == accountId);
      final last = matching.isEmpty ? 0.0 : matching.last.balance;
      final key = 'LED:$fy';
      final next = (snap.workspace.series[key] ?? 0) + 1;
      snap.workspace.series[key] = next;
      final entry = LedgerEntry(
        id: ID.unique(),
        entryNumber: formatSeriesNumber('LED', fy, next),
        entryDate: now,
        accountType: accountType,
        accountId: accountId,
        description: description,
        debitAmount: debitAmount,
        creditAmount: creditAmount,
        balance: last + debitAmount - creditAmount,
        referenceType: referenceType,
        referenceId: referenceId,
        financialYear: fy,
        createdAt: now,
      );
      snap.workspace.ledger.add(entry);
      await _finance.save(snap.workspace);
      await _audit.log(userId: _actorId(), action: 'ledger_entry_created', metadata: {'id': entry.id});
      return entry;
    });
  }

  @override
  Future<AppResult<TrialBalance>> getTrialBalance(DateTime asOfDate) {
    return AppwriteService.guard(() async {
      final entries = (await getLedgerEntries(to: asOfDate)).dataOrNull ?? const <LedgerEntry>[];
      final byAccount = <String, ({double debit, double credit})>{};
      var debits = 0.0, credits = 0.0;
      for (final item in entries) {
        final key = '${item.accountType.value}:${item.accountId ?? '-'}';
        final current = byAccount[key] ?? (debit: 0.0, credit: 0.0);
        byAccount[key] = (debit: current.debit + item.debitAmount, credit: current.credit + item.creditAmount);
        debits += item.debitAmount;
        credits += item.creditAmount;
      }
      return TrialBalance(debits: debits, credits: credits, byAccount: byAccount);
    });
  }

  @override
  Future<AppResult<ProfitAndLoss>> getProfitAndLoss(DateTime from, DateTime to) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final revenue = invoices
          .where((row) => row.invoice.status == InvoiceStatus.paid && _inRange(row.invoice.invoiceDate, from, to))
          .fold<double>(0, (sum, row) => sum + row.invoice.grandTotal);
      final summary = (await getExpenseSummary(from, to)).dataOrNull ?? {};
      final expenses = summary.values.fold<double>(0, (sum, value) => sum + value);
      return ProfitAndLoss(
        revenue: revenue,
        expensesByCategory: {for (final entry in summary.entries) entry.key.label: entry.value},
        totalExpenses: expenses,
        netProfit: revenue - expenses,
      );
    });
  }

  @override
  Future<AppResult<BalanceSheet>> getBalanceSheet(DateTime asOfDate) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final receivables = invoices
          .where((row) => row.invoice.status != InvoiceStatus.paid && row.invoice.status != InvoiceStatus.voided && row.invoice.status != InvoiceStatus.draft)
          .fold<double>(0, (sum, row) => sum + row.invoice.outstanding);
      final pl = (await getProfitAndLoss(DateTime(asOfDate.year, 4, 1), asOfDate)).dataOrNull;
      return BalanceSheet(
        receivables: receivables,
        cash: 0,
        bank: 0,
        payables: 0,
        gstPayable: invoices.fold<double>(0, (sum, row) => sum + row.invoice.totalCgst + row.invoice.totalSgst + row.invoice.totalIgst),
        retainedEarnings: pl?.netProfit ?? 0,
      );
    });
  }

  Future<AppResult<Expense>> _setExpenseStatus(String id, ExpenseStatus status, String action) {
    return AppwriteService.guard(() async {
      final next = await _mutateExpense(id, (current) {
        return Expense(
          id: current.id,
          expenseNumber: current.expenseNumber,
          projectId: current.projectId,
          category: current.category,
          description: current.description,
          amount: current.amount,
          gstAmount: current.gstAmount,
          totalAmount: current.totalAmount,
          expenseDate: current.expenseDate,
          vendorId: current.vendorId,
          billId: current.billId,
          paymentStatus: current.paymentStatus,
          paymentMethod: current.paymentMethod,
          receiptId: current.receiptId,
          approvedBy: current.approvedBy,
          approvedAt: current.approvedAt,
          status: status,
          createdBy: current.createdBy,
          notes: current.notes,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      });
      await _audit.log(userId: _actorId(), action: action, metadata: {'id': id});
      if (status == ExpenseStatus.submitted) {
        await AppNotifications.instance.showImmediate(title: 'Expense submitted', body: next.expenseNumber);
      }
      return next;
    });
  }

  Future<Expense> _mutateExpense(String id, Expense Function(Expense current) update) async {
    final snap = await _finance.ensure();
    final index = snap.workspace.expenses.indexWhere((item) => item.id == id);
    if (index < 0) throw AppwriteException('Expense not found', 404);
    final next = update(snap.workspace.expenses[index]);
    snap.workspace.expenses[index] = next;
    await _finance.save(snap.workspace);
    return next;
  }

  bool _inPeriod(DateTime date, String period) {
    final parts = period.split('-');
    if (parts.length < 2) return true;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return true;
    return date.year == year && date.month == month;
  }

  bool _inRange(DateTime value, DateTime? from, DateTime? to) {
    if (from != null && value.isBefore(from)) return false;
    if (to != null && value.isAfter(to)) return false;
    return true;
  }
}
