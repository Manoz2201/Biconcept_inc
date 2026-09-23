import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../currency/domain/money.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../platform/presentation/widgets/platform_widgets.dart';
import '../../../rbac/domain/permission.dart';
import '../../../vendor_bills/domain/vendor_bill.dart';
import '../../../vendors/presentation/providers/vendors_provider.dart';
import '../../domain/payment_schedule.dart';

class PaymentScheduleListScreen extends ConsumerStatefulWidget {
  const PaymentScheduleListScreen({super.key});

  @override
  ConsumerState<PaymentScheduleListScreen> createState() => _PaymentScheduleListScreenState();
}

class _PaymentScheduleListScreenState extends ConsumerState<PaymentScheduleListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _filters = [null, PaymentScheduleStatus.draft, PaymentScheduleStatus.pendingApproval, PaymentScheduleStatus.approved, PaymentScheduleStatus.scheduled, PaymentScheduleStatus.completed, PaymentScheduleStatus.failed];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(paymentSchedulesProvider(ScheduleQuery(status: _filters[_tabs.index])));
    final currencies = ref.watch(currenciesProvider(true)).asData?.value ?? const [];
    return PermissionGate(
      permission: Permission.paymentScheduleView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment schedules'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Draft'),
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Completed'),
              Tab(text: 'Failed'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => context.push('/admin/payment-schedules/approval'), child: const Text('Approvals')),
            TextButton(onPressed: () => context.push('/admin/payment-schedules/batch'), child: const Text('Batch')),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.paymentScheduleCreate,
          child: FloatingActionButton(onPressed: () => context.push('/admin/payment-schedules/new'), child: const Icon(Icons.add)),
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text('${item.scheduleNumber} · ${item.currencyCode}'),
                  subtitle: Text('${item.scheduledDate.toLocal().toString().split(' ').first} · ${item.priority}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(item, currencies)),
                      ScheduleStatusBadge(status: item.status),
                    ],
                  ),
                  onTap: () => context.push('/admin/payment-schedules/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(PaymentSchedule item, List currencies) {
  for (final currency in currencies) {
    if (currency.code == item.currencyCode) return Money(item.totalAmount, currency).format();
  }
  return '${item.currencyCode} ${item.totalAmount.toStringAsFixed(2)}';
}

