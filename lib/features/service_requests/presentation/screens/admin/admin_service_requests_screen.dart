import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/service_request.dart';
import '../../providers/service_requests_provider.dart';
import '../../widgets/service_request_status_badge.dart';

class AdminServiceRequestsScreen extends ConsumerStatefulWidget {
  const AdminServiceRequestsScreen({super.key});

  @override
  ConsumerState<AdminServiceRequestsScreen> createState() => _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState extends ConsumerState<AdminServiceRequestsScreen> {
  final _search = TextEditingController();
  ServiceRequestStatus? _status;
  String? _assignedTo;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ServiceRequestQuery(status: _status, assignedTo: _assignedTo, search: _search.text);
    final async = ref.watch(serviceRequestsProvider(query));
    final staff = ref.watch(userListProvider).valueOrNull?.users ?? [];
    return PermissionGate(
      permission: Permission.serviceRequestView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Service requests'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/app')),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: 'Search title', prefixIcon: Icon(Icons.search)),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _status == null,
                    onSelected: (_) => setState(() => _status = null),
                  ),
                  const SizedBox(width: 8),
                  for (final status in ServiceRequestStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
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
                error: (error, _) => Center(child: Text('$error', style: TextStyle(color: AppColors.down))),
                data: (items) {
                  final filtered = items.where((item) {
                    if (_range == null || item.createdAt == null) return true;
                    final created = item.createdAt!;
                    return !created.isBefore(_range!.start) &&
                        !created.isAfter(_range!.end.add(const Duration(days: 1)));
                  }).toList();
                  if (filtered.isEmpty) return const Center(child: Text('No service requests'));
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final assignee = staff.where((user) => user.accountId == item.assignedTo).firstOrNull;
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          [
                            item.clientId,
                            if (assignee != null) assignee.name,
                            if (item.createdAt != null) item.createdAt!.toLocal().toString().split('.').first,
                          ].join(' · '),
                        ),
                        trailing: ServiceRequestStatusBadge(status: item.status),
                        onTap: () => context.push('/admin/requests/${item.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
