import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../catalog/domain/storage_repository.dart';
import '../../../gst/domain/gst_math.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/compliance_math.dart';
import '../../domain/gstr9_return.dart';
import '../../domain/itc_ledger_entry.dart';
import '../../domain/itc_reversal.dart';
import '../providers/compliance_providers.dart';
import '../widgets/compliance_widgets.dart';

class AuditDashboardScreen extends ConsumerWidget {
  const AuditDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final period = gstPeriodFromDate(DateTime.now());
    final itc = ref.watch(itcSummaryProvider((fy: fy, period: period)));
    final tds = ref.watch(tdsSummaryProvider((fy: fy, quarter: gstQuarterFromDate(DateTime.now()))));
    final eInvoices = ref.watch(eInvoicesProvider(null));
    final ewb = ref.watch(eWayBillsProvider(null));
    return PermissionGate(
      permission: Permission.auditDashboardView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('GST audit')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(itcSummaryProvider);
            ref.invalidate(tdsSummaryProvider);
            ref.invalidate(eInvoicesProvider);
            ref.invalidate(eWayBillsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  itc.when(
                    loading: () => const ComplianceSummaryCard(label: 'ITC available', value: '…'),
                    error: (error, _) => ComplianceSummaryCard(label: 'ITC', value: '$error'),
                    data: (item) => ComplianceSummaryCard(
                      label: 'ITC available',
                      value: formatMoney(item.eligible),
                      onTap: () => context.push('/admin/audit/itc-ledger'),
                    ),
                  ),
                  itc.maybeWhen(
                    data: (item) => ComplianceSummaryCard(label: 'ITC claimed', value: formatMoney(item.claimed)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  itc.maybeWhen(
                    data: (item) => ComplianceSummaryCard(label: 'ITC reversed', value: formatMoney(item.reversed), onTap: () => context.push('/admin/audit/itc-reversals')),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  itc.maybeWhen(
                    data: (item) => ComplianceSummaryCard(label: 'Pending ITC', value: formatMoney(item.pending)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  tds.maybeWhen(
                    data: (item) => ComplianceSummaryCard(label: 'TDS deducted', value: formatMoney(item.tds), onTap: () => context.push('/admin/tds')),
                    orElse: () => const ComplianceSummaryCard(label: 'TDS deducted', value: '…'),
                  ),
                  eInvoices.maybeWhen(
                    data: (rows) => ComplianceSummaryCard(label: 'E-invoices this month', value: '${rows.where((item) => gstPeriodFromDate(item.invoiceDate) == period).length}', onTap: () => context.push('/admin/e-invoices')),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  ewb.maybeWhen(
                    data: (rows) => ComplianceSummaryCard(label: 'E-way bills this month', value: '${rows.where((item) => gstPeriodFromDate(item.invoiceDate) == period).length}', onTap: () => context.push('/admin/e-way-bills')),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: () => context.push('/admin/audit/gstr2b'), child: const Text('Import GSTR-2B')),
                  OutlinedButton(onPressed: () => context.push('/admin/audit/itc-ledger'), child: const Text('Reconcile ITC')),
                  OutlinedButton(onPressed: () => context.push('/admin/audit/gstr9'), child: const Text('Prepare GSTR-9')),
                  OutlinedButton(onPressed: () => context.push('/admin/e-invoices'), child: const Text('Generate e-invoice')),
                  OutlinedButton(onPressed: () => context.push('/admin/e-way-bills/new'), child: const Text('Generate e-way bill')),
                  OutlinedButton(onPressed: () => context.push('/admin/audit/compliance-report'), child: const Text('Compliance report')),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compliance calendar'),
                subtitle: const Text('GSTR-1, GSTR-3B, TDS, GSTR-9 due dates'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/audit/compliance-calendar'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Budgets and forecasts'),
                onTap: () => context.push('/admin/forecasts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ITCLedgerScreen extends ConsumerWidget {
  const ITCLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final rows = ref.watch(itcLedgerProvider(ItcQuery(financialYear: fy)));
    final summary = ref.watch(itcSummaryProvider((fy: fy, period: gstPeriodFromDate(DateTime.now()))));
    return PermissionGate(
      permission: Permission.itcLedgerView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ITC ledger'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final csv = await ref.read(itcRepositoryProvider).exportITCLedgerToCsv(financialYear: fy);
                final text = csv.dataOrNull;
                if (text != null) await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied')));
              },
            ),
          ],
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
                  ComplianceSummaryCard(label: 'Eligible', value: formatMoney(item.eligible)),
                  ComplianceSummaryCard(label: 'Claimed', value: formatMoney(item.claimed)),
                  ComplianceSummaryCard(label: 'Reversed', value: formatMoney(item.reversed)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('${item.supplierName} · ${item.invoiceNumber}'),
                      subtitle: Wrap(spacing: 8, children: [ItcStatusBadge(status: item.itcStatus), MatchStatusBadge(status: item.matchStatus)]),
                      trailing: MoneyText(item.itcEligible),
                      onTap: () => context.push('/admin/audit/itc-ledger/${item.id}'),
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

class ITCEntryDetailScreen extends ConsumerWidget {
  const ITCEntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(itcEntryByIdProvider(entryId));
    return Scaffold(
      appBar: AppBar(title: const Text('ITC entry')),
      body: entry.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.supplierName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${item.supplierGstin} · ${item.invoiceNumber}'),
            Text(formatDisplayDate(item.invoiceDate)),
            const SizedBox(height: 12),
            Text('Taxable ${formatMoney(item.taxableValue)}'),
            Text('CGST ${formatMoney(item.cgstAmount)}  SGST ${formatMoney(item.sgstAmount)}  IGST ${formatMoney(item.igstAmount)}'),
            ItcStatusBadge(status: item.itcStatus),
            MatchStatusBadge(status: item.matchStatus),
            if (item.mismatchReason != null) Text(item.mismatchReason!),
            const SizedBox(height: 16),
            if (item.itcStatus == ITCStatus.pending || item.itcStatus == ITCStatus.eligible)
              FilledButton(
                onPressed: () async {
                  await ref.read(itcRepositoryProvider).markITCClaimed(item.id, item.itcEligible, item.period);
                  ref.invalidate(itcEntryByIdProvider(entryId));
                },
                child: const Text('Mark as claimed'),
              ),
            if (item.itcStatus != ITCStatus.reversed)
              OutlinedButton(
                onPressed: () => context.push('/admin/audit/itc-reversals/new?itcId=${item.id}'),
                child: const Text('Mark as reversed'),
              ),
            if (item.matchStatus == MatchStatus.mismatched || item.matchStatus == MatchStatus.suggestedMatch)
              OutlinedButton(
                onPressed: () async {
                  await ref.read(gstr2bRepositoryProvider).resolveMismatch(item.id, MatchStatus.matched, 'Manual accept');
                  ref.invalidate(itcEntryByIdProvider(entryId));
                },
                child: const Text('Resolve mismatch'),
              ),
          ],
        ),
      ),
    );
  }
}

class ITCReversalScreen extends ConsumerWidget {
  const ITCReversalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(itcReversalsProvider(ItcQuery(financialYear: currentFinancialYear())));
    return Scaffold(
      appBar: AppBar(title: const Text('ITC reversals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/audit/itc-reversals/new'),
        child: const Icon(Icons.add),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text('${item.invoiceNumber} · ${item.reversalReason.label}'),
                subtitle: Text(item.status.label),
                trailing: MoneyText(item.reversalAmount),
              ),
          ],
        ),
      ),
    );
  }
}

class ITCReversalFormScreen extends ConsumerStatefulWidget {
  const ITCReversalFormScreen({super.key, this.itcId});

