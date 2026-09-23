import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/result/app_result.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/domain/user.dart';
import '../../../rbac/domain/user_role.dart';
import '../providers/user_providers.dart';

class EditUserScreen extends ConsumerStatefulWidget {
  const EditUserScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  UserRole? _role;
  bool? _active;
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppResult<User>>(
      future: ref.read(userRepositoryProvider).getById(widget.userId),
      builder: (context, snapshot) {
        final user = snapshot.data?.dataOrNull;
        _role ??= user?.role;
        _active ??= user?.isActive;
        return Scaffold(
          appBar: AppBar(title: Text(user?.name ?? 'Edit user')),
          body: user == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: TextStyle(color: AppColors.down)),
                      ),
                    DropdownButtonFormField<UserRole>(
                      initialValue: _role ?? user.role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final role in UserRole.values)
                          DropdownMenuItem(value: role, child: Text(role.label)),
                      ],
                      onChanged: (value) => setState(() => _role = value),
                    ),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: _active ?? true,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : () => _save(user.role, user.isActive),
                      child: const Text('Save'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _save(UserRole previousRole, bool previousActive) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(userRepositoryProvider);
    if (_role != null && _role != previousRole) {
      final result = await repo.updateRole(userId: widget.userId, role: _role!);
      if (result.isFailure) {
        setState(() {
          _busy = false;
          _error = result.errorOrNull?.userMessage;
        });
        return;
      }
    }
    if (_active != null && _active != previousActive) {
      final result = await repo.setActive(userId: widget.userId, isActive: _active!);
      if (result.isFailure) {
        setState(() {
          _busy = false;
          _error = result.errorOrNull?.userMessage;
        });
        return;
      }
    }
    if (!mounted) return;
    ref.invalidate(userListProvider);
    context.go('/users/${widget.userId}');
  }
}
