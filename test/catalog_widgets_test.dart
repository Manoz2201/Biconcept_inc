import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
import 'package:biconcept/features/catalog/domain/storage_repository.dart';
import 'package:biconcept/features/catalog/domain/team_member.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/portfolio_card.dart';
import 'package:biconcept/features/catalog/presentation/widgets/service_card.dart';
import 'package:biconcept/features/catalog/presentation/widgets/team_member_card.dart';
import 'package:biconcept/features/enquiries/domain/enquiry.dart';
import 'package:biconcept/features/enquiries/presentation/widgets/enquiry_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends Fake implements StorageRepository {
  @override
  String getFilePreviewUrl(String bucketId, String fileId, {int? width, int? height}) =>
      'https://example.com/$fileId';

  @override
  String getFileViewUrl(String bucketId, String fileId) => 'https://example.com/$fileId';
}

void main() {
  testWidgets('ServiceCard shows title, copy, and price', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceCard(
          item: const ServiceItem(
            id: '1',
            title: 'Interiors',
            slug: 'interiors',
            category: 'Interior',
            shortDescription: 'Full-home interiors',
            startingPrice: 1200000,
            priceUnit: 'project',
          ),
        ),
      ),
    );
    expect(find.text('Interiors'), findsOneWidget);
    expect(find.text('Full-home interiors'), findsOneWidget);
    expect(find.textContaining('1200000'), findsOneWidget);
  });

  testWidgets('PortfolioCard and TeamMemberCard render titles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageRepositoryProvider.overrideWithValue(_Storage()),
        ],
        child: MaterialApp(
          home: SingleChildScrollView(
            child: Column(
              children: const [
                PortfolioCard(
                  item: PortfolioItem(
                    id: 'p1',
                    title: 'Noida villa',
                    slug: 'noida-villa',
                    projectType: 'Residential',
                    location: 'Noida',
                    coverImageId: 'img-1',
                  ),
                ),
                TeamMemberCard(
                  member: TeamMember(id: 't1', name: 'Manoj', role: 'Principal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Noida villa'), findsOneWidget);
    expect(find.text('Manoj'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
  });

  testWidgets('EnquiryStatusBadge uses the status label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EnquiryStatusBadge(status: EnquiryStatus.qualified)),
    );
    expect(find.text('Qualified'), findsOneWidget);
  });
}
