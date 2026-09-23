import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/result/app_result.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/domain/user.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/user_repository.dart';
import '../providers/user_providers.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AppResult<User>>(
      future: ref.read(userRepositoryProvider).getById(userId),
      builder: (context, snapshot) {
        final result = snapshot.data;
        final user = result?.dataOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(user?.name ?? 'User'),
            actions: [
              PermissionGate(
                permission: Permission.userEdit,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/users/$userId/edit'),
                ),
              ),
            ],
          ),
          body: user == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(user.email, style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    Text('Role: ${user.role.label}'),
                    Text('Status: ${user.isActive ? 'Active' : 'Inactive'}'),
                    Text('Email verified: ${user.emailVerified ? 'Yes' : 'No'}'),
                    if (user.clientId != null) Text('Linked client: ${user.clientId}'),
                    if (user.vendorId != null) Text('Linked vendor: ${user.vendorId}'),
                    const SizedBox(height: 24),
                    PermissionGate(
                      permission: Permission.auditLogView,
                      child: _AuditList(userId: user.accountId),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _AuditList extends ConsumerWidget {
  const _AuditList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AppResult<List<AuditEvent>>>(
      future: ref.read(userRepositoryProvider).listAuditLogs(userId),
      builder: (context, snapshot) {
        final logs = snapshot.data?.dataOrNull ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Text('No audit events', style: TextStyle(color: AppColors.muted))
            else
              for (final event in logs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event.action.replaceAll('_', ' ')),
                  subtitle: Text(event.timestamp.toLocal().toString()),
                ),
          ],
        );
      },
    );
  }
}
