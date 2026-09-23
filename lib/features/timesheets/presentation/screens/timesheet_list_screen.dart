import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/timesheet.dart';
import '../providers/timesheets_provider.dart';

class TimesheetListScreen extends ConsumerStatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  ConsumerState<TimesheetListScreen> createState() => _TimesheetListScreenState();
}

class _TimesheetListScreenState extends ConsumerState<TimesheetListScreen> {
  TimesheetStatus? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(timesheetsProvider(TimesheetQuery(status: _status)));
    return PermissionGate(
      permission: Permission.timesheetView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timesheets'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/app')),
          actions: [
            PermissionGate(
              permission: Permission.timesheetApprove,
              child: TextButton(
                onPressed: () => context.push('/admin/timesheets/approval'),
                child: const Text('Approvals'),
              ),
            ),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.timesheetCreate,
          child: FloatingActionButton(
            onPressed: () => context.push('/admin/timesheets/new'),
            child: const Icon(Icons.add),
          ),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FilterChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                  for (final status in TimesheetStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (items) => ListView(
                  children: [
                    for (final row in items)
                      ListTile(
                        title: Text('${row.hours}h · ${row.status.label}'),
                        subtitle: Text(row.description),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
