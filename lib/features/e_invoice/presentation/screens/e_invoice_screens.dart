import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../gst_audit/presentation/providers/compliance_providers.dart';
import '../../../gst_audit/presentation/widgets/compliance_widgets.dart';
import '../../../invoices/presentation/providers/finance_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/e_invoice.dart';

class EInvoiceListScreen extends ConsumerWidget {
  const EInvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(eInvoicesProvider(null));
    return PermissionGate(
      permission: Permission.eInvoiceView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('E-invoices'),
          actions: [
            IconButton(onPressed: () => context.push('/admin/e-invoices/settings'), icon: const Icon(Icons.settings)),
          ],
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ComplianceSummaryCard(label: 'Generated', value: '${items.where((item) => item.status == EInvoiceStatus.generated).length}'),
                    ComplianceSummaryCard(label: 'Failed', value: '${items.where((item) => item.status == EInvoiceStatus.failed).length}'),
                    ComplianceSummaryCard(label: 'Pending', value: '${items.where((item) => item.status == EInvoiceStatus.pending).length}'),
                  ],
                ),
              ),
              for (final item in items)
                ListTile(
                  title: Text(item.invoiceNumber),
                  subtitle: Text(item.irn == null ? item.status.label : '${item.irn!.substring(0, item.irn!.length.clamp(0, 12))}…'),
                  trailing: StatusChip(label: item.status.label, tone: item.status == EInvoiceStatus.generated ? Colors.green : Colors.orange),
                  onTap: () => context.push('/admin/e-invoices/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EInvoiceDetailScreen extends ConsumerWidget {
  const EInvoiceDetailScreen({super.key, required this.eInvoiceId});

  final String eInvoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(eInvoiceByIdProvider(eInvoiceId));
    return Scaffold(
      appBar: AppBar(title: const Text('E-invoice')),
      body: row.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.invoiceNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            StatusChip(label: item.status.label),
            if (item.irn != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('IRN'),
                subtitle: SelectableText(item.irn!),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: item.irn!)),
                ),
              ),
            if (item.ackNumber != null) Text('Ack ${item.ackNumber}'),
            if (item.errorMessage != null) Text(item.errorMessage!),
            if (item.status == EInvoiceStatus.generated)
              OutlinedButton(
                onPressed: () async {
                  await ref.read(eInvoiceRepositoryProvider).cancelIRN(item.id, '1', 'Cancelled from CRM');
                  ref.invalidate(eInvoiceByIdProvider(eInvoiceId));
                },
                child: const Text('Cancel IRN (24 hours)'),
              ),
            if (item.status == EInvoiceStatus.failed)
              FilledButton(
                onPressed: () async {
                  await ref.read(eInvoiceRepositoryProvider).retryIRNGeneration(item.id);
                  ref.invalidate(eInvoiceByIdProvider(eInvoiceId));
                },
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

class EInvoiceSettingsScreen extends ConsumerStatefulWidget {
  const EInvoiceSettingsScreen({super.key});

  @override
  ConsumerState<EInvoiceSettingsScreen> createState() => _EInvoiceSettingsScreenState();
}

class _EInvoiceSettingsScreenState extends ConsumerState<EInvoiceSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(irpSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('E-invoice settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'IRP Client ID, Client Secret, username, and password stay in the generate-einvoice-irn Function environment. They are never stored in this app.',
            ),
            SwitchListTile(
              value: item.autoGenerate,
              onChanged: (value) async {
                await ref.read(eInvoiceRepositoryProvider).saveIrpSettings(IrpSettings(environment: item.environment, autoGenerate: value));
                ref.invalidate(irpSettingsProvider);
              },
              title: const Text('Auto-generate IRN when an invoice is issued'),
            ),
            DropdownButtonFormField<String>(
              initialValue: item.environment,
              items: const [
                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')),
                DropdownMenuItem(value: 'production', child: Text('Production')),
              ],
              onChanged: (value) async {
                await ref.read(eInvoiceRepositoryProvider).saveIrpSettings(IrpSettings(environment: value ?? 'sandbox', autoGenerate: item.autoGenerate));
                ref.invalidate(irpSettingsProvider);
              },
              decoration: const InputDecoration(labelText: 'Function environment hint'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final invoices = await ref.read(invoicesProvider(const InvoiceQuery()).future);
                for (final invoice in invoices.where((row) => row.eInvoiceIrn == null && row.status.name != 'draft')) {
                  await ref.read(eInvoiceRepositoryProvider).generateIRN(invoice.id);
                }
                ref.invalidate(eInvoicesProvider);
              },
              child: const Text('Generate pending IRNs'),
            ),
          ],
        ),
      ),
    );
  }
}
