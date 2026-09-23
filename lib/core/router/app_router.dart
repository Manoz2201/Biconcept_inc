import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/forbidden_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/session_expired_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/catalog/presentation/screens/admin/catalog_dashboard_screen.dart';
import '../../features/catalog/presentation/screens/admin/portfolio_form_screen.dart';
import '../../features/catalog/presentation/screens/admin/service_form_screen.dart';
import '../../features/catalog/presentation/screens/admin/team_member_form_screen.dart';
import '../../features/catalog/presentation/screens/public/about_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/catalog/presentation/screens/public/contact_screen.dart';
import '../../features/catalog/presentation/screens/public/home_screen.dart';
import '../../features/catalog/presentation/screens/public/portfolio_detail_screen.dart';
import '../../features/catalog/presentation/screens/public/portfolio_list_screen.dart';
import '../../features/catalog/presentation/screens/public/service_detail_screen.dart';
import '../../features/catalog/presentation/screens/public/services_list_screen.dart';
import '../../features/catalog/presentation/screens/public/team_screen.dart';
import '../../features/change_requests/presentation/screens/change_request_detail_screen.dart';
import '../../features/change_requests/presentation/screens/change_request_form_screen.dart';
import '../../features/change_requests/presentation/screens/change_request_list_screen.dart';
import '../../features/client_portal/presentation/screens/client_profile_screen.dart';
import '../../features/documents/presentation/screens/document_detail_screen.dart';
import '../../features/documents/presentation/screens/document_upload_screen.dart';
import '../../features/projects/presentation/screens/admin/admin_project_detail_screen.dart';
import '../../features/projects/presentation/screens/admin/admin_projects_screen.dart';
import '../../features/projects/presentation/screens/admin/milestone_form_screen.dart';
import '../../features/projects/presentation/screens/admin/project_form_screen.dart';
import '../../features/projects/presentation/screens/admin/task_form_screen.dart';
import '../../features/projects/presentation/screens/client/client_change_requests_screen.dart';
import '../../features/projects/presentation/screens/client/client_project_detail_screen.dart';
import '../../features/projects/presentation/screens/client/client_projects_screen.dart';
import '../../features/timesheets/presentation/screens/timesheet_approval_screen.dart';
import '../../features/timesheets/presentation/screens/timesheet_form_screen.dart';
import '../../features/timesheets/presentation/screens/timesheet_list_screen.dart';
import '../../features/client_portal/presentation/widgets/client_shell.dart';
import '../../features/project_vendors/presentation/screens/project_vendor_assignment_screen.dart';
import '../../features/purchase_orders/presentation/screens/po_screens.dart';
import '../../features/rfqs/presentation/screens/admin/rfq_detail_screen.dart';
import '../../features/rfqs/presentation/screens/admin/rfq_form_screen.dart';
import '../../features/rfqs/presentation/screens/admin/rfq_list_screen.dart';
import '../../features/rfqs/presentation/screens/admin/vendor_quote_comparison_screen.dart';
import '../../features/rfqs/presentation/screens/vendor/vendor_rfq_screens.dart';
import '../../features/accounting/presentation/screens/finance_screens.dart';
import '../../features/e_invoice/presentation/screens/e_invoice_screens.dart';
import '../../features/e_way_bill/presentation/screens/e_way_bill_screens.dart';
import '../../features/analytics/presentation/screens/analytics_screens.dart';
import '../../features/backup/presentation/screens/backup_screens.dart';
import '../../features/branding/presentation/screens/branding_screens.dart';
import '../../features/currency/presentation/screens/currency_screens.dart';
import '../../features/forecasting/presentation/screens/forecast_screens.dart';
import '../../features/ai_assistant/presentation/screens/ai_screens.dart';
import '../../features/image_ai/presentation/screens/image_ai_screens.dart';
import '../../features/integrations/presentation/screens/integration_screens.dart';
import '../../features/multi_firm/presentation/screens/multi_firm_screens.dart';
import '../../features/ocr/presentation/screens/ocr_screens.dart';
import '../../features/predictive/presentation/screens/predictive_screens.dart';
import '../../features/voice/presentation/widgets/voice_input_button.dart';
import '../../features/whatsapp/presentation/screens/whatsapp_screens.dart';
import '../../features/notifications/presentation/screens/notification_screens.dart';
import '../../features/payment_schedules/presentation/screens/payment_schedule_screens.dart';
import '../../features/gst/domain/gst_settings.dart';
import '../../features/gst_audit/presentation/screens/gst_audit_screens.dart';
import '../../features/invoices/presentation/screens/admin/invoice_screens.dart';
import '../../features/invoices/presentation/screens/client/client_invoice_screens.dart';
import '../../features/tds/presentation/screens/tds_screens.dart';
import '../../features/vendor_bills/presentation/screens/vendor_bill_screens.dart';
import '../../features/vendors/presentation/screens/admin/vendor_detail_screen.dart';
import '../../features/vendors/presentation/screens/admin/vendor_form_screen.dart';
import '../../features/vendors/presentation/screens/admin/vendor_list_screen.dart';
import '../../features/vendors/presentation/screens/admin/vendor_rate_form_screen.dart';
import '../../features/vendors/presentation/screens/admin/vendor_verification_screen.dart';
import '../../features/vendors/presentation/screens/vendor/vendor_dashboard_screen.dart';
import '../../features/vendors/presentation/screens/vendor/vendor_profile_screen.dart';
import '../../features/vendors/presentation/widgets/vendor_shell.dart';
import '../../features/enquiries/presentation/screens/enquiry_detail_screen.dart';
import '../../features/enquiries/presentation/screens/enquiry_list_screen.dart';
import '../../features/messaging/presentation/screens/client_messages_screen.dart';
import '../../features/quotations/presentation/screens/admin/admin_quotation_detail_screen.dart';
import '../../features/quotations/presentation/screens/admin/admin_quotations_screen.dart';
import '../../features/quotations/presentation/screens/admin/quotation_builder_screen.dart';
import '../../features/quotations/presentation/screens/client/client_quotations_screen.dart';
import '../../features/quotations/presentation/screens/client/quotation_detail_screen.dart';
import '../../features/rbac/domain/permission.dart';
import '../../features/rbac/domain/user_role.dart';
import '../../features/rbac/presentation/rbac_provider.dart';
import '../../features/service_requests/presentation/screens/admin/admin_service_request_detail_screen.dart';
import '../../features/service_requests/presentation/screens/admin/admin_service_requests_screen.dart';
import '../../features/service_requests/presentation/screens/client/client_dashboard_screen.dart';
import '../../features/service_requests/presentation/screens/client/client_service_requests_screen.dart';
import '../../features/service_requests/presentation/screens/client/service_request_detail_screen.dart';
import '../../features/service_requests/presentation/screens/client/service_request_form_screen.dart';
import '../../features/user_management/presentation/screens/edit_user_screen.dart';
import '../../features/user_management/presentation/screens/invite_user_screen.dart';
import '../../features/user_management/presentation/screens/user_detail_screen.dart';
import '../../features/user_management/presentation/screens/user_list_screen.dart';
import '../../ui/home_page.dart';
import 'home_location.dart';

