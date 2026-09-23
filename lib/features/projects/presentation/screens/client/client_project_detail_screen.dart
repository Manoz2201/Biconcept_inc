import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../change_requests/presentation/providers/change_requests_provider.dart';
import '../../../../documents/presentation/providers/documents_provider.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../providers/projects_provider.dart';
import '../../widgets/milestone_timeline.dart';
import '../../widgets/project_activity_feed.dart';
import '../../widgets/project_progress_bar.dart';
import '../../widgets/project_status_badge.dart';
import '../../widgets/task_list_view.dart';

class ClientProjectDetailScreen extends ConsumerWidget {
  const ClientProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectByIdProvider(projectId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (project) => DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: Text(project.projectNumber),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/client/projects')),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Milestones'),
                Tab(text: 'Tasks'),
                Tab(text: 'Documents'),
                Tab(text: 'Changes'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _Overview(projectId: projectId),
              _Milestones(projectId: projectId),
              _Tasks(projectId: projectId),
              _Documents(projectId: projectId),
              _Changes(projectId: projectId),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId)).valueOrNull;
    if (project == null) return const SizedBox.shrink();
    final users = ref.watch(userListProvider).valueOrNull?.users ?? const [];
    final architect = users.where((user) => user.accountId == project.assignedArchitect).firstOrNull;
    final milestones = ref.watch(milestonesProvider(projectId)).valueOrNull ?? const [];
    final activities = ref.watch(projectActivitiesProvider(projectId)).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(project.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            ProjectStatusBadge(status: project.status),
          ],
        ),
        const SizedBox(height: 12),
        Text('${formatDisplayDate(project.startDate)} – ${formatDisplayDate(project.endDate)}'),
        if (architect != null) Text('Architect · ${architect.name}'),
        if (project.budget != null) Text('Budget ${formatMoney(project.budget!)}'),
        const SizedBox(height: 12),
        ProjectProgressBar(progress: project.progress),
        const SizedBox(height: 16),
        MilestoneTimeline(milestones: milestones, readOnly: true),
        const SizedBox(height: 16),
        ProjectActivityFeed(activities: activities.take(6).toList()),
      ],
    );
  }
}

class _Milestones extends ConsumerWidget {
  const _Milestones({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(milestonesProvider(projectId)).valueOrNull ?? const [];
    return ListView(padding: const EdgeInsets.all(16), children: [MilestoneTimeline(milestones: items, readOnly: true)]);
  }
}

class _Tasks extends ConsumerWidget {
  const _Tasks({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(tasksProvider(TaskQuery(projectId: projectId))).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [TaskListView(tasks: items, readOnly: true)],
    );
  }
}

class _Documents extends ConsumerWidget {
  const _Documents({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(projectDocumentsProvider(DocumentQuery(projectId: projectId, clientVisible: true))).valueOrNull ?? const [];
    final repo = ref.watch(documentRepositoryProvider);
    return ListView(
      children: [
        for (final doc in items)
          ListTile(
            title: Text(doc.title),
            subtitle: Text(doc.category.label),
            trailing: const Icon(Icons.download_outlined),
            onTap: () => launchUrl(Uri.parse(repo.getDownloadUrl(doc.fileId))),
          ),
      ],
    );
  }
}

class _Changes extends ConsumerWidget {
  const _Changes({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(changeRequestsProvider(ChangeRequestQuery(projectId: projectId))).valueOrNull ?? const [];
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => context.go('/client/projects/$projectId/change-requests/new'),
            child: const Text('Request change'),
          ),
        ),
        for (final row in items)
          ListTile(
            title: Text(row.title),
            subtitle: Text(row.status.label),
            onTap: () => context.go('/client/projects/$projectId/change-requests'),
          ),
      ],
    );
  }
}
