import 'package:biconcept/core/errors/app_exception.dart';
import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/auth/domain/auth_repository.dart';
import 'package:biconcept/features/auth/domain/user.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/catalog/domain/catalog_repository.dart';
import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/domain/storage_repository.dart';
import 'package:biconcept/features/catalog/domain/team_member.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/screens/public/home_screen.dart';
import 'package:biconcept/features/enquiries/domain/enquiry.dart';
import 'package:biconcept/features/enquiries/domain/enquiry_repository.dart';
import 'package:biconcept/features/enquiries/presentation/enquiry_cooldown.dart';
import 'package:biconcept/features/enquiries/presentation/providers/enquiries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Fake implements AuthRepository {
  @override
  Future<AppResult<User?>> getCurrentUser() async => const Success(null);
}

class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<AppResult<List<ServiceItem>>> getServices({bool activeOnly = true}) async => const Success([
        ServiceItem(
          id: 'svc1',
          title: 'Turnkey home interiors',
          slug: 'turnkey-home-interiors',
          category: 'Interiors',
          shortDescription: 'Design plus execution for the full home.',
          startingPrice: 1800,
          priceUnit: 'sqft',
        ),
      ]);

  @override
  Future<AppResult<List<PortfolioItem>>> getPortfolioItems({
    bool activeOnly = true,
    bool featuredOnly = false,
  }) async =>
      const Success([
        PortfolioItem(
          id: 'p1',
          title: 'Sector 59 residence',
          slug: 'sector-59-residence',
          projectType: 'Residential',
          location: 'Noida',
          area: '2400 sqft',
          year: 2025,
          coverImageId: '',
        ),
      ]);

  @override
  Future<AppResult<List<TeamMember>>> getTeamMembers({bool activeOnly = true}) async => const Success([]);
}

class _Storage extends Fake implements StorageRepository {
  @override
  String getFilePreviewUrl(String bucketId, String fileId, {int? width, int? height}) =>
      'https://example.com/$fileId';

  @override
  String getFileViewUrl(String bucketId, String fileId) => 'https://example.com/$fileId';
}

class _Enquiries extends Fake implements EnquiryRepository {
  @override
  Future<AppResult<Enquiry>> submitEnquiry({
    required String name,
    required String email,
    String? phone,
    String? serviceId,
    required String message,
    String? source,
  }) async =>
      const Failure(AppError(message: 'unused'));
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

  testWidgets('entry page shows studio story, services, requirements, and login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('login-page'))),
        GoRoute(path: '/register', builder: (context, state) => const Scaffold(body: Text('register-page'))),
        GoRoute(path: '/services', builder: (context, state) => const Scaffold(body: Text('services-page'))),
        GoRoute(path: '/portfolio', builder: (context, state) => const Scaffold(body: Text('portfolio-page'))),
        GoRoute(path: '/about', builder: (context, state) => const Scaffold(body: Text('about-page'))),
        GoRoute(path: '/contact', builder: (context, state) => const Scaffold(body: Text('contact-page'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Auth()),
          catalogRepositoryProvider.overrideWithValue(_Catalog()),
          storageRepositoryProvider.overrideWithValue(_Storage()),
          enquiryRepositoryProvider.overrideWithValue(_Enquiries()),
          enquiryCooldownProvider.overrideWithValue(_OpenCooldown()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Homes designed as one complete whole'), findsOneWidget);
    expect(find.byKey(const Key('landing-login')), findsOneWidget);
    expect(find.byKey(const Key('public-login')), findsOneWidget);
    expect(find.byKey(const Key('landing-start-project')), findsOneWidget);

    await tester.tap(find.byKey(const Key('landing-start-project')));
    await tester.pumpAndSettle();
    expect(find.text('Start with a conversation.'), findsOneWidget);
    expect(find.text('Name'), findsWidgets);

    await tester.tap(find.byKey(const Key('public-login')));
    await tester.pumpAndSettle();
    expect(find.text('login-page'), findsOneWidget);
  });
}
