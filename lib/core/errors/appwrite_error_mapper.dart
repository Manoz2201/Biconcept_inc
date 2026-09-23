import 'package:appwrite/appwrite.dart';

import 'app_exception.dart';

class AppwriteErrorMapper {
  const AppwriteErrorMapper._();

  static AppError fromAppwrite(AppwriteException error) {
    final code = error.code;
    final kind = error.type ?? '';
    final loginFailed = kind == 'user_invalid_credentials';
    final type = switch (code) {
      401 => loginFailed ? AppErrorType.auth : AppErrorType.permission,
      403 => AppErrorType.permission,
      409 => AppErrorType.validation,
      429 => AppErrorType.network,
      0 || null => AppErrorType.network,
      _ => AppErrorType.unknown,
    };
    final raw = error.message?.trim() ?? '';
    return AppError(
      message: loginFailed
          ? 'Invalid credentials'
          : raw.isNotEmpty
              ? raw
              : 'Something went wrong. Please try again',
      code: code,
      type: type,
    );
  }

  static AppError unknown(Object error) {
    return AppError(
      message: error.toString(),
      type: AppErrorType.unknown,
    );
  }
}
