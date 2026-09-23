import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../gst_audit/domain/compliance_math.dart';
import '../../../gst_audit/presentation/providers/compliance_providers.dart';
import '../../../gst_audit/presentation/widgets/compliance_widgets.dart';
import '../../../rbac/domain/permission.dart';
import '../../../tds/data/tds_certificate_service.dart';
import '../../../vendors/presentation/providers/vendors_provider.dart';
import '../../domain/tds_deduction.dart';

class TDSDeductionScreen extends ConsumerWidget {
  const TDSDeductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final quarter = gstQuarterFromDate(DateTime.now());
    final rows = ref.watch(tdsDeductionsProvider(TdsQuery(financialYear: fy, quarter: quarter)));
    final summary = ref.watch(tdsSummaryProvider((fy: fy, quarter: quarter)));
    return PermissionGate(
      permission: Permission.tdsView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TDS'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final csv = await ref.read(tdsRepositoryProvider).exportTDSRegisterToCsv(financialYear: fy, quarter: quarter);
                if (csv.dataOrNull != null) await Clipboard.setData(ClipboardData(text: csv.dataOrNull!));
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/admin/tds/new'),
          child: const Icon(Icons.add),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summary.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (item) => Wrap(
                spacing: 8,
                children: [
                  ComplianceSummaryCard(label: 'Gross', value: formatMoney(item.gross)),
                  ComplianceSummaryCard(label: 'TDS', value: formatMoney(item.tds)),
                  ComplianceSummaryCard(label: 'Net', value: formatMoney(item.net)),
                ],
              ),
            ),
            rows.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('${item.deducteeName} · ${item.section.value}'),
                      subtitle: Text('${item.deducteePan} · ${item.status.label}'),
                      trailing: MoneyText(item.tdsAmount),
                      onTap: () => context.push('/admin/tds/${item.id}'),
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

class TDSFormScreen extends ConsumerStatefulWidget {
  const TDSFormScreen({super.key});

