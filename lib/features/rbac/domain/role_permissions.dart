import 'permission.dart';
import 'user_role.dart';

const _catalogAdmin = {
  Permission.catalogView,
  Permission.catalogCreate,
  Permission.catalogEdit,
  Permission.catalogDelete,
  Permission.enquiryView,
  Permission.enquiryManage,
  Permission.enquiryConvert,
};

const _phase3Staff = {
  Permission.serviceRequestView,
  Permission.serviceRequestCreate,
  Permission.serviceRequestEdit,
  Permission.serviceRequestConvert,
  Permission.quotationView,
  Permission.quotationCreate,
  Permission.quotationEdit,
  Permission.quotationSend,
  Permission.messageView,
  Permission.messageSend,
};

const _phase4Core = {
  Permission.projectView,
  Permission.projectCreate,
  Permission.projectEdit,
  Permission.projectConvert,
  Permission.milestoneView,
  Permission.milestoneCreate,
  Permission.milestoneEdit,
  Permission.milestoneDelete,
  Permission.taskView,
  Permission.taskCreate,
  Permission.taskEdit,
  Permission.taskDelete,
  Permission.taskAssign,
  Permission.timesheetView,
  Permission.timesheetCreate,
  Permission.timesheetEdit,
  Permission.documentView,
  Permission.documentUpload,
  Permission.documentDelete,
  Permission.changeRequestView,
  Permission.changeRequestCreate,
  Permission.activityView,
};

const _phase4Admin = {
  ..._phase4Core,
  Permission.projectDelete,
  Permission.timesheetApprove,
  Permission.changeRequestApprove,
};

const _phase5Architect = {
  Permission.vendorView,
  Permission.vendorRateView,
  Permission.projectVendorView,
  Permission.projectVendorAssign,
  Permission.projectVendorRemove,
  Permission.rfqView,
  Permission.rfqCreate,
  Permission.rfqEdit,
  Permission.rfqSend,
  Permission.vendorQuoteView,
  Permission.vendorQuoteEdit,
  Permission.purchaseOrderView,
  Permission.purchaseOrderCreate,
  Permission.purchaseOrderEdit,
  Permission.purchaseOrderIssue,
  Permission.vendorBillView,
  Permission.vendorRatingView,
  Permission.vendorRatingCreate,
};

const _phase5Admin = {
  ..._phase5Architect,
  Permission.vendorInvite,
  Permission.vendorCreate,
  Permission.vendorEdit,
  Permission.vendorDelete,
  Permission.vendorVerify,
  Permission.vendorRateCreate,
  Permission.vendorRateEdit,
  Permission.vendorRateDelete,
  Permission.rfqDelete,
  Permission.rfqAward,
  Permission.vendorQuoteCreate,
  Permission.purchaseOrderDelete,
  Permission.vendorBillCreate,
  Permission.vendorBillEdit,
  Permission.vendorBillApprove,
  Permission.vendorPaymentView,
  Permission.vendorPaymentCreate,
  Permission.vendorPaymentEdit,
};

const _phase5Accountant = {
  Permission.vendorView,
  Permission.vendorRateView,
  Permission.projectVendorView,
  Permission.rfqView,
  Permission.vendorQuoteView,
  Permission.purchaseOrderView,
  Permission.vendorBillView,
  Permission.vendorBillApprove,
  Permission.vendorPaymentView,
  Permission.vendorPaymentCreate,
  Permission.vendorPaymentEdit,
};

const _phase6Architect = {
  Permission.invoiceView,
  Permission.paymentView,
  Permission.expenseView,
  Permission.expenseCreate,
  Permission.ledgerView,
};

const _phase6Core = {
  Permission.invoiceCreate,
  Permission.invoiceEdit,
  Permission.invoiceIssue,
  Permission.invoiceVoid,
  Permission.paymentView,
  Permission.paymentCreate,
  Permission.paymentEdit,
  Permission.paymentRefund,
  Permission.creditNoteView,
  Permission.creditNoteCreate,
  Permission.creditNoteEdit,
  Permission.debitNoteView,
  Permission.debitNoteCreate,
  Permission.debitNoteEdit,
  Permission.expenseView,
  Permission.expenseCreate,
  Permission.expenseEdit,
  Permission.expenseApprove,
  Permission.ledgerView,
  Permission.ledgerCreate,
  Permission.gstReturnView,
  Permission.gstReturnCreate,
  Permission.gstReturnFile,
  Permission.gstSettingsView,
  Permission.taxRateView,
  Permission.financialReportView,
  Permission.financialReportExport,
  Permission.bankReconciliationView,
  Permission.bankReconciliationEdit,
};