const _authPublic = {
  '/login',
  '/forgot-password',
  '/reset-password',
  '/register',
  '/verify-email',
  '/session-expired',
  '/splash',
  '/403',
};

bool isPublicLocation(String location) {
  if (_authPublic.contains(location)) return true;
  if (location == '/') return true;
  if (location == '/services' || location.startsWith('/services/')) return true;
  if (location == '/portfolio' || location.startsWith('/portfolio/')) return true;
  if (location == '/team' || location == '/about' || location == '/contact') return true;
  return false;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (previous, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;
      final public = isPublicLocation(location);

      if (session.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (session.isAuthenticated &&
          (location == '/login' || location == '/splash' || location == '/session-expired')) {
        return homeLocationFor(session.user?.role);
      }

      if (!session.isAuthenticated && location == '/splash') {
        return '/';
      }

      if (!session.isAuthenticated && !public) {
        return '/login';
      }

      final role = session.user?.role;
      if (session.isAuthenticated && role != null) {
        if (role == UserRole.client && (location == '/chat' || location.startsWith('/chat/'))) {
          if (location == '/chat') return '/client/chat';
          return '/client/chat/${state.uri.pathSegments.last}';
        }
        if (role == UserRole.client && isStaffOnlyLocation(location)) {
          return '/client/dashboard';
        }
        if (role == UserRole.vendor && (isStaffOnlyLocation(location) || isClientPortalLocation(location))) {
          return '/vendor/dashboard';
        }
        if (role != UserRole.client && isClientPortalLocation(location)) {
          return staffLocationFromClientRoute(role);
        }
        if (role != UserRole.vendor && isVendorPortalLocation(location)) {
          return role == UserRole.client ? '/client/dashboard' : '/admin/vendors';
        }
      }

      final required = _permissionFor(location);
      if (required != null) {
        final rbac = ref.read(rbacProvider);
        if (!rbac.allows(required)) {
          return '/403';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(path: '/session-expired', builder: (context, state) => const SessionExpiredScreen()),
      GoRoute(path: '/403', builder: (context, state) => const ForbiddenScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/services', builder: (context, state) => const ServicesListScreen()),
      GoRoute(
        path: '/services/:slug',
        builder: (context, state) => ServiceDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/portfolio', builder: (context, state) => const PortfolioListScreen()),
      GoRoute(
        path: '/portfolio/:slug',
        builder: (context, state) => PortfolioDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/team', builder: (context, state) => const TeamScreen()),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(path: '/contact', builder: (context, state) => const ContactScreen()),
      GoRoute(path: '/app', builder: (context, state) => const EstimateHomePage()),
      GoRoute(path: '/admin/catalog', builder: (context, state) => const CatalogDashboardScreen()),
      GoRoute(path: '/admin/catalog/services/new', builder: (context, state) => const ServiceFormScreen()),
      GoRoute(
        path: '/admin/catalog/services/:id',
        builder: (context, state) => ServiceFormScreen(serviceId: state.pathParameters['id']),
      ),
      GoRoute(path: '/admin/catalog/portfolio/new', builder: (context, state) => const PortfolioFormScreen()),
      GoRoute(
        path: '/admin/catalog/portfolio/:id',
        builder: (context, state) => PortfolioFormScreen(itemId: state.pathParameters['id']),
      ),
      GoRoute(path: '/admin/catalog/team/new', builder: (context, state) => const TeamMemberFormScreen()),
      GoRoute(
        path: '/admin/catalog/team/:id',
        builder: (context, state) => TeamMemberFormScreen(memberId: state.pathParameters['id']),
      ),
      GoRoute(path: '/admin/enquiries', builder: (context, state) => const EnquiryListScreen()),
      GoRoute(
        path: '/admin/enquiries/:id',
        builder: (context, state) => EnquiryDetailScreen(enquiryId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/requests', builder: (context, state) => const AdminServiceRequestsScreen()),
      GoRoute(
        path: '/admin/requests/:id',
        builder: (context, state) => AdminServiceRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/quotations/new', builder: (context, state) {
        return QuotationBuilderScreen(requestId: state.uri.queryParameters['requestId']);
      }),
      GoRoute(
        path: '/admin/quotations/:id/edit',
        builder: (context, state) => QuotationBuilderScreen(quotationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/admin/quotations/:id',
        builder: (context, state) => AdminQuotationDetailScreen(quotationId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/quotations', builder: (context, state) => const AdminQuotationsScreen()),
      GoRoute(path: '/admin/projects', builder: (context, state) => const AdminProjectsScreen()),
      GoRoute(path: '/admin/projects/new', builder: (context, state) => const ProjectFormScreen()),
      GoRoute(
        path: '/admin/projects/:id/edit',
        builder: (context, state) => ProjectFormScreen(projectId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/admin/projects/:id/milestones/new',
        builder: (context, state) => MilestoneFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/projects/:id/milestones/:mid/edit',
        builder: (context, state) => MilestoneFormScreen(
          projectId: state.pathParameters['id']!,
          milestoneId: state.pathParameters['mid'],
        ),
      ),
      GoRoute(
        path: '/admin/projects/:id/tasks/new',
        builder: (context, state) => TaskFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/projects/:id/tasks/:tid/edit',
        builder: (context, state) => TaskFormScreen(
          projectId: state.pathParameters['id']!,
          taskId: state.pathParameters['tid'],
        ),
      ),
      GoRoute(
        path: '/admin/projects/:id/documents/upload',
        builder: (context, state) => DocumentUploadScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/projects/:id/documents/:docId',
        builder: (context, state) => DocumentDetailScreen(
          projectId: state.pathParameters['id']!,
          documentId: state.pathParameters['docId']!,
        ),
      ),
      GoRoute(
        path: '/admin/projects/:id/vendors',
        builder: (context, state) => ProjectVendorAssignmentScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/projects/:id',
        builder: (context, state) => AdminProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/vendors/verification', builder: (context, state) => const VendorVerificationScreen()),
      GoRoute(path: '/admin/vendors/new', builder: (context, state) => const VendorFormScreen()),
      GoRoute(
        path: '/admin/vendors/:id/edit',
        builder: (context, state) => VendorFormScreen(vendorId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/admin/vendors/:id/rates/new',
        builder: (context, state) => VendorRateFormScreen(vendorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/vendors/:id',
        builder: (context, state) => VendorDetailScreen(vendorId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/vendors', builder: (context, state) => const VendorListScreen()),
      GoRoute(path: '/admin/rfqs/new', builder: (context, state) => const RFQFormScreen()),
      GoRoute(
        path: '/admin/rfqs/:id/edit',
        builder: (context, state) => RFQFormScreen(rfqId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/admin/rfqs/:id/vendors',
        builder: (context, state) => RFQVendorSelectionScreen(rfqId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/rfqs/:id/compare',
        builder: (context, state) => VendorQuoteComparisonScreen(rfqId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/rfqs/:id/award',
        builder: (context, state) => RFQAwardScreen(
          rfqId: state.pathParameters['id']!,
          quoteId: state.uri.queryParameters['quoteId'] ?? '',
          vendorId: state.uri.queryParameters['vendorId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/rfqs/:id',
        builder: (context, state) => RFQDetailScreen(rfqId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/rfqs', builder: (context, state) => const RFQListScreen()),
      GoRoute(path: '/admin/purchase-orders/new', builder: (context, state) => const POFormScreen()),
      GoRoute(
        path: '/admin/purchase-orders/:id',
        builder: (context, state) => PODetailScreen(poId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/purchase-orders', builder: (context, state) => const POListScreen()),
      GoRoute(path: '/admin/vendor-bills/approval', builder: (context, state) => const VendorBillApprovalScreen()),
      GoRoute(
        path: '/admin/vendor-bills/:id',
        builder: (context, state) => VendorBillDetailScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/vendor-bills', builder: (context, state) => const VendorBillListScreen()),
      GoRoute(
        path: '/admin/vendor-payments/new',
        builder: (context, state) => VendorPaymentFormScreen(billId: state.uri.queryParameters['billId']),
      ),
      GoRoute(path: '/admin/accounting', builder: (context, state) => const AccountantDashboardScreen()),
      GoRoute(path: '/admin/invoices/new', builder: (context, state) => const InvoiceFormScreen()),
      GoRoute(
        path: '/admin/invoices/:id/edit',
        builder: (context, state) => InvoiceFormScreen(invoiceId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/admin/invoices/:id/void',
        builder: (context, state) => InvoiceVoidScreen(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/invoices/:id',
        builder: (context, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/invoices', builder: (context, state) => const InvoiceListScreen()),
      GoRoute(
        path: '/admin/payments/new',
        builder: (context, state) => PaymentFormScreen(invoiceId: state.uri.queryParameters['invoiceId']),
      ),
      GoRoute(path: '/admin/payments', builder: (context, state) => const PaymentListScreen()),
      GoRoute(path: '/admin/credit-notes/new', builder: (context, state) => const CreditNoteFormScreen()),
      GoRoute(
        path: '/admin/credit-notes/:id',
        builder: (context, state) => CreditNoteDetailScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/credit-notes', builder: (context, state) => const CreditNoteListScreen()),
      GoRoute(path: '/admin/debit-notes/new', builder: (context, state) => const DebitNoteFormScreen()),
      GoRoute(
        path: '/admin/debit-notes/:id',
        builder: (context, state) => DebitNoteDetailScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/debit-notes', builder: (context, state) => const DebitNoteListScreen()),
      GoRoute(path: '/admin/expenses/new', builder: (context, state) => const ExpenseFormScreen()),
      GoRoute(path: '/admin/expenses/approval', builder: (context, state) => const ExpenseApprovalScreen()),
      GoRoute(
        path: '/admin/expenses/:id',
        builder: (context, state) => ExpenseDetailScreen(expenseId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/expenses', builder: (context, state) => const ExpenseListScreen()),
      GoRoute(
        path: '/admin/ledger/client/:id',
        builder: (context, state) => ClientLedgerScreen(clientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/ledger/vendor/:id',
        builder: (context, state) => VendorLedgerScreen(vendorId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/ledger/general', builder: (context, state) => const GeneralLedgerScreen()),
      GoRoute(path: '/admin/gst/settings', builder: (context, state) => const GSTSettingsScreen()),
      GoRoute(path: '/admin/gst/tax-rates/new', builder: (context, state) => const TaxRateFormScreen()),
      GoRoute(
        path: '/admin/gst/tax-rates/:id/edit',
        builder: (context, state) => TaxRateFormScreen(rateId: state.pathParameters['id']),
      ),
      GoRoute(path: '/admin/gst/tax-rates', builder: (context, state) => const TaxRateListScreen()),
      GoRoute(path: '/admin/gst/gstr1', builder: (context, state) => const GSTRExportScreen(type: GSTReturnType.gstr1)),
      GoRoute(path: '/admin/gst/gstr3b', builder: (context, state) => const GSTRExportScreen(type: GSTReturnType.gstr3b)),
      GoRoute(path: '/admin/gst/gstr2b', builder: (context, state) => const GSTRExportScreen(type: GSTReturnType.gstr2b)),
      GoRoute(
        path: '/admin/gst/returns/:id',
        builder: (context, state) => GSTReturnDetailScreen(returnId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/gst/returns', builder: (context, state) => const GSTReturnListScreen()),
      GoRoute(path: '/admin/accounting/receivables', builder: (context, state) => const ReceivablesScreen()),
      GoRoute(path: '/admin/accounting/payables', builder: (context, state) => const PayablesScreen()),
      GoRoute(path: '/admin/accounting/cashflow', builder: (context, state) => const CashflowScreen()),
      GoRoute(path: '/admin/accounting/pl', builder: (context, state) => const PLStatementScreen()),
      GoRoute(path: '/admin/accounting/bank-reconciliation', builder: (context, state) => const BankReconciliationScreen()),
      GoRoute(path: '/admin/accounting/fy-closing', builder: (context, state) => const FinancialYearClosingScreen()),
      GoRoute(path: '/admin/audit/itc-ledger/:id', builder: (context, state) => ITCEntryDetailScreen(entryId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/audit/itc-ledger', builder: (context, state) => const ITCLedgerScreen()),
      GoRoute(path: '/admin/audit/itc-reversals/new', builder: (context, state) => ITCReversalFormScreen(itcId: state.uri.queryParameters['itcId'])),
      GoRoute(path: '/admin/audit/itc-reversals', builder: (context, state) => const ITCReversalScreen()),
      GoRoute(path: '/admin/audit/gstr2b/:id/reconciliation', builder: (context, state) => GSTR2BReconciliationScreen(importId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/audit/gstr2b', builder: (context, state) => const GSTR2BImportScreen()),
      GoRoute(path: '/admin/audit/gstr9/:id', builder: (context, state) => GSTR9PreparationScreen(returnId: state.pathParameters['id'])),
      GoRoute(path: '/admin/audit/gstr9', builder: (context, state) => const GSTR9PreparationScreen()),
      GoRoute(path: '/admin/audit/gstr9c', builder: (context, state) => const GSTR9CPreparationScreen()),
      GoRoute(path: '/admin/audit/compliance-calendar', builder: (context, state) => const ComplianceCalendarScreen()),
      GoRoute(path: '/admin/audit/compliance-report', builder: (context, state) => const ComplianceReportScreen()),
      GoRoute(path: '/admin/audit', builder: (context, state) => const AuditDashboardScreen()),
      GoRoute(path: '/admin/tds/new', builder: (context, state) => const TDSFormScreen()),
      GoRoute(path: '/admin/tds/certificates', builder: (context, state) => TDSCertificateScreen(deductionId: state.uri.queryParameters['id'])),
      GoRoute(path: '/admin/tds/returns', builder: (context, state) => const TDSReturnScreen()),
      GoRoute(path: '/admin/tds/:id', builder: (context, state) => TDSDeductionDetailScreen(deductionId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/tds', builder: (context, state) => const TDSDeductionScreen()),
      GoRoute(path: '/admin/gst-tds/new', builder: (context, state) => const GSTTDSFormScreen()),
      GoRoute(path: '/admin/gst-tds', builder: (context, state) => const GSTTDSScreen()),
      GoRoute(path: '/admin/e-invoices/settings', builder: (context, state) => const EInvoiceSettingsScreen()),
      GoRoute(path: '/admin/e-invoices/:id', builder: (context, state) => EInvoiceDetailScreen(eInvoiceId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/e-invoices', builder: (context, state) => const EInvoiceListScreen()),
      GoRoute(path: '/admin/e-way-bills/new', builder: (context, state) => const EWayBillFormScreen()),
      GoRoute(path: '/admin/e-way-bills/:id/part-b', builder: (context, state) => EWayBillPartBScreen(ewayBillId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/e-way-bills/:id', builder: (context, state) => EWayBillDetailScreen(ewayBillId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/e-way-bills', builder: (context, state) => const EWayBillListScreen()),
      GoRoute(path: '/admin/budgets/new', builder: (context, state) => const BudgetFormScreen()),
      GoRoute(path: '/admin/budgets/vs-actual', builder: (context, state) => const BudgetVsActualScreen()),
      GoRoute(path: '/admin/budgets/:id/edit', builder: (context, state) => BudgetFormScreen(budgetId: state.pathParameters['id'])),
      GoRoute(path: '/admin/budgets/:id', builder: (context, state) => BudgetDetailScreen(budgetId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/budgets', builder: (context, state) => const BudgetListScreen()),
      GoRoute(path: '/admin/forecasts/new', builder: (context, state) => const ForecastFormScreen()),
      GoRoute(path: '/admin/forecasts/cashflow', builder: (context, state) => const CashflowProjectionScreen()),
      GoRoute(path: '/admin/forecasts/:id', builder: (context, state) => ForecastDetailScreen(forecastId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/forecasts', builder: (context, state) => const ForecastDashboardScreen()),
      GoRoute(path: '/admin/currencies/new', builder: (context, state) => const CurrencyFormScreen()),
      GoRoute(path: '/admin/currencies/:code/history', builder: (context, state) => ExchangeRateHistoryScreen(code: state.pathParameters['code']!)),
      GoRoute(path: '/admin/currencies/:code', builder: (context, state) => CurrencyDetailScreen(code: state.pathParameters['code']!)),
      GoRoute(path: '/admin/currencies', builder: (context, state) => const CurrencyListScreen()),
      GoRoute(path: '/admin/currency-converter', builder: (context, state) => const CurrencyConverterScreen()),
      GoRoute(path: '/admin/payment-schedules/new', builder: (context, state) => const PaymentScheduleFormScreen()),
      GoRoute(path: '/admin/payment-schedules/approval', builder: (context, state) => const PaymentScheduleApprovalScreen()),
      GoRoute(path: '/admin/payment-schedules/batch', builder: (context, state) => const BatchPaymentScreen()),
      GoRoute(path: '/admin/payment-schedules/:id/edit', builder: (context, state) => PaymentScheduleFormScreen(scheduleId: state.pathParameters['id'])),
      GoRoute(path: '/admin/payment-schedules/:id', builder: (context, state) => PaymentScheduleDetailScreen(scheduleId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/payment-schedules', builder: (context, state) => const PaymentScheduleListScreen()),
      GoRoute(path: '/admin/integrations/setup/:provider', builder: (context, state) => IntegrationSetupScreen(provider: state.pathParameters['provider']!)),
      GoRoute(path: '/admin/integrations/:id/logs', builder: (context, state) => SyncLogScreen(integrationId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/integrations/:id', builder: (context, state) => IntegrationDetailScreen(integrationId: state.pathParameters['id']!)),
      GoRoute(path: '/admin/integrations', builder: (context, state) => const IntegrationListScreen()),
      GoRoute(path: '/admin/branding/colors', builder: (context, state) => const ColorPickerScreen()),
      GoRoute(path: '/admin/branding/email-templates', builder: (context, state) => const EmailTemplateEditorScreen()),
      GoRoute(path: '/admin/branding', builder: (context, state) => const BrandingSettingsScreen()),
      GoRoute(path: '/admin/backups/new', builder: (context, state) => const BackupJobFormScreen()),
      GoRoute(path: '/admin/backups/restore', builder: (context, state) => const RestoreScreen()),
      GoRoute(path: '/admin/backups/:id/edit', builder: (context, state) => BackupJobFormScreen(jobId: state.pathParameters['id'])),
      GoRoute(path: '/admin/backups/:id/history', builder: (context, state) => BackupHistoryScreen(jobId: state.pathParameters['id'])),
      GoRoute(path: '/admin/backups', builder: (context, state) => const BackupListScreen()),
      GoRoute(path: '/admin/analytics/kpis', builder: (context, state) => const KPIDashboardScreen()),
      GoRoute(path: '/admin/analytics/cohorts', builder: (context, state) => const CohortAnalysisScreen()),
      GoRoute(path: '/admin/analytics/funnels/:name', builder: (context, state) => FunnelAnalysisScreen(funnelName: state.pathParameters['name']!)),
      GoRoute(path: '/admin/analytics/revenue', builder: (context, state) => const RevenueAnalyticsScreen()),
      GoRoute(path: '/admin/analytics/users', builder: (context, state) => const UserAnalyticsScreen()),
      GoRoute(path: '/admin/analytics', builder: (context, state) => const AnalyticsDashboardScreen()),
      GoRoute(path: '/admin/timesheets', builder: (context, state) => const TimesheetListScreen()),
      GoRoute(
        path: '/admin/timesheets/new',
        builder: (context, state) => TimesheetFormScreen(projectId: state.uri.queryParameters['projectId']),
      ),
      GoRoute(path: '/admin/timesheets/approval', builder: (context, state) => const TimesheetApprovalScreen()),
      GoRoute(path: '/admin/change-requests', builder: (context, state) => const ChangeRequestListScreen()),
      GoRoute(
        path: '/admin/change-requests/:id',
        builder: (context, state) => ChangeRequestDetailScreen(
          changeRequestId: state.pathParameters['id']!,
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: '/client/dashboard', builder: (context, state) => const ClientDashboardScreen()),
          GoRoute(path: '/client/requests/new', builder: (context, state) => const ServiceRequestFormScreen()),
          GoRoute(
            path: '/client/requests/:id',
            builder: (context, state) => ServiceRequestDetailScreen(requestId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/client/requests', builder: (context, state) => const ClientServiceRequestsScreen()),
          GoRoute(
            path: '/client/quotations/:id',
            builder: (context, state) => QuotationDetailScreen(quotationId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/client/quotations', builder: (context, state) => const ClientQuotationsScreen()),
          GoRoute(path: '/client/projects', builder: (context, state) => const ClientProjectsScreen()),
          GoRoute(
            path: '/client/projects/:id/change-requests/new',
            builder: (context, state) => ChangeRequestFormScreen(projectId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/client/projects/:id/change-requests',
            builder: (context, state) => ClientChangeRequestsScreen(projectId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/client/projects/:id',
            builder: (context, state) => ClientProjectDetailScreen(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/client/messages', builder: (context, state) => const ClientMessagesScreen()),
          GoRoute(path: '/client/chat', builder: (context, state) => const ChatListScreen(embedded: true)),
          GoRoute(
            path: '/client/chat/:id',
            builder: (context, state) => ChatDetailScreen(
              conversationId: state.pathParameters['id']!,
              embedded: true,
            ),
          ),
          GoRoute(path: '/client/profile', builder: (context, state) => const ClientProfileScreen()),
          GoRoute(
            path: '/client/invoices/:id/pay',
            builder: (context, state) => ClientPaymentScreen(invoiceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/client/invoices/:id',
            builder: (context, state) => ClientInvoiceDetailScreen(invoiceId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/client/invoices', builder: (context, state) => const ClientInvoicesScreen()),
          GoRoute(path: '/client/payments', builder: (context, state) => const ClientPaymentHistoryScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          GoRoute(path: '/vendor/dashboard', builder: (context, state) => const VendorDashboardScreen()),
          GoRoute(path: '/vendor/profile', builder: (context, state) => const VendorProfileScreen()),
          GoRoute(path: '/vendor/rates', builder: (context, state) => const VendorRatesScreen()),
          GoRoute(path: '/vendor/rfqs', builder: (context, state) => const VendorRFQListScreen()),
          GoRoute(
            path: '/vendor/rfqs/:id/quote',
            builder: (context, state) => VendorQuoteFormScreen(rfqId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/vendor/rfqs/:id',
            builder: (context, state) => VendorRFQDetailScreen(rfqId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/vendor/pos', builder: (context, state) => const VendorPOListScreen()),
          GoRoute(
            path: '/vendor/pos/:id',
            builder: (context, state) => VendorPODetailScreen(poId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/vendor/bills/new', builder: (context, state) => const VendorBillFormScreen()),
          GoRoute(path: '/vendor/bills', builder: (context, state) => const VendorPortalBillListScreen()),
          GoRoute(path: '/vendor/payments', builder: (context, state) => const VendorPaymentHistoryScreen()),
        ],
      ),
      GoRoute(path: '/ai/assistant', builder: (context, state) => const AIAssistantScreen()),
      GoRoute(path: '/ai/quotation-suggest', builder: (context, state) => const AIQuotationSuggestionScreen()),
      GoRoute(path: '/ai/cost-estimate', builder: (context, state) => const AICostEstimateScreen()),
      GoRoute(path: '/ai/timeline-predict', builder: (context, state) => const AITimelinePredictionScreen()),
      GoRoute(path: '/ai/lead-score', builder: (context, state) => const AILeadScoreScreen()),
      GoRoute(path: '/ai/semantic-search', builder: (context, state) => const SemanticSearchScreen()),
      GoRoute(path: '/ai/natural-language-query', builder: (context, state) => const NaturalLanguageQueryScreen()),
      GoRoute(path: '/voice/transcribe', builder: (context, state) => const VoiceTranscriptionScreen()),
      GoRoute(path: '/projects/:id/photos/capture', builder: (context, state) => SitePhotoCaptureScreen(projectId: state.pathParameters['id']!)),
      GoRoute(path: '/projects/:id/photos/:photoId', builder: (context, state) => SitePhotoDetailScreen(projectId: state.pathParameters['id']!, photoId: state.pathParameters['photoId']!)),
      GoRoute(path: '/projects/:id/photos', builder: (context, state) => SitePhotoGalleryScreen(projectId: state.pathParameters['id']!)),
      GoRoute(path: '/image-analysis', builder: (context, state) => const ImageAnalysisScreen()),
      GoRoute(path: '/ocr/upload', builder: (context, state) => const OCRUploadScreen()),
      GoRoute(path: '/ocr/documents/:id/verify', builder: (context, state) => OCRVerificationScreen(documentId: state.pathParameters['id']!)),
      GoRoute(path: '/ocr/documents/:id', builder: (context, state) => OCRResultScreen(documentId: state.pathParameters['id']!)),
      GoRoute(path: '/ocr/documents', builder: (context, state) => const OCRDocumentListScreen()),
      GoRoute(path: '/whatsapp/messages', builder: (context, state) => const WhatsAppMessagesScreen()),
      GoRoute(path: '/whatsapp/compose/:clientId', builder: (context, state) => WhatsAppComposeScreen(clientId: state.pathParameters['clientId']!)),
      GoRoute(path: '/whatsapp/templates', builder: (context, state) => const WhatsAppTemplateSelectorScreen()),
      GoRoute(path: '/whatsapp/settings', builder: (context, state) => const WhatsAppSettingsScreen()),
      GoRoute(path: '/multi-firm/dashboard', builder: (context, state) => const MultiFirmDashboardScreen()),
      GoRoute(path: '/multi-firm/tenants/new', builder: (context, state) => const TenantOnboardingScreen()),
      GoRoute(path: '/multi-firm/tenants/:id/settings', builder: (context, state) => TenantSettingsScreen(tenantId: state.pathParameters['id']!)),
      GoRoute(path: '/multi-firm/tenants/:id/usage', builder: (context, state) => UsageDashboardScreen(tenantId: state.pathParameters['id']!)),
      GoRoute(path: '/multi-firm/tenants/:id', builder: (context, state) => TenantSettingsScreen(tenantId: state.pathParameters['id']!)),
      GoRoute(path: '/multi-firm/subscription/plans', builder: (context, state) => const SubscriptionPlansScreen()),
      GoRoute(path: '/tenant-switcher', builder: (context, state) => const TenantSwitcherScreen()),
      GoRoute(path: '/predictive/risk', builder: (context, state) => const RiskDashboardScreen()),
      GoRoute(path: '/predictive/alerts', builder: (context, state) => const MaintenanceAlertsScreen()),
      GoRoute(path: '/predictive/projects/:id/health', builder: (context, state) => ProjectHealthScreen(projectId: state.pathParameters['id']!)),
      GoRoute(path: '/notifications/preferences', builder: (context, state) => const NotificationPreferencesScreen()),
      GoRoute(path: '/notifications/:id', builder: (context, state) => NotificationDetailScreen(notificationId: state.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationCenterScreen()),
      GoRoute(path: '/chat', builder: (context, state) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatDetailScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/users', builder: (context, state) => const UserListScreen()),
      GoRoute(path: '/users/invite', builder: (context, state) => const InviteUserScreen()),
      GoRoute(
        path: '/users/:id',
        builder: (context, state) => UserDetailScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/users/:id/edit',
        builder: (context, state) => EditUserScreen(userId: state.pathParameters['id']!),
      ),
    ],
  );
});

Permission? _permissionFor(String location) {
  if (location == '/users/invite') return Permission.userCreate;
  if (RegExp(r'^/users/[^/]+/edit$').hasMatch(location)) return Permission.userEdit;
  if (location == '/users' || location.startsWith('/users/')) return Permission.userView;
  if (location == '/admin/catalog/services/new' ||
      location == '/admin/catalog/portfolio/new' ||
      location == '/admin/catalog/team/new') {
    return Permission.catalogCreate;
  }
  if (RegExp(r'^/admin/catalog/(services|portfolio|team)/[^/]+$').hasMatch(location)) {
    return Permission.catalogEdit;
  }
  if (location == '/admin/catalog' || location.startsWith('/admin/catalog/')) {
    return Permission.catalogView;
  }
  if (location == '/admin/enquiries' || location.startsWith('/admin/enquiries/')) {
    return Permission.enquiryView;
  }
  if (location == '/admin/requests' || location.startsWith('/admin/requests/')) {
    return Permission.serviceRequestView;
  }
  if (location == '/admin/quotations/new' || RegExp(r'^/admin/quotations/[^/]+/edit$').hasMatch(location)) {
    return Permission.quotationCreate;
  }
  if (location == '/admin/quotations' || location.startsWith('/admin/quotations/')) {
    return Permission.quotationView;
  }
  if (location == '/admin/timesheets/new') return Permission.timesheetCreate;
  if (location == '/admin/timesheets/approval') return Permission.timesheetApprove;
  if (location == '/admin/timesheets' || location.startsWith('/admin/timesheets/')) {
    return Permission.timesheetView;
  }
  if (location == '/admin/change-requests' || location.startsWith('/admin/change-requests/')) {
    return Permission.changeRequestView;
  }
  if (location == '/admin/projects/new') return Permission.projectCreate;
  if (RegExp(r'^/admin/projects/[^/]+/edit$').hasMatch(location)) return Permission.projectEdit;
  if (RegExp(r'^/admin/projects/[^/]+/vendors$').hasMatch(location)) return Permission.projectVendorView;
  if (location == '/admin/projects' || location.startsWith('/admin/projects/')) {
    return Permission.projectView;
  }
  if (location == '/admin/vendors/new' || location.endsWith('/rates/new')) return Permission.vendorCreate;
  if (location == '/admin/vendors/verification') return Permission.vendorVerify;
  if (location == '/admin/vendors' || location.startsWith('/admin/vendors/')) return Permission.vendorView;
  if (location == '/admin/rfqs/new' || location.endsWith('/edit')) {
    if (location.startsWith('/admin/rfqs')) return Permission.rfqCreate;
  }
  if (location == '/admin/rfqs' || location.startsWith('/admin/rfqs/')) return Permission.rfqView;
  if (location == '/admin/purchase-orders/new') return Permission.purchaseOrderCreate;
  if (location == '/admin/purchase-orders' || location.startsWith('/admin/purchase-orders/')) {
    return Permission.purchaseOrderView;
  }
  if (location == '/admin/vendor-bills/approval') return Permission.vendorBillApprove;
  if (location == '/admin/vendor-bills' || location.startsWith('/admin/vendor-bills/')) {
    return Permission.vendorBillView;
  }
  if (location.startsWith('/admin/vendor-payments/')) return Permission.vendorPaymentCreate;
  if (location == '/admin/invoices/new' || location.endsWith('/edit') && location.startsWith('/admin/invoices')) {
    return Permission.invoiceCreate;
  }
  if (location.endsWith('/void') && location.startsWith('/admin/invoices')) return Permission.invoiceVoid;
  if (location == '/admin/invoices' || location.startsWith('/admin/invoices/')) return Permission.invoiceView;
  if (location == '/admin/payments/new') return Permission.paymentCreate;
  if (location == '/admin/payments' || location.startsWith('/admin/payments/')) return Permission.paymentView;
  if (location.startsWith('/admin/credit-notes')) return Permission.creditNoteView;
  if (location.startsWith('/admin/debit-notes')) return Permission.debitNoteView;
  if (location == '/admin/expenses/approval') return Permission.expenseApprove;
  if (location == '/admin/expenses/new') return Permission.expenseCreate;
  if (location == '/admin/expenses' || location.startsWith('/admin/expenses/')) return Permission.expenseView;
  if (location.startsWith('/admin/ledger')) return Permission.ledgerView;
  if (location == '/admin/gst/settings') return Permission.gstSettingsView;
  if (location.startsWith('/admin/gst/tax-rates')) return Permission.taxRateView;
  if (location.startsWith('/admin/gst')) return Permission.gstReturnView;
  if (location.startsWith('/admin/accounting')) return Permission.financialReportView;
  if (location.startsWith('/admin/audit/itc-reversals')) return Permission.itcReversalView;
  if (location.startsWith('/admin/audit/itc-ledger')) return Permission.itcLedgerView;
  if (location.startsWith('/admin/audit/gstr2b')) return Permission.gstr2bImport;
  if (location.startsWith('/admin/audit/gstr9c')) return Permission.gstr9cView;
  if (location.startsWith('/admin/audit/gstr9')) return Permission.gstr9View;
  if (location.startsWith('/admin/audit/compliance')) return Permission.complianceReportView;
  if (location == '/admin/audit' || location.startsWith('/admin/audit/')) return Permission.auditDashboardView;
  if (location.startsWith('/admin/tds')) return Permission.tdsView;
  if (location.startsWith('/admin/gst-tds')) return Permission.gstTdsView;
  if (location.startsWith('/admin/e-invoices')) return Permission.eInvoiceView;
  if (location.startsWith('/admin/e-way-bills')) return Permission.eWayBillView;
  if (location.startsWith('/admin/budgets')) return Permission.budgetView;
  if (location.startsWith('/admin/forecasts')) return Permission.forecastView;
  if (location.startsWith('/admin/currencies') || location.startsWith('/admin/currency-converter')) {
    return Permission.currencyView;
  }
  if (location.startsWith('/admin/payment-schedules/approval')) return Permission.paymentScheduleApprove;
  if (location.startsWith('/admin/payment-schedules/batch')) return Permission.paymentScheduleProcess;
  if (location.startsWith('/admin/payment-schedules')) return Permission.paymentScheduleView;
  if (location.startsWith('/admin/integrations')) return Permission.integrationView;
  if (location.startsWith('/admin/branding')) return Permission.brandingView;
  if (location.startsWith('/admin/backups/restore')) return Permission.backupRestore;
  if (location.startsWith('/admin/backups')) return Permission.backupView;
  if (location.startsWith('/admin/analytics/kpis')) return Permission.kpiView;
  if (location.startsWith('/admin/analytics')) return Permission.analyticsView;
  if (location.startsWith('/ai/quotation-suggest')) return Permission.aiQuotationSuggest;
  if (location.startsWith('/ai/cost-estimate')) return Permission.aiCostEstimate;
  if (location.startsWith('/ai/timeline-predict')) return Permission.aiTimelinePredict;
  if (location.startsWith('/ai/lead-score')) return Permission.aiLeadScore;
  if (location.startsWith('/ai/semantic-search')) return Permission.aiSemanticSearch;
  if (location.startsWith('/ai/natural-language-query') || location.startsWith('/ai/assistant')) {
    return Permission.aiNaturalLanguageQuery;
  }
  if (location.startsWith('/voice/')) return Permission.voiceToText;
  if (location.contains('/photos/capture')) return Permission.sitePhotoUpload;
  if (location.contains('/photos')) return Permission.sitePhotoAnalyze;
  if (location.startsWith('/image-analysis')) return Permission.aiImageAnalyze;
  if (location.endsWith('/verify') && location.startsWith('/ocr/')) return Permission.ocrVerify;
  if (location.startsWith('/ocr/')) return Permission.ocrUpload;
  if (location.startsWith('/whatsapp/settings')) return Permission.whatsappConfigure;
  if (location.startsWith('/whatsapp/compose')) return Permission.whatsappSend;
  if (location.startsWith('/whatsapp/')) return Permission.whatsappView;
  if (location.startsWith('/multi-firm/tenants/new')) return Permission.tenantCreate;
  if (location.startsWith('/multi-firm/subscription') || location.contains('/usage')) {
    return Permission.tenantSubscriptionView;
  }
  if (location.startsWith('/multi-firm/')) return Permission.multiFirmDashboard;
  if (location.startsWith('/tenant-switcher')) return Permission.tenantView;
  if (location.startsWith('/predictive/')) return Permission.aiTimelinePredict;
  if (location.startsWith('/notifications')) return Permission.notificationPreferenceView;
  if (location.startsWith('/vendor/')) return Permission.vendorPortalAccess;
  if (location.startsWith('/client/')) {
    return Permission.clientPortalAccess;
  }
  if (location == '/chat' || location.startsWith('/chat/')) {
    return Permission.messageView;
  }
  return null;
}

String? requireAuthRedirect({required bool isAuthenticated, required String location}) {
  if (!isAuthenticated && !isPublicLocation(location)) return '/login';
  return null;
}

String? requirePermissionRedirect({
  required bool allowed,
  required Permission permission,
  required String location,
}) {
  final needed = _permissionFor(location);
  if (needed == null) return null;
  if (!allowed) return '/403';
  return null;
}
