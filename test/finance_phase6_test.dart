import 'package:biconcept/features/gst/domain/gst_math.dart';
import 'package:biconcept/features/invoices/domain/invoice.dart';
import 'package:biconcept/features/invoices/presentation/widgets/invoice_widgets.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intra-state GST splits CGST and SGST', () {
    final line = calculateGstLine(quantity: 10, rate: 100, taxRate: 18, interState: false);
    expect(line.taxableValue, 1000);
    expect(line.cgst, 90);
    expect(line.sgst, 90);
    expect(line.igst, 0);
    expect(line.total, 1180);
  });

  test('inter-state GST uses IGST only', () {
    final line = calculateGstLine(quantity: 2, rate: 500, taxRate: 18, interState: true);
    expect(line.cgst, 0);
    expect(line.sgst, 0);
    expect(line.igst, 180);
    expect(line.total, 1180);
  });

  test('round off stores the nearest rupee separately', () {
    final totals = invoiceTotalsFromLines([
      calculateGstLine(quantity: 1, rate: 100.4, taxRate: 0, interState: true),
    ]);
    expect(totals.subtotal, 100.4);
    expect(totals.grandTotal, 100);
    expect(totals.roundOff, closeTo(-0.4, 0.0001));
  });

  test('amount in words uses Indian numbering', () {
    expect(
      amountInIndianWords(123456.78),
      'One Lakh Twenty Three Thousand Four Hundred Fifty Six Rupees and Seventy Eight Paise Only',
    );
  });

  test('financial year label resets in April', () {
    expect(financialYearLabel(DateTime(2026, 4, 1)), '2026-27');
    expect(financialYearLabel(DateTime(2026, 3, 31)), '2025-26');
    expect(formatSeriesNumber('INV', '2026-27', 1), 'INV/2026-27/0001');
    expect(formatSeriesNumber('INV', '2026-27', 1).length, lessThanOrEqualTo(16));
  });

  test('ageing buckets', () {
    expect(ageingBucket(0), AgeingBucket.current);
    expect(ageingBucket(12), AgeingBucket.days30);
    expect(ageingBucket(45), AgeingBucket.days60);
    expect(ageingBucket(80), AgeingBucket.days90);
    expect(ageingBucket(120), AgeingBucket.days90Plus);
  });

  test('issued invoice past due date displays as overdue', () {
    final invoice = Invoice(
      id: '1',
      invoiceNumber: 'INV/2026-27/0001',
      clientId: 'c1',
      invoiceDate: DateTime(2026, 4, 1),
      dueDate: DateTime(2026, 4, 2),
      placeOfSupply: 'Tamil Nadu',
      placeOfSupplyCode: '33',
      isInterState: false,
      items: const [],
      subtotal: 100,
      totalCgst: 9,
      totalSgst: 9,
      totalIgst: 0,
      grandTotal: 118,
      amountInWords: 'One Hundred Eighteen Rupees Only',
      status: InvoiceStatus.issued,
      createdBy: 'staff',
    );
    expect(invoice.displayStatus, InvoiceStatus.overdue);
  });

  test('phase 6 role mapping', () {
    expect(hasPermission(UserRole.accountant, Permission.invoiceIssue), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.vendorBillApprove), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.gstSettingsEdit), isFalse);
    expect(hasPermission(UserRole.architect, Permission.expenseCreate), isTrue);
    expect(hasPermission(UserRole.architect, Permission.invoiceIssue), isFalse);
    expect(hasPermission(UserRole.client, Permission.clientPortalInvoiceView), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.invoiceView), isFalse);
    expect(hasPermission(UserRole.admin, Permission.gstReturnFile), isTrue);
  });

  testWidgets('InvoiceCard shows number and total', (tester) async {
    final invoice = Invoice(
      id: '1',
      invoiceNumber: 'INV/2026-27/0001',
      clientId: 'c1',
      invoiceDate: DateTime(2026, 4, 1),
      dueDate: DateTime(2026, 4, 15),
      placeOfSupply: 'Tamil Nadu',
      placeOfSupplyCode: '33',
      isInterState: false,
      items: const [],
      subtotal: 100,
      totalCgst: 9,
      totalSgst: 9,
      totalIgst: 0,
      grandTotal: 118,
      amountInWords: 'One Hundred Eighteen Rupees Only',
      status: InvoiceStatus.draft,
      createdBy: 'staff',
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InvoiceCard(invoice: invoice, clientName: 'Asha'))));
    expect(find.textContaining('INV/2026-27/0001'), findsOneWidget);
    expect(find.textContaining('118.00'), findsOneWidget);
  });
}
