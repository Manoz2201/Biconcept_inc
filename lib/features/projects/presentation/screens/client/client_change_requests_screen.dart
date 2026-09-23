import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../change_requests/presentation/providers/change_requests_provider.dart';

class ClientChangeRequestsScreen extends ConsumerWidget {
  const ClientChangeRequestsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(changeRequestsProvider(ChangeRequestQuery(projectId: projectId)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change requests'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/client/projects/$projectId')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/client/projects/$projectId/change-requests/new'),
        label: const Text('Request change'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          children: [
            for (final row in items)
              ListTile(
                title: Text(row.title),
                subtitle: Text(row.status.label),
              ),
          ],
        ),
      ),
    );
  }
}
