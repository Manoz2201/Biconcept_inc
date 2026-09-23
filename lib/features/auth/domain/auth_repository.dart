import '../../../core/result/app_result.dart';
import 'user.dart';

abstract class AuthRepository {
  Future<AppResult<User>> login(String email, String password);

  Future<AppResult<void>> logout();

  Future<AppResult<User>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? teamId,
    String? membershipId,
    String? userId,
    String? secret,
  });

  Future<AppResult<void>> sendPasswordReset(String email);

  Future<AppResult<void>> completePasswordReset({
    required String userId,
    required String secret,
    required String password,
  });

  Future<AppResult<void>> sendEmailVerification();

  Future<AppResult<void>> verifyEmail({
    required String userId,
    required String secret,
  });

  Future<AppResult<User?>> getCurrentUser();

  Future<AppResult<void>> refreshSession();

  Future<AppResult<User>> updateProfile({required String name, String? phone});

  Future<AppResult<void>> updatePassword({
    required String oldPassword,
    required String newPassword,
  });
}
