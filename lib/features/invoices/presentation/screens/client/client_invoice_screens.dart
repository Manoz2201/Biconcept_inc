import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../../../payments/domain/payment.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../domain/invoice.dart';
import '../../providers/finance_providers.dart';
import '../../widgets/invoice_widgets.dart';

class ClientInvoicesScreen extends ConsumerWidget {
  const ClientInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(clientInvoicesProvider);
    return PermissionGate(
      permission: Permission.clientPortalInvoiceView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: PortalPageScaffold(
        title: 'invoices',
        subtitle: 'Amounts due and paid studio invoices.',
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientInvoicesProvider),
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(children: [Center(child: Text('$error'))]),
            data: (rows) => rows.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('No invoices yet'))])
                : ListView(
                    children: [
                      for (final item in rows)
                        InvoiceCard(invoice: item, onTap: () => context.push('/client/invoices/${item.id}')),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class ClientInvoiceDetailScreen extends ConsumerWidget {
  const ClientInvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceByIdProvider(invoiceId));
    final payments = ref.watch(paymentsProvider(PaymentQuery(invoiceId: invoiceId)));
    return invoice.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (item) => Scaffold(
        appBar: AppBar(
          title: Text(item.invoiceNumber),
          actions: [
            IconButton(onPressed: () => ref.read(invoiceRepositoryProvider).sharePdf(item.id), icon: const Icon(Icons.download_outlined)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InvoiceStatusBadge(status: item.displayStatus),
            GstBreakdownWidget(invoice: item),
            if (item.bankDetails != null) Text(item.bankDetails!),
            payments.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (rows) => Column(
                children: [
                  for (final payment in rows)
                    ListTile(title: Text(payment.paymentNumber), trailing: Text(formatMoney(payment.amount))),
                ],
              ),
            ),
            if (item.displayStatus == InvoiceStatus.issued || item.displayStatus == InvoiceStatus.partiallyPaid || item.displayStatus == InvoiceStatus.overdue)
              FilledButton(
                onPressed: () => context.push('/client/invoices/${item.id}/pay'),
                child: const Text('Pay Now'),
              ),
          ],
        ),
      ),
    );
  }
}

class ClientPaymentScreen extends ConsumerStatefulWidget {
  const ClientPaymentScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends ConsumerState<ClientPaymentScreen> {
  final _reference = TextEditingController();
  var _busy = false;
  String? _message;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceByIdProvider(widget.invoiceId)).valueOrNull;
    final razorpay = ref.watch(razorpayServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pay invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (invoice != null) Text('Balance ${formatMoney(invoice.outstanding)}'),
          if (_message != null) Text(_message!),
          if (!razorpay.isConfigured)
            const Text('Online checkout is not configured. Pay by bank transfer or UPI and send the reference below.'),
          TextField(controller: _reference, decoration: const InputDecoration(labelText: 'UPI / bank reference')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || invoice == null
                ? null
                : () async {
                    setState(() => _busy = true);
                    final result = await ref.read(paymentRepositoryProvider).createPayment(
                          invoiceId: invoice.id,
                          clientId: invoice.clientId,
                          amount: invoice.outstanding,
                          paymentDate: DateTime.now(),
                          paymentMethod: razorpay.isConfigured ? PaymentMethod.razorpay : PaymentMethod.upi,
                          referenceNumber: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
                          notes: 'Client portal payment',
                          completeImmediately: false,
                        );
                    result.when(
                      success: (_) {
                        ref.invalidate(invoiceByIdProvider(widget.invoiceId));
                        setState(() => _message = 'Payment submitted. Accounts will confirm it.');
                      },
                      failure: (error) => setState(() => _message = error.userMessage),
                    );
                    if (mounted) setState(() => _busy = false);
                  },
            child: const Text('Submit payment'),
          ),
        ],
      ),
    );
  }
}

class ClientPaymentHistoryScreen extends ConsumerWidget {
  const ClientPaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(paymentsProvider(const PaymentQuery()));
    return PermissionGate(
      permission: Permission.clientPortalPaymentView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: PortalPageScaffold(
        title: 'payments',
        subtitle: 'Receipts against your studio invoices.',
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
                  onTap: item.invoiceId == null ? null : () => context.push('/client/invoices/${item.invoiceId}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
