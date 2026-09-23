import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/timesheet.dart';
import '../providers/timesheets_provider.dart';

class TimesheetApprovalScreen extends ConsumerWidget {
  const TimesheetApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timesheetsProvider(const TimesheetQuery(status: TimesheetStatus.submitted)));
    return PermissionGate(
      permission: Permission.timesheetApprove,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timesheet approval'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/timesheets')),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) {
            final grouped = <String, List<Timesheet>>{};
            for (final item in items) {
              grouped.putIfAbsent(item.userId, () => []).add(item);
            }
            if (grouped.isEmpty) return const Center(child: Text('Nothing pending'));
            return ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  ListTile(title: Text(entry.key), subtitle: Text('${entry.value.fold<double>(0, (sum, row) => sum + row.hours)}h this batch')),
                  for (final row in entry.value)
                    ListTile(
                      title: Text('${row.hours}h · ${row.description}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              final actor = ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';
                              await ref.read(timesheetRepositoryProvider).approveTimesheet(row.id, actor);
                              ref.invalidate(timesheetsProvider);
                            },
                            icon: const Icon(Icons.check),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref.read(timesheetRepositoryProvider).rejectTimesheet(row.id, 'Needs revision');
                              ref.invalidate(timesheetsProvider);
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