class PaymentScheduleDetailScreen extends ConsumerWidget {
  const PaymentScheduleDetailScreen({super.key, required this.scheduleId});

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(paymentScheduleByIdProvider(scheduleId));
    final currencies = ref.watch(currenciesProvider(true)).asData?.value ?? const [];
    return PermissionGate(
      permission: Permission.paymentScheduleView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Payment schedule')),
        body: row.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.scheduleNumber, style: Theme.of(context).textTheme.titleLarge),
              ScheduleStatusBadge(status: item.status),
              Text(_money(item, currencies)),
              Text('${item.paymentMethod} · ${item.scheduledDate.toLocal()}'),
              Text('Bills: ${item.billIds.join(', ')}'),
              if (item.notes != null) Text(item.notes!),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.status == PaymentScheduleStatus.draft)
                    FilledButton(
                      onPressed: () async {
                        await ref.read(paymentScheduleRepositoryProvider).submitForApproval(item.id);
                        ref.invalidate(paymentScheduleByIdProvider(scheduleId));
                      },
                      child: const Text('Submit for approval'),
                    ),
                  if (item.status == PaymentScheduleStatus.pendingApproval)
                    PermissionGate(
                      permission: Permission.paymentScheduleApprove,
                      child: FilledButton(
                        onPressed: () async {
                          final ok = await confirmPhrase(context, title: 'Approve schedule', phrase: 'APPROVE');
                          if (!ok) return;
                          final userId = ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';
                          await ref.read(paymentScheduleRepositoryProvider).approvePaymentSchedule(item.id, userId);
                          ref.invalidate(paymentScheduleByIdProvider(scheduleId));
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                  if (item.status == PaymentScheduleStatus.pendingApproval)
                    PermissionGate(
                      permission: Permission.paymentScheduleApprove,
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref.read(paymentScheduleRepositoryProvider).rejectPaymentSchedule(item.id, 'Rejected');
                          ref.invalidate(paymentScheduleByIdProvider(scheduleId));
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                  if (item.status == PaymentScheduleStatus.approved)
                    FilledButton(
                      onPressed: () async {
                        await ref.read(paymentScheduleRepositoryProvider).schedulePayment(item.id);
                        ref.invalidate(paymentScheduleByIdProvider(scheduleId));
                      },
                      child: const Text('Schedule'),
                    ),
                  if (item.status == PaymentScheduleStatus.scheduled || item.status == PaymentScheduleStatus.approved)
                    PermissionGate(
                      permission: Permission.paymentScheduleProcess,
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(paymentScheduleRepositoryProvider).processPayment(item.id);
                          ref.invalidate(paymentScheduleByIdProvider(scheduleId));
                        },
                        child: const Text('Process now'),
                      ),
                    ),
                  if (item.status.canCancel)
                    TextButton(
                      onPressed: () async {
                        await ref.read(paymentScheduleRepositoryProvider).cancelPaymentSchedule(item.id, 'Cancelled');
                        ref.invalidate(paymentScheduleByIdProvider(scheduleId));
                      },
                      child: const Text('Cancel'),
                    ),
                  if (item.status == PaymentScheduleStatus.draft)
                    OutlinedButton(onPressed: () => context.push('/admin/payment-schedules/${item.id}/edit'), child: const Text('Edit')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentScheduleFormScreen extends ConsumerStatefulWidget {
  const PaymentScheduleFormScreen({super.key, this.scheduleId});

  final String? scheduleId;

  @override
  ConsumerState<PaymentScheduleFormScreen> createState() => _PaymentScheduleFormScreenState();
}

class _PaymentScheduleFormScreenState extends ConsumerState<PaymentScheduleFormScreen> {
  String? _vendorId;
  final _selected = <String>{};
  DateTime _date = DateTime.now().add(const Duration(days: 3));
  String _method = 'bank_transfer';
  String _priority = 'normal';
  final _notes = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorsProvider(const VendorQuery()));
    final bills = _vendorId == null ? null : ref.watch(unpaidVendorBillsProvider(_vendorId!));
    return PermissionGate(
      permission: Permission.paymentScheduleCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.scheduleId == null ? 'New schedule' : 'Edit schedule')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            vendors.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _vendorId,
                items: [for (final item in items) DropdownMenuItem(value: item.id, child: Text(item.companyName))],
                onChanged: (value) => setState(() {
                  _vendorId = value;
                  _selected.clear();
                }),
                decoration: const InputDecoration(labelText: 'Vendor'),
              ),
            ),
            if (bills != null)
              bills.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('$error'),
                data: (items) => Column(
                  children: [
                    for (final item in items.cast<VendorBill>())
                      CheckboxListTile(
                        value: _selected.contains(item.id),
                        title: Text(item.billNumber),
                        subtitle: Text('Due ${item.remaining.toStringAsFixed(2)}'),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(item.id);
                          } else {
                            _selected.remove(item.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ListTile(
              title: Text('Scheduled ${_date.toLocal().toString().split(' ').first}'),
              onTap: () async {
                final next = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _date);
                if (next != null) setState(() => _date = next);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _method,
              items: const [
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
              decoration: const InputDecoration(labelText: 'Payment method'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) => setState(() => _priority = value ?? _priority),
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _vendorId == null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final result = await ref.read(paymentScheduleRepositoryProvider).createPaymentSchedule(
                            vendorId: _vendorId!,
                            billIds: _selected.toList(),
                            scheduledDate: _date,
                            paymentMethod: _method,
                            priority: _priority,
                            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                          );
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      result.when(
                        success: (_) {
                          ref.invalidate(paymentSchedulesProvider);
                          context.pop();
                        },
                        failure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.userMessage))),
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

class PaymentScheduleApprovalScreen extends ConsumerWidget {
  const PaymentScheduleApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(paymentSchedulesProvider(const ScheduleQuery(status: PaymentScheduleStatus.pendingApproval)));
    return PermissionGate(
      permission: Permission.paymentScheduleApprove,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Approvals')),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.scheduleNumber),
                  subtitle: Text(item.createdBy),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final ok = await confirmPhrase(context, title: 'Approve', phrase: 'APPROVE');
                          if (!ok) return;
                          await ref.read(paymentScheduleRepositoryProvider).approvePaymentSchedule(item.id, ref.read(sessionControllerProvider).user?.accountId ?? 'unknown');
                          ref.invalidate(paymentSchedulesProvider);
                        },
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref.read(paymentScheduleRepositoryProvider).rejectPaymentSchedule(item.id, 'Rejected');
                          ref.invalidate(paymentSchedulesProvider);
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                  onTap: () => context.push('/admin/payment-schedules/${item.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BatchPaymentScreen extends ConsumerStatefulWidget {
  const BatchPaymentScreen({super.key});

  @override
  ConsumerState<BatchPaymentScreen> createState() => _BatchPaymentScreenState();
}

class _BatchPaymentScreenState extends ConsumerState<BatchPaymentScreen> {
  final _selected = <String>{};
  BatchPaymentSummary? _summary;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(paymentSchedulesProvider(const ScheduleQuery(status: PaymentScheduleStatus.scheduled)));
    return PermissionGate(
      permission: Permission.paymentScheduleProcess,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Batch payments')),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => ListView(
            children: [
              for (final item in items)
                CheckboxListTile(
                  value: _selected.contains(item.id),
                  title: Text(item.scheduleNumber),
                  subtitle: Text('${item.currencyCode} ${item.totalAmount}'),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.add(item.id);
                    } else {
                      _selected.remove(item.id);
                    }
                  }),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          final result = await ref.read(paymentScheduleRepositoryProvider).batchProcess(_selected.toList());
                          setState(() => _summary = result.dataOrNull);
                          ref.invalidate(paymentSchedulesProvider);
                        },
                  child: const Text('Process batch'),
                ),
              ),
              if (_summary != null)
                ListTile(title: Text('Succeeded ${_summary!.succeeded.length} · Failed ${_summary!.failed.length} · Pending ${_summary!.pending.length}')),
            ],
          ),
        ),
      ),
    );
  }
}

class UpcomingPaymentsWidget extends ConsumerWidget {
  const UpcomingPaymentsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(upcomingPaymentsProvider(7));
    return rows.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('$error'),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming payments'),
          for (final item in items)
            ListTile(
              title: Text(item.scheduleNumber),
              subtitle: Text(item.scheduledDate.toLocal().toString().split(' ').first),
              onTap: () => context.push('/admin/payment-schedules/${item.id}'),
            ),
        ],
      ),
    );
  }
}
