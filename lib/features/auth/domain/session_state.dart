import '../../../core/errors/app_exception.dart';
import 'user.dart';

class SessionState {
  const SessionState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  final User? user;
  final bool isAuthenticated;
  final bool isLoading;
  final AppError? error;

  SessionState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isLoading,
    AppError? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return SessionState(
      user: clearUser ? null : user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}
