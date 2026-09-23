import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../gst/domain/gst_math.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../domain/invoice.dart';
import '../../providers/finance_providers.dart';
import '../../widgets/invoice_widgets.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  InvoiceStatus? _status;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(invoicesProvider(InvoiceQuery(status: _status)));
    return PermissionGate(
      permission: Permission.invoiceView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invoices'),
          actions: [
            IconButton(
              tooltip: 'Copy CSV',
              onPressed: () {
                final rows = items.valueOrNull ?? const [];
                final csv = ref.read(invoiceRepositoryProvider).exportInvoicesToCsv(rows);
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied')));
              },
              icon: const Icon(Icons.table_view_outlined),
            ),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.invoiceCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/invoices/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Invoice'),
          ),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  FilterChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                  for (final status in InvoiceStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (rows) => ListView(
                  children: [
                    for (final item in rows)
                      InvoiceCard(invoice: item, onTap: () => context.push('/admin/invoices/${item.id}')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceByIdProvider(invoiceId));
    final payments = ref.watch(paymentsProvider(PaymentQuery(invoiceId: invoiceId)));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (invoice) => PermissionGate(
        permission: Permission.invoiceView,
        fallback: const Scaffold(body: Center(child: Text('No access'))),
        child: Scaffold(
          appBar: AppBar(
            title: Text(invoice.invoiceNumber),
            actions: [
              IconButton(
                onPressed: () => ref.read(invoiceRepositoryProvider).sharePdf(invoice.id),
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  InvoiceStatusBadge(status: invoice.displayStatus),
                  const Spacer(),
                  Text(formatMoney(invoice.grandTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              Text('Client ${invoice.clientId}'),
              Text('Place of supply ${invoice.placeOfSupply} (${invoice.placeOfSupplyCode})'),
              Text(invoice.amountInWords),
              const SizedBox(height: 16),
              GstBreakdownWidget(invoice: invoice),
              const SizedBox(height: 16),
              Text('Paid ${formatMoney(invoice.paidAmount)} · Balance ${formatMoney(invoice.outstanding)}'),
              payments.when(
                loading: () => const SizedBox.shrink(),
                error: (error, _) => Text('$error'),
                data: (rows) => Column(
                  children: [
                    for (final payment in rows)
                      ListTile(
                        title: Text(payment.paymentNumber),
                        subtitle: Text('${payment.paymentMethod.label} · ${payment.status.label}'),
                        trailing: Text(formatMoney(payment.amount)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (invoice.status == InvoiceStatus.draft)
                    PermissionGate(
                      permission: Permission.invoiceIssue,
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(invoiceRepositoryProvider).issueInvoice(invoice.id);
                          ref.invalidate(invoiceByIdProvider(invoiceId));
                          ref.invalidate(invoicesProvider);
                        },
                        child: const Text('Issue Invoice'),
                      ),
                    ),
                  if (invoice.status == InvoiceStatus.draft)
                    PermissionGate(
                      permission: Permission.invoiceEdit,
                      child: OutlinedButton(
                        onPressed: () => context.push('/admin/invoices/${invoice.id}/edit'),
                        child: const Text('Edit'),
                      ),
                    ),
                  if (invoice.status == InvoiceStatus.issued || invoice.status == InvoiceStatus.partiallyPaid || invoice.displayStatus == InvoiceStatus.overdue)
                    PermissionGate(
                      permission: Permission.paymentCreate,
                      child: OutlinedButton(
                        onPressed: () => context.push('/admin/payments/new?invoiceId=${invoice.id}'),
                        child: const Text('Record Payment'),
                      ),
                    ),
                  if (invoice.paidAmount == 0 && invoice.status != InvoiceStatus.voided)
                    PermissionGate(
                      permission: Permission.invoiceVoid,
                      child: TextButton(
                        onPressed: () => context.push('/admin/invoices/${invoice.id}/void'),
                        child: const Text('Void'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  String? _clientId;
  String _stateCode = '33';
  final _notes = TextEditingController();
  final _lines = <_DraftLine>[_DraftLine()];
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientUsersProvider);
    final settings = ref.watch(gstSettingsProvider).valueOrNull;
    final rates = ref.watch(taxRatesProvider).valueOrNull ?? const [];
    final interState = isInterStateSupply(settings?.firmStateCode ?? '33', _stateCode);
    final items = [
      for (final line in _lines)
        InvoiceItem.priced(
          description: line.description.text,
          hsnSac: line.hsn.text,
          quantity: double.tryParse(line.qty.text) ?? 0,
          unit: line.unit.text.isEmpty ? 'nos' : line.unit.text,
          rate: double.tryParse(line.rate.text) ?? 0,
          taxRate: double.tryParse(line.tax.text) ?? settings?.defaultTaxRate ?? 18,
          interState: interState,
        ),
    ];
    final totals = invoiceTotalsFromLines([
      for (final item in items)
        GstLineTotals(
          taxableValue: item.taxableValue,
          cgst: item.cgst,
          sgst: item.sgst,
          igst: item.igst,
          cess: item.cess,
          total: item.total,
        ),
    ]);

    return PermissionGate(
      permission: Permission.invoiceCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.invoiceId == null ? 'New invoice' : 'Edit invoice')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!),
            clients.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextField(
                decoration: const InputDecoration(labelText: 'Client account ID'),
                onChanged: (value) => _clientId = value,
              ),
              data: (rows) => DropdownButtonFormField<String>(
                initialValue: _clientId,
                decoration: const InputDecoration(labelText: 'Client'),
                items: [
                  for (final user in rows) DropdownMenuItem(value: user.accountId, child: Text(user.name)),
                ],
                onChanged: (value) => setState(() => _clientId = value),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _stateCode,
              decoration: const InputDecoration(labelText: 'Place of supply'),
              items: [
                for (final entry in kGstStates.entries) DropdownMenuItem(value: entry.key, child: Text('${entry.value} (${entry.key})')),
              ],
              onChanged: (value) => setState(() => _stateCode = value ?? '33'),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _lines.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(controller: _lines[i].description, decoration: const InputDecoration(labelText: 'Description'), onChanged: (_) => setState(() {})),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: rates.any((item) => item.hsnSacCode == _lines[i].hsn.text) ? _lines[i].hsn.text : null,
                              decoration: const InputDecoration(labelText: 'HSN/SAC'),
                              items: [
                                for (final rate in rates)
                                  DropdownMenuItem(value: rate.hsnSacCode, child: Text('${rate.hsnSacCode} · ${rate.taxRate.toStringAsFixed(0)}%')),
                              ],
                              onChanged: (value) {
                                final rate = rates.where((item) => item.hsnSacCode == value).firstOrNull;
                                setState(() {
                                  _lines[i].hsn.text = value ?? '';
                                  if (rate != null) _lines[i].tax.text = rate.taxRate.toStringAsFixed(0);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextField(controller: _lines[i].qty, decoration: const InputDecoration(labelText: 'Qty'), onChanged: (_) => setState(() {})),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: TextField(controller: _lines[i].rate, decoration: const InputDecoration(labelText: 'Rate'), onChanged: (_) => setState(() {})),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(onPressed: () => setState(() => _lines.removeAt(i)), icon: const Icon(Icons.delete_outline)),
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(_DraftLine())),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 12),
            Text('Subtotal ${formatMoney(totals.subtotal)}'),
            Text(interState ? 'IGST ${formatMoney(totals.totalIgst)}' : 'CGST ${formatMoney(totals.totalCgst)} · SGST ${formatMoney(totals.totalSgst)}'),
            Text('Grand total ${formatMoney(totals.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(amountInIndianWords(totals.grandTotal)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => _save(items, issue: false),
              child: const Text('Save as Draft'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(items, issue: true),
              child: const Text('Save and Issue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(List<InvoiceItem> items, {required bool issue}) async {
    final clientId = _clientId;
    if (clientId == null || clientId.isEmpty) {
      setState(() => _error = 'Select a client');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final now = DateTime.now();
    final repo = ref.read(invoiceRepositoryProvider);
    final created = widget.invoiceId == null
        ? await repo.createInvoice(
            clientId: clientId,
            invoiceDate: now,
            dueDate: now.add(const Duration(days: 15)),
            placeOfSupply: gstStateName(_stateCode),
            placeOfSupplyCode: _stateCode,
            items: items,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          )
        : await repo.updateInvoice(widget.invoiceId!, items, notes: _notes.text.trim());
    final invoice = created.dataOrNull;
    if (invoice == null) {
      setState(() => _error = created.errorOrNull?.userMessage);
    } else {
      if (issue) await repo.issueInvoice(invoice.id);
      ref.invalidate(invoicesProvider);
      if (mounted) context.go('/admin/invoices/${invoice.id}');
    }
    if (mounted) setState(() => _busy = false);
  }
}

class InvoiceVoidScreen extends ConsumerStatefulWidget {
  const InvoiceVoidScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceVoidScreen> createState() => _InvoiceVoidScreenState();
}

class _InvoiceVoidScreenState extends ConsumerState<InvoiceVoidScreen> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Void invoice')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(invoiceRepositoryProvider).voidInvoice(widget.invoiceId, _reason.text.trim());
                result.when(
                  success: (_) {
                    ref.invalidate(invoicesProvider);
                    context.go('/admin/invoices/${widget.invoiceId}');
                  },
                  failure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.userMessage))),
                );
              },
              child: const Text('Void invoice'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLine {
  final description = TextEditingController();
  final hsn = TextEditingController(text: '9983');
  final qty = TextEditingController(text: '1');
  final unit = TextEditingController(text: 'nos');
  final rate = TextEditingController();
  final tax = TextEditingController(text: '18');

  void dispose() {
    description.dispose();
    hsn.dispose();
    qty.dispose();
    unit.dispose();
    rate.dispose();
    tax.dispose();
  }
}
