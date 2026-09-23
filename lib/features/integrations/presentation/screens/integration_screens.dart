import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/integration_models.dart';

class IntegrationListScreen extends ConsumerWidget {
  const IntegrationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(integrationsProvider(null));
    return PermissionGate(
      permission: Permission.integrationView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Integrations')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final provider in IntegrationProvider.values)
                  Card(
                    child: InkWell(
                      onTap: () => context.push('/admin/integrations/setup/${provider.value}'),
                      child: SizedBox(
                        width: 180,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(provider.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(rows.asData?.value.any((item) => item.provider == provider && item.isActive) == true ? 'Connected' : 'Not connected'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            rows.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item.displayName),
                      subtitle: Text('${item.provider.label} · ${item.lastSyncStatus ?? 'never synced'}'),
                      onTap: () => context.push('/admin/integrations/${item.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntegrationSetupScreen extends ConsumerStatefulWidget {
  const IntegrationSetupScreen({super.key, required this.provider});

  final String provider;

  @override
  ConsumerState<IntegrationSetupScreen> createState() => _IntegrationSetupScreenState();
}

class _IntegrationSetupScreenState extends ConsumerState<IntegrationSetupScreen> {
  final _name = TextEditingController();
  final _host = TextEditingController();
  String _direction = 'export';
  String _frequency = 'manual';

  @override
  void initState() {
    super.initState();
    _name.text = IntegrationProvider.fromString(widget.provider).label;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = IntegrationProvider.fromString(widget.provider);
    return PermissionGate(
      permission: Permission.integrationConfigure,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text('Set up ${provider.label}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
            if (provider == IntegrationProvider.tally)
              TextField(controller: _host, decoration: const InputDecoration(labelText: 'Tally URL (no credentials)')),
            if (provider != IntegrationProvider.tally)
              const Text('OAuth client ID, secret, and refresh tokens stay in Function env. This screen only stores non-secret mapping.'),
            DropdownButtonFormField<String>(
              initialValue: _direction,
              items: const [
                DropdownMenuItem(value: 'export', child: Text('Export')),
                DropdownMenuItem(value: 'import', child: Text('Import')),
                DropdownMenuItem(value: 'bidirectional', child: Text('Bidirectional')),
              ],
              onChanged: (value) => setState(() => _direction = value ?? _direction),
              decoration: const InputDecoration(labelText: 'Direction'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              ],
              onChanged: (value) => setState(() => _frequency = value ?? _frequency),
              decoration: const InputDecoration(labelText: 'Frequency'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(integrationRepositoryProvider).createIntegration(
                      provider: provider,
                      displayName: _name.text.trim(),
                      config: {'host': _host.text.trim(), 'syncDirection': _direction, 'syncFrequency': _frequency},
                    );
                if (!context.mounted) return;
                result.when(
                  success: (item) {
                    ref.invalidate(integrationsProvider);
                    context.go('/admin/integrations/${item.id}');
                  },
                  failure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.userMessage))),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class IntegrationDetailScreen extends ConsumerWidget {
  const IntegrationDetailScreen({super.key, required this.integrationId});

  final String integrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(integrationByIdProvider(integrationId));
    final logs = ref.watch(syncLogsProvider(integrationId));
    return PermissionGate(
      permission: Permission.integrationView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Integration')),
        body: row.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.displayName, style: Theme.of(context).textTheme.titleLarge),
              Text('${item.provider.label} · ${item.isActive ? 'Active' : 'Disabled'}'),
              Text('Last sync ${item.lastSyncAt ?? 'never'}'),
              Wrap(
                spacing: 8,
                children: [
                  PermissionGate(
                    permission: Permission.integrationSync,
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(integrationRepositoryProvider).syncNow(item.id);
                        ref.invalidate(integrationByIdProvider(integrationId));
                        ref.invalidate(syncLogsProvider(integrationId));
                      },
                      child: const Text('Sync now'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final xml = await ref.read(integrationRepositoryProvider).exportToTally();
                      final text = xml.dataOrNull;
                      if (text != null) await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export copied')));
                    },
                    child: const Text('Copy Tally XML'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(integrationRepositoryProvider).toggleIntegration(item.id, !item.isActive);
                      ref.invalidate(integrationByIdProvider(integrationId));
                    },
                    child: Text(item.isActive ? 'Disable' : 'Enable'),
                  ),
                ],
              ),
              ListTile(title: const Text('Sync logs'), onTap: () => context.push('/admin/integrations/$integrationId/logs')),
              logs.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) => Column(children: [for (final log in items.take(5)) ListTile(title: Text(log.status.label), subtitle: Text('${log.recordsSucceeded}/${log.recordsProcessed}'))]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SyncLogScreen extends ConsumerWidget {
  const SyncLogScreen({super.key, required this.integrationId});

  final String integrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(syncLogsProvider(integrationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Sync logs')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ExpansionTile(
                title: Text('${item.entityType} · ${item.status.label}'),
                subtitle: Text('${item.startedAt.toLocal()} · ${item.recordsSucceeded}/${item.recordsProcessed}'),
                children: [if (item.errorDetails != null) ListTile(title: Text(item.errorDetails!))],
              ),
          ],
        ),
      ),
    );
  }
}
