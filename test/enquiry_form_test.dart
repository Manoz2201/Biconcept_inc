import 'dart:convert';

import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/auth/domain/email_validation_service.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/catalog/domain/catalog_repository.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/enquiry_form.dart';
import 'package:biconcept/features/enquiries/domain/enquiry.dart';
import 'package:biconcept/features/enquiries/domain/enquiry_repository.dart';
import 'package:biconcept/features/enquiries/presentation/enquiry_cooldown.dart';
import 'package:biconcept/features/enquiries/presentation/providers/enquiries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<AppResult<List<ServiceItem>>> getServices({bool activeOnly = true}) async => const Success([]);
}

class _Enquiries extends Fake implements EnquiryRepository {
  Enquiry? last;

  @override
  Future<AppResult<Enquiry>> submitEnquiry({
    required String name,
    required String email,
    String? phone,
    String? serviceId,
    required String message,
    String? source,
  }) async {
    last = Enquiry(
      id: 'e1',
      name: name,
      email: email,
      phone: phone,
      serviceId: serviceId,
      message: message,
      status: EnquiryStatus.newLead,
      source: source,
    );
    return Success(last!);
  }
}

class _OpenCooldown extends EnquiryCooldown {
  @override
  Future<Duration?> remaining() async => null;

  @override
  Future<void> markSubmitted() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows validation errors when the enquiry form is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_Catalog()),
          enquiryRepositoryProvider.overrideWithValue(_Enquiries()),
          enquiryCooldownProvider.overrideWithValue(_OpenCooldown()),
        ],
        child: const MaterialApp(home: Scaffold(body: EnquiryForm())),
      ),
    );
    await tester.tap(find.byKey(const Key('enquiry-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Message is required'), findsOneWidget);
  });

  testWidgets('submits after local and backend email validation', (tester) async {
    final repo = _Enquiries();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_Catalog()),
          enquiryRepositoryProvider.overrideWithValue(repo),
          enquiryCooldownProvider.overrideWithValue(_OpenCooldown()),
          emailValidationServiceProvider.overrideWithValue(
            EmailValidationService(
              execute: (email) async => jsonEncode({
                'isValid': true,
                'isDisposable': false,
                'isFreeProvider': true,
                'mxFound': true,
              }),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: EnquiryForm())),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Asha');
    await tester.enterText(find.byType(TextField).at(1), 'asha@example.com');
    await tester.enterText(find.byType(TextField).at(3), 'Need a kitchen');
    await tester.tap(find.byKey(const Key('enquiry-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enquiry-success')), findsOneWidget);
    expect(repo.last?.email, 'asha@example.com');
  });
}
