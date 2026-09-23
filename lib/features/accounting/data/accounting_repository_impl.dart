import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../gst/data/finance_workspace_store.dart';
import '../../gst/domain/gst_math.dart';
import '../../gst/domain/gst_settings.dart';
import '../../invoices/data/invoice_workspace_store.dart';
import '../../invoices/domain/invoice.dart';
import '../../payments/domain/payment.dart';
import '../../vendor_bills/data/vendor_bill_repository_impl.dart';
import '../../vendor_bills/domain/vendor_bill.dart';
import '../../vendor_bills/domain/vendor_bill_repository.dart';
import '../../expenses/domain/expense.dart';
import '../domain/accounting_repository.dart';
import '../domain/financial_summary.dart';

class AccountingRepositoryImpl implements AccountingRepository {
  AccountingRepositoryImpl({
    InvoiceWorkspaceStore? invoices,
    FinanceWorkspaceStore? finance,
    VendorBillRepository? bills,
    AuditRepository? audit,
    String Function()? actorId,
  })  : _invoices = invoices ?? InvoiceWorkspaceStore(),
        _finance = finance ?? FinanceWorkspaceStore(),
        _bills = bills ?? VendorBillRepositoryImpl(),
        _audit = audit ?? AuditRepository(),
        _actorId = actorId ?? (() => 'unknown');

  final InvoiceWorkspaceStore _invoices;
  final FinanceWorkspaceStore _finance;
  final VendorBillRepository _bills;
  final AuditRepository _audit;
  final String Function() _actorId;

