import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../gst_audit/presentation/providers/compliance_providers.dart';
import '../../../gst_audit/presentation/widgets/compliance_widgets.dart';
import '../../../invoices/presentation/providers/finance_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/e_way_bill.dart';

class EWayBillListScreen extends ConsumerWidget {
  const EWayBillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(eWayBillsProvider(null));
    return PermissionGate(
      permission: Permission.eWayBillView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('E-way bills')),
        floatingActionButton: FloatingActionButton(onPressed: () => context.push('/admin/e-way-bills/new'), child: const Icon(Icons.add)),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.ewayBillNumber ?? item.invoiceNumber),
                  subtitle: Text('${item.fromPlace} → ${item.toPlace} · valid ${item.validUntil == null ? '—' : formatDisplayDate(item.validUntil!)}'),
                  trailing: StatusChip(label: item.displayStatus.label),
                  onTap: () => context.push('/admin/e-way-bills/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EWayBillDetailScreen extends ConsumerWidget {
  const EWayBillDetailScreen({super.key, required this.ewayBillId});

  final String ewayBillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(eWayBillByIdProvider(ewayBillId));
    return Scaffold(
      appBar: AppBar(title: const Text('E-way bill')),
      body: row.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.ewayBillNumber ?? 'Pending number', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            StatusChip(label: item.displayStatus.label),
            Text('Part A · ${item.invoiceNumber} · ${formatMoney(item.totalValue)} · HSN ${item.hsnCode}'),
            Text('${item.fromPlace} (${item.fromGstin}) → ${item.toPlace} (${item.toGstin ?? 'URP'})'),
            Text('Part B · ${item.vehicleNumber ?? 'No vehicle'} · ${item.distance ?? 0} km'),
            if (item.validUntil != null) Text('Valid until ${formatDisplayDate(item.validUntil!)}'),
            OutlinedButton(onPressed: () => context.push('/admin/e-way-bills/${item.id}/part-b'), child: const Text('Update Part B')),
            if (item.status == EWayBillStatus.generated)
              FilledButton(
                onPressed: () async {
                  await ref.read(eWayBillRepositoryProvider).cancelEWayBill(item.id, 'Cancelled from CRM');
                  ref.invalidate(eWayBillByIdProvider(ewayBillId));
                },
                child: const Text('Cancel (24 hours)'),
              ),
            OutlinedButton(
              onPressed: () async {
                await ref.read(eWayBillRepositoryProvider).extendEWayBill(item.id, 200);
                ref.invalidate(eWayBillByIdProvider(ewayBillId));
              },
              child: const Text('Extend by 200 km'),
            ),
          ],
        ),
      ),
    );
  }
}

class EWayBillFormScreen extends ConsumerStatefulWidget {
  const EWayBillFormScreen({super.key});

  @override
  ConsumerState<EWayBillFormScreen> createState() => _EWayBillFormScreenState();
}

class _EWayBillFormScreenState extends ConsumerState<EWayBillFormScreen> {
  final _invoice = TextEditingController();
  final _toPlace = TextEditingController();
  final _toPin = TextEditingController();
  final _hsn = TextEditingController(text: '9983');
  final _value = TextEditingController();
  final _distance = TextEditingController(text: '200');
  bool _busy = false;

  @override
  void dispose() {
    _invoice.dispose();
    _toPlace.dispose();
    _toPin.dispose();
    _hsn.dispose();
    _value.dispose();
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gstSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New e-way bill')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (gst) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _invoice, decoration: const InputDecoration(labelText: 'Invoice number')),
            TextField(controller: _toPlace, decoration: const InputDecoration(labelText: 'To place')),
            TextField(controller: _toPin, decoration: const InputDecoration(labelText: 'To pincode')),
            TextField(controller: _hsn, decoration: const InputDecoration(labelText: 'HSN')),
            TextField(controller: _value, decoration: const InputDecoration(labelText: 'Consignment value'), keyboardType: TextInputType.number),
            TextField(controller: _distance, decoration: const InputDecoration(labelText: 'Distance (km)'), keyboardType: TextInputType.number),
            const Text('Mandatory above ₹50,000. Job work is always required for inter-state movement.'),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final created = await ref.read(eWayBillRepositoryProvider).generateEWayBill(
                            invoiceNumber: _invoice.text.trim(),
                            invoiceDate: DateTime.now(),
                            supplyType: EwbSupplyType.outward,
                            subSupplyType: EwbSubSupplyType.supply,
                            documentType: EwbDocumentType.taxInvoice,
                            fromGstin: gst.firmGstin ?? '',
                            fromAddress: gst.firmAddress,
                            fromPlace: gst.firmCity,
                            fromPincode: gst.firmPincode,
                            fromStateCode: gst.firmStateCode,
                            fromTradeName: gst.firmName,
                            toAddress: _toPlace.text.trim(),
                            toPlace: _toPlace.text.trim(),
                            toPincode: _toPin.text.trim(),
                            toStateCode: gst.firmStateCode,
                            totalValue: double.tryParse(_value.text) ?? 0,
                            taxableValue: double.tryParse(_value.text) ?? 0,
                            hsnCode: _hsn.text.trim(),
                            distance: int.tryParse(_distance.text),
                          );
                      if (!context.mounted) return;
                      if (created.dataOrNull == null && created.isSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Below ₹50,000 — e-way bill not required')));
                      }
                      if (!context.mounted) return;
                      context.pop();
                    },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}

class EWayBillPartBScreen extends ConsumerStatefulWidget {
  const EWayBillPartBScreen({super.key, required this.ewayBillId});

  final String ewayBillId;

  @override
  ConsumerState<EWayBillPartBScreen> createState() => _EWayBillPartBScreenState();
}

class _EWayBillPartBScreenState extends ConsumerState<EWayBillPartBScreen> {
  final _vehicle = TextEditingController();
  final _transporter = TextEditingController();
  final _distance = TextEditingController();

  @override
  void dispose() {
    _vehicle.dispose();
    _transporter.dispose();
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Part B')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _vehicle, decoration: const InputDecoration(labelText: 'Vehicle number')),
          TextField(controller: _transporter, decoration: const InputDecoration(labelText: 'Transporter ID')),
          TextField(controller: _distance, decoration: const InputDecoration(labelText: 'Distance (km)'), keyboardType: TextInputType.number),
          FilledButton(
            onPressed: () async {
              await ref.read(eWayBillRepositoryProvider).updatePartB(
                    widget.ewayBillId,
                    _vehicle.text.trim(),
                    _transporter.text.trim(),
                    int.tryParse(_distance.text) ?? 0,
                  );
              if (!context.mounted) return;
              context.pop();
            },
            child: const Text('Save Part B'),
          ),
        ],
      ),
    );
  }
}
