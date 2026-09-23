import 'package:biconcept/core/widgets/permission_gate.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:biconcept/features/rbac/presentation/rbac_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders child when the role allows the permission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rbacProvider.overrideWith(
            (ref) => RbacState(
              role: UserRole.admin,
              permissions: kRolePermissions[UserRole.admin]!,
            ),
          ),
        ],
        child: const MaterialApp(
          home: PermissionGate(
            permission: Permission.userView,
            fallback: Text('hidden'),
            child: Text('allowed'),
          ),
        ),
      ),
    );
    expect(find.text('allowed'), findsOneWidget);
    expect(find.text('hidden'), findsNothing);
  });

  testWidgets('renders fallback when the role is missing the permission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rbacProvider.overrideWith(
            (ref) => const RbacState(role: UserRole.client, permissions: {}),
          ),
        ],
        child: const MaterialApp(
          home: PermissionGate(
            permission: Permission.userView,
            fallback: Text('hidden'),
            child: Text('allowed'),
          ),
        ),
      ),
    );
    expect(find.text('hidden'), findsOneWidget);
    expect(find.text('allowed'), findsNothing);
  });
}
