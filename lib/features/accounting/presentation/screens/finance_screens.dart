import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../ui/widgets/portal_shell.dart';
import '../../../credit_notes/domain/credit_note.dart';
import '../../../debit_notes/domain/debit_note.dart';
import '../../../expenses/domain/expense.dart';
import '../../../gst/domain/gst_math.dart';
import '../../../gst/domain/gst_settings.dart';
import '../../../invoices/domain/invoice.dart';
import '../../../invoices/presentation/providers/finance_providers.dart';
import '../../../ledger/domain/ledger_entry.dart';
import '../../../payments/domain/payment.dart';
import '../../../rbac/domain/permission.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class AccountantDashboardScreen extends ConsumerWidget {
  const AccountantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financialSummaryProvider);
    final invoices = ref.watch(invoicesProvider(const InvoiceQuery()));
    final payments = ref.watch(paymentsProvider(const PaymentQuery()));
    return PermissionGate(
      permission: Permission.financialReportView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: PortalPageScaffold(
        title: 'accounting',
        subtitle: 'Receivables, payables, and recent cash movement.',
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(financialSummaryProvider);
            ref.invalidate(invoicesProvider);
            ref.invalidate(paymentsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              summary.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('$error'),
                data: (item) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryCard(label: 'Receivables', value: formatMoney(item.totalReceivables), onTap: () => context.push('/admin/accounting/receivables')),
                    _SummaryCard(label: 'Payables', value: formatMoney(item.totalPayables), onTap: () => context.push('/admin/accounting/payables')),
                    _SummaryCard(label: 'Cash', value: formatMoney(item.cashInHand)),
                    _SummaryCard(label: 'Bank', value: formatMoney(item.bankBalance)),
                    _SummaryCard(label: 'Overdue AR', value: formatMoney(item.overdueReceivables), onTap: () => context.push('/admin/accounting/receivables')),
                    _SummaryCard(label: 'Pending expenses', value: '${item.pendingExpenses}', onTap: () => context.push('/admin/expenses/approval')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(onPressed: () => context.push('/admin/invoices/new'), child: const Text('New Invoice')),
                  OutlinedButton(onPressed: () => context.push('/admin/payments/new'), child: const Text('Record Payment')),
                  OutlinedButton(onPressed: () => context.push('/admin/expenses/new'), child: const Text('Add Expense')),
                  OutlinedButton(onPressed: () => context.push('/admin/gst/gstr1'), child: const Text('File GST')),
                  OutlinedButton(onPressed: () => context.push('/admin/audit'), child: const Text('GST audit')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Recent invoices', style: TextStyle(fontWeight: FontWeight.w700)),
              invoices.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (rows) => Column(
                  children: [
                    for (final item in rows.take(5))
                      ListTile(
                        title: Text(item.invoiceNumber),
                        trailing: Text(formatMoney(item.grandTotal)),
                        onTap: () => context.push('/admin/invoices/${item.id}'),
                      ),
                  ],
                ),
              ),
              const Text('Recent payments', style: TextStyle(fontWeight: FontWeight.w700)),
              payments.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (rows) => Column(
                  children: [
                    for (final item in rows.take(5))
                      ListTile(title: Text(item.paymentNumber), trailing: Text(formatMoney(item.amount))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: PortalKpiCard(label: label, value: value, icon: Icons.account_balance_outlined, onTap: onTap),
    );
  }
}

class PaymentListScreen extends ConsumerWidget {
  const PaymentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(paymentsProvider(const PaymentQuery()));
    return PermissionGate(
      permission: Permission.paymentView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Payments')),
        floatingActionButton: PermissionGate(
          permission: Permission.paymentCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/payments/new'),
            icon: const Icon(Icons.add),
            label: const Text('Record Payment'),
          ),
        ),
        body: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (rows) => ListView(
            children: [
              for (final item in rows)
                ListTile(
                  title: Text(item.paymentNumber),
                  subtitle: Text('${item.paymentMethod.label} · ${item.status.label}'),
                  trailing: Text(formatMoney(item.amount)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  String? _invoiceId;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.bankTransfer;

  @override
  void initState() {
    super.initState();
    _invoiceId = widget.invoiceId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider(const InvoiceQuery(status: InvoiceStatus.issued)));
    final extra = ref.watch(invoicesProvider(const InvoiceQuery(status: InvoiceStatus.partiallyPaid)));
    final rows = [...(invoices.valueOrNull ?? const []), ...(extra.valueOrNull ?? const [])];
    final selected = rows.where((item) => item.id == _invoiceId).firstOrNull;
    if (selected != null && _amount.text.isEmpty) {
      _amount.text = selected.outstanding.toStringAsFixed(2);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Record payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _invoiceId,
            decoration: const InputDecoration(labelText: 'Invoice'),
            items: [
              for (final item in rows)
                DropdownMenuItem(value: item.id, child: Text('${item.invoiceNumber} · ${formatMoney(item.outstanding)}')),
            ],
            onChanged: (value) => setState(() => _invoiceId = value),
          ),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount')),
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: [
              for (final method in PaymentMethod.values) DropdownMenuItem(value: method, child: Text(method.label)),
            ],
            onChanged: (value) => setState(() => _method = value ?? PaymentMethod.bankTransfer),
          ),
          TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _invoiceId == null
                ? null
                : () async {
                    final result = await ref.read(paymentRepositoryProvider).createPayment(
                          invoiceId: _invoiceId,
                          amount: double.tryParse(_amount.text) ?? 0,
                          paymentDate: DateTime.now(),
                          paymentMethod: _method,
                          referenceNumber: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
                        );
                    result.when(
                      success: (_) {
                        ref.invalidate(paymentsProvider);
                        ref.invalidate(invoicesProvider);
                        context.pop();
                      },
                      failure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.userMessage))),
                    );
                  },
            child: const Text('Save payment'),
          ),
        ],
      ),
    );
  }
}

