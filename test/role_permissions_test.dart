import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('super admin has every permission', () {
    expect(
      kRolePermissions[UserRole.superAdmin],
      containsAll(Permission.values),
    );
  });

  test('admin cannot delete users', () {
    expect(hasPermission(UserRole.admin, Permission.userDelete), isFalse);
    expect(hasPermission(UserRole.admin, Permission.userCreate), isTrue);
  });

  test('architect can edit projects but not users', () {
    expect(hasPermission(UserRole.architect, Permission.projectEdit), isTrue);
    expect(hasPermission(UserRole.architect, Permission.userView), isFalse);
  });

  test('accountant can view invoices and audit logs', () {
    expect(hasPermission(UserRole.accountant, Permission.invoiceView), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.auditLogView), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.projectView), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.timesheetApprove), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.projectEdit), isFalse);
    expect(hasPermission(UserRole.accountant, Permission.catalogView), isFalse);
    expect(hasPermission(UserRole.accountant, Permission.enquiryView), isFalse);
  });

  test('admin and architect get catalog and enquiry permissions', () {
    expect(hasPermission(UserRole.admin, Permission.catalogDelete), isTrue);
    expect(hasPermission(UserRole.admin, Permission.enquiryConvert), isTrue);
    expect(hasPermission(UserRole.architect, Permission.catalogView), isTrue);
    expect(hasPermission(UserRole.architect, Permission.catalogCreate), isFalse);
    expect(hasPermission(UserRole.architect, Permission.enquiryManage), isTrue);
    expect(hasPermission(UserRole.architect, Permission.enquiryConvert), isTrue);
  });

  test('vendor can view assigned project work; client has portal access', () {
    expect(hasPermission(UserRole.vendor, Permission.projectView), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.taskView), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.vendorPortalAccess), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.vendorQuoteCreate), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.rfqAward), isFalse);
    expect(hasPermission(UserRole.vendor, Permission.projectEdit), isFalse);
    expect(hasPermission(UserRole.admin, Permission.rfqAward), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.vendorBillApprove), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.rfqCreate), isFalse);
    expect(hasPermission(UserRole.client, Permission.vendorView), isFalse);
    expect(hasPermission(UserRole.client, Permission.clientPortalAccess), isTrue);
    expect(hasPermission(UserRole.client, Permission.quotationApprove), isTrue);
    expect(hasPermission(UserRole.client, Permission.serviceRequestCreate), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.quotationView), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.quotationCreate), isFalse);
    expect(hasPermission(UserRole.accountant, Permission.invoiceIssue), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.auditDashboardView), isTrue);
    expect(hasPermission(UserRole.architect, Permission.forecastView), isTrue);
    expect(hasPermission(UserRole.client, Permission.clientPortalInvoiceView), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.paymentCreate), isFalse);
    expect(hasPermission(UserRole.architect, Permission.quotationSend), isTrue);
    expect(hasPermission(UserRole.architect, Permission.clientPortalAccess), isFalse);
    expect(hasPermission(UserRole.admin, Permission.analyticsView), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.paymentScheduleProcess), isTrue);
    expect(hasPermission(UserRole.client, Permission.brandingView), isTrue);
  });

  test('unknown role strings default to client', () {
    expect(UserRole.fromString('not-a-role'), UserRole.client);
    expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
  });
}
