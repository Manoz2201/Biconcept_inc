import 'package:biconcept/core/errors/app_exception.dart';
import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/auth/domain/auth_repository.dart';
import 'package:biconcept/features/auth/domain/user.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/auth/presentation/screens/register_screen.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AppResult<User>> login(String email, String password) async =>
      const Failure(AppError(message: 'unused'));

  @override
  Future<AppResult<void>> logout() async => const Success(null);

  @override
  Future<AppResult<User>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? teamId,
    String? membershipId,
    String? userId,
    String? secret,
  }) async =>
      Success(
        User(
          id: '1',
          accountId: 'acc',
          name: name,
          email: email,
          role: UserRole.client,
        ),
      );

  @override
  Future<AppResult<void>> sendPasswordReset(String email) async => const Success(null);

  @override
  Future<AppResult<void>> completePasswordReset({
    required String userId,
    required String secret,
    required String password,
  }) async =>
      const Success(null);

  @override
  Future<AppResult<void>> sendEmailVerification() async => const Success(null);

  @override
  Future<AppResult<void>> verifyEmail({required String userId, required String secret}) async =>
      const Success(null);

  @override
  Future<AppResult<User?>> getCurrentUser() async => const Success(null);

  @override
  Future<AppResult<void>> refreshSession() async => const Success(null);

  @override
  Future<AppResult<User>> updateProfile({required String name, String? phone}) async =>
      const Failure(AppError(message: 'unused'));

  @override
  Future<AppResult<void>> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async =>
      const Success(null);
}

void main() {
  testWidgets('shows the client sign-up form without an invite', (tester) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/login', builder: (context, state) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Invite only'), findsNothing);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