  final String? itcId;

  @override
  ConsumerState<ITCReversalFormScreen> createState() => _ITCReversalFormScreenState();
}

class _ITCReversalFormScreenState extends ConsumerState<ITCReversalFormScreen> {
  final _amount = TextEditingController();
  ReversalReason _reason = ReversalReason.rule37;
  bool _interest = false;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(itcLedgerProvider(ItcQuery(financialYear: currentFinancialYear())));
    return Scaffold(
      appBar: AppBar(title: const Text('New ITC reversal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ledger.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (items) => DropdownButtonFormField<String>(
              initialValue: widget.itcId ?? (items.isEmpty ? null : items.first.id),
              items: [for (final item in items) DropdownMenuItem(value: item.id, child: Text('${item.invoiceNumber} · ${item.supplierName}'))],
              onChanged: (_) {},
              decoration: const InputDecoration(labelText: 'ITC entry'),
            ),
          ),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Reversal amount'), keyboardType: TextInputType.number),
          DropdownButtonFormField<ReversalReason>(
            initialValue: _reason,
            items: [for (final reason in ReversalReason.values) DropdownMenuItem(value: reason, child: Text(reason.label))],
            onChanged: (value) => setState(() => _reason = value ?? _reason),
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          SwitchListTile(value: _interest, onChanged: (value) => setState(() => _interest = value), title: const Text('Interest applicable')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final selected = widget.itcId ?? ledger.valueOrNull?.firstOrNull?.id;
                    if (selected == null) return;
                    setState(() => _busy = true);
                    final entry = await ref.read(itcRepositoryProvider).getITCEntryById(selected);
                    final item = entry.dataOrNull;
                    if (item == null) {
                      if (mounted) setState(() => _busy = false);
                      return;
                    }
                    await ref.read(itcReversalRepositoryProvider).createITCReversal(
                          itcLedgerId: item.id,
                          supplierGstin: item.supplierGstin,
                          invoiceNumber: item.invoiceNumber,
                          reversalAmount: double.tryParse(_amount.text) ?? 0,
                          reversalReason: _reason,
                          interestApplicable: _interest,
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

class GSTR2BImportScreen extends ConsumerWidget {
  const GSTR2BImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(gstr2bImportsProvider(ItcQuery(financialYear: currentFinancialYear())));
    return Scaffold(
      appBar: AppBar(title: const Text('GSTR-2B imports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final picked = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: const ['json']);
          final file = picked?.files.firstOrNull;
          if (file?.bytes == null) return;
          final now = DateTime.now();
          await ref.read(gstr2bRepositoryProvider).importGSTR2B(
                financialYear: financialYearLabel(now),
                period: gstPeriodFromDate(now),
                jsonFile: UploadBytes(bytes: file!.bytes!, filename: file.name),
              );
          ref.invalidate(gstr2bImportsProvider);
          ref.invalidate(itcLedgerProvider);
        },
        label: const Text('Import JSON'),
        icon: const Icon(Icons.upload_file),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text('${item.period} · ${item.fileName}'),
                subtitle: Text('${item.totalRecords} records · ${item.status.label}'),
                trailing: MoneyText(item.totalTaxableValue),
                onTap: () => context.push('/admin/audit/gstr2b/${item.id}/reconciliation'),
              ),
          ],
        ),
      ),
    );
  }
}

class GSTR2BReconciliationScreen extends ConsumerWidget {
  const GSTR2BReconciliationScreen({super.key, required this.importId});

