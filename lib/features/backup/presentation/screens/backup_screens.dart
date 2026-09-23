import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../platform/presentation/widgets/platform_widgets.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/backup_models.dart';

class BackupListScreen extends ConsumerWidget {
  const BackupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(backupJobsProvider(null));
    return PermissionGate(
      permission: Permission.backupView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Backups')),
        floatingActionButton: PermissionGate(
          permission: Permission.backupCreate,
          child: FloatingActionButton(onPressed: () => context.push('/admin/backups/new'), child: const Icon(Icons.add)),
        ),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => ListView(
            children: [
              ListTile(title: const Text('Restore'), onTap: () => context.push('/admin/backups/restore')),
              for (final item in items)
                ListTile(
                  title: Text(item.jobName),
                  subtitle: Text('${item.jobType.label} · ${item.frequency} · ${item.lastRunStatus ?? 'never'}'),
                  onTap: () => context.push('/admin/backups/${item.id}/history'),
                  trailing: PermissionGate(
                    permission: Permission.backupCreate,
                    child: TextButton(
                      onPressed: () async {
                        await ref.read(backupRepositoryProvider).runBackupNow(item.id);
                        ref.invalidate(backupJobsProvider);
                        ref.invalidate(backupHistoryProvider);
                      },
                      child: const Text('Run'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackupJobFormScreen extends ConsumerStatefulWidget {
  const BackupJobFormScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<BackupJobFormScreen> createState() => _BackupJobFormScreenState();
}

class _BackupJobFormScreenState extends ConsumerState<BackupJobFormScreen> {
  final _name = TextEditingController();
  var _type = BackupJobType.full;
  var _frequency = 'manual';
  var _retention = 30;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.backupCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup job')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Job name')),
            DropdownButtonFormField<BackupJobType>(
              initialValue: _type,
              items: [for (final item in BackupJobType.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: (value) => setState(() => _type = value ?? _type),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              ],
              onChanged: (value) => setState(() => _frequency = value ?? _frequency),
              decoration: const InputDecoration(labelText: 'Frequency'),
            ),
            Text('Retention $_retention days'),
            Slider(value: _retention.toDouble(), min: 7, max: 90, divisions: 83, onChanged: (value) => setState(() => _retention = value.round())),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(backupRepositoryProvider).createBackupJob(
                      jobName: _name.text.trim(),
                      jobType: _type,
                      frequency: _frequency,
                      retentionDays: _retention,
                      storageLocation: 'appwrite',
                    );
                if (!context.mounted) return;
                result.when(
                  success: (_) {
                    ref.invalidate(backupJobsProvider);
                    context.pop();
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

class BackupHistoryScreen extends ConsumerWidget {
  const BackupHistoryScreen({super.key, this.jobId});

  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(backupHistoryProvider(jobId));
    return Scaffold(
      appBar: AppBar(title: const Text('Backup history')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text('$error'),
        data: (items) => ListView(
          children: [
            for (final item in items)
              ListTile(
                title: Text(item.fileName),
                subtitle: Text('${item.fileSize} bytes · ${item.recordCount} records'),
                trailing: BackupStatusBadge(status: item.status),
                onTap: () => context.push('/admin/backups/restore'),
              ),
          ],
        ),
      ),
    );
  }
}

class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  String? _selected;
  var _dryRun = true;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(backupHistoryProvider(null));
    return PermissionGate(
      permission: Permission.backupRestore,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Restore')),
        body: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => ListView(
            children: [
              SwitchListTile(title: const Text('Dry run'), value: _dryRun, onChanged: (value) => setState(() => _dryRun = value)),
              for (final item in items)
                ListTile(
                  selected: _selected == item.id,
                  title: Text(item.fileName),
                  subtitle: Text(item.startedAt.toLocal().toString()),
                  trailing: Icon(_selected == item.id ? Icons.check_circle : Icons.circle_outlined),
                  onTap: () => setState(() => _selected = item.id),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () async {
                          if (!_dryRun) {
                            final ok = await confirmPhrase(context, title: 'Restore backup', phrase: 'RESTORE');
                            if (!ok) return;
                          }
                          final result = await ref.read(backupRepositoryProvider).restoreFromBackup(_selected!, dryRun: _dryRun);
                          if (!context.mounted) return;
                          result.when(
                            success: (preview) => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${_dryRun ? 'Dry run' : 'Restored'} · ${preview.recordCount} records · checksum ${preview.checksumOk}')),
                            ),
                            failure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.userMessage))),
                          );
                          ref.invalidate(backupHistoryProvider);
                        },
                  child: Text(_dryRun ? 'Validate' : 'Restore'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