  @override
  ConsumerState<TDSFormScreen> createState() => _TDSFormScreenState();
}

class _TDSFormScreenState extends ConsumerState<TDSFormScreen> {
  final _name = TextEditingController();
  final _pan = TextEditingController();
  final _gross = TextEditingController();
  TdsSection _section = TdsSection.section194J;
  TdsDeducteeType _type = TdsDeducteeType.firm;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pan.dispose();
    _gross.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gross = double.tryParse(_gross.text) ?? 0;
    final preview = computeTds(section: _section, deducteeType: _type, grossAmount: gross);
    return Scaffold(
      appBar: AppBar(title: const Text('New TDS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<TdsSection>(
            initialValue: _section,
            items: [for (final item in TdsSection.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: (value) => setState(() => _section = value ?? _section),
            decoration: const InputDecoration(labelText: 'Section'),
          ),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Deductee name')),
          TextField(controller: _pan, decoration: const InputDecoration(labelText: 'PAN (ABCDE1234F)'), textCapitalization: TextCapitalization.characters),
          DropdownButtonFormField<TdsDeducteeType>(
            initialValue: _type,
            items: [for (final item in TdsDeducteeType.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: (value) => setState(() => _type = value ?? _type),
            decoration: const InputDecoration(labelText: 'Deductee type'),
          ),
          TextField(
            controller: _gross,
            decoration: const InputDecoration(labelText: 'Gross amount'),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text('Rate ${preview.rate}% · TDS ${formatMoney(preview.tdsAmount)} · Net ${formatMoney(preview.netPayable)}'),
          Text(preview.thresholdCrossed ? 'Threshold crossed' : 'Threshold not crossed — TDS stays 0'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final created = await ref.read(tdsRepositoryProvider).createTDSDeduction(
                          section: _section,
                          deducteeName: _name.text.trim(),
                          deducteePan: _pan.text.trim(),
                          deducteeType: _type,
                          invoiceDate: DateTime.now(),
                          grossAmount: gross,
                        );
                    if (!context.mounted) return;
                    if (created.isFailure) {
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created.errorOrNull?.userMessage ?? 'Could not save')));
                      return;
                    }
                    context.pop();
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class TDSDeductionDetailScreen extends ConsumerWidget {
  const TDSDeductionDetailScreen({super.key, required this.deductionId});

  final String deductionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(tdsDeductionByIdProvider(deductionId));
    return Scaffold(
      appBar: AppBar(title: const Text('TDS deduction')),
      body: row.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.deducteeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${item.section.label} · ${item.deducteePan}'),
            Text('Gross ${formatMoney(item.grossAmount)} · TDS ${formatMoney(item.tdsAmount)}'),
            StatusChip(label: item.status.label),
            if (item.status == TDSStatus.pending)
              FilledButton(
                onPressed: () async {
                  await ref.read(tdsRepositoryProvider).markTDSDeducted(item.id);
                  ref.invalidate(tdsDeductionByIdProvider(deductionId));
                },
                child: const Text('Mark deducted'),
              ),
            if (item.status == TDSStatus.deducted)
              OutlinedButton(
                onPressed: () async {
                  await ref.read(tdsRepositoryProvider).depositTDS(item.id, 'CHLN-${item.id.substring(0, 6)}', DateTime.now());
                  ref.invalidate(tdsDeductionByIdProvider(deductionId));
                },
                child: const Text('Record challan'),
              ),
            if (item.status == TDSStatus.deposited || item.status == TDSStatus.certificateIssued)
              FilledButton(
                onPressed: () => context.push('/admin/tds/certificates?id=${item.id}'),
                child: const Text('Form 16A'),
              ),
          ],
        ),
      ),
    );
  }
}

class TDSCertificateScreen extends ConsumerWidget {
  const TDSCertificateScreen({super.key, this.deductionId});

  final String? deductionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(tdsDeductionsProvider(TdsQuery(financialYear: currentFinancialYear(), status: TDSStatus.deposited)));
    return Scaffold(
      appBar: AppBar(title: const Text('TDS certificates')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text(item.deducteeName),
                subtitle: Text(item.certificateNumber ?? 'Not issued'),
                trailing: TextButton(
                  onPressed: () async {
                    final pdf = await ref.read(tdsRepositoryProvider).generateTDSCertificate(item.id);
                    final bytes = pdf.dataOrNull;
                    if (bytes == null) return;
                    await TdsCertificateService().share(bytes, 'Form16A_${item.deducteeName}.pdf');
                  },
                  child: const Text('PDF'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TDSReturnScreen extends ConsumerWidget {
  const TDSReturnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final quarter = gstQuarterFromDate(DateTime.now());
    final summary = ref.watch(tdsSummaryProvider((fy: fy, quarter: quarter)));
    return Scaffold(
      appBar: AppBar(title: const Text('Form 26Q / GSTR-7')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('$fy $quarter', style: const TextStyle(fontWeight: FontWeight.w700)),
          summary.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (item) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Section-wise TDS'),
                for (final entry in item.bySection.entries) Text('${entry.key}: ${formatMoney(entry.value)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GSTTDSScreen extends ConsumerWidget {
  const GSTTDSScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(gstTdsProvider(ItcQuery(financialYear: currentFinancialYear())));
    return PermissionGate(
      permission: Permission.gstTdsView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('GST TDS')),
        floatingActionButton: FloatingActionButton(onPressed: () => context.push('/admin/gst-tds/new'), child: const Icon(Icons.add)),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text('${item.vendorGstin} · ${item.invoiceNumber}'),
                  subtitle: Text(item.status.label),
                  trailing: MoneyText(item.totalTds),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GSTTDSFormScreen extends ConsumerStatefulWidget {
  const GSTTDSFormScreen({super.key});

  @override
  ConsumerState<GSTTDSFormScreen> createState() => _GSTTDSFormScreenState();
}

class _GSTTDSFormScreenState extends ConsumerState<GSTTDSFormScreen> {
  final _invoice = TextEditingController();
  final _taxable = TextEditingController();
  final _contract = TextEditingController();
  String? _vendorId;
  bool _interState = false;
  bool _busy = false;

  @override
  void dispose() {
    _invoice.dispose();
    _taxable.dispose();
    _contract.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorsProvider(const VendorQuery()));
    final taxable = double.tryParse(_taxable.text) ?? 0;
    final contract = double.tryParse(_contract.text) ?? 0;
    final preview = computeGstTds(taxableValue: taxable, contractValue: contract, interState: _interState);
    return Scaffold(
      appBar: AppBar(title: const Text('New GST TDS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          vendors.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (items) => DropdownButtonFormField<String>(
              initialValue: _vendorId,
              items: [for (final item in items) DropdownMenuItem(value: item.id, child: Text('${item.companyName} · ${item.gstin ?? 'No GSTIN'}'))],
              onChanged: (value) => setState(() => _vendorId = value),
              decoration: const InputDecoration(labelText: 'Vendor'),
            ),
          ),
          TextField(controller: _invoice, decoration: const InputDecoration(labelText: 'Invoice number')),
          TextField(controller: _taxable, decoration: const InputDecoration(labelText: 'Taxable value'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
          TextField(controller: _contract, decoration: const InputDecoration(labelText: 'Contract value'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
          SwitchListTile(value: _interState, onChanged: (value) => setState(() => _interState = value), title: const Text('Inter-state')),
          Text(preview.applicable ? 'TDS ${formatMoney(preview.totalTds)} (CGST ${formatMoney(preview.cgstTds)} SGST ${formatMoney(preview.sgstTds)} IGST ${formatMoney(preview.igstTds)})' : 'Below ₹2,50,000 — GST TDS not applicable'),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final vendor = vendors.valueOrNull?.where((item) => item.id == _vendorId).firstOrNull;
                    if (vendor == null) return;
                    setState(() => _busy = true);
                    await ref.read(gstTdsRepositoryProvider).createGSTTDS(
                          vendorId: vendor.id,
                          vendorGstin: vendor.gstin ?? '',
                          invoiceNumber: _invoice.text.trim(),
                          invoiceDate: DateTime.now(),
                          taxableValue: taxable,
                          contractValue: contract,
                          interState: _interState,
                        );
                    if (!context.mounted) return;
                    context.pop();
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
