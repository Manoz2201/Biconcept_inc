import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounting/data/accounting_repository_impl.dart';
import '../../../accounting/domain/accounting_repository.dart';
import '../../../accounting/domain/financial_summary.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../credit_notes/domain/credit_note.dart';
import '../../../credit_notes/domain/credit_note_repository.dart';
import '../../../debit_notes/domain/debit_note.dart';
import '../../../debit_notes/domain/debit_note_repository.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/domain/expense_repository.dart';
import '../../../gst/data/finance_repository_impl.dart';
import '../../../gst/data/finance_workspace_store.dart';
import '../../../gst/domain/gst_repository.dart';
import '../../../gst/domain/gst_settings.dart';
import '../../../ledger/domain/ledger_entry.dart';
import '../../../ledger/domain/ledger_repository.dart';
import '../../../payments/data/razorpay_service.dart';
import '../../../payments/domain/payment.dart';
import '../../../payments/domain/payment_repository.dart';
import '../../../rbac/domain/user_role.dart';
import '../../../user_management/presentation/providers/user_providers.dart';
import '../../../vendor_bills/data/vendor_bill_repository_impl.dart';
import '../../data/invoice_pdf_service.dart';
import '../../data/invoice_repository_impl.dart';
import '../../data/invoice_workspace_store.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_repository.dart';

String Function() _actorId(Ref ref) => () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';

InvoiceWorkspaceStore _invoices() => InvoiceWorkspaceStore();
FinanceWorkspaceStore _finance() => FinanceWorkspaceStore();

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepositoryImpl(invoices: _invoices(), finance: _finance(), actorId: _actorId(ref));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return InvoiceRepositoryImpl(invoices: _invoices(), finance: _finance(), actorId: _actorId(ref));
});

final creditNoteRepositoryProvider = Provider<CreditNoteRepository>((ref) {
  return InvoiceRepositoryImpl(invoices: _invoices(), finance: _finance(), actorId: _actorId(ref));
});

final debitNoteRepositoryProvider = Provider<DebitNoteRepository>((ref) {
  return InvoiceRepositoryImpl(invoices: _invoices(), finance: _finance(), actorId: _actorId(ref));
});

final gstRepositoryProvider = Provider<GSTRepository>((ref) {
  return FinanceRepositoryImpl(finance: _finance(), invoices: _invoices(), actorId: _actorId(ref));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return FinanceRepositoryImpl(finance: _finance(), invoices: _invoices(), actorId: _actorId(ref));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return FinanceRepositoryImpl(finance: _finance(), invoices: _invoices(), actorId: _actorId(ref));
});

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepositoryImpl(
    invoices: _invoices(),
    finance: _finance(),
    bills: VendorBillRepositoryImpl(),
    actorId: _actorId(ref),
  );
});

final invoicePdfProvider = Provider<InvoicePdfBuilder>((ref) => InvoicePdfBuilder());
final razorpayServiceProvider = Provider<RazorpayServiceImpl>((ref) => RazorpayServiceImpl());

class InvoiceQuery {
  const InvoiceQuery({this.clientId, this.status, this.from, this.to});

  final String? clientId;
  final InvoiceStatus? status;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is InvoiceQuery && other.clientId == clientId && other.status == status && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(clientId, status, from, to);
}

