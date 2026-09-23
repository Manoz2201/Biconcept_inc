import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../ui/widgets/portal_shell.dart';
import '../../../rbac/domain/permission.dart';
import '../../../vendors/domain/line_items.dart';
import '../../../vendors/presentation/providers/vendors_provider.dart';
import '../../domain/vendor_bill.dart';
import '../../domain/vendor_payment.dart';

class VendorBillListScreen extends ConsumerWidget {
  const VendorBillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vendorBillsProvider(const BillQuery()));
    return PermissionGate(
      permission: Permission.vendorBillView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendor bills'),
          actions: [
            PermissionGate(
              permission: Permission.vendorBillApprove,
              child: IconButton(
                onPressed: () => context.push('/admin/vendor-bills/approval'),
                icon: const Icon(Icons.fact_check_outlined),
              ),
            ),
          ],
        ),
        body: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in rows)
                ListTile(
                  title: Text(item.billNumber),
                  subtitle: Text('${item.status.label} · due ${formatDisplayDate(item.dueDate)}'),
                  trailing: Text(formatMoney(item.total)),
                  onTap: () => context.push('/admin/vendor-bills/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VendorBillDetailScreen extends ConsumerWidget {
  const VendorBillDetailScreen({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(vendorBillsProvider(const BillQuery())).valueOrNull ?? const [];
    final bill = bills.where((item) => item.id == billId).firstOrNull;
    if (bill == null) return const Scaffold(body: Center(child: Text('Not found')));
    return PermissionGate(
      permission: Permission.vendorBillView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(bill.billNumber)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(bill.status.label),
            Text(formatMoney(bill.total)),
            Text('Paid ${formatMoney(bill.paidAmount)} · remaining ${formatMoney(bill.remaining)}'),
            if (bill.status == VendorBillStatus.submitted || bill.status == VendorBillStatus.underReview)
              PermissionGate(
                permission: Permission.vendorBillApprove,
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: () async {
                        await ref.read(vendorBillRepositoryProvider).approveVendorBill(bill.id, 'staff');
                        ref.invalidate(vendorBillsProvider);
                      },
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(vendorBillRepositoryProvider).rejectVendorBill(bill.id, 'Rejected');
                        ref.invalidate(vendorBillsProvider);
                      },
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ),
            PermissionGate(
              permission: Permission.vendorPaymentCreate,
              child: FilledButton.tonal(
                onPressed: () => context.push('/admin/vendor-payments/new?billId=${bill.id}'),
                child: const Text('Record payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorBillApprovalScreen extends ConsumerWidget {
  const VendorBillApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vendorBillsProvider(const BillQuery(status: VendorBillStatus.submitted))).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.vendorBillApprove,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Bill approval')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items)
              ListTile(
                title: Text(item.billNumber),
                trailing: FilledButton(
                  onPressed: () async {
                    await ref.read(vendorBillRepositoryProvider).approveVendorBill(item.id, 'staff');
                    ref.invalidate(vendorBillsProvider);
                  },
                  child: const Text('Approve'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VendorPaymentFormScreen extends ConsumerStatefulWidget {
  const VendorPaymentFormScreen({super.key, this.billId});

  final String? billId;

  @override
  ConsumerState<VendorPaymentFormScreen> createState() => _VendorPaymentFormScreenState();
}

class _VendorPaymentFormScreenState extends ConsumerState<VendorPaymentFormScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.bankTransfer;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.vendorPaymentCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Record payment')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              items: [for (final item in PaymentMethod.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference')),
            FilledButton(
              onPressed: widget.billId == null
                  ? null
                  : () async {
                      final amount = double.tryParse(_amount.text);
                      if (amount == null) return;
                      final created = await ref.read(vendorPaymentRepositoryProvider).createVendorPayment(
                            billId: widget.billId!,
                            amount: amount,
                            paymentDate: DateTime.now(),
                            paymentMethod: _method,
                            referenceNumber: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
                      );
                      final id = created.dataOrNull?.id;
                      if (id != null) await ref.read(vendorPaymentRepositoryProvider).completePayment(id);
                      ref.invalidate(vendorBillsProvider);
                      if (context.mounted) context.pop();
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorPortalBillListScreen extends ConsumerWidget {
  const VendorPortalBillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final items = vendor == null
        ? const <VendorBill>[]
        : ref.watch(vendorBillsProvider(BillQuery(vendorId: vendor.id))).valueOrNull ?? const [];
    return PortalPageScaffold(
      title: 'bills',
      subtitle: 'Invoices you have submitted to the studio.',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/vendor/bills/new'),
        tooltip: 'Submit bill',
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            ListTile(
              title: Text(item.billNumber),
              subtitle: Text(item.status.label),
              trailing: Text(formatMoney(item.total)),
            ),
        ],
      ),
    );
  }
}

class VendorBillFormScreen extends ConsumerStatefulWidget {
  const VendorBillFormScreen({super.key});

  @override
  ConsumerState<VendorBillFormScreen> createState() => _VendorBillFormScreenState();
}

class _VendorBillFormScreenState extends ConsumerState<VendorBillFormScreen> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _rate = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _qty.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('New bill')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _number, decoration: const InputDecoration(labelText: 'Bill number')),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item')),
          TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Qty')),
          TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Rate')),
          FilledButton(
            onPressed: vendor == null
                ? null
                : () async {
                    final qty = double.tryParse(_qty.text) ?? 1;
                    final rate = double.tryParse(_rate.text) ?? 0;
                    final created = await ref.read(vendorBillRepositoryProvider).createVendorBill(
                          vendorId: vendor.id,
                          billNumber: _number.text,
                          billDate: DateTime.now(),
                          dueDate: DateTime.now().add(const Duration(days: 15)),
                          items: [PricedLine(itemName: _name.text, quantity: qty, unit: 'nos', rate: rate, total: qty * rate)],
                        );
                    final id = created.dataOrNull?.id;
                    if (id != null) await ref.read(vendorBillRepositoryProvider).submitVendorBill(id);
                    ref.invalidate(vendorBillsProvider);
                    if (context.mounted) context.go('/vendor/bills');
                  },
            child: const Text('Submit bill'),
          ),
        ],
      ),
    );
  }
}

class VendorPaymentHistoryScreen extends ConsumerWidget {
  const VendorPaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final items = ref.watch(vendorPaymentsProvider(vendor?.id)).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            ListTile(
              title: Text(formatMoney(item.amount)),
              subtitle: Text('${item.paymentMethod.label} · ${item.status.label}'),
            ),
        ],
      ),
    );
  }
}
