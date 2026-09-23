import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../projects/presentation/providers/projects_provider.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../vendors/domain/line_items.dart';
import '../../../../vendors/domain/vendor.dart';
import '../../../../vendors/presentation/providers/vendors_provider.dart';

class RFQFormScreen extends ConsumerStatefulWidget {
  const RFQFormScreen({super.key, this.rfqId});

  final String? rfqId;

  @override
  ConsumerState<RFQFormScreen> createState() => _RFQFormScreenState();
}

class _RFQFormScreenState extends ConsumerState<RFQFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _projectId;
  String _category = kVendorCategories.first;
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  final _items = <CatalogLine>[CatalogLine(itemName: '', quantity: 1, unit: 'nos')];
  final _vendors = <String>{};
  var _send = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider(const ProjectQuery())).valueOrNull ?? const [];
    final vendors = ref.watch(vendorsProvider(const VendorQuery(isActive: true))).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.rfqCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('New RFQ')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            DropdownButtonFormField<String>(
              initialValue: _projectId,
              decoration: const InputDecoration(labelText: 'Project'),
              items: [
                for (final project in projects)
                  DropdownMenuItem(value: project.id, child: Text(project.title)),
              ],
              onChanged: (value) => setState(() => _projectId = value),
            ),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final item in kVendorCategories)
                  DropdownMenuItem(value: item, child: Text(vendorCategoryLabel(item))),
              ],
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            ListTile(
              title: Text('Due ${_due.toLocal().toString().split(' ').first}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: _due,
                );
                if (picked != null) setState(() => _due = picked);
              },
            ),
            const Text('Items'),
            for (var i = 0; i < _items.length; i++)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _items[i].itemName,
                      decoration: const InputDecoration(labelText: 'Item'),
                      onChanged: (value) => _items[i] = CatalogLine(
                        itemName: value,
                        quantity: _items[i].quantity,
                        unit: _items[i].unit,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _items[i].quantity.toString(),
                      decoration: const InputDecoration(labelText: 'Qty'),
                      onChanged: (value) => _items[i] = CatalogLine(
                        itemName: _items[i].itemName,
                        quantity: double.tryParse(value) ?? 1,
                        unit: _items[i].unit,
                      ),
                    ),
                  ),
                ],
              ),
            TextButton(
              onPressed: () => setState(() => _items.add(const CatalogLine(itemName: '', quantity: 1, unit: 'nos'))),
              child: const Text('Add item'),
            ),
            const Text('Invite vendors'),
            for (final vendor in vendors)
              CheckboxListTile(
                value: _vendors.contains(vendor.id),
                title: Text(vendor.companyName),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _vendors.add(vendor.id);
                  } else {
                    _vendors.remove(vendor.id);
                  }
                }),
              ),
            SwitchListTile(
              value: _send,
              onChanged: (value) => setState(() => _send = value),
              title: const Text('Save and send'),
            ),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_projectId == null || _title.text.trim().isEmpty) {
      setState(() => _error = 'Project and title are required');
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(rfqRepositoryProvider).createRFQ(
          projectId: _projectId!,
          title: _title.text,
          description: _description.text,
          category: _category,
          items: [for (final item in _items) if (item.itemName.trim().isNotEmpty) item],
          dueDate: _due,
          vendorIds: _vendors.toList(),
        );
    if (!mounted) return;
    await result.when(
      success: (rfq) async {
        if (_send) await ref.read(rfqRepositoryProvider).sendRFQ(rfq.id);
        ref.invalidate(rfqsProvider);
        if (mounted) context.go('/admin/rfqs/${rfq.id}');
      },
      failure: (error) async => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}
