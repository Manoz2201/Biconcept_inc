import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../ui/widgets/portal_shell.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../rbac/domain/permission.dart';
import '../../../vendors/domain/line_items.dart';
import '../../../vendors/presentation/providers/vendors_provider.dart';
import '../../domain/purchase_order.dart';

class POListScreen extends ConsumerWidget {
  const POListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(purchaseOrdersProvider(const PoQuery()));
    return PermissionGate(
      permission: Permission.purchaseOrderView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Purchase orders')),
        floatingActionButton: PermissionGate(
          permission: Permission.purchaseOrderCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/purchase-orders/new'),
            icon: const Icon(Icons.add),
            label: const Text('Create PO'),
          ),
        ),
        body: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in rows)
                ListTile(
                  title: Text('${item.poNumber} · ${item.title}'),
                  subtitle: Text('${item.status.label} · ${formatMoney(item.total)}'),
                  onTap: () => context.push('/admin/purchase-orders/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PODetailScreen extends ConsumerWidget {
  const PODetailScreen({super.key, required this.poId});

  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersProvider(const PoQuery())).valueOrNull ?? const [];
    final order = orders.where((item) => item.id == poId).firstOrNull;
    if (order == null) return const Scaffold(body: Center(child: Text('Not found')));
    return PermissionGate(
      permission: Permission.purchaseOrderView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(order.poNumber)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(order.status.label),
            Text(formatMoney(order.total)),
            for (final item in order.items) ListTile(title: Text(item.itemName), trailing: Text(formatMoney(item.total))),
            if (order.status == PurchaseOrderStatus.draft)
              PermissionGate(
                permission: Permission.purchaseOrderIssue,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(purchaseOrderRepositoryProvider).issuePurchaseOrder(order.id);
                    ref.invalidate(purchaseOrdersProvider);
                  },
                  child: const Text('Issue'),
                ),
              ),
            FilledButton.tonal(
              onPressed: () async {
                final vendors = ref.read(vendorsProvider(const VendorQuery())).valueOrNull ?? const [];
                await ref.read(poPdfServiceProvider).sharePdf(
                      order,
                      vendorName: vendors.where((item) => item.id == order.vendorId).firstOrNull?.companyName,
                    );
              },
              child: const Text('Share PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class POFormScreen extends ConsumerStatefulWidget {
  const POFormScreen({super.key});

  @override
  ConsumerState<POFormScreen> createState() => _POFormScreenState();
}

class _POFormScreenState extends ConsumerState<POFormScreen> {
  final _title = TextEditingController();
  String? _projectId;
  String? _vendorId;
  final _delivery = DateTime.now().add(const Duration(days: 21));
  final _items = <PricedLine>[const PricedLine(itemName: '', quantity: 1, unit: 'nos', rate: 0, total: 0)];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider(const ProjectQuery())).valueOrNull ?? const [];
    final vendors = ref.watch(vendorsProvider(const VendorQuery(isActive: true))).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.purchaseOrderCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('New PO')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _projectId,
              decoration: const InputDecoration(labelText: 'Project'),
              items: [for (final item in projects) DropdownMenuItem(value: item.id, child: Text(item.title))],
              onChanged: (value) => setState(() => _projectId = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: _vendorId,
              decoration: const InputDecoration(labelText: 'Vendor'),
              items: [for (final item in vendors) DropdownMenuItem(value: item.id, child: Text(item.companyName))],
              onChanged: (value) => setState(() => _vendorId = value),
            ),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            FilledButton(
              onPressed: () async {
                if (_projectId == null || _vendorId == null) return;
                final result = await ref.read(purchaseOrderRepositoryProvider).createPurchaseOrder(
                      projectId: _projectId!,
                      vendorId: _vendorId!,
                      title: _title.text,
                      items: [for (final item in _items) if (item.itemName.trim().isNotEmpty) item],
                      deliveryDate: _delivery,
                    );
                result.when(
                  success: (order) {
                    ref.invalidate(purchaseOrdersProvider);
                    context.go('/admin/purchase-orders/${order.id}');
                  },
                  failure: (_) {},
                );
              },
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorPOListScreen extends ConsumerWidget {
  const VendorPOListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final items = vendor == null
        ? const <PurchaseOrder>[]
        : ref.watch(purchaseOrdersProvider(PoQuery(vendorId: vendor.id))).valueOrNull ?? const [];
    return PortalPageScaffold(
      title: 'orders',
      subtitle: 'Purchase orders issued to your firm.',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            ListTile(
              title: Text(item.poNumber),
              subtitle: Text(item.status.label),
              trailing: Text(formatMoney(item.total)),
              onTap: () => context.push('/vendor/pos/${item.id}'),
            ),
        ],
      ),
    );
  }
}

class VendorPODetailScreen extends ConsumerWidget {
  const VendorPODetailScreen({super.key, required this.poId});

  final String poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final items = vendor == null
        ? const <PurchaseOrder>[]
        : ref.watch(purchaseOrdersProvider(PoQuery(vendorId: vendor.id))).valueOrNull ?? const [];
    final order = items.where((item) => item.id == poId).firstOrNull;
    if (order == null) return const Scaffold(body: Center(child: Text('Not found')));
    return Scaffold(
      appBar: AppBar(title: Text(order.poNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(order.status.label),
          for (final item in order.items) ListTile(title: Text(item.itemName), trailing: Text(formatMoney(item.total))),
          if (order.status == PurchaseOrderStatus.issued)
            FilledButton(
              onPressed: () async {
                await ref.read(purchaseOrderRepositoryProvider).acknowledgePurchaseOrder(order.id);
                ref.invalidate(purchaseOrdersProvider);
              },
              child: const Text('Acknowledge'),
            ),
          if (order.status == PurchaseOrderStatus.acknowledged)
            FilledButton(
              onPressed: () async {
                await ref.read(purchaseOrderRepositoryProvider).updatePurchaseOrderStatus(order.id, PurchaseOrderStatus.inProgress);
                ref.invalidate(purchaseOrdersProvider);
              },
              child: const Text('Mark in progress'),
            ),
          if (order.status == PurchaseOrderStatus.inProgress)
            FilledButton(
              onPressed: () async {
                await ref.read(purchaseOrderRepositoryProvider).updatePurchaseOrderStatus(order.id, PurchaseOrderStatus.delivered);
                ref.invalidate(purchaseOrdersProvider);
              },
              child: const Text('Mark delivered'),
            ),
        ],
      ),
    );
  }
}
