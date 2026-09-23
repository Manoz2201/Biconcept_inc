import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../rbac/domain/permission.dart';
import '../providers/change_requests_provider.dart';

class ChangeRequestFormScreen extends ConsumerStatefulWidget {
  const ChangeRequestFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ChangeRequestFormScreen> createState() => _ChangeRequestFormScreenState();
}

class _ChangeRequestFormScreenState extends ConsumerState<ChangeRequestFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _cost = TextEditingController();
  final _days = TextEditingController();
  String? _projectId;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _cost.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider(const ProjectQuery())).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.changeRequestCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('New change request')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            DropdownButtonFormField<String>(
              initialValue: _projectId,
              decoration: const InputDecoration(labelText: 'Project'),
              items: [for (final item in projects) DropdownMenuItem(value: item.id, child: Text(item.title))],
              onChanged: (value) => setState(() => _projectId = value),
            ),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
            TextField(controller: _cost, decoration: const InputDecoration(labelText: 'Impact cost'), keyboardType: TextInputType.number),
            TextField(controller: _days, decoration: const InputDecoration(labelText: 'Impact days'), keyboardType: TextInputType.number),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Submit')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final projectId = _projectId;
    if (projectId == null || _title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Project, title, and description are required');
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(changeRequestRepositoryProvider).createChangeRequest(
          projectId: projectId,
          title: _title.text,
          description: _description.text,
          impactCost: double.tryParse(_cost.text),
          impactDays: int.tryParse(_days.text),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(changeRequestsProvider);
        context.pop();
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
