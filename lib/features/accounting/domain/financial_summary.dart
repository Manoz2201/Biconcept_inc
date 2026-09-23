import '../../gst/domain/gst_math.dart';

class FinancialSummary {
  const FinancialSummary({
    required this.totalReceivables,
    required this.totalPayables,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.cashInHand,
    required this.bankBalance,
    required this.overdueReceivables,
    required this.overduePayables,
    this.pendingExpenses = 0,
  });

  final double totalReceivables;
  final double totalPayables;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double cashInHand;
  final double bankBalance;
  final double overdueReceivables;
  final double overduePayables;
  final int pendingExpenses;
}

class AgeingEntry {
  const AgeingEntry({
    this.clientId,
    this.vendorId,
    required this.name,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.amount,
    required this.daysOverdue,
    required this.bucket,
  });

  final String? clientId;
  final String? vendorId;
  final String name;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final double amount;
  final int daysOverdue;
  final AgeingBucket bucket;
}

class AgeingReport {
  const AgeingReport({
    required this.current,
    required this.days30,
    required this.days60,
    required this.days90,
    required this.days90Plus,
    required this.totalAmount,
    required this.entries,
  });

  final double current;
  final double days30;
  final double days60;
  final double days90;
  final double days90Plus;
  final double totalAmount;
  final List<AgeingEntry> entries;
}

class CashflowMonth {
  const CashflowMonth({
    required this.period,
    required this.cashIn,
    required this.cashOut,
  });

  final String period;
  final double cashIn;
  final double cashOut;
  double get net => cashIn - cashOut;
}

class ProfitAndLoss {
  const ProfitAndLoss({
    required this.revenue,
    required this.expensesByCategory,
    required this.totalExpenses,
    required this.netProfit,
  });

  final double revenue;
  final Map<String, double> expensesByCategory;
  final double totalExpenses;
  final double netProfit;
}

class BalanceSheet {
  const BalanceSheet({
    required this.receivables,
    required this.cash,
    required this.bank,
    required this.payables,
    required this.gstPayable,
    required this.retainedEarnings,
  });

  final double receivables;
  final double cash;
  final double bank;
  final double payables;
  final double gstPayable;
  final double retainedEarnings;

  double get assets => receivables + cash + bank;
  double get liabilities => payables + gstPayable;
}

class TrialBalance {
  const TrialBalance({
    required this.debits,
    required this.credits,
    required this.byAccount,
  });

  final double debits;
  final double credits;
  final Map<String, ({double debit, double credit})> byAccount;

  bool get balanced => (debits - credits).abs() < 0.01;
}

class NamedTotal {
  const NamedTotal({required this.id, required this.name, required this.total});

  final String id;
  final String name;
  final double total;
}

class BankReconciliation {
  const BankReconciliation({
    required this.bookEntries,
    required this.statementLines,
    required this.matched,
    required this.unmatchedBook,
    required this.unmatchedStatement,
  });

  final List<({String id, DateTime date, String description, double amount})> bookEntries;
  final List<({String id, DateTime date, String description, double amount, bool matched})> statementLines;
  final int matched;
  final int unmatchedBook;
  final int unmatchedStatement;
}

class FinancialYearClosing {
  const FinancialYearClosing({
    required this.financialYear,
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    required this.gstLiability,
    required this.locked,
  });

  final String financialYear;
  final double revenue;
  final double expenses;
  final double netProfit;
  final double gstLiability;
  final bool locked;
}
