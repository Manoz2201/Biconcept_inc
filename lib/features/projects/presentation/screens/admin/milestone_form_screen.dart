import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../providers/projects_provider.dart';

class MilestoneFormScreen extends ConsumerStatefulWidget {
  const MilestoneFormScreen({super.key, required this.projectId, this.milestoneId});

  final String projectId;
  final String? milestoneId;

  @override
  ConsumerState<MilestoneFormScreen> createState() => _MilestoneFormScreenState();
}

class _MilestoneFormScreenState extends ConsumerState<MilestoneFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _weight = TextEditingController(text: '1');
  DateTime _due = DateTime.now().add(const Duration(days: 14));
  var _busy = false;
  var _hydrated = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(milestonesProvider(widget.projectId)).valueOrNull;
    final current = existing?.where((item) => item.id == widget.milestoneId).firstOrNull;
    if (current != null && !_hydrated) {
      _hydrated = true;
      _title.text = current.title;
      _description.text = current.description ?? '';
      _weight.text = current.weight.toString();
      _due = current.dueDate;
    }
    return PermissionGate(
      permission: Permission.milestoneCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.milestoneId == null ? 'New milestone' : 'Edit milestone')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: _weight, decoration: const InputDecoration(labelText: 'Weight 1-10'), keyboardType: TextInputType.number),
            ListTile(
              title: Text('Due ${_due.day}/${_due.month}/${_due.year}'),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _due);
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
    final repo = ref.read(milestoneRepositoryProvider);
    final weight = int.tryParse(_weight.text) ?? 1;
    if (widget.milestoneId == null) {
      await repo.createMilestone(
        projectId: widget.projectId,
        title: _title.text,
        description: _description.text,
        dueDate: _due,
        weight: weight.clamp(1, 10),
      );
    } else {
      await repo.updateMilestone(widget.milestoneId!, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'dueDate': _due.toUtc().toIso8601String(),
        'weight': weight.clamp(1, 10),
      });
    }
    ref.invalidate(milestonesProvider(widget.projectId));
    ref.invalidate(projectByIdProvider(widget.projectId));
    if (mounted) context.go('/admin/projects/${widget.projectId}');
  }
}
