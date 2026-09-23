/// Compile-time Appwrite + deep-link settings.
///
/// Override with `--dart-define=APPWRITE_ENDPOINT=…` (see `.env.example`).
class Env {
  const Env._();

  static const appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://sgp.cloud.appwrite.io/v1',
  );

  static const appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6a86a3d4001d87aa9809',
  );

  static const databaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: '6a86ad9300190bcdd0df',
  );

  static const deepLinkScheme = String.fromEnvironment(
    'APPWRITE_DEEP_LINK_SCHEME',
    defaultValue: 'biconcept',
  );

  static const teamStaff = 'firm_staff';
  static const teamClients = 'clients';
  static const teamVendors = 'vendors';

  static const usersTable = 'users';
  static const auditTable = 'audit_logs';
  static const servicesTable = 'services';
  static const portfolioTable = 'portfolio_items';
  static const teamMembersTable = 'team_members';
  static const enquiriesTable = 'enquiries';
  static const serviceRequestsTable = 'service_requests';
  static const messagesTable = 'service_request_messages';
  static const chatMessagesTable = 'chat_messages';
  static const projectsTable = 'projects';
  static const vendorsTable = 'vendors';
  static const rfqsTable = 'rfqs';
  static const invoicesTable = 'invoices';
  static const financeTable = 'finance';
  static const financeRowId = 'firm';
  static const complianceTable = 'compliance';
  static const complianceRowId = 'firm';
  static const platformTable = 'platform';
  static const platformRowId = 'firm';
  static const intelligenceTable = 'intelligence';
  static const intelligenceRowId = 'firm';
  static const defaultTenantId = 'default_firm';
  static const aiQuotationSuggestFn = 'ai-quotation-suggest';
  static const aiCostEstimateFn = 'ai-cost-estimate';
  static const aiTimelinePredictFn = 'ai-timeline-predict';
  static const aiLeadScoreFn = 'ai-lead-score';
  static const aiOcrExtractFn = 'ai-ocr-extract';
  static const aiImageAnalyzeFn = 'ai-image-analyze';
  static const aiNaturalLanguageQueryFn = 'ai-natural-language-query';
  static const aiEmbedDocumentFn = 'ai-embed-document';
  static const aiSemanticSearchFn = 'ai-semantic-search';
  static const whatsappSendTemplateFn = 'whatsapp-send-template';
  static const whatsappWebhookFn = 'whatsapp-webhook';
  static const tenantProvisionFn = 'tenant-provision';
  static const tenantUsageTrackerFn = 'tenant-usage-tracker';
  static const syncExchangeRatesFn = 'sync-exchange-rates';
  static const processPaymentScheduleFn = 'process-payment-schedule';
  static const integrationSyncFn = 'integration-sync';
  static const createBackupFn = 'create-backup';
  static const restoreBackupFn = 'restore-backup';
  static const computeKpiMetricsFn = 'compute-kpi-metrics';
  static const sendPushNotificationFn = 'send-push-notification';
  static const gstr2bReconcileFn = 'gstr2b-reconcile';
  static const generateEinvoiceIrnFn = 'generate-einvoice-irn';
  static const generateEwaybillFn = 'generate-ewaybill';
  static const tdsCalculateFn = 'tds-calculate';
  static const generateTdsCertificateFn = 'generate-tds-certificate';
  static const gstTdsCalculateFn = 'gst-tds-calculate';
  static const validateEmailFn = 'validate-email';
  static const workersAiProxyFn = 'workers-ai-proxy';
  static const generateQuotationPdfFn = 'generate-quotation-pdf';
  static const generateProjectNumberFn = 'generate-project-number';
  static const generateRfqNumberFn = 'generate-rfq-number';
  static const generatePoNumberFn = 'generate-po-number';
  static const generateInvoiceNumberFn = 'generate-invoice-number';
  static const generateCreditNoteNumberFn = 'generate-credit-note-number';
  static const generateDebitNoteNumberFn = 'generate-debit-note-number';
  static const createRazorpayOrderFn = 'create-razorpay-order';
  static const verifyRazorpaySignatureFn = 'verify-razorpay-signature';
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');
  static const clientUploadsBucket = String.fromEnvironment(
    'APPWRITE_CLIENT_UPLOADS_BUCKET',
    defaultValue: 'portfolio_images',
  );
  static const portfolioImagesBucket = String.fromEnvironment(
    'APPWRITE_PORTFOLIO_IMAGES_BUCKET',
    defaultValue: 'portfolio_images',
  );
  static const teamPhotosBucket = String.fromEnvironment(
    'APPWRITE_TEAM_PHOTOS_BUCKET',
    defaultValue: 'portfolio_images',
  );

  static String get verifyUrl => '$deepLinkScheme://verify';
  static String get resetUrl => '$deepLinkScheme://reset-password';
  static String get inviteUrl => '$deepLinkScheme://invite';
}
