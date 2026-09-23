import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../../theme/app_theme.dart';
import '../../../rbac/domain/permission.dart';
import '../../../rbac/domain/user_role.dart';
import '../providers/user_providers.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  final _search = TextEditingController();
  UserRole? _role;
  bool? _active;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app'),
        ),
        actions: [
          PermissionGate(
            permission: Permission.userCreate,
            child: IconButton(
              tooltip: 'Invite',
              onPressed: () => context.push('/users/invite'),
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search name or email',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _apply(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All roles'),
                  selected: _role == null,
                  onSelected: (_) {
                    setState(() => _role = null);
                    _apply();
                  },
                ),
                const SizedBox(width: 8),
                for (final role in UserRole.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(role.label),
                      selected: _role == role,
                      onSelected: (_) {
                        setState(() => _role = role);
                        _apply();
                      },
                    ),
                  ),
                FilterChip(
                  label: const Text('Active'),
                  selected: _active == true,
                  onSelected: (selected) {
                    setState(() => _active = selected ? true : null);
                    _apply();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (page) {
                final users = page.users;
                if (users.isEmpty) {
                  return Center(
                    child: Text('No users match this filter', style: TextStyle(color: AppColors.muted)),
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text('${user.email} · ${user.role.label}'),
                      trailing: Text(user.isActive ? 'Active' : 'Inactive'),
                      onTap: () => context.push('/users/${user.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _apply() {
    ref.read(userListProvider.notifier).apply(
          UserListQuery(search: _search.text, role: _role, isActive: _active),
        );
  }
}
