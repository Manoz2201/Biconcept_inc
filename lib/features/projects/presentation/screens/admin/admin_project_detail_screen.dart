import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../change_requests/presentation/providers/change_requests_provider.dart';
import '../../../../documents/presentation/providers/documents_provider.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../timesheets/presentation/providers/timesheets_provider.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/project.dart';
import '../../../domain/project_status.dart';
import '../../../domain/task.dart';
import '../../providers/projects_provider.dart';
import '../../widgets/milestone_timeline.dart';
import '../../widgets/project_activity_feed.dart';
import '../../widgets/project_progress_bar.dart';
import '../../widgets/project_status_badge.dart';
import '../../widgets/task_calendar_view.dart';
import '../../widgets/task_kanban_board.dart';
import '../../widgets/task_list_view.dart';

class AdminProjectDetailScreen extends ConsumerStatefulWidget {
  const AdminProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<AdminProjectDetailScreen> createState() => _AdminProjectDetailScreenState();
}

class _AdminProjectDetailScreenState extends ConsumerState<AdminProjectDetailScreen> {
  var _taskView = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectByIdProvider(widget.projectId));
    return PermissionGate(
      permission: Permission.projectView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: async.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (project) => DefaultTabController(
          length: 8,
          child: Scaffold(
            appBar: AppBar(
              title: Text(project.projectNumber),
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/projects')),
              actions: [
                PermissionGate(
                  permission: Permission.projectEdit,
                  child: IconButton(
                    onPressed: () => context.push('/admin/projects/${project.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Milestones'),
                  Tab(text: 'Tasks'),
                  Tab(text: 'Documents'),
                  Tab(text: 'Timesheets'),
                  Tab(text: 'Changes'),
                  Tab(text: 'Vendors'),
                  Tab(text: 'Activity'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OverviewTab(project: project),
                _MilestonesTab(projectId: project.id),
                _TasksTab(
                  projectId: project.id,
                  view: _taskView,
                  onView: (value) => setState(() => _taskView = value),
                ),
                _DocumentsTab(projectId: project.id),
                _TimesheetsTab(projectId: project.id),
                _ChangesTab(projectId: project.id),
                _VendorsLinkTab(projectId: project.id),
                _ActivityTab(projectId: project.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userListProvider).valueOrNull?.users ?? const [];
    final milestones = ref.watch(milestonesProvider(project.id)).valueOrNull ?? const [];
    final activities = ref.watch(projectActivitiesProvider(project.id)).valueOrNull ?? const [];
    final client = users.where((user) => user.accountId == project.clientId).firstOrNull;
    final architect = users.where((user) => user.accountId == project.assignedArchitect).firstOrNull;
    final upcoming = [
      for (final item in milestones)
        if (!item.isComplete) item,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(project.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            ProjectStatusBadge(status: project.status),
          ],
        ),
        if (project.priority != null) Text(project.priority!.label),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text(client?.name ?? project.clientId),
            subtitle: Text([
              if (architect != null) 'Architect · ${architect.name}',
              '${formatDisplayDate(project.startDate)} – ${formatDisplayDate(project.endDate)}',
              if (project.budget != null) 'Budget ${formatMoney(project.budget!)} · spent ${formatMoney(project.spent)}',
            ].join('\n')),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 12),
        ProjectProgressBar(progress: project.progress, label: 'Milestone progress ${project.progress}%'),
        const SizedBox(height: 16),
        if ((project.budget ?? 0) > 0)
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: project.spent, color: AppColors.primary, title: 'Spent'),
                  PieChartSectionData(
                    value: ((project.budget ?? 0) - project.spent).clamp(0, double.infinity),
                    color: AppColors.outline,
                    title: 'Left',
                  ),
                ],
              ),
            ),
          ),
        PermissionGate(
          permission: Permission.projectEdit,
          child: Wrap(
            spacing: 8,
            children: [
              for (final status in ProjectStatus.values)
                if (project.status.canTransitionTo(status))
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(projectRepositoryProvider).updateProjectStatus(project.id, status);
                      ref.invalidate(projectByIdProvider(project.id));
                    },
                    child: Text(status.label),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Upcoming milestones', style: TextStyle(fontWeight: FontWeight.w700)),
        MilestoneTimeline(milestones: upcoming.take(3).toList(), readOnly: true),
        const SizedBox(height: 16),
        const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700)),
        ProjectActivityFeed(activities: activities.take(8).toList()),
      ],
    );
  }
}

