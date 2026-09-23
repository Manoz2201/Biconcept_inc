import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../rbac/domain/user_role.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/task.dart';
import '../../providers/projects_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, required this.projectId, this.taskId});

  final String projectId;
  final String? taskId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _hours = TextEditingController();
  final _tags = TextEditingController();
  String? _milestoneId;
  String? _parentTaskId;
  String? _assigneeId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _due;
  var _busy = false;
  var _hydrated = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _hours.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestones = ref.watch(milestonesProvider(widget.projectId)).valueOrNull ?? const [];
    final tasks = ref.watch(tasksProvider(TaskQuery(projectId: widget.projectId))).valueOrNull ?? const [];
    final users = ref.watch(userListProvider).valueOrNull?.users ?? const [];
    final current = tasks.where((item) => item.id == widget.taskId).firstOrNull;
    if (current != null && !_hydrated) {
      _hydrated = true;
      _title.text = current.title;
      _description.text = current.description ?? '';
      _hours.text = current.estimatedHours?.toString() ?? '';
      _tags.text = current.tags.join(', ');
      _milestoneId = current.milestoneId;
      _parentTaskId = current.parentTaskId;
      _assigneeId = current.assigneeId;
      _priority = current.priority ?? TaskPriority.medium;
      _due = current.dueDate;
    }
    return PermissionGate(
      permission: Permission.taskCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.taskId == null ? 'New task' : 'Edit task')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            DropdownButtonFormField<String?>(
              initialValue: _milestoneId,
              decoration: const InputDecoration(labelText: 'Milestone'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final item in milestones) DropdownMenuItem(value: item.id, child: Text(item.title)),
              ],
              onChanged: (value) => setState(() => _milestoneId = value),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _parentTaskId,
              decoration: const InputDecoration(labelText: 'Parent task'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final item in tasks.where((task) => task.id != widget.taskId))
                  DropdownMenuItem(value: item.id, child: Text(item.title)),
              ],
              onChanged: (value) => setState(() => _parentTaskId = value),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Assignee'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                for (final user in users.where((item) => item.role.isStaff || item.role == UserRole.vendor))
                  DropdownMenuItem(value: user.accountId, child: Text(user.name)),
              ],
              onChanged: (value) => setState(() => _assigneeId = value),
            ),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [for (final item in TaskPriority.values) DropdownMenuItem(value: item, child: Text(item.label))],
              onChanged: (value) => setState(() => _priority = value ?? TaskPriority.medium),
            ),
            TextField(controller: _hours, decoration: const InputDecoration(labelText: 'Estimated hours')),
            TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags (comma separated)')),
            ListTile(
              title: Text(_due == null ? 'Due date' : 'Due ${_due!.day}/${_due!.month}/${_due!.year}'),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _due ?? DateTime.now());
                if (picked != null) setState(() => _due = picked);
              },
            ),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final reporter = ref.read(sessionControllerProvider).user?.accountId ?? 'unknown';
    final repo = ref.read(taskRepositoryProvider);
    final tags = _tags.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (widget.taskId == null) {
      await repo.createTask(
        projectId: widget.projectId,
        title: _title.text,
        description: _description.text,
        reporterId: reporter,
        milestoneId: _milestoneId,
        parentTaskId: _parentTaskId,
        priority: _priority,
        assigneeId: _assigneeId,
        dueDate: _due,
        estimatedHours: double.tryParse(_hours.text),
        tags: tags,
      );
    } else {
      await repo.updateTask(widget.taskId!, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'milestoneId': _milestoneId,
        'assigneeId': _assigneeId,
        'priority': _priority.value,
        'dueDate': _due?.toUtc().toIso8601String(),
        'estimatedHours': double.tryParse(_hours.text),
      });
    }
    ref.invalidate(tasksProvider(TaskQuery(projectId: widget.projectId)));
    if (mounted) context.go('/admin/projects/${widget.projectId}');
  }
}
