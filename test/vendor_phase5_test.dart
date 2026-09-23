import 'package:biconcept/core/appwrite/row_permissions.dart';
import 'package:biconcept/features/purchase_orders/domain/purchase_order.dart';
import 'package:biconcept/features/rfqs/domain/rfq.dart';
import 'package:biconcept/features/vendors/domain/vendor_rating.dart';
import 'package:biconcept/features/vendors/presentation/widgets/vendor_card.dart';
import 'package:biconcept/features/vendors/domain/vendor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GSTIN, PAN, and IFSC validation', () {
    expect(isValidGstin(null), isTrue);
    expect(isValidGstin('27AAPFU0939F1ZV'), isTrue);
    expect(isValidGstin('bad'), isFalse);
    expect(isValidPan('ABCDE1234F'), isTrue);
    expect(isValidPan('abc'), isFalse);
    expect(isValidIfsc('SBIN0001234'), isTrue);
    expect(isValidIfsc('SBIN123'), isFalse);
  });

  test('priced totals include GST', () {
    final totals = pricedTotals(const [(quantity: 2, rate: 100)], 18);
    expect(totals.subtotal, 200);
    expect(totals.taxAmount, 36);
    expect(totals.total, 236);
  });

  test('rating average and overall score', () {
    expect(overallFromScores(quality: 5, timeliness: 3, communication: 4, cost: 4), 4);
    expect(
      ratingAverage(const [
        VendorRating(
          id: '1',
          vendorId: 'v',
          projectId: 'p',
          ratedBy: 'u',
          qualityScore: 4,
          timelinessScore: 4,
          communicationScore: 4,
          costScore: 4,
          overallScore: 4,
        ),
        VendorRating(
          id: '2',
          vendorId: 'v',
          projectId: 'p2',
          ratedBy: 'u',
          qualityScore: 2,
          timelinessScore: 2,
          communicationScore: 2,
          costScore: 2,
          overallScore: 2,
        ),
      ]),
      3,
    );
  });

  test('RFQ and PO status transitions', () {
    expect(RFQStatus.draft.canTransitionTo(RFQStatus.sent), isTrue);
    expect(RFQStatus.underReview.canTransitionTo(RFQStatus.awarded), isTrue);
    expect(RFQStatus.awarded.canTransitionTo(RFQStatus.cancelled), isFalse);
    expect(PurchaseOrderStatus.draft.canTransitionTo(PurchaseOrderStatus.issued), isTrue);
    expect(PurchaseOrderStatus.issued.canTransitionTo(PurchaseOrderStatus.acknowledged), isTrue);
    expect(PurchaseOrderStatus.completed.canTransitionTo(PurchaseOrderStatus.issued), isFalse);
  });

  testWidgets('VendorCard shows company and rating', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VendorCard(
            vendor: Vendor(
              id: 'v1',
              companyName: 'Steel Works',
              contactPerson: 'Ravi',
              email: 'ravi@example.com',
              phone: '999',
              address: '1 Main',
              city: 'Chennai',
              state: 'TN',
              pincode: '600001',
              categories: ['civil'],
              rating: 4.5,
              totalRatings: 2,
              isVerified: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Steel Works'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });
}
