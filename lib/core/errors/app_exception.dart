enum AppErrorType { network, auth, permission, validation, unknown }

class AppError {
  const AppError({
    required this.message,
    this.code,
    this.type = AppErrorType.unknown,
  });

  final String message;
  final int? code;
  final AppErrorType type;

  bool get isUnauthorized => code == 401 || type == AppErrorType.auth;
  bool get isForbidden => code == 403 || type == AppErrorType.permission;
  bool get isRateLimited => code == 429;

  String get userMessage {
    if (type == AppErrorType.auth) return 'Invalid credentials';
    if (code == 401 || code == 403 || type == AppErrorType.permission) {
      if (message.toLowerCase().contains('credential')) {
        return 'Could not save. Sign out, sign in, and try again.';
      }
      return message.trim().isEmpty ? 'You do not have permission to do that' : message;
    }
    if (code == 409) return 'That record already exists';
    if (code == 429) return 'Too many attempts. Try again shortly';
    return message;
  }
}
