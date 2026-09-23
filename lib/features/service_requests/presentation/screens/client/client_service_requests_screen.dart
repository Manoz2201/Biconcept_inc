import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../ui/widgets/portal_shell.dart';
import '../../../domain/service_request.dart';
import '../../providers/service_requests_provider.dart';
import '../../widgets/service_request_card.dart';

class ClientServiceRequestsScreen extends ConsumerStatefulWidget {
  const ClientServiceRequestsScreen({super.key});

  @override
  ConsumerState<ClientServiceRequestsScreen> createState() => _ClientServiceRequestsScreenState();
}

class _ClientServiceRequestsScreenState extends ConsumerState<ClientServiceRequestsScreen> {
  ServiceRequestStatus? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceRequestsProvider(ServiceRequestQuery(status: _status)));
    return PortalPageScaffold(
      title: 'requests',
      subtitle: 'Track and start service work with the studio.',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/client/requests/new'),
        tooltip: 'New request',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                const SizedBox(width: 8),
                for (final status in ServiceRequestStatus.values)
                  if (status != ServiceRequestStatus.rejected)
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
              error: (error, _) => Center(child: Text('$error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No requests yet'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ServiceRequestCard(
                      request: item,
                      onTap: () => context.go('/client/requests/${item.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
