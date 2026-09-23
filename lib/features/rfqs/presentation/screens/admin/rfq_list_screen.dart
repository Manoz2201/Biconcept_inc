import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../vendors/presentation/providers/vendors_provider.dart';
import '../../../domain/rfq.dart';

class RFQListScreen extends ConsumerStatefulWidget {
  const RFQListScreen({super.key});

  @override
  ConsumerState<RFQListScreen> createState() => _RFQListScreenState();
}

class _RFQListScreenState extends ConsumerState<RFQListScreen> {
  RFQStatus? _status;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(rfqsProvider(RfqQuery(status: _status)));
    return PermissionGate(
      permission: Permission.rfqView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('RFQs')),
        floatingActionButton: PermissionGate(
          permission: Permission.rfqCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/rfqs/new'),
            icon: const Icon(Icons.add),
            label: const Text('Create RFQ'),
          ),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  FilterChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                  for (final status in RFQStatus.values)
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
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (rows) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in rows)
                      ListTile(
                        title: Text('${item.rfqNumber} · ${item.title}'),
                        subtitle: Text('${item.status.label} · due ${formatDisplayDate(item.dueDate)}'),
                        onTap: () => context.push('/admin/rfqs/${item.id}'),
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
