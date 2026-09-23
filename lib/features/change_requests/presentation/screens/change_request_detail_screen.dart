import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/change_request.dart';
import '../providers/change_requests_provider.dart';

class ChangeRequestDetailScreen extends ConsumerWidget {
  const ChangeRequestDetailScreen({super.key, required this.changeRequestId, this.projectId});

  final String changeRequestId;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(changeRequestsProvider(ChangeRequestQuery(projectId: projectId)));
    return PermissionGate(
      permission: Permission.changeRequestView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: async.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (items) {
          final row = items.where((item) => item.id == changeRequestId).firstOrNull;
          if (row == null) return const Scaffold(body: Center(child: Text('Not found')));
          return Scaffold(
            appBar: AppBar(title: Text(row.title)),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(row.status.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(row.description),
                const SizedBox(height: 12),
                if (row.impactCost != null) Text('Cost impact ${formatMoney(row.impactCost!)}'),
                if (row.impactDays != null) Text('Schedule impact ${row.impactDays} days'),
                if (row.clientNotes != null) Text('Notes: ${row.clientNotes}'),
                const SizedBox(height: 16),
                if (row.status == ChangeRequestStatus.pending)
                  PermissionGate(
                    permission: Permission.changeRequestApprove,
                    child: Row(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            await ref.read(changeRequestRepositoryProvider).approveChangeRequest(row.id);
                            ref.invalidate(changeRequestsProvider);
                          },
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(changeRequestRepositoryProvider).rejectChangeRequest(row.id, 'Rejected');
                            ref.invalidate(changeRequestsProvider);
                          },
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ),
                if (row.status == ChangeRequestStatus.approved)
                  PermissionGate(
                    permission: Permission.changeRequestApprove,
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(changeRequestRepositoryProvider).implementChangeRequest(row.id);
                        ref.invalidate(changeRequestsProvider);
                      },
                      child: const Text('Mark implemented'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