final invoicesProvider = FutureProvider.family<List<Invoice>, InvoiceQuery>((ref, query) async {
  final session = ref.watch(sessionControllerProvider);
  final clientId = session.user?.role == UserRole.client ? session.user?.accountId : query.clientId;
  final result = await ref.watch(invoiceRepositoryProvider).getInvoices(
        clientId: clientId,
        status: query.status,
        from: query.from,
        to: query.to,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final invoiceByIdProvider = FutureProvider.family<Invoice, String>((ref, id) async {
  final result = await ref.watch(invoiceRepositoryProvider).getInvoiceById(id);
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final clientInvoicesProvider = FutureProvider<List<Invoice>>((ref) {
  return ref.watch(invoicesProvider(const InvoiceQuery()).future);
});

class PaymentQuery {
  const PaymentQuery({this.invoiceId, this.clientId, this.status});

  final String? invoiceId;
  final String? clientId;
  final ClientPaymentStatus? status;

  @override
  bool operator ==(Object other) =>
      other is PaymentQuery && other.invoiceId == invoiceId && other.clientId == clientId && other.status == status;

  @override
  int get hashCode => Object.hash(invoiceId, clientId, status);
}

final paymentsProvider = FutureProvider.family<List<Payment>, PaymentQuery>((ref, query) async {
  final session = ref.watch(sessionControllerProvider);
  final clientId = session.user?.role == UserRole.client ? session.user?.accountId : query.clientId;
  final result = await ref.watch(paymentRepositoryProvider).getPayments(
        invoiceId: query.invoiceId,
        clientId: clientId,
        status: query.status,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final creditNotesProvider = FutureProvider.family<List<CreditNote>, String?>((ref, invoiceId) async {
  final result = await ref.watch(creditNoteRepositoryProvider).getCreditNotes(invoiceId: invoiceId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final debitNotesProvider = FutureProvider.family<List<DebitNote>, String?>((ref, invoiceId) async {
  final result = await ref.watch(debitNoteRepositoryProvider).getDebitNotes(invoiceId: invoiceId);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

class ExpenseQuery {
  const ExpenseQuery({this.projectId, this.category, this.status});

  final String? projectId;
  final ExpenseCategory? category;
  final ExpenseStatus? status;

  @override
  bool operator ==(Object other) =>
      other is ExpenseQuery && other.projectId == projectId && other.category == category && other.status == status;

  @override
  int get hashCode => Object.hash(projectId, category, status);
}

final expensesProvider = FutureProvider.family<List<Expense>, ExpenseQuery>((ref, query) async {
  final result = await ref.watch(expenseRepositoryProvider).getExpenses(
        projectId: query.projectId,
        category: query.category,
        status: query.status,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final gstSettingsProvider = FutureProvider<GSTSettings>((ref) async {
  final result = await ref.watch(gstRepositoryProvider).getGSTSettings();
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final taxRatesProvider = FutureProvider<List<TaxRate>>((ref) async {
  final result = await ref.watch(gstRepositoryProvider).getTaxRates(isActive: true);
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final gstReturnsProvider = FutureProvider<List<GSTReturn>>((ref) async {
  final result = await ref.watch(gstRepositoryProvider).getGSTReturns();
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

class LedgerQuery {
  const LedgerQuery({this.accountType, this.accountId});

  final AccountType? accountType;
  final String? accountId;

  @override
  bool operator ==(Object other) => other is LedgerQuery && other.accountType == accountType && other.accountId == accountId;

  @override
  int get hashCode => Object.hash(accountType, accountId);
}

final ledgerProvider = FutureProvider.family<List<LedgerEntry>, LedgerQuery>((ref, query) async {
  final result = await ref.watch(ledgerRepositoryProvider).getLedgerEntries(
        accountType: query.accountType,
        accountId: query.accountId,
      );
  return result.when(success: (rows) => rows, failure: (error) => throw Exception(error.userMessage));
});

final financialSummaryProvider = FutureProvider<FinancialSummary>((ref) async {
  final result = await ref.watch(accountingRepositoryProvider).getFinancialSummary();
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final ageingReportProvider = FutureProvider.family<AgeingReport, String>((ref, type) async {
  final result = await ref.watch(accountingRepositoryProvider).getAgeingReport(type: type);
  return result.when(success: (item) => item, failure: (error) => throw Exception(error.userMessage));
});

final clientUsersProvider = FutureProvider<List<User>>((ref) async {
  final result = await ref.watch(userRepositoryProvider).list(role: UserRole.client, limit: 100);
  return result.when(success: (page) => page.users, failure: (_) => const <User>[]);
});
