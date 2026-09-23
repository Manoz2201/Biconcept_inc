import 'package:biconcept/features/e_way_bill/domain/e_way_bill.dart';
import 'package:biconcept/features/forecasting/domain/budget.dart';
import 'package:biconcept/features/gst_audit/domain/compliance_math.dart';
import 'package:biconcept/features/gst_audit/domain/itc_ledger_entry.dart';
import 'package:biconcept/features/gst_audit/presentation/widgets/compliance_widgets.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:biconcept/features/tds/domain/tds_deduction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('194C rates and thresholds', () {
    final individual = computeTds(
      section: TdsSection.section194C,
      deducteeType: TdsDeducteeType.individual,
      grossAmount: 40000,
    );
    expect(individual.rate, 1);
    expect(individual.thresholdCrossed, isTrue);
    expect(individual.tdsAmount, 400);

    final below = computeTds(
      section: TdsSection.section194C,
      deducteeType: TdsDeducteeType.company,
      grossAmount: 20000,
      annualGross: 10000,
    );
    expect(below.thresholdCrossed, isFalse);
    expect(below.tdsAmount, 0);

    final annual = computeTds(
      section: TdsSection.section194C,
      deducteeType: TdsDeducteeType.company,
      grossAmount: 20000,
      annualGross: 90000,
    );
    expect(annual.rate, 2);
    expect(annual.thresholdCrossed, isTrue);
    expect(annual.tdsAmount, 400);
  });

  test('194J and 194I rates', () {
    expect(
      computeTds(section: TdsSection.section194J, deducteeType: TdsDeducteeType.firm, grossAmount: 60000, kind194j: Tds194JKind.technical).rate,
      2,
    );
    expect(
      computeTds(section: TdsSection.section194J, deducteeType: TdsDeducteeType.firm, grossAmount: 60000).rate,
      10,
    );
    expect(
      computeTds(section: TdsSection.section194I, deducteeType: TdsDeducteeType.firm, grossAmount: 250000, kind194i: Tds194IKind.plantMachinery).rate,
      2,
    );
    expect(
      computeTds(section: TdsSection.section194I, deducteeType: TdsDeducteeType.firm, grossAmount: 250000).rate,
      10,
    );
  });

  test('GST TDS threshold and place of supply', () {
    final below = computeGstTds(taxableValue: 100000, contractValue: 200000, interState: false);
    expect(below.applicable, isFalse);
    final intra = computeGstTds(taxableValue: 300000, contractValue: 354000, interState: false);
    expect(intra.applicable, isTrue);
    expect(intra.cgstTds, 3000);
    expect(intra.sgstTds, 3000);
    expect(intra.igstTds, 0);
    final inter = computeGstTds(taxableValue: 300000, contractValue: 354000, interState: true);
    expect(inter.igstTds, 6000);
    expect(inter.cgstTds, 0);
  });

  test('e-way bill validity and threshold', () {
    expect(ewayBillRequired(49999), isFalse);
    expect(ewayBillRequired(50001), isTrue);
    expect(ewayBillValidityDays(distanceKm: 200, overDimensional: false), 1);
    expect(ewayBillValidityDays(distanceKm: 201, overDimensional: false), 2);
    expect(ewayBillValidityDays(distanceKm: 20, overDimensional: true), 1);
    expect(ewayBillValidityDays(distanceKm: 21, overDimensional: true), 2);
    expect(ewayBillGoodsTooOld(DateTime.now().subtract(const Duration(days: 181))), isTrue);
    expect(withinHours(DateTime.now().subtract(const Duration(hours: 2)), 24), isTrue);
  });

  test('GSTR-2B matching classifies exact, suggested, and missing rows', () {
    final bundle = classifyGstr2bMatches(
      financialYear: '2026-27',
      period: '2026-04',
      importId: 'imp1',
      gstr2b: [
        Gstr2bLine(
          supplierGstin: '33AAAAA0000A1Z5',
          supplierName: 'Vendor A',
          invoiceNumber: 'B-1',
          invoiceDate: DateTime(2026, 4, 2),
          taxableValue: 10000,
          cgst: 900,
          sgst: 900,
          igst: 0,
        ),
        Gstr2bLine(
          supplierGstin: '33BBBBB0000B1Z5',
          supplierName: 'Vendor B',
          invoiceNumber: 'B-2',
          invoiceDate: DateTime(2026, 4, 3),
          taxableValue: 8000,
          cgst: 720,
          sgst: 720,
          igst: 0,
        ),
      ],
      books: [
        PurchaseRegisterLine(
          billId: 'bill-1',
          supplierGstin: '33AAAAA0000A1Z5',
          supplierName: 'Vendor A',
          invoiceNumber: 'B-1',
          invoiceDate: DateTime(2026, 4, 2),
          taxableValue: 10000,
          taxAmount: 1800,
        ),
        PurchaseRegisterLine(
          billId: 'bill-3',
          supplierGstin: '33CCCCC0000C1Z5',
          supplierName: 'Vendor C',
          invoiceNumber: 'B-3',
          invoiceDate: DateTime(2026, 4, 4),
          taxableValue: 5000,
          taxAmount: 900,
        ),
      ],
    );
    expect(bundle.result.exactMatches, 1);
    expect(bundle.result.missingInBooks, 1);
    expect(bundle.result.missingIn2b, 1);
    expect(bundle.entries.any((item) => item.matchStatus == MatchStatus.exactMatch), isTrue);
    expect(bundle.entries.any((item) => item.matchStatus == MatchStatus.missingInBooks), isTrue);
    expect(bundle.entries.any((item) => item.matchStatus == MatchStatus.missingIn2b), isTrue);
  });

  test('parse official GSTR-2B JSON', () {
    final lines = parseGstr2bJson({
      'b2b': [
        {
          'ctin': '33AAAAA0000A1Z5',
          'trdnm': 'Vendor A',
          'inv': [
            {
              'inum': 'INV1',
              'idt': '02-04-2026',
              'itms': [
                {
                  'itm_det': {'txval': 1000, 'camt': 90, 'samt': 90, 'iamt': 0},
                },
              ],
            },
          ],
        },
      ],
    });
    expect(lines, hasLength(1));
    expect(lines.first.taxableValue, 1000);
    expect(lines.first.totalTax, 180);
  });

  test('budget variance percent', () {
    final variance = 100000 - 120000;
    final percent = (variance / 100000) * 100;
    expect(percent, -20);
    expect(percent.abs() > 10, isTrue);
  });

  test('revenue forecast grows from history', () {
    final projected = projectSeries(
      history: const [MonthlyPoint(period: '2026-03', amount: 100)],
      months: 2,
      monthlyGrowth: 0.05,
    );
    expect(projected, hasLength(2));
    expect(projected.first.amount, closeTo(105, 0.01));
  });

  test('phase 7 role mapping', () {
    expect(hasPermission(UserRole.admin, Permission.eInvoiceCancel), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.gstr2bReconcile), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.eInvoiceCancel), isFalse);
    expect(hasPermission(UserRole.accountant, Permission.budgetApprove), isFalse);
    expect(hasPermission(UserRole.architect, Permission.budgetView), isTrue);
    expect(hasPermission(UserRole.architect, Permission.itcLedgerView), isFalse);
    expect(hasPermission(UserRole.client, Permission.auditDashboardView), isFalse);
    expect(hasPermission(UserRole.vendor, Permission.tdsView), isFalse);
    expect(kRolePermissions[UserRole.superAdmin], containsAll(Permission.values));
  });

  testWidgets('ITC status badge renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ItcStatusBadge(status: ITCStatus.claimed)),
      ),
    );
    expect(find.text('Claimed'), findsOneWidget);
  });

  test('e-way bill display status expires', () {
    final bill = EWayBill(
      id: '1',
      invoiceNumber: 'INV/1',
      invoiceDate: DateTime(2026, 4, 1),
      supplyType: EwbSupplyType.outward,
      subSupplyType: EwbSubSupplyType.supply,
      documentType: EwbDocumentType.taxInvoice,
      fromGstin: '33AAAAA0000A1Z5',
      fromAddress: 'A',
      fromPlace: 'Chennai',
      fromPincode: '600001',
      fromStateCode: '33',
      toAddress: 'B',
      toPlace: 'Madurai',
      toPincode: '625001',
      toStateCode: '33',
      totalValue: 60000,
      taxableValue: 50000,
      hsnCode: '9983',
      status: EWayBillStatus.generated,
      validUntil: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(bill.displayStatus, EWayBillStatus.expired);
  });

  test('budget json round trip', () {
    final now = DateTime.utc(2026, 4, 1);
    final budget = Budget(
      id: 'b1',
      financialYear: '2026-27',
      category: BudgetCategory.expense,
      budgetedAmount: 10,
      status: BudgetStatus.draft,
      createdAt: now,
    );
    expect(Budget.fromJson(budget.toJson()).budgetedAmount, 10);
  });
}