class CreditNoteListScreen extends ConsumerWidget {
  const CreditNoteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(creditNotesProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text('Credit notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/credit-notes/new'),
        label: const Text('New credit note'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => ListView(
          children: [
            for (final item in rows)
              ListTile(
                title: Text(item.creditNoteNumber),
                subtitle: Text(item.status.label),
                trailing: Text(formatMoney(item.grandTotal)),
                onTap: () => context.push('/admin/credit-notes/${item.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

class CreditNoteFormScreen extends ConsumerStatefulWidget {
  const CreditNoteFormScreen({super.key});

  @override
  ConsumerState<CreditNoteFormScreen> createState() => _CreditNoteFormScreenState();
}

class _CreditNoteFormScreenState extends ConsumerState<CreditNoteFormScreen> {
  String? _invoiceId;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider(const InvoiceQuery()));
    final invoice = (invoices.valueOrNull ?? const []).where((item) => item.id == _invoiceId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Credit note')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _invoiceId,
            decoration: const InputDecoration(labelText: 'Invoice'),
            items: [
              for (final item in invoices.valueOrNull ?? const <Invoice>[])
                DropdownMenuItem(value: item.id, child: Text(item.invoiceNumber)),
            ],
            onChanged: (value) => setState(() => _invoiceId = value),
          ),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: invoice == null
                ? null
                : () async {
                    final created = await ref.read(creditNoteRepositoryProvider).createCreditNote(
                          invoiceId: invoice.id,
                          reason: _reason.text.trim(),
                          items: invoice.items,
                        );
                    final note = created.dataOrNull;
                    if (note == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Failed')));
                    } else {
                      await ref.read(creditNoteRepositoryProvider).issueCreditNote(note.id);
                      ref.invalidate(creditNotesProvider);
                      if (!context.mounted) return;
                      context.pop();
                    }
                  },
            child: const Text('Issue credit note'),
          ),
        ],
      ),
    );
  }
}

class CreditNoteDetailScreen extends ConsumerWidget {
  const CreditNoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(creditNotesProvider(null)).valueOrNull ?? const <CreditNote>[];
    final note = notes.where((item) => item.id == noteId).firstOrNull;
    if (note == null) return const Scaffold(body: Center(child: Text('Not found')));
    return Scaffold(
      appBar: AppBar(title: Text(note.creditNoteNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(note.status.label),
          Text(note.reason),
          Text(formatMoney(note.grandTotal)),
          if (note.status == CreditNoteStatus.issued)
            FilledButton(
              onPressed: () async {
                await ref.read(creditNoteRepositoryProvider).applyCreditNote(note.id);
                ref.invalidate(creditNotesProvider);
              },
              child: const Text('Apply'),
            ),
        ],
      ),
    );
  }
}

