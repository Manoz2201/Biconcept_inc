import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../rbac/domain/user_role.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/project_status.dart';
import '../../providers/projects_provider.dart';
import '../../widgets/project_card.dart';

class AdminProjectsScreen extends ConsumerStatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  ConsumerState<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends ConsumerState<AdminProjectsScreen> {
  final _search = TextEditingController();
  ProjectStatus? _status;
  String? _architect;
  var _grid = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ProjectQuery(status: _status, assignedArchitect: _architect, search: _search.text);
    final async = ref.watch(projectsProvider(query));
    final staff = ref.watch(userListProvider).valueOrNull?.users ?? const [];
    return PermissionGate(
      permission: Permission.projectView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Projects'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/app')),
          actions: [
            IconButton(
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            ),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.projectCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/projects/new'),
            label: const Text('New Project'),
            icon: const Icon(Icons.add),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: 'Search title', prefixIcon: Icon(Icons.search)),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                  for (final status in ProjectStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: _architect,
                    hint: const Text('Architect'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All architects')),
                      for (final user in staff.where((item) => item.role == UserRole.architect || item.role.isStaff))
                        DropdownMenuItem(value: user.accountId, child: Text(user.name)),
                    ],
                    onChanged: (value) => setState(() => _architect = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (items) {
                  if (items.isEmpty) return const Center(child: Text('No projects yet'));
                  if (_grid) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => ProjectCard(
                        project: items[index],
                        onTap: () => context.push('/admin/projects/${items[index].id}'),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) => ProjectCard(
                      project: items[index],
                      onTap: () => context.push('/admin/projects/${items[index].id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
