import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appwrite/appwrite_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/result/app_result.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/audit_repository.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';
import '../../domain/email_validation_service.dart';
import '../../domain/session_state.dart';
import '../../domain/user.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    account: AppwriteService.account,
    tables: AppwriteService.tables,
    teams: AppwriteService.teams,
    audit: ref.watch(auditRepositoryProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

final emailValidationServiceProvider = Provider<EmailValidationService>((ref) {
  return EmailValidationService(
    execute: (email) async {
      final execution = await AppwriteService.functions.createExecution(
        functionId: AppwriteService.validateFn,
        body: jsonEncode({'email': email}),
      );
      final body = execution.responseBody;
      if (body.isEmpty) {
        throw AppwriteException('Empty validation response', 500);
      }
      return body;
    },
  );
});

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState(isLoading: true);
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restore() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getCurrentUser();
    state = result.when(
      success: (user) {
        if (user == null) {
          return const SessionState();
        }
        if (!user.isActive) {
          return const SessionState(
            error: AppError(
              message: 'This account has been deactivated',
              type: AppErrorType.permission,
              code: 403,
            ),
          );
        }
        return SessionState(user: user, isAuthenticated: true);
      },
      failure: (error) {
        if (error.isUnauthorized) {
          return const SessionState();
        }
        return SessionState(error: error);
      },
    );
  }

  Future<AppResult<User>> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.login(email, password);
    result.when(
      success: (user) {
        state = SessionState(user: user, isAuthenticated: true);
      },
      failure: (error) {
        state = SessionState(error: error);
      },
    );
    return result;
  }

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
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.register(
          email: email,
          password: password,
          name: name,
          phone: phone,
          teamId: teamId,
          membershipId: membershipId,
          userId: userId,
          secret: secret,
          clientId: clientId,
          vendorId: vendorId,
        );
    result.when(
      success: (user) => state = SessionState(user: user, isAuthenticated: true),
      failure: (error) => state = SessionState(error: error),
    );
    return result;
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const SessionState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<AppResult<User>> updateProfile({required String name, String? phone}) async {
    final result = await _repo.updateProfile(name: name, phone: phone);
    result.when(
      success: (user) => state = SessionState(user: user, isAuthenticated: true),
      failure: (error) => state = state.copyWith(error: error),
    );
    return result;
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
