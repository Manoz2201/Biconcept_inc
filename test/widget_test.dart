import 'package:biconcept/app.dart';
import 'package:biconcept/core/errors/app_exception.dart';
import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/data/settings_store.dart';
import 'package:biconcept/features/auth/domain/auth_repository.dart';
import 'package:biconcept/features/auth/domain/user.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/branding/domain/branding_settings.dart';
import 'package:biconcept/features/catalog/domain/catalog_repository.dart';
import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/domain/team_member.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/platform/presentation/providers/platform_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoSessionAuth implements AuthRepository {
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
  Future<AppResult<void>> sendEmailVerification() async => const Success(null);

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

class _EmptyCatalog extends Fake implements CatalogRepository {
  @override
  Future<AppResult<List<ServiceItem>>> getServices({bool activeOnly = true}) async => const Success([]);

  @override
  Future<AppResult<List<PortfolioItem>>> getPortfolioItems({
    bool activeOnly = true,
    bool featuredOnly = false,
  }) async =>
      const Success([]);

  @override
  Future<AppResult<List<TeamMember>>> getTeamMembers({bool activeOnly = true}) async => const Success([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Estimate app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_NoSessionAuth()),
          catalogRepositoryProvider.overrideWithValue(_EmptyCatalog()),
          brandingSettingsProvider.overrideWith((ref) async => BrandingSettings.defaults),
        ],
        child: const BiconceptApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('DeepSeek is the default agent API', () {
    expect(SettingsStore.defaultBaseUrl, 'https://api.deepseek.com/v1');
    expect(SettingsStore.defaultModel, 'deepseek-chat');
  });
}
