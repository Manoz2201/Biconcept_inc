import '../errors/app_exception.dart';

sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => null,
      };

  AppError? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final error) => error,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      Failure<T>(:final error) => failure(error),
    };
  }
}

class Success<T> extends AppResult<T> {
  const Success(this.data);
  final T data;
}

class Failure<T> extends AppResult<T> {
  const Failure(this.error);
  final AppError error;
}
