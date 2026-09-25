import 'package:biconcept/core/errors/app_exception.dart';
import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/auth/domain/auth_repository.dart';
import 'package:biconcept/features/auth/domain/session_state.dart';
import 'package:biconcept/features/auth/domain/user.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _VerifyRepo implements AuthRepository {
  var sent = 0;

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
    String? clientId,
    String? vendorId,
  }) async =>
      const Failure(AppError(message: 'unused'));

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
  Future<AppResult<void>> sendEmailVerification() async {
    sent++;
    return const Success(null);
  }

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

class _Session extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      isAuthenticated: true,
      user: User(
        id: '1',
        accountId: 'acc',
        name: 'Manoj',
        email: 'manoj@biconcept.in',
        role: UserRole.admin,
      ),
    );
  }
}

void main() {
  testWidgets('resend starts a 60 second cooldown', (tester) async {
    final repo = _VerifyRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          sessionControllerProvider.overrideWith(_Session.new),
        ],
        child: const MaterialApp(home: VerifyEmailScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Resend link'));
    await tester.pump();
    expect(repo.sent, 1);
    expect(find.text('Resend in 60s'), findsOneWidget);
  });
}