const _phase6Admin = {
  ..._phase6Core,
  Permission.gstSettingsEdit,
  Permission.taxRateCreate,
  Permission.taxRateEdit,
};

const _phase6Client = {
  Permission.clientPortalInvoiceView,
  Permission.clientPortalPaymentView,
};

const _phase7Architect = {
  Permission.budgetView,
  Permission.forecastView,
};

const _phase7Core = {
  Permission.itcLedgerView,
  Permission.itcLedgerCreate,
  Permission.itcLedgerEdit,
  Permission.itcReversalView,
  Permission.itcReversalCreate,
  Permission.gstr2bImport,
  Permission.gstr2bReconcile,
  Permission.tdsView,
  Permission.tdsCreate,
  Permission.tdsEdit,
  Permission.tdsCertificateGenerate,
  Permission.gstTdsView,
  Permission.gstTdsCreate,
  Permission.gstTdsEdit,
  Permission.gstTdsFile,
  Permission.eInvoiceView,
  Permission.eInvoiceGenerate,
  Permission.eWayBillView,
  Permission.eWayBillGenerate,
  Permission.gstr9View,
  Permission.gstr9Prepare,
  Permission.gstr9File,
  Permission.gstr9cView,
  Permission.gstr9cPrepare,
  Permission.gstr9cCertify,
  Permission.budgetView,
  Permission.budgetCreate,
  Permission.budgetEdit,
  Permission.forecastView,
  Permission.forecastCreate,
  Permission.forecastEdit,
  Permission.auditDashboardView,
  Permission.complianceReportView,
  Permission.complianceReportExport,
};

const _phase7Admin = {
  ..._phase7Core,
  Permission.eInvoiceCancel,
  Permission.eWayBillCancel,
  Permission.eWayBillExtend,
  Permission.budgetApprove,
};

const _phase8Architect = {
  Permission.currencyView,
  Permission.exchangeRateView,
  Permission.paymentScheduleView,
  Permission.notificationPreferenceView,
  Permission.notificationPreferenceEdit,
  Permission.analyticsView,
  Permission.kpiView,
};

const _phase8Core = {
  Permission.currencyView,
  Permission.exchangeRateView,
  Permission.exchangeRateUpdate,
  Permission.paymentScheduleView,
  Permission.paymentScheduleCreate,
  Permission.paymentScheduleEdit,
  Permission.paymentScheduleApprove,
  Permission.paymentScheduleProcess,
  Permission.notificationPreferenceView,
  Permission.notificationPreferenceEdit,
  Permission.integrationView,
  Permission.integrationSync,
  Permission.analyticsView,
  Permission.analyticsExport,
  Permission.kpiView,
};

const _phase8Admin = {
  ..._phase8Core,
  Permission.currencyCreate,
  Permission.currencyEdit,
  Permission.integrationConfigure,
  Permission.brandingView,
  Permission.brandingEdit,
  Permission.backupView,
  Permission.backupCreate,
  Permission.backupRestore,
  Permission.backupDelete,
  Permission.kpiConfigure,
  Permission.auditLogExport,
  Permission.systemSettingsView,
  Permission.systemSettingsEdit,
};

const _phase8Portal = {
  Permission.currencyView,
  Permission.notificationPreferenceView,
  Permission.notificationPreferenceEdit,
  Permission.brandingView,
};

const _phase8VendorExtra = {
  Permission.exchangeRateView,
};

const _phase9Shared = {
  Permission.aiOcrExtract,
  Permission.aiNaturalLanguageQuery,
  Permission.aiSemanticSearch,
  Permission.voiceToText,
  Permission.ocrUpload,
  Permission.whatsappView,
  Permission.whatsappSend,
};

const _phase9Architect = {
  ..._phase9Shared,
  Permission.aiQuotationSuggest,
  Permission.aiCostEstimate,
  Permission.aiTimelinePredict,
  Permission.aiImageAnalyze,
  Permission.sitePhotoUpload,
  Permission.sitePhotoAnalyze,
};