class DebitNoteListScreen extends ConsumerWidget {
  const DebitNoteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(debitNotesProvider(null));
    return Scaffold(
      appBar: AppBar(title: const Text('Debit notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/debit-notes/new'),
        label: const Text('New debit note'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => ListView(
          children: [
            for (final item in rows)
              ListTile(
                title: Text(item.debitNoteNumber),
                trailing: Text(formatMoney(item.grandTotal)),
                onTap: () => context.push('/admin/debit-notes/${item.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

class DebitNoteFormScreen extends ConsumerStatefulWidget {
  const DebitNoteFormScreen({super.key});

  @override
  ConsumerState<DebitNoteFormScreen> createState() => _DebitNoteFormScreenState();
}

class _DebitNoteFormScreenState extends ConsumerState<DebitNoteFormScreen> {
  String? _invoiceId;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider(const InvoiceQuery()));
    final invoice = (invoices.valueOrNull ?? const []).where((item) => item.id == _invoiceId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Debit note')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _invoiceId,
            decoration: const InputDecoration(labelText: 'Invoice'),
            items: [
              for (final item in invoices.valueOrNull ?? const <Invoice>[])
                DropdownMenuItem(value: item.id, child: Text(item.invoiceNumber)),
            ],
            onChanged: (value) => setState(() => _invoiceId = value),
          ),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
          FilledButton(
            onPressed: invoice == null
                ? null
                : () async {
                    final created = await ref.read(debitNoteRepositoryProvider).createDebitNote(
                          invoiceId: invoice.id,
                          reason: _reason.text.trim(),
                          items: invoice.items,
                        );
                    final note = created.dataOrNull;
                    if (note == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Failed')));
                    } else {
                      await ref.read(debitNoteRepositoryProvider).issueDebitNote(note.id);
                      ref.invalidate(debitNotesProvider);
                      if (!context.mounted) return;
                      context.pop();
                    }
                  },
            child: const Text('Issue debit note'),
          ),
        ],
      ),
    );
  }
}

class DebitNoteDetailScreen extends ConsumerWidget {
  const DebitNoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(debitNotesProvider(null)).valueOrNull ?? const <DebitNote>[];
    final note = notes.where((item) => item.id == noteId).firstOrNull;
    if (note == null) return const Scaffold(body: Center(child: Text('Not found')));
    return Scaffold(
      appBar: AppBar(title: Text(note.debitNoteNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(note.status.label),
          Text(note.reason),
          Text(formatMoney(note.grandTotal)),
        ],
      ),
    );
  }
}

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(expensesProvider(const ExpenseQuery()));
    return PermissionGate(
      permission: Permission.expenseView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expenses'),
          actions: [
            IconButton(onPressed: () => context.push('/admin/expenses/approval'), icon: const Icon(Icons.fact_check_outlined)),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.expenseCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/expenses/new'),
            label: const Text('Add Expense'),
          ),
        ),
        body: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (rows) => ListView(
            children: [
              for (final item in rows)
                ListTile(
                  title: Text('${item.expenseNumber} · ${item.category.label}'),
                  subtitle: Text('${item.status.label} · ${item.description}'),
                  trailing: Text(formatMoney(item.totalAmount)),
                  onTap: () => context.push('/admin/expenses/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _gst = TextEditingController(text: '0');
  ExpenseCategory _category = ExpenseCategory.office;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _gst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _category,
            items: [for (final item in ExpenseCategory.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: (value) => setState(() => _category = value ?? ExpenseCategory.office),
          ),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount')),
          TextField(controller: _gst, decoration: const InputDecoration(labelText: 'GST amount')),
          FilledButton(
            onPressed: () async {
              final created = await ref.read(expenseRepositoryProvider).createExpense(
                    description: _description.text.trim(),
                    amount: double.tryParse(_amount.text) ?? 0,
                    expenseDate: DateTime.now(),
                    category: _category,
                    gstAmount: double.tryParse(_gst.text) ?? 0,
                  );
              final item = created.dataOrNull;
              if (item == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Failed')));
              } else {
                await ref.read(expenseRepositoryProvider).submitExpense(item.id);
                ref.invalidate(expensesProvider);
                if (!context.mounted) return;
                context.pop();
              }
            },
            child: const Text('Submit for approval'),
          ),
        ],
      ),
    );
  }
}

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(expensesProvider(const ExpenseQuery())).valueOrNull ?? const <Expense>[];
    final item = items.where((row) => row.id == expenseId).firstOrNull;
    if (item == null) return const Scaffold(body: Center(child: Text('Not found')));
    return Scaffold(
      appBar: AppBar(title: Text(item.expenseNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item.description),
          Text(item.status.label),
          Text(formatMoney(item.totalAmount)),
        ],
      ),
    );
  }
}

