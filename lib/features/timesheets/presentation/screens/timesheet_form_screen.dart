import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../rbac/domain/permission.dart';
import '../providers/timesheets_provider.dart';

class TimesheetFormScreen extends ConsumerStatefulWidget {
  const TimesheetFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<TimesheetFormScreen> createState() => _TimesheetFormScreenState();
}

class _TimesheetFormScreenState extends ConsumerState<TimesheetFormScreen> {
  final _hours = TextEditingController();
  final _description = TextEditingController();
  String? _projectId;
  String? _taskId;
  DateTime _date = DateTime.now();
  var _billable = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
  }

  @override
  void dispose() {
    _hours.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider(const ProjectQuery())).valueOrNull ?? const [];
    final tasks = _projectId == null
        ? const []
        : ref.watch(tasksProvider(TaskQuery(projectId: _projectId!))).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.timesheetCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Log time')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            DropdownButtonFormField<String>(
              initialValue: _projectId,
              decoration: const InputDecoration(labelText: 'Project'),
              items: [for (final item in projects) DropdownMenuItem(value: item.id, child: Text(item.title))],
              onChanged: (value) => setState(() {
                _projectId = value;
                _taskId = null;
              }),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _taskId,
              decoration: const InputDecoration(labelText: 'Task'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final item in tasks) DropdownMenuItem(value: item.id, child: Text(item.title)),
              ],
              onChanged: (value) => setState(() => _taskId = value),
            ),
            ListTile(
              title: Text('Date ${_date.day}/${_date.month}/${_date.year}'),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(controller: _hours, decoration: const InputDecoration(labelText: 'Hours'), keyboardType: TextInputType.number),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            SwitchListTile(value: _billable, onChanged: (value) => setState(() => _billable = value), title: const Text('Billable')),
            FilledButton(onPressed: _busy ? null : () => _save(false), child: const Text('Save draft')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : () => _save(true), child: const Text('Submit')),
          ],
        ),
      ),
    );
  }

  Future<void> _save(bool submit) async {
    final projectId = _projectId;
    final hours = double.tryParse(_hours.text);
    if (projectId == null || hours == null || _description.text.trim().isEmpty) {
      setState(() => _error = 'Project, hours, and description are required');
      return;
    }
    setState(() => _busy = true);
    final created = await ref.read(timesheetRepositoryProvider).createTimesheet(
          projectId: projectId,
          taskId: _taskId,
          date: _date,
          hours: hours,
          description: _description.text,
          billable: _billable,
        );
    await created.when(
      success: (row) async {
        if (submit) await ref.read(timesheetRepositoryProvider).submitTimesheet(row.id);
        ref.invalidate(timesheetsProvider);
        if (mounted) context.pop();
      },
      failure: (error) async => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
