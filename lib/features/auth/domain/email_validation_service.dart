import 'dart:convert';

import 'package:email_validator/email_validator.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/result/app_result.dart';
import 'email_validation_result.dart';

typedef EmailFunctionExecutor = Future<String> Function(String email);

class EmailValidationService {
  EmailValidationService({required this.execute});

  final EmailFunctionExecutor execute;

  bool validateLocally(String email) => EmailValidator.validate(email.trim());

  Future<AppResult<EmailValidationResult>> validateWithBackend(String email) async {
    final trimmed = email.trim();
    if (!validateLocally(trimmed)) {
      return const Failure(
        AppError(
          message: 'Enter a valid email address',
          type: AppErrorType.validation,
        ),
      );
    }
    try {
      final raw = await execute(trimmed);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(
          AppError(message: 'Unexpected validation response', type: AppErrorType.unknown),
        );
      }
      if (decoded['error'] != null && decoded['isValid'] == null) {
        return Failure(
          AppError(
            message: decoded['error'].toString(),
            type: AppErrorType.validation,
          ),
        );
      }
      return Success(EmailValidationResult.fromJson(decoded));
    } catch (error) {
      return Failure(
        AppError(
          message: 'Could not validate this email right now',
          type: AppErrorType.network,
        ),
      );
    }
  }

  String? hardBlockMessage(EmailValidationResult result) {
    if (result.isDisposable) {
      return 'Disposable email addresses are not allowed';
    }
    if (!result.isValid) {
      return result.reason ?? 'This email cannot be used';
    }
    return null;
  }

  String? warningMessage(EmailValidationResult result) {
    if (result.suggestion != null && result.suggestion!.isNotEmpty) {
      return 'Did you mean ${result.suggestion}?';
    }
    if (!result.mxFound) {
      return 'Email domain is not reachable';
    }
    return null;
  }
}