class ExpenseApprovalScreen extends ConsumerWidget {
  const ExpenseApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(expensesProvider(const ExpenseQuery(status: ExpenseStatus.submitted)));
    final actor = ref.watch(sessionControllerProvider).user?.accountId ?? 'staff';
    return Scaffold(
      appBar: AppBar(title: const Text('Expense approval')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => ListView(
          children: [
            for (final item in rows)
              ListTile(
                title: Text(item.expenseNumber),
                subtitle: Text(item.description),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatMoney(item.totalAmount)),
                    IconButton(
                      onPressed: () async {
                        await ref.read(expenseRepositoryProvider).approveExpense(item.id, actor);
                        ref.invalidate(expensesProvider);
                      },
                      icon: const Icon(Icons.check),
                    ),
                    IconButton(
                      onPressed: () async {
                        await ref.read(expenseRepositoryProvider).rejectExpense(item.id, 'Rejected');
                        ref.invalidate(expensesProvider);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ClientLedgerScreen extends ConsumerWidget {
  const ClientLedgerScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ledgerProvider(LedgerQuery(accountType: AccountType.client, accountId: clientId)));
    return _LedgerScaffold(title: 'Client ledger', items: items);
  }
}

class VendorLedgerScreen extends ConsumerWidget {
  const VendorLedgerScreen({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ledgerProvider(LedgerQuery(accountType: AccountType.vendor, accountId: vendorId)));
    return _LedgerScaffold(title: 'Vendor ledger', items: items);
  }
}

class GeneralLedgerScreen extends ConsumerWidget {
  const GeneralLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ledgerProvider(const LedgerQuery()));
    return _LedgerScaffold(title: 'General ledger', items: items);
  }
}

class _LedgerScaffold extends StatelessWidget {
  const _LedgerScaffold({required this.title, required this.items});

  final String title;
  final AsyncValue<List<LedgerEntry>> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () {
              final rows = items.valueOrNull ?? const [];
              final csv = [
                'date,description,debit,credit,balance',
                for (final item in rows)
                  '${item.entryDate.toIso8601String()},${item.description},${item.debitAmount},${item.creditAmount},${item.balance}',
              ].join('\n');
              Clipboard.setData(ClipboardData(text: csv));
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => ListView(
          children: [
            for (final item in rows)
              ListTile(
                title: Text(item.description),
                subtitle: Text(item.entryNumber),
                trailing: Text('${formatMoney(item.debitAmount)} / ${formatMoney(item.creditAmount)}'),
              ),
          ],
        ),
      ),
    );
  }
}

class GSTSettingsScreen extends ConsumerStatefulWidget {
  const GSTSettingsScreen({super.key});

