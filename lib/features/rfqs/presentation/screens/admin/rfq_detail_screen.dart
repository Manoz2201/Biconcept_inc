import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../vendors/presentation/providers/vendors_provider.dart';
import '../../../domain/rfq.dart';

class RFQDetailScreen extends ConsumerWidget {
  const RFQDetailScreen({super.key, required this.rfqId});

  final String rfqId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rfqByIdProvider(rfqId));
    return PermissionGate(
      permission: Permission.rfqView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: async.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (rfq) => DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(rfq.rfqNumber),
              actions: [
                if (rfq.status == RFQStatus.draft)
                  PermissionGate(
                    permission: Permission.rfqSend,
                    child: TextButton(
                      onPressed: () async {
                        await ref.read(rfqRepositoryProvider).sendRFQ(rfq.id);
                        ref.invalidate(rfqByIdProvider(rfq.id));
                      },
                      child: const Text('Send'),
                    ),
                  ),
              ],
              bottom: const TabBar(tabs: [Tab(text: 'Items'), Tab(text: 'Vendors'), Tab(text: 'Quotes'), Tab(text: 'Details')]),
            ),
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in rfq.items)
                      ListTile(title: Text(item.itemName), subtitle: Text('${item.quantity} ${item.unit}')),
                  ],
                ),
                _VendorsTab(rfqId: rfq.id),
                _QuotesTab(rfq: rfq),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(rfq.title, style: Theme.of(context).textTheme.titleLarge),
                    Text(rfq.description),
                    Text(rfq.status.label),
                    Text('Due ${formatDisplayDate(rfq.dueDate)}'),
                    PermissionGate(
                      permission: Permission.rfqDelete,
                      child: TextButton(
                        onPressed: () async {
                          await ref.read(rfqRepositoryProvider).cancelRFQ(rfq.id);
                          ref.invalidate(rfqByIdProvider(rfq.id));
                        },
                        child: const Text('Cancel RFQ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab({required this.rfqId});
  final String rfqId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipients = ref.watch(rfqRecipientsProvider(rfqId)).valueOrNull ?? const [];
    final vendors = ref.watch(vendorsProvider(const VendorQuery())).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PermissionGate(
          permission: Permission.rfqEdit,
          child: FilledButton(
            onPressed: () => context.push('/admin/rfqs/$rfqId/vendors'),
            child: const Text('Invite vendors'),
          ),
        ),
        for (final item in recipients)
          ListTile(
            title: Text(vendors.where((vendor) => vendor.id == item.vendorId).firstOrNull?.companyName ?? item.vendorId),
            subtitle: Text(item.status.label),
          ),
      ],
    );
  }
}

class _QuotesTab extends ConsumerWidget {
  const _QuotesTab({required this.rfq});
  final RFQ rfq;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(vendorQuotesProvider(rfq.id)).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(
          onPressed: () => context.push('/admin/rfqs/${rfq.id}/compare'),
          child: const Text('Compare quotes'),
        ),
        for (final item in quotes)
          ListTile(
            title: Text(item.quoteNumber),
            subtitle: Text(item.status.label),
            trailing: Text(formatMoney(item.total)),
          ),
      ],
    );
  }
}

class RFQVendorSelectionScreen extends ConsumerWidget {
  const RFQVendorSelectionScreen({super.key, required this.rfqId});

  final String rfqId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(vendorsProvider(const VendorQuery(isActive: true))).valueOrNull ?? const [];
    final selected = <String>{};
    return PermissionGate(
      permission: Permission.rfqEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Invite vendors')),
        body: _InviteBody(rfqId: rfqId, vendors: vendors, selected: selected),
      ),
    );
  }
}

class _InviteBody extends StatefulWidget {
  const _InviteBody({required this.rfqId, required this.vendors, required this.selected});
  final String rfqId;
  final List<dynamic> vendors;
  final Set<String> selected;

  @override
  State<_InviteBody> createState() => _InviteBodyState();
}

class _InviteBodyState extends State<_InviteBody> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final vendor in widget.vendors)
            CheckboxListTile(
              value: widget.selected.contains(vendor.id as String),
              title: Text(vendor.companyName as String),
              subtitle: Text('Rating ${(vendor.rating as num).toStringAsFixed(1)}'),
              onChanged: (value) => setState(() {
                if (value == true) {
                  widget.selected.add(vendor.id as String);
                } else {
                  widget.selected.remove(vendor.id as String);
                }
              }),
            ),
          FilledButton(
            onPressed: () async {
              await ref.read(rfqRepositoryProvider).inviteVendors(widget.rfqId, widget.selected.toList());
              ref.invalidate(rfqRecipientsProvider(widget.rfqId));
              if (context.mounted) context.pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
