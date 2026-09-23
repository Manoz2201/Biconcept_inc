import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/core/widgets/permission_gate.dart';
import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/domain/team_member.dart';
import 'package:biconcept/features/catalog/presentation/providers/portfolio_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/team_provider.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/theme/app_theme.dart';

class CatalogDashboardScreen extends ConsumerStatefulWidget {
  const CatalogDashboardScreen({super.key});

  @override
  ConsumerState<CatalogDashboardScreen> createState() => _CatalogDashboardScreenState();
}

class _CatalogDashboardScreenState extends ConsumerState<CatalogDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.catalogView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catalog'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/app'),
          ),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Services'),
              Tab(text: 'Portfolio'),
              Tab(text: 'Team'),
            ],
          ),
          actions: [
            PermissionGate(
              permission: Permission.catalogCreate,
              child: IconButton(
                tooltip: 'Add new',
                onPressed: () {
                  final path = switch (_tabs.index) {
                    1 => '/admin/catalog/portfolio/new',
                    2 => '/admin/catalog/team/new',
                    _ => '/admin/catalog/services/new',
                  };
                  context.push(path);
                },
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ServicesTab(query: _search.text),
                  _PortfolioTab(query: _search.text),
                  _TeamTab(query: _search.text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesTab extends ConsumerWidget {
  const _ServicesTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminServicesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        final q = query.trim().toLowerCase();
        final visible = q.isEmpty
            ? items
            : items.where((item) => item.title.toLowerCase().contains(q) || item.category.toLowerCase().contains(q)).toList();
        if (visible.isEmpty) {
          return Center(key: Key('catalog-empty'), child: Text('No services yet', style: TextStyle(color: AppColors.muted)));
        }
        return ListView.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final item = visible[index];
            return ListTile(
              title: Text(item.title),
              subtitle: Text('${item.category}${item.isActive ? '' : ' · inactive'}'),
              onTap: item.id.startsWith('svc_') ? null : () => context.push('/admin/catalog/services/${item.id}'),
              trailing: item.id.startsWith('svc_')
                  ? Text('Built-in', style: TextStyle(color: AppColors.muted, fontSize: 12))
                  : _RowActions(
                      isActive: item.isActive,
                      onToggle: () => _toggleService(ref, item),
                      onEdit: () => context.push('/admin/catalog/services/${item.id}'),
                      onDelete: () => _confirmDelete(context, () async {
                        await ref.read(catalogRepositoryProvider).deleteService(item.id);
                        ref.invalidate(adminServicesProvider);
                        ref.invalidate(publicServicesProvider);
                      }),
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleService(WidgetRef ref, ServiceItem item) async {
    await ref.read(catalogRepositoryProvider).updateService(item.id, {'isActive': !item.isActive});
    ref.invalidate(adminServicesProvider);
    ref.invalidate(publicServicesProvider);
  }
}

class _PortfolioTab extends ConsumerWidget {
  const _PortfolioTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPortfolioProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        final q = query.trim().toLowerCase();
        final visible = q.isEmpty
            ? items
            : items.where((item) => item.title.toLowerCase().contains(q) || item.projectType.toLowerCase().contains(q)).toList();
        if (visible.isEmpty) {
          return Center(key: Key('catalog-empty'), child: Text('No portfolio items yet', style: TextStyle(color: AppColors.muted)));
        }
        return ListView.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final item = visible[index];
            return ListTile(
              title: Text(item.title),
              subtitle: Text('${item.projectType}${item.isActive ? '' : ' · inactive'}'),
              onTap: () => context.push('/admin/catalog/portfolio/${item.id}'),
              trailing: _RowActions(
                isActive: item.isActive,
                onToggle: () => _toggle(ref, item),
                onEdit: () => context.push('/admin/catalog/portfolio/${item.id}'),
                onDelete: () => _confirmDelete(context, () async {
                  await ref.read(catalogRepositoryProvider).deletePortfolioItem(item.id);
                  ref.invalidate(adminPortfolioProvider);
                  ref.invalidate(publicPortfolioProvider);
                  ref.invalidate(featuredPortfolioProvider);
                }),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggle(WidgetRef ref, PortfolioItem item) async {
    await ref.read(catalogRepositoryProvider).updatePortfolioItem(item.id, {'isActive': !item.isActive});
    ref.invalidate(adminPortfolioProvider);
    ref.invalidate(publicPortfolioProvider);
    ref.invalidate(featuredPortfolioProvider);
  }
}

class _TeamTab extends ConsumerWidget {
  const _TeamTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminTeamProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        final q = query.trim().toLowerCase();
        final visible = q.isEmpty
            ? items
            : items.where((item) => item.name.toLowerCase().contains(q) || item.role.toLowerCase().contains(q)).toList();
        if (visible.isEmpty) {
          return Center(key: Key('catalog-empty'), child: Text('No team members yet', style: TextStyle(color: AppColors.muted)));
        }
        return ListView.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final item = visible[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.role}${item.isActive ? '' : ' · inactive'}'),
              onTap: () => context.push('/admin/catalog/team/${item.id}'),
              trailing: _RowActions(
                isActive: item.isActive,
                onToggle: () => _toggle(ref, item),
                onEdit: () => context.push('/admin/catalog/team/${item.id}'),
                onDelete: () => _confirmDelete(context, () async {
                  await ref.read(catalogRepositoryProvider).deleteTeamMember(item.id);
                  ref.invalidate(adminTeamProvider);
                  ref.invalidate(publicTeamProvider);
                }),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggle(WidgetRef ref, TeamMember item) async {
    await ref.read(catalogRepositoryProvider).updateTeamMember(item.id, {'isActive': !item.isActive});
    ref.invalidate(adminTeamProvider);
    ref.invalidate(publicTeamProvider);
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.isActive,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isActive;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PermissionGate(
          permission: Permission.catalogEdit,
          child: IconButton(
            tooltip: isActive ? 'Deactivate' : 'Activate',
            onPressed: onToggle,
            icon: Icon(isActive ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
        PermissionGate(
          permission: Permission.catalogEdit,
          child: IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
        ),
        PermissionGate(
          permission: Permission.catalogDelete,
          child: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
        ),
      ],
    );
  }
}

Future<void> _confirmDelete(BuildContext context, Future<void> Function() action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this item?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok == true) await action();
}
