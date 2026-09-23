import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/quotation.dart';
import '../../providers/quotations_provider.dart';
import '../../widgets/quotation_status_badge.dart';

class AdminQuotationsScreen extends ConsumerStatefulWidget {
  const AdminQuotationsScreen({super.key});

  @override
  ConsumerState<AdminQuotationsScreen> createState() => _AdminQuotationsScreenState();
}

class _AdminQuotationsScreenState extends ConsumerState<AdminQuotationsScreen> {
  final _search = TextEditingController();
  QuotationStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quotationsProvider(QuotationQuery(status: _status, search: _search.text)));
    final users = ref.watch(userListProvider).valueOrNull?.users ?? [];
    return PermissionGate(
      permission: Permission.quotationView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quotations'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/app')),
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.quotationCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/quotations/new'),
            icon: const Icon(Icons.add),
            label: const Text('New quotation'),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: 'Search number or title', prefixIcon: Icon(Icons.search)),
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
                  for (final status in QuotationStatus.values)
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
                  if (items.isEmpty) return const Center(child: Text('No quotations'));
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final client = users.where((user) => user.accountId == item.clientId).firstOrNull;
                      return ListTile(
                        title: Text('${item.quotationNumber} · ${item.title}'),
                        subtitle: Text(
                          [
                            client?.name ?? item.clientId,
                            formatMoney(item.total),
                            formatDisplayDate(item.validUntil),
                          ].join(' · '),
                        ),
                        trailing: QuotationStatusBadge(status: item.effectiveStatus),
                        onTap: () => context.push('/admin/quotations/${item.id}'),
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