class _MilestonesTab extends ConsumerWidget {
  const _MilestonesTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(milestonesProvider(projectId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionGate(
            permission: Permission.milestoneCreate,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => context.push('/admin/projects/$projectId/milestones/new'),
                icon: const Icon(Icons.add),
                label: const Text('Add milestone'),
              ),
            ),
          ),
          MilestoneTimeline(
            milestones: items,
            onEdit: (item) => context.push('/admin/projects/$projectId/milestones/${item.id}/edit'),
            onStatus: (item, status) async {
              await ref.read(milestoneRepositoryProvider).updateMilestoneStatus(item.id, status);
              ref.invalidate(milestonesProvider(projectId));
              ref.invalidate(projectByIdProvider(projectId));
            },
            onDelete: (item) async {
              await ref.read(milestoneRepositoryProvider).deleteMilestone(item.id);
              ref.invalidate(milestonesProvider(projectId));
              ref.invalidate(projectByIdProvider(projectId));
            },
          ),
        ],
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.projectId, required this.view, required this.onView});

  final String projectId;
  final int view;
  final ValueChanged<int> onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tasksProvider(TaskQuery(projectId: projectId)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Kanban')),
                  ButtonSegment(value: 1, label: Text('List')),
                  ButtonSegment(value: 2, label: Text('Calendar')),
                ],
                selected: {view},
                onSelectionChanged: (value) => onView(value.first),
              ),
              const Spacer(),
              PermissionGate(
                permission: Permission.taskCreate,
                child: FilledButton.icon(
                  onPressed: () => context.push('/admin/projects/$projectId/tasks/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Task'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (view == 0)
            TaskKanbanBoard(tasks: items, onStatus: (task, status) => _status(ref, task, status)),
          if (view == 1)
            TaskListView(
              tasks: items,
              onStatus: (task, status) => _status(ref, task, status),
              onOpen: (task) => context.push('/admin/projects/$projectId/tasks/${task.id}/edit'),
            ),
          if (view == 2)
            TaskCalendarView(
              tasks: items,
              onOpen: (task) => context.push('/admin/projects/$projectId/tasks/${task.id}/edit'),
            ),
        ],
      ),
    );
  }

  Future<void> _status(WidgetRef ref, Task task, TaskStatus status) async {
    await ref.read(taskRepositoryProvider).updateTaskStatus(task.id, status);
    ref.invalidate(tasksProvider(TaskQuery(projectId: projectId)));
    ref.invalidate(projectActivitiesProvider(projectId));
  }
}

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectDocumentsProvider(DocumentQuery(projectId: projectId)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => context.push('/admin/projects/$projectId/documents/upload'),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
          ),
          for (final doc in items)
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(doc.title),
              subtitle: Text('${doc.category.label} · v${doc.version}'),
              onTap: () => context.push('/admin/projects/$projectId/documents/${doc.id}'),
            ),
        ],
      ),
    );
  }
}

class _TimesheetsTab extends ConsumerWidget {
  const _TimesheetsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timesheetsProvider(TimesheetQuery(projectId: projectId)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => context.push('/admin/timesheets/new?projectId=$projectId'),
              child: const Text('Log time'),
            ),
          ),
          for (final row in items)
            ListTile(
              title: Text('${row.hours}h · ${row.status.label}'),
              subtitle: Text(row.description),
            ),
        ],
      ),
    );
  }
}

class _ChangesTab extends ConsumerWidget {
  const _ChangesTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(changeRequestsProvider(ChangeRequestQuery(projectId: projectId)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) => ListView(
        children: [
          for (final row in items)
            ListTile(
              title: Text(row.title),
              subtitle: Text(row.status.label),
              onTap: () => context.push('/admin/change-requests/${row.id}?projectId=$projectId'),
            ),
        ],
      ),
    );
  }
}

class _VendorsLinkTab extends StatelessWidget {
  const _VendorsLinkTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () => context.push('/admin/projects/$projectId/vendors'),
        child: const Text('Manage project vendors'),
      ),
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectActivitiesProvider(projectId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [ProjectActivityFeed(activities: items)],
      ),
    );
  }
}