const _phase9Accountant = {
  ..._phase9Shared,
  Permission.ocrVerify,
};

const _phase9Admin = {
  ..._phase9Architect,
  Permission.ocrVerify,
  Permission.aiLeadScore,
  Permission.aiEmbedDocument,
  Permission.tenantView,
};

const _phase9Super = {
  Permission.tenantCreate,
  Permission.tenantEdit,
  Permission.tenantDelete,
  Permission.tenantSubscriptionView,
  Permission.tenantSubscriptionEdit,
  Permission.multiFirmDashboard,
  Permission.multiFirmAnalytics,
  Permission.whatsappConfigure,
};

const _phase9Client = {
  Permission.whatsappView,
  Permission.aiSemanticSearch,
};

const _phase9Vendor = {
  Permission.whatsappView,
};

const _phase5Vendor = {
  Permission.projectView,
  Permission.taskView,
  Permission.vendorView,
  Permission.projectVendorView,
  Permission.rfqView,
  Permission.vendorQuoteView,
  Permission.vendorQuoteCreate,
  Permission.vendorQuoteEdit,
  Permission.purchaseOrderView,
  Permission.vendorBillView,
  Permission.vendorBillCreate,
  Permission.vendorBillEdit,
  Permission.vendorPaymentView,
  Permission.vendorPortalAccess,
};

const Map<UserRole, Set<Permission>> kRolePermissions = {
  UserRole.superAdmin: {
    Permission.userView,
    Permission.userCreate,
    Permission.userEdit,
    Permission.userDelete,
    Permission.clientView,
    Permission.clientInvite,
    Permission.invoiceView,
    Permission.auditLogView,
    Permission.settingsManage,
    ..._catalogAdmin,
    ..._phase3Staff,
    ..._phase4Admin,
    ..._phase5Admin,
    ..._phase6Admin,
    ..._phase6Client,
    ..._phase7Admin,
    ..._phase8Admin,
    ..._phase9Admin,
    ..._phase9Super,
    Permission.quotationApprove,
    Permission.quotationReject,
    Permission.clientPortalAccess,
    Permission.vendorPortalAccess,
  },
  UserRole.admin: {
    Permission.userView,
    Permission.userCreate,
    Permission.userEdit,
    Permission.clientView,
    Permission.clientInvite,
    Permission.invoiceView,
    Permission.auditLogView,
    Permission.settingsManage,
    ..._catalogAdmin,
    ..._phase3Staff,
    ..._phase4Admin,
    ..._phase5Admin,
    ..._phase6Admin,
    ..._phase7Admin,
    ..._phase8Admin,
    ..._phase9Admin,
    Permission.clientPortalAccess,
  },
  UserRole.architect: {
    Permission.clientView,
    Permission.catalogView,
    Permission.enquiryView,
    Permission.enquiryManage,
    Permission.enquiryConvert,
    ..._phase3Staff,
    ..._phase4Core,
    ..._phase5Architect,
    ..._phase6Architect,
    ..._phase7Architect,
    ..._phase8Architect,
    ..._phase9Architect,
  },
  UserRole.accountant: {
    Permission.clientView,
    Permission.invoiceView,
    Permission.auditLogView,
    Permission.quotationView,
    Permission.projectView,
    Permission.timesheetView,
    Permission.timesheetApprove,
    Permission.activityView,
    ..._phase5Accountant,
    ..._phase6Core,
    ..._phase7Core,
    ..._phase8Core,
    ..._phase9Accountant,
  },
  UserRole.vendor: {
    ..._phase5Vendor,
    ..._phase8Portal,
    ..._phase8VendorExtra,
    ..._phase9Vendor,
  },
  UserRole.client: {
    Permission.serviceRequestView,
    Permission.serviceRequestCreate,
    Permission.serviceRequestEdit,
    Permission.quotationView,
    Permission.quotationApprove,
    Permission.quotationReject,
    Permission.messageView,
    Permission.messageSend,
    Permission.clientPortalAccess,
    Permission.projectView,
    Permission.milestoneView,
    Permission.taskView,
    Permission.documentView,
    Permission.changeRequestView,
    Permission.changeRequestCreate,
    ..._phase6Client,
    ..._phase8Portal,
    ..._phase9Client,
  },
};

bool hasPermission(UserRole role, Permission permission) =>
    kRolePermissions[role]?.contains(permission) ?? false;