  @override
  Future<AppResult<FinancialSummary>> getFinancialSummary() {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final finance = await _finance.ensure();
      final bills = (await _bills.getVendorBills()).dataOrNull ?? const <VendorBill>[];
      final openInvoices = invoices.where((row) {
        final status = row.invoice.status;
        return status != InvoiceStatus.paid && status != InvoiceStatus.voided && status != InvoiceStatus.draft && status != InvoiceStatus.cancelled;
      });
      final receivables = openInvoices.fold<double>(0, (sum, row) => sum + row.invoice.outstanding);
      final overdueReceivables = openInvoices
          .where((row) => row.invoice.displayStatus == InvoiceStatus.overdue)
          .fold<double>(0, (sum, row) => sum + row.invoice.outstanding);
      final payables = bills
          .where((bill) => bill.status != VendorBillStatus.paid && bill.status != VendorBillStatus.rejected)
          .fold<double>(0, (sum, bill) => sum + (bill.total - bill.paidAmount));
      final overduePayables = bills
          .where((bill) => bill.dueDate.isBefore(DateTime.now()) && bill.status != VendorBillStatus.paid)
          .fold<double>(0, (sum, bill) => sum + (bill.total - bill.paidAmount));
      final revenue = invoices
          .where((row) => row.invoice.status == InvoiceStatus.paid)
          .fold<double>(0, (sum, row) => sum + row.invoice.grandTotal);
      final expenses = finance.workspace.expenses
          .where((item) => item.status == ExpenseStatus.approved || item.status == ExpenseStatus.reimbursed)
          .fold<double>(0, (sum, item) => sum + item.totalAmount);
      final cashIn = invoices.expand((row) => row.workspace.payments).where((item) => item.status == ClientPaymentStatus.completed && item.paymentMethod == PaymentMethod.cash);
      final bankIn = invoices.expand((row) => row.workspace.payments).where((item) => item.status == ClientPaymentStatus.completed && item.paymentMethod != PaymentMethod.cash);
      return FinancialSummary(
        totalReceivables: receivables,
        totalPayables: payables,
        totalRevenue: revenue,
        totalExpenses: expenses,
        netProfit: revenue - expenses,
        cashInHand: cashIn.fold<double>(0, (sum, item) => sum + item.amount),
        bankBalance: bankIn.fold<double>(0, (sum, item) => sum + item.amount) - expenses,
        overdueReceivables: overdueReceivables,
        overduePayables: overduePayables,
        pendingExpenses: finance.workspace.expenses.where((item) => item.status == ExpenseStatus.submitted).length,
      );
    });
  }

  @override
  Future<AppResult<AgeingReport>> getAgeingReport({required String type}) {
    return AppwriteService.guard(() async {
      final entries = <AgeingEntry>[];
      if (type == 'payables') {
        final bills = (await _bills.getVendorBills()).dataOrNull ?? const <VendorBill>[];
        for (final bill in bills.where((item) => item.status != VendorBillStatus.paid && item.status != VendorBillStatus.rejected)) {
          final days = daysOverdue(bill.dueDate);
          entries.add(
            AgeingEntry(
              vendorId: bill.vendorId,
              name: bill.vendorId,
              invoiceNumber: bill.billNumber,
              invoiceDate: bill.billDate,
              dueDate: bill.dueDate,
              amount: bill.total - bill.paidAmount,
              daysOverdue: days,
              bucket: ageingBucket(days),
            ),
          );
        }
      } else {
        for (final row in await _invoices.list()) {
          final invoice = row.invoice;
          if (invoice.status == InvoiceStatus.paid || invoice.status == InvoiceStatus.voided || invoice.status == InvoiceStatus.draft) {
            continue;
          }
          final days = daysOverdue(invoice.dueDate);
          entries.add(
            AgeingEntry(
              clientId: invoice.clientId,
              name: invoice.clientId,
              invoiceNumber: invoice.invoiceNumber,
              invoiceDate: invoice.invoiceDate,
              dueDate: invoice.dueDate,
              amount: invoice.outstanding,
              daysOverdue: days,
              bucket: ageingBucket(days),
            ),
          );
        }
      }
      double sum(AgeingBucket bucket) => entries.where((item) => item.bucket == bucket).fold(0, (total, item) => total + item.amount);
      return AgeingReport(
        current: sum(AgeingBucket.current),
        days30: sum(AgeingBucket.days30),
        days60: sum(AgeingBucket.days60),
        days90: sum(AgeingBucket.days90),
        days90Plus: sum(AgeingBucket.days90Plus),
        totalAmount: entries.fold(0, (total, item) => total + item.amount),
        entries: entries,
      );
    });
  }

  @override
  Future<AppResult<List<CashflowMonth>>> getCashflow(DateTime from, DateTime to) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final finance = await _finance.ensure();
      final months = <String, CashflowMonth>{};
      void add(DateTime date, {double cashIn = 0, double cashOut = 0}) {
        if (date.isBefore(from) || date.isAfter(to)) return;
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final current = months[key] ?? CashflowMonth(period: key, cashIn: 0, cashOut: 0);
        months[key] = CashflowMonth(period: key, cashIn: current.cashIn + cashIn, cashOut: current.cashOut + cashOut);
      }

      for (final row in invoices) {
        for (final payment in row.workspace.payments.where((item) => item.status == ClientPaymentStatus.completed)) {
          add(payment.paymentDate, cashIn: payment.amount);
        }
      }
      for (final expense in finance.workspace.expenses.where((item) => item.status == ExpenseStatus.reimbursed)) {
        add(expense.expenseDate, cashOut: expense.totalAmount);
      }
      final keys = months.keys.toList()..sort();
      return [for (final key in keys) months[key]!];
    });
  }

  @override
  Future<AppResult<List<NamedTotal>>> getMonthlyRevenueTrend(int months) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final now = DateTime.now();
      final totals = <String, double>{};
      for (var i = months - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        totals['${date.year}-${date.month.toString().padLeft(2, '0')}'] = 0;
      }
      for (final row in invoices) {
        final key = '${row.invoice.invoiceDate.year}-${row.invoice.invoiceDate.month.toString().padLeft(2, '0')}';
        if (totals.containsKey(key)) {
          totals[key] = (totals[key] ?? 0) + row.invoice.grandTotal;
        }
      }
      return [for (final entry in totals.entries) NamedTotal(id: entry.key, name: entry.key, total: entry.value)];
    });
  }

  @override
  Future<AppResult<List<NamedTotal>>> getTopClients({int limit = 10}) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final totals = <String, double>{};
      for (final row in invoices) {
        totals[row.invoice.clientId] = (totals[row.invoice.clientId] ?? 0) + row.invoice.grandTotal;
      }
      final ranked = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (final entry in ranked.take(limit)) NamedTotal(id: entry.key, name: entry.key, total: entry.value),
      ];
    });
  }

  @override
  Future<AppResult<List<NamedTotal>>> getTopVendors({int limit = 10}) {
    return AppwriteService.guard(() async {
      final bills = (await _bills.getVendorBills()).dataOrNull ?? const <VendorBill>[];
      final totals = <String, double>{};
      for (final bill in bills) {
        totals[bill.vendorId] = (totals[bill.vendorId] ?? 0) + bill.total;
      }
      final ranked = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (final entry in ranked.take(limit)) NamedTotal(id: entry.key, name: entry.key, total: entry.value),
      ];
    });
  }

  @override
  Future<AppResult<BankReconciliation>> getBankReconciliation({required DateTime from, required DateTime to}) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final finance = await _finance.ensure();
      final book = [
        for (final row in invoices)
          for (final payment in row.workspace.payments)
            if (payment.status == ClientPaymentStatus.completed && !payment.paymentDate.isBefore(from) && !payment.paymentDate.isAfter(to))
              (id: payment.id, date: payment.paymentDate, description: payment.paymentNumber, amount: payment.amount),
      ];
      final statement = [
        for (final line in finance.workspace.bankLines)
          if (!line.entryDate.isBefore(from) && !line.entryDate.isAfter(to))
            (id: line.id, date: line.entryDate, description: line.description, amount: line.amount, matched: line.matched),
      ];
      return BankReconciliation(
        bookEntries: book,
        statementLines: statement,
        matched: statement.where((item) => item.matched).length,
        unmatchedBook: book.length - statement.where((item) => item.matched).length,
        unmatchedStatement: statement.where((item) => !item.matched).length,
      );
    });
  }

  @override
  Future<AppResult<BankStatementLine>> addBankStatementLine({
    required DateTime entryDate,
    required String description,
    required double amount,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final line = BankStatementLine(
        id: ID.unique(),
        entryDate: entryDate,
        description: description,
        amount: amount,
      );
      snap.workspace.bankLines.add(line);
      await _finance.save(snap.workspace);
      return line;
    });
  }

  @override
  Future<AppResult<void>> matchBankLine(String lineId, String referenceId) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      final index = snap.workspace.bankLines.indexWhere((item) => item.id == lineId);
      if (index < 0) throw AppwriteException('Bank line not found', 404);
      final current = snap.workspace.bankLines[index];
      snap.workspace.bankLines[index] = BankStatementLine(
        id: current.id,
        entryDate: current.entryDate,
        description: current.description,
        amount: current.amount,
        matchedReferenceId: referenceId,
        matched: true,
      );
      await _finance.save(snap.workspace);
    });
  }

  @override
  Future<AppResult<FinancialYearClosing>> getFinancialYearClosing(String financialYear) {
    return AppwriteService.guard(() async {
      final invoices = await _invoices.list();
      final finance = await _finance.ensure();
      final revenue = invoices
          .where((row) => financialYearLabel(row.invoice.invoiceDate, startMonth: finance.settings.financialYearStart) == financialYear)
          .fold<double>(0, (sum, row) => sum + row.invoice.grandTotal);
      final expenses = finance.workspace.expenses
          .where((item) => financialYearLabel(item.expenseDate, startMonth: finance.settings.financialYearStart) == financialYear)
          .fold<double>(0, (sum, item) => sum + item.totalAmount);
      final gst = invoices
          .where((row) => financialYearLabel(row.invoice.invoiceDate, startMonth: finance.settings.financialYearStart) == financialYear)
          .fold<double>(0, (sum, row) => sum + row.invoice.totalCgst + row.invoice.totalSgst + row.invoice.totalIgst);
      return FinancialYearClosing(
        financialYear: financialYear,
        revenue: revenue,
        expenses: expenses,
        netProfit: revenue - expenses,
        gstLiability: gst,
        locked: finance.settings.fyLockedYears.contains(financialYear),
      );
    });
  }

  @override
  Future<AppResult<FinancialYearClosing>> closeFinancialYear(String financialYear) {
    return AppwriteService.guard(() async {
      final snap = await _finance.ensure();
      if (snap.settings.fyLockedYears.contains(financialYear)) {
        throw AppwriteException('Financial year $financialYear is already closed', 400);
      }
      final years = [...snap.settings.fyLockedYears, financialYear];
      await _finance.save(snap.workspace, settingsPatch: {'fyLockedYears': years});
      await _audit.log(userId: _actorId(), action: 'financial_year_closed', metadata: {'financialYear': financialYear});
      return (await getFinancialYearClosing(financialYear)).when(
        success: (value) => value,
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }
}
