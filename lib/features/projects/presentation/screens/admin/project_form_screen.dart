import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../rbac/domain/user_role.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/project.dart';
import '../../../domain/project_status.dart';
import '../../providers/projects_provider.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  String? _clientId;
  String? _architectId;
  ProjectPriority _priority = ProjectPriority.medium;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 90));
  var _busy = false;
  String? _error;
  var _hydrated = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _hydrate(Project project) {
    if (_hydrated) return;
    _hydrated = true;
    _title.text = project.title;
    _description.text = project.description ?? '';
    _budget.text = project.budget?.toString() ?? '';
    _clientId = project.clientId;
    _architectId = project.assignedArchitect;
    _priority = project.priority ?? ProjectPriority.medium;
    _start = project.startDate;
    _end = project.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(userListProvider).valueOrNull?.users ?? const [];
    final existing = widget.projectId == null ? null : ref.watch(projectByIdProvider(widget.projectId!));
    existing?.whenData(_hydrate);
    return PermissionGate(
      permission: widget.projectId == null ? Permission.projectCreate : Permission.projectEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.projectId == null ? 'New project' : 'Edit project')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              decoration: const InputDecoration(labelText: 'Client'),
              items: [
                for (final user in users.where((item) => item.role == UserRole.client))
                  DropdownMenuItem(value: user.accountId, child: Text(user.name)),
              ],
              onChanged: (value) => setState(() => _clientId = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: _architectId,
              decoration: const InputDecoration(labelText: 'Architect'),
              items: [
                for (final user in users.where((item) => item.role.isStaff))
                  DropdownMenuItem(value: user.accountId, child: Text(user.name)),
              ],
              onChanged: (value) => setState(() => _architectId = value),
            ),
            DropdownButtonFormField<ProjectPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final item in ProjectPriority.values) DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: (value) => setState(() => _priority = value ?? ProjectPriority.medium),
            ),
            TextField(controller: _budget, decoration: const InputDecoration(labelText: 'Budget'), keyboardType: TextInputType.number),
            ListTile(
              title: Text('Start ${_start.day}/${_start.month}/${_start.year}'),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _start);
                if (picked != null) setState(() => _start = picked);
              },
            ),
            ListTile(
              title: Text('End ${_end.day}/${_end.month}/${_end.year}'),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _end);
                if (picked != null) setState(() => _end = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final clientId = _clientId;
    if (_title.text.trim().isEmpty || clientId == null) {
      setState(() => _error = 'Title and client are required');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'End date must be after start date');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final budget = double.tryParse(_budget.text);
    final repo = ref.read(projectRepositoryProvider);
    final result = widget.projectId == null
        ? await repo.createProject(
            clientId: clientId,
            title: _title.text,
            description: _description.text,
            startDate: _start,
            endDate: _end,
            budget: budget,
            assignedArchitect: _architectId,
            priority: _priority,
          )
        : await repo.updateProject(widget.projectId!, {
            'title': _title.text.trim(),
            'description': _description.text.trim(),
            'budget': budget,
            'assignedArchitect': _architectId,
            'priority': _priority.value,
            'startDate': _start.toUtc().toIso8601String(),
            'endDate': _end.toUtc().toIso8601String(),
          });
    if (!mounted) return;
    result.when(
      success: (project) {
        ref.invalidate(projectsProvider);
        ref.invalidate(projectByIdProvider(project.id));
        context.go('/admin/projects/${project.id}');
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