  @override
  ConsumerState<GSTSettingsScreen> createState() => _GSTSettingsScreenState();
}

class _GSTSettingsScreenState extends ConsumerState<GSTSettingsScreen> {
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  String _stateCode = '33';

  @override
  void dispose() {
    _gstin.dispose();
    _pan.dispose();
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _pincode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gstSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GST settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) {
          _gstin.text = _gstin.text.isEmpty ? item.firmGstin ?? '' : _gstin.text;
          _pan.text = _pan.text.isEmpty ? item.firmPan ?? '' : _pan.text;
          _name.text = _name.text.isEmpty ? item.firmName : _name.text;
          _address.text = _address.text.isEmpty ? item.firmAddress : _address.text;
          _city.text = _city.text.isEmpty ? item.firmCity : _city.text;
          _pincode.text = _pincode.text.isEmpty ? item.firmPincode : _pincode.text;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Firm name')),
              TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
              TextField(controller: _pan, decoration: const InputDecoration(labelText: 'PAN')),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
              DropdownButtonFormField<String>(
                initialValue: _stateCode,
                items: [for (final entry in kGstStates.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
                onChanged: (value) => setState(() => _stateCode = value ?? '33'),
              ),
              TextField(controller: _pincode, decoration: const InputDecoration(labelText: 'Pincode')),
              FilledButton(
                onPressed: () async {
                  if (!isValidGstin(_gstin.text.trim()) || !isValidPan(_pan.text.trim())) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check GSTIN and PAN')));
                    return;
                  }
                  await ref.read(gstRepositoryProvider).updateGSTSettings({
                    'firmName': _name.text.trim(),
                    'firmGstin': _gstin.text.trim().toUpperCase(),
                    'firmPan': _pan.text.trim().toUpperCase(),
                    'firmAddress': _address.text.trim(),
                    'firmCity': _city.text.trim(),
                    'firmState': gstStateName(_stateCode),
                    'firmStateCode': _stateCode,
                    'firmPincode': _pincode.text.trim(),
                  });
                  ref.invalidate(gstSettingsProvider);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TaxRateListScreen extends ConsumerWidget {
  const TaxRateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(taxRatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HSN / SAC rates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/gst/tax-rates/new'),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => ListView(
          children: [
            for (final item in rows)
              ListTile(
                title: Text('${item.hsnSacCode} · ${item.description}'),
                trailing: Text('${item.taxRate.toStringAsFixed(0)}%'),
                onTap: () => context.push('/admin/gst/tax-rates/${item.id}/edit'),
              ),
          ],
        ),
      ),
    );
  }
}

class TaxRateFormScreen extends ConsumerStatefulWidget {
  const TaxRateFormScreen({super.key, this.rateId});

  final String? rateId;

  @override
  ConsumerState<TaxRateFormScreen> createState() => _TaxRateFormScreenState();
}

class _TaxRateFormScreenState extends ConsumerState<TaxRateFormScreen> {
  final _hsn = TextEditingController();
  final _description = TextEditingController();
  final _rate = TextEditingController(text: '18');

  @override
  void dispose() {
    _hsn.dispose();
    _description.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tax rate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _hsn, decoration: const InputDecoration(labelText: 'HSN / SAC')),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
          TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Tax rate %')),
          FilledButton(
            onPressed: () async {
              if (widget.rateId == null) {
                await ref.read(gstRepositoryProvider).createTaxRate(
                      hsnSacCode: _hsn.text.trim(),
                      description: _description.text.trim(),
                      taxRate: double.tryParse(_rate.text) ?? 18,
                      type: TaxRateType.services,
                    );
              } else {
                await ref.read(gstRepositoryProvider).updateTaxRate(widget.rateId!, {
                  'hsnSacCode': _hsn.text.trim(),
                  'description': _description.text.trim(),
                  'taxRate': double.tryParse(_rate.text) ?? 18,
                });
              }
              ref.invalidate(taxRatesProvider);
              if (context.mounted) context.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class GSTReturnListScreen extends ConsumerWidget {
  const GSTReturnListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(gstReturnsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GST returns')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => ListView(
          children: [
            ListTile(title: const Text('GSTR-1'), onTap: () => context.push('/admin/gst/gstr1')),
            ListTile(title: const Text('GSTR-3B'), onTap: () => context.push('/admin/gst/gstr3b')),
            ListTile(title: const Text('GSTR-2B'), onTap: () => context.push('/admin/gst/gstr2b')),
            for (final item in rows)
              ListTile(
                title: Text('${item.returnType.label} · ${item.period}'),
                subtitle: Text(item.status.label),
                onTap: () => context.push('/admin/gst/returns/${item.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

class GSTReturnDetailScreen extends ConsumerWidget {
  const GSTReturnDetailScreen({super.key, required this.returnId});

  final String returnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(gstReturnsProvider).valueOrNull ?? const <GSTReturn>[];
    final item = items.where((row) => row.id == returnId).firstOrNull;
    if (item == null) return const Scaffold(body: Center(child: Text('Not found')));
    return Scaffold(
      appBar: AppBar(title: Text(item.returnType.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item.period),
          Text('Taxable ${formatMoney(item.totalTaxableValue)}'),
          Text(item.status.label),
          if (item.status == GSTReturnStatus.draft)
            FilledButton(
              onPressed: () async {
                await ref.read(gstRepositoryProvider).fileGSTReturn(item.id, 'ACK-${item.period}');
                ref.invalidate(gstReturnsProvider);
              },
              child: const Text('Mark as filed'),
            ),
        ],
      ),
    );
  }
}

class GSTRExportScreen extends ConsumerWidget {
  const GSTRExportScreen({super.key, required this.type});

  final GSTReturnType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final fy = financialYearLabel(now);
    return Scaffold(
      appBar: AppBar(title: Text(type.label)),
      body: FutureBuilder(
        future: type == GSTReturnType.gstr3b
            ? ref.read(gstRepositoryProvider).exportGSTR3B(period, fy)
            : ref.read(gstRepositoryProvider).exportGSTR1(period, fy),
        builder: (context, snapshot) {
          final data = snapshot.data?.dataOrNull ?? snapshot.data?.errorOrNull?.userMessage ?? 'Loading…';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Period $period · FY $fy'),
              SelectableText(data),
              FilledButton(
                onPressed: () async {
                  await ref.read(gstRepositoryProvider).createGSTReturn(returnType: type, period: period, financialYear: fy);
                  ref.invalidate(gstReturnsProvider);
                },
                child: const Text('Save draft return'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(ageingReportProvider('receivables'));
    return _AgeingScaffold(title: 'Receivables', report: report);
  }
}

class PayablesScreen extends ConsumerWidget {
  const PayablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(ageingReportProvider('payables'));
    return _AgeingScaffold(title: 'Payables', report: report);
  }
}

class _AgeingScaffold extends StatelessWidget {
  const _AgeingScaffold({required this.title, required this.report});

  final String title;
  final AsyncValue<dynamic> report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) {
          final ageing = item as dynamic;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text(['Now', '30', '60', '90', '90+'][value.toInt().clamp(0, 4)]),
                        ),
                      ),
                    ),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: (ageing.current as num).toDouble())]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: (ageing.days30 as num).toDouble())]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: (ageing.days60 as num).toDouble())]),
                      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: (ageing.days90 as num).toDouble())]),
                      BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: (ageing.days90Plus as num).toDouble())]),
                    ],
                  ),
                ),
              ),
              for (final entry in ageing.entries)
                ListTile(
                  title: Text(entry.invoiceNumber.toString()),
                  subtitle: Text('${entry.daysOverdue} days · ${entry.bucket.label}'),
                  trailing: Text(formatMoney((entry.amount as num).toDouble())),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CashflowScreen extends ConsumerWidget {
  const CashflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 5, 1);
    return Scaffold(
      appBar: AppBar(title: const Text('Cashflow')),
      body: FutureBuilder(
        future: ref.read(accountingRepositoryProvider).getCashflow(from, now),
        builder: (context, snapshot) {
          final rows = snapshot.data?.dataOrNull ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in rows)
                ListTile(
                  title: Text(item.period),
                  subtitle: Text('In ${formatMoney(item.cashIn)} · Out ${formatMoney(item.cashOut)}'),
                  trailing: Text(formatMoney(item.net)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PLStatementScreen extends ConsumerWidget {
  const PLStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Profit and loss')),
      body: FutureBuilder(
        future: ref.read(ledgerRepositoryProvider).getProfitAndLoss(DateTime(now.year, 4, 1), now),
        builder: (context, snapshot) {
          final item = snapshot.data?.dataOrNull;
          if (item == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Revenue ${formatMoney(item.revenue)}'),
              for (final entry in item.expensesByCategory.entries) Text('${entry.key} ${formatMoney(entry.value)}'),
              Text('Net profit ${formatMoney(item.netProfit)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          );
        },
      ),
    );
  }
}

class BankReconciliationScreen extends ConsumerStatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  ConsumerState<BankReconciliationScreen> createState() => _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends ConsumerState<BankReconciliationScreen> {
  final _description = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Bank reconciliation')),
      body: FutureBuilder(
        future: ref.read(accountingRepositoryProvider).getBankReconciliation(from: DateTime(now.year, now.month, 1), to: now),
        builder: (context, snapshot) {
          final data = snapshot.data?.dataOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _description, decoration: const InputDecoration(labelText: 'Statement line')),
              TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount')),
              FilledButton(
                onPressed: () async {
                  await ref.read(accountingRepositoryProvider).addBankStatementLine(
                        entryDate: DateTime.now(),
                        description: _description.text.trim(),
                        amount: double.tryParse(_amount.text) ?? 0,
                      );
                  setState(() {});
                },
                child: const Text('Add statement line'),
              ),
              if (data != null) ...[
                Text('Matched ${data.matched} · Unmatched book ${data.unmatchedBook}'),
                for (final item in data.bookEntries) ListTile(title: Text(item.description), trailing: Text(formatMoney(item.amount))),
                for (final item in data.statementLines)
                  ListTile(
                    title: Text(item.description),
                    subtitle: Text(item.matched ? 'Matched' : 'Unmatched'),
                    trailing: Text(formatMoney(item.amount)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class FinancialYearClosingScreen extends ConsumerWidget {
  const FinancialYearClosingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = financialYearLabel(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Financial year closing')),
      body: FutureBuilder(
        future: ref.read(accountingRepositoryProvider).getFinancialYearClosing(fy),
        builder: (context, snapshot) {
          final item = snapshot.data?.dataOrNull;
          if (item == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('FY ${item.financialYear}'),
              Text('Revenue ${formatMoney(item.revenue)}'),
              Text('Expenses ${formatMoney(item.expenses)}'),
              Text('Net profit ${formatMoney(item.netProfit)}'),
              Text('GST liability ${formatMoney(item.gstLiability)}'),
              if (!item.locked)
                FilledButton(
                  onPressed: () async {
                    await ref.read(accountingRepositoryProvider).closeFinancialYear(fy);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Financial year closed')));
                  },
                  child: const Text('Close financial year'),
                )
              else
                const Text('This year is locked'),
            ],
          );
        },
      ),
    );
  }
}