  final String importId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(reconciliationResultProvider(importId));
    final rows = ref.watch(itcLedgerProvider(const ItcQuery()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('GSTR-2B reconciliation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final csv = await ref.read(gstr2bRepositoryProvider).exportReconciliationReport(importId);
              if (csv.dataOrNull != null) await Clipboard.setData(ClipboardData(text: csv.dataOrNull!));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          result.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (item) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ComplianceSummaryCard(label: 'Processed', value: '${item.totalProcessed}'),
                ComplianceSummaryCard(label: 'Exact', value: '${item.exactMatches}'),
                ComplianceSummaryCard(label: 'Suggested', value: '${item.suggestedMatches}'),
                ComplianceSummaryCard(label: 'Mismatched', value: '${item.mismatched}'),
                ComplianceSummaryCard(label: 'Missing in 2B', value: '${item.missingIn2b}'),
                ComplianceSummaryCard(label: 'Missing in books', value: '${item.missingInBooks}'),
                ComplianceSummaryCard(label: 'Match %', value: item.matchPercentage.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          rows.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) => Column(
              children: [
                for (final item in items.where((row) => row.gstr2bId == importId))
                  ListTile(
                    title: Text('${item.supplierName} · ${item.invoiceNumber}'),
                    subtitle: MatchStatusBadge(status: item.matchStatus),
                    trailing: MoneyText(item.taxableValue),
                    onTap: () => context.push('/admin/audit/itc-ledger/${item.id}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GSTR9PreparationScreen extends ConsumerWidget {
  const GSTR9PreparationScreen({super.key, this.returnId});

  final String? returnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final list = ref.watch(gstr9ReturnsProvider(fy));
    return Scaffold(
      appBar: AppBar(title: const Text('GSTR-9')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ref.read(gstr9RepositoryProvider).prepareGSTR9(fy);
          ref.invalidate(gstr9ReturnsProvider);
        },
        label: const Text('Prepare return'),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          final item = returnId == null ? items.firstOrNull : items.cast<GSTR9Return?>().firstWhere((row) => row?.id == returnId, orElse: () => items.firstOrNull);
          if (item == null) return const Center(child: Text('Prepare a GSTR-9 draft for this year'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${item.legalName} · ${item.gstin}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(item.financialYear),
              StatusChip(label: item.status.label),
              const SizedBox(height: 12),
              Text('Part II taxable ${formatMoney(item.totalTaxableValue)}'),
              Text('CGST ${formatMoney(item.totalCgst)}  SGST ${formatMoney(item.totalSgst)}  IGST ${formatMoney(item.totalIgst)}'),
              Text('ITC claimed ${formatMoney(item.totalItcClaimed)} · reversed ${formatMoney(item.totalItcReversed)}'),
              Text('Net tax ${formatMoney(item.netTaxPayable)}'),
              const SizedBox(height: 16),
              if (item.status != GSTR9Status.filed)
                FilledButton(
                  onPressed: () async {
                    await ref.read(gstr9RepositoryProvider).fileGSTR9(item.id, 'ACK-${item.financialYear}');
                    ref.invalidate(gstr9ReturnsProvider);
                  },
                  child: const Text('File GSTR-9'),
                ),
              OutlinedButton(
                onPressed: () async {
                  final json = await ref.read(gstr9RepositoryProvider).exportGSTR9(item.id);
                  if (json.dataOrNull != null) await Clipboard.setData(ClipboardData(text: json.dataOrNull!));
                },
                child: const Text('Export JSON'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GSTR9CPreparationScreen extends ConsumerWidget {
  const GSTR9CPreparationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final rows = ref.watch(gstr9cProvider(fy));
    final gstr9 = ref.watch(gstr9ReturnsProvider(fy));
    return Scaffold(
      appBar: AppBar(title: const Text('GSTR-9C')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final source = gstr9.valueOrNull?.firstOrNull;
          if (source == null) return;
          await ref.read(gstr9cRepositoryProvider).prepareGSTR9C(source.id);
          ref.invalidate(gstr9cProvider);
        },
        label: const Text('Prepare from GSTR-9'),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items) ...[
              Text(item.financialYear, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Turnover audited ${formatMoney(item.turnoverAsPerAudited)} vs returns ${formatMoney(item.turnoverAsPerReturns)}'),
              Text('Difference ${formatMoney(item.difference)}'),
              Text('ITC difference ${formatMoney(item.itcDifference)}'),
              StatusChip(label: item.status.label),
              if (item.status != GSTR9CStatus.selfCertified && item.status != GSTR9CStatus.filed)
                FilledButton(
                  onPressed: () async {
                    await ref.read(gstr9cRepositoryProvider).selfCertifyGSTR9C(item.id);
                    ref.invalidate(gstr9cProvider);
                  },
                  child: const Text('Self-certify'),
                ),
              if (item.status == GSTR9CStatus.selfCertified)
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(gstr9cRepositoryProvider).fileGSTR9C(item.id);
                    ref.invalidate(gstr9cProvider);
                  },
                  child: const Text('File GSTR-9C'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ComplianceCalendarScreen extends StatelessWidget {
  const ComplianceCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dues = complianceDuesForMonth(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Compliance calendar')),
      body: ListView(
        children: [
          for (final due in dues)
            ListTile(
              title: Text(due.label),
              subtitle: Text(formatDisplayDate(due.date)),
              leading: Icon(
                Icons.event,
                color: due.date.isBefore(DateTime.now()) ? Colors.red : Colors.teal,
              ),
            ),
        ],
      ),
    );
  }
}

class ComplianceReportScreen extends ConsumerWidget {
  const ComplianceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fy = currentFinancialYear();
    final itc = ref.watch(itcSummaryProvider((fy: fy, period: gstPeriodFromDate(DateTime.now()))));
    final tds = ref.watch(tdsSummaryProvider((fy: fy, quarter: gstQuarterFromDate(DateTime.now()))));
    final einv = ref.watch(eInvoicesProvider(null));
    final ewb = ref.watch(eWayBillsProvider(null));
    return PermissionGate(
      permission: Permission.complianceReportView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Compliance report')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Financial year $fy', style: const TextStyle(fontWeight: FontWeight.w700)),
            itc.maybeWhen(data: (item) => Text('ITC eligible ${formatMoney(item.eligible)}, claimed ${formatMoney(item.claimed)}'), orElse: () => const SizedBox.shrink()),
            tds.maybeWhen(data: (item) => Text('TDS ${formatMoney(item.tds)} on ${formatMoney(item.gross)}'), orElse: () => const SizedBox.shrink()),
            einv.maybeWhen(data: (rows) => Text('E-invoices ${rows.length}'), orElse: () => const SizedBox.shrink()),
            ewb.maybeWhen(data: (rows) => Text('E-way bills ${rows.length}'), orElse: () => const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
