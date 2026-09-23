import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../intelligence/presentation/providers/intelligence_providers.dart';
import '../../../rbac/domain/permission.dart';

class RiskDashboardScreen extends ConsumerWidget {
  const RiskDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(maintenanceAlertsProvider);
    return PermissionGate(
      permission: Permission.aiTimelinePredict,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Project risk')),
        body: alerts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              ListTile(title: const Text('Maintenance alerts'), onTap: () => context.push('/predictive/alerts')),
              for (final item in items)
                ListTile(
                  title: Text('${item.severity} · ${item.alertType}'),
                  subtitle: Text(item.description),
                  trailing: Text(item.projectId),
                  onTap: () => context.push('/predictive/projects/${item.projectId}/health'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenanceAlertsScreen extends ConsumerWidget {
  const MaintenanceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(maintenanceAlertsProvider);
    return PermissionGate(
      permission: Permission.aiTimelinePredict,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Maintenance alerts')),
        body: alerts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.alertType),
                  subtitle: Text('${item.severity}\n${item.suggestedAction}'),
                  isThreeLine: true,
                  trailing: item.isResolved
                      ? const Text('Resolved')
                      : TextButton(
                          onPressed: () async {
                            await ref.read(intelligenceRepositoryProvider).resolveAlert(item.id);
                            ref.invalidate(maintenanceAlertsProvider);
                          },
                          child: const Text('Resolve'),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectHealthScreen extends ConsumerWidget {
  const ProjectHealthScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(projectHealthProvider(projectId));
    final risk = ref.watch(projectRiskProvider(projectId));
    return PermissionGate(
      permission: Permission.aiTimelinePredict,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Project health')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            health.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Score ${item.score.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineSmall),
                  LinearProgressIndicator(value: item.score / 100),
                  ListTile(title: Text('Schedule ${item.schedule.toStringAsFixed(0)}')),
                  ListTile(title: Text('Budget ${item.budget.toStringAsFixed(0)}')),
                  ListTile(title: Text('Client ${item.client.toStringAsFixed(0)}')),
                  ListTile(title: Text('Team ${item.team.toStringAsFixed(0)}')),
                  for (final rec in item.recommendations) ListTile(leading: const Icon(Icons.lightbulb_outline), title: Text(rec)),
                ],
              ),
            ),
            risk.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (item) => Column(
                children: [
                  ListTile(title: Text('Risk ${item.riskLevel} · ${item.riskScore.toStringAsFixed(0)}')),
                  for (final factor in item.factors) ListTile(title: Text(factor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
