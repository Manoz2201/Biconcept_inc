import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/change_request.dart';
import '../providers/change_requests_provider.dart';

class ChangeRequestListScreen extends ConsumerStatefulWidget {
  const ChangeRequestListScreen({super.key});

  @override
  ConsumerState<ChangeRequestListScreen> createState() => _ChangeRequestListScreenState();
}

class _ChangeRequestListScreenState extends ConsumerState<ChangeRequestListScreen> {
  ChangeRequestStatus? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(changeRequestsProvider(ChangeRequestQuery(status: _status)));
    return PermissionGate(
      permission: Permission.changeRequestView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Change requests'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/app')),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FilterChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                  for (final status in ChangeRequestStatus.values)
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
                        title: Text(row.title),
                        subtitle: Text(row.status.label),
                        onTap: () => context.push('/admin/change-requests/${row.id}?projectId=${row.projectId}'),
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
