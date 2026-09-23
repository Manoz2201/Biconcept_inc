import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../../../vendors/domain/line_items.dart';
import '../../../../vendors/presentation/providers/vendors_provider.dart';
import '../../../domain/rfq.dart';
import '../../../domain/vendor_quote.dart';

class VendorRFQListScreen extends ConsumerWidget {
  const VendorRFQListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final rfqs = ref.watch(rfqsProvider(const RfqQuery())).valueOrNull ?? const [];
    final mine = [
      for (final rfq in rfqs)
        if (vendor != null)
          if ((ref.watch(rfqRecipientsProvider(rfq.id)).valueOrNull ?? const []).any((item) => item.vendorId == vendor.id))
            rfq,
    ];
    return PortalPageScaffold(
      title: 'rfqs',
      subtitle: 'Invites waiting for your quotation.',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in mine)
            ListTile(
              title: Text('${item.rfqNumber} · ${item.title}'),
              subtitle: Text('${item.status.label} · ${formatDisplayDate(item.dueDate)}'),
              onTap: () => context.push('/vendor/rfqs/${item.id}'),
            ),
        ],
      ),
    );
  }
}

class VendorRFQDetailScreen extends ConsumerWidget {
  const VendorRFQDetailScreen({super.key, required this.rfqId});

  final String rfqId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rfq = ref.watch(rfqByIdProvider(rfqId)).valueOrNull;
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final quotes = vendor == null
        ? const <VendorQuote>[]
        : (ref.watch(vendorQuotesProvider(rfqId)).valueOrNull ?? const []).where((item) => item.vendorId == vendor.id).toList();
    if (rfq == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(rfq.rfqNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(rfq.title, style: Theme.of(context).textTheme.titleLarge),
          Text(rfq.description),
          for (final item in rfq.items) ListTile(title: Text(item.itemName), subtitle: Text('${item.quantity} ${item.unit}')),
          if (quotes.isNotEmpty)
            Text('Your quote ${quotes.first.quoteNumber} · ${quotes.first.status.label} · ${formatMoney(quotes.first.total)}'),
          if (rfq.status.isOpen || rfq.status == RFQStatus.sent)
            FilledButton(
              onPressed: () => context.push('/vendor/rfqs/$rfqId/quote'),
              child: const Text('Submit quote'),
            ),
        ],
      ),
    );
  }
}

class VendorQuoteFormScreen extends ConsumerStatefulWidget {
  const VendorQuoteFormScreen({super.key, required this.rfqId});

  final String rfqId;

  @override
  ConsumerState<VendorQuoteFormScreen> createState() => _VendorQuoteFormScreenState();
}

class _VendorQuoteFormScreenState extends ConsumerState<VendorQuoteFormScreen> {
  final _rates = <int, TextEditingController>{};
  final _days = TextEditingController(text: '14');
  final _notes = TextEditingController();
  final _tax = 18.0;
  final _valid = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    for (final controller in _rates.values) {
      controller.dispose();
    }
    _days.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfq = ref.watch(rfqByIdProvider(widget.rfqId)).valueOrNull;
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    if (rfq == null || vendor == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final items = [
      for (var i = 0; i < rfq.items.length; i++)
        PricedLine.fromCatalog(rfq.items[i], double.tryParse(_rates.putIfAbsent(i, () => TextEditingController()).text) ?? 0),
    ];
    final totals = pricedTotals([for (final item in items) (quantity: item.quantity, rate: item.rate)], _tax);
    return Scaffold(
      appBar: AppBar(title: const Text('Quote')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < rfq.items.length; i++)
            ListTile(
              title: Text(rfq.items[i].itemName),
              subtitle: Text('${rfq.items[i].quantity} ${rfq.items[i].unit}'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  controller: _rates[i],
                  decoration: const InputDecoration(labelText: 'Rate'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          Text('Subtotal ${formatMoney(totals.subtotal)}'),
          Text('GST ${formatMoney(totals.taxAmount)}'),
          Text('Total ${formatMoney(totals.total)}'),
          TextField(controller: _days, decoration: const InputDecoration(labelText: 'Delivery days')),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
          FilledButton(
            onPressed: () async {
              final created = await ref.read(vendorQuoteRepositoryProvider).createVendorQuote(
                    rfqId: widget.rfqId,
                    vendorId: vendor.id,
                    items: items,
                    taxRate: _tax,
                    validUntil: _valid,
                    deliveryDays: int.tryParse(_days.text),
                    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                  );
              await created.when(
                success: (quote) => ref.read(vendorQuoteRepositoryProvider).submitVendorQuote(quote.id),
                failure: (error) async {},
              );
              ref.invalidate(vendorQuotesProvider(widget.rfqId));
              if (context.mounted) context.pop();
            },
            child: const Text('Submit quote'),
          ),
        ],
      ),
    );
  }
}
