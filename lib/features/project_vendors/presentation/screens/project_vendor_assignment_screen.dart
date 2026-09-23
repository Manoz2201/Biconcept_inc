import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../rbac/domain/permission.dart';
import '../../../vendors/presentation/providers/vendors_provider.dart';
import '../../../vendors/presentation/widgets/vendor_card.dart';

class ProjectVendorAssignmentScreen extends ConsumerStatefulWidget {
  const ProjectVendorAssignmentScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectVendorAssignmentScreen> createState() => _ProjectVendorAssignmentScreenState();
}

class _ProjectVendorAssignmentScreenState extends ConsumerState<ProjectVendorAssignmentScreen> {
  String? _vendorId;
  final _role = TextEditingController();

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assigned = ref.watch(projectVendorsProvider(widget.projectId)).valueOrNull ?? const [];
    final vendors = ref.watch(vendorsProvider(const VendorQuery(isActive: true))).valueOrNull ?? const [];
    return PermissionGate(
      permission: Permission.projectVendorView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Project vendors')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in assigned)
              ListTile(
                title: Text(vendors.where((vendor) => vendor.id == item.vendorId).firstOrNull?.companyName ?? item.vendorId),
                subtitle: Text(item.role ?? item.status.label),
                trailing: PermissionGate(
                  permission: Permission.projectVendorRemove,
                  child: IconButton(
                    onPressed: () async {
                      await ref.read(projectVendorRepositoryProvider).removeVendorFromProject(item.id);
                      ref.invalidate(projectVendorsProvider(widget.projectId));
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _vendorId,
              decoration: const InputDecoration(labelText: 'Add vendor'),
              items: [for (final item in vendors) DropdownMenuItem(value: item.id, child: Text(item.companyName))],
              onChanged: (value) => setState(() => _vendorId = value),
            ),
            TextField(controller: _role, decoration: const InputDecoration(labelText: 'Role')),
            PermissionGate(
              permission: Permission.projectVendorAssign,
              child: FilledButton(
                onPressed: _vendorId == null
                    ? null
                    : () async {
                        await ref.read(projectVendorRepositoryProvider).assignVendorToProject(
                              projectId: widget.projectId,
                              vendorId: _vendorId!,
                              role: _role.text.trim().isEmpty ? null : _role.text.trim(),
                            );
                        ref.invalidate(projectVendorsProvider(widget.projectId));
                      },
                child: const Text('Assign'),
              ),
            ),
            for (final vendor in vendors.take(3)) VendorCard(vendor: vendor),
          ],
        ),
      ),
    );
  }
}
