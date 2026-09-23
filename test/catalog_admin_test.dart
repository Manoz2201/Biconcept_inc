import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/catalog/domain/catalog_repository.dart';
import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/domain/team_member.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/screens/admin/catalog_dashboard_screen.dart';
import 'package:biconcept/features/enquiries/domain/enquiry.dart';
import 'package:biconcept/features/enquiries/domain/enquiry_repository.dart';
import 'package:biconcept/features/enquiries/presentation/providers/enquiries_provider.dart';
import 'package:biconcept/features/enquiries/presentation/screens/enquiry_list_screen.dart';
import 'package:biconcept/features/enquiries/presentation/widgets/enquiry_status_badge.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:biconcept/features/rbac/presentation/rbac_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Catalog extends Fake implements CatalogRepository {
  _Catalog({this.services = const []});

  final List<ServiceItem> services;

  @override
  Future<AppResult<List<ServiceItem>>> getServices({bool activeOnly = true}) async => Success(services);

  @override
  Future<AppResult<List<PortfolioItem>>> getPortfolioItems({
    bool activeOnly = true,
    bool featuredOnly = false,
  }) async =>
      const Success([]);

  @override
  Future<AppResult<List<TeamMember>>> getTeamMembers({bool activeOnly = true}) async => const Success([]);
}

class _Enquiries extends Fake implements EnquiryRepository {
  _Enquiries(this.items);
  final List<Enquiry> items;

  @override
  Future<AppResult<List<Enquiry>>> getEnquiries({EnquiryStatus? status, String? assignedTo}) async =>
      Success(items);
}

GoRouter _router(Widget home) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(path: '/app', builder: (context, state) => const SizedBox()),
      GoRoute(path: '/admin/catalog/services/new', builder: (context, state) => const SizedBox()),
      GoRoute(path: '/admin/enquiries/:id', builder: (context, state) => const SizedBox()),
    ],
  );
}

void main() {
  testWidgets('admin catalog list shows empty and search states', (tester) async {
    final catalog = _Catalog(
      services: const [
        ServiceItem(
          id: '1',
          title: 'Kitchens',
          slug: 'kitchens',
          category: 'Interior',
          shortDescription: 'Kitchen interiors',
        ),
        ServiceItem(
          id: '2',
          title: 'Offices',
          slug: 'offices',
          category: 'Commercial',
          shortDescription: 'Workplace interiors',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(catalog),
          rbacProvider.overrideWith(
            (ref) => RbacState(role: UserRole.admin, permissions: kRolePermissions[UserRole.admin]!),
          ),
        ],
        child: MaterialApp.router(routerConfig: _router(const CatalogDashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kitchens'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'office');
    await tester.pumpAndSettle();
    expect(find.text('Offices'), findsOneWidget);
    expect(find.text('Kitchens'), findsNothing);
  });

  testWidgets('admin catalog empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_Catalog()),
          rbacProvider.overrideWith(
            (ref) => RbacState(role: UserRole.admin, permissions: kRolePermissions[UserRole.admin]!),
          ),
        ],
        child: MaterialApp.router(routerConfig: _router(const CatalogDashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-empty')), findsOneWidget);
  });

  testWidgets('public enquiry appears in the admin list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_Catalog()),
          enquiryRepositoryProvider.overrideWithValue(
            _Enquiries([
              Enquiry(
                id: 'e1',
                name: 'Asha',
                email: 'asha@example.com',
                message: 'Kitchen',
                status: EnquiryStatus.newLead,
                createdAt: DateTime(2026, 9, 11),
              ),
            ]),
          ),
          rbacProvider.overrideWith(
            (ref) => RbacState(role: UserRole.admin, permissions: kRolePermissions[UserRole.admin]!),
          ),
        ],
        child: MaterialApp.router(routerConfig: _router(const EnquiryListScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Asha'), findsOneWidget);
    expect(find.byType(EnquiryStatusBadge), findsOneWidget);
  });
}
