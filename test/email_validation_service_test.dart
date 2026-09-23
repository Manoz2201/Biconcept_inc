import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/auth/domain/email_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validateLocally rejects malformed addresses', () {
    final service = EmailValidationService(execute: (_) async => '{}');
    expect(service.validateLocally('not-an-email'), isFalse);
    expect(service.validateLocally('architect@biconcept.in'), isTrue);
  });

  test('parses a backend JSON payload', () async {
    final service = EmailValidationService(
      execute: (_) async => '''
        {
          "isValid": true,
          "isDisposable": false,
          "isFreeProvider": true,
          "mxFound": true,
          "suggestion": "architect@biconcept.in",
          "reason": null
        }
      ''',
    );
    final result = await service.validateWithBackend('architec@biconcept.in');
    final data = result.dataOrNull!;
    expect(data.isValid, isTrue);
    expect(data.isFreeProvider, isTrue);
    expect(data.suggestion, 'architect@biconcept.in');
    expect(service.warningMessage(data), contains('Did you mean'));
  });

  test('hard-blocks disposable addresses', () async {
    final service = EmailValidationService(
      execute: (_) async => '{"isValid":false,"isDisposable":true,"isFreeProvider":false,"mxFound":false}',
    );
    final result = await service.validateWithBackend('temp@mailinator.com');
    expect(service.hardBlockMessage(result.dataOrNull!), contains('Disposable'));
  });

  test('warns when MX is missing', () async {
    final service = EmailValidationService(
      execute: (_) async => '{"isValid":true,"isDisposable":false,"isFreeProvider":false,"mxFound":false}',
    );
    final result = await service.validateWithBackend('name@no-mx.example');
    expect(service.warningMessage(result.dataOrNull!), contains('not reachable'));
  });

  test('returns a validation failure when the function payload is an error object', () async {
    final service = EmailValidationService(
      execute: (_) async => '{"error":"email required"}',
    );
    final result = await service.validateWithBackend('ok@biconcept.in');
    expect(result, isA<Failure<dynamic>>());
  });
}
