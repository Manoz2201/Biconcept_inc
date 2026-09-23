import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../vendors/presentation/providers/vendors_provider.dart';
import '../../../domain/vendor_quote.dart';

class VendorQuoteComparisonScreen extends ConsumerWidget {
  const VendorQuoteComparisonScreen({super.key, required this.rfqId});

  final String rfqId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = (ref.watch(vendorQuotesProvider(rfqId)).valueOrNull ?? const [])
        .where((item) => item.status != VendorQuoteStatus.draft)
        .toList();
    final vendors = ref.watch(vendorsProvider(const VendorQuery())).valueOrNull ?? const [];
    final lowest = quotes.isEmpty ? null : quotes.reduce((a, b) => a.total <= b.total ? a : b);
    final fastest = quotes.where((item) => item.deliveryDays != null).fold<VendorQuote?>(null, (best, item) {
      if (best == null) return item;
      return (item.deliveryDays ?? 999) < (best.deliveryDays ?? 999) ? item : best;
    });
    return PermissionGate(
      permission: Permission.vendorQuoteView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Compare quotes')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Vendor')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Days')),
                  DataColumn(label: Text('Valid')),
                ],
                rows: [
                  for (final quote in quotes)
                    DataRow(
                      color: WidgetStatePropertyAll(
                        quote.id == lowest?.id ? Colors.teal.withValues(alpha: 0.12) : null,
                      ),
                      cells: [
                        DataCell(Text(vendors.where((item) => item.id == quote.vendorId).firstOrNull?.companyName ?? quote.vendorId)),
                        DataCell(Text(formatMoney(quote.total))),
                        DataCell(Text('${quote.deliveryDays ?? '—'}')),
                        DataCell(Text(formatDisplayDate(quote.validUntil))),
                      ],
                    ),
                ],
              ),
            ),
            if (lowest != null) Text('Lowest total: ${lowest.quoteNumber}'),
            if (fastest != null) Text('Fastest delivery: ${fastest.quoteNumber}'),
            for (final quote in quotes)
              ExpansionTile(
                title: Text('${quote.quoteNumber} · ${formatMoney(quote.total)}'),
                children: [
                  for (final item in quote.items)
                    ListTile(title: Text(item.itemName), trailing: Text(formatMoney(item.total))),
                  PermissionGate(
                    permission: Permission.rfqAward,
                    child: FilledButton(
                      onPressed: () => context.push('/admin/rfqs/$rfqId/award?quoteId=${quote.id}&vendorId=${quote.vendorId}'),
                      child: const Text('Award to this vendor'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class RFQAwardScreen extends ConsumerWidget {
  const RFQAwardScreen({super.key, required this.rfqId, required this.quoteId, required this.vendorId});

  final String rfqId;
  final String quoteId;
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      permission: Permission.rfqAward,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Award RFQ')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Award this quote, reject the others, and create a draft purchase order.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ref.read(rfqRepositoryProvider).awardRFQ(rfqId, vendorId, quoteId);
                  await ref.read(purchaseOrderRepositoryProvider).createFromVendorQuote(quoteId);
                  ref.invalidate(rfqByIdProvider(rfqId));
                  ref.invalidate(purchaseOrdersProvider);
                  if (context.mounted) context.go('/admin/purchase-orders');
                },
                child: const Text('Confirm award'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
