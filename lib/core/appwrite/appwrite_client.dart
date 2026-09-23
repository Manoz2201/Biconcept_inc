import 'package:appwrite/appwrite.dart';

import '../config/env.dart';
import '../errors/appwrite_error_mapper.dart';
import '../result/app_result.dart';

/// Session-based Appwrite client (Account / Teams / TablesDB / Functions).
/// CRM data sync still uses the API-key client in `lib/data/appwrite_sync.dart`.
class AppwriteService {
  AppwriteService._();

  static final Client client = Client()
    ..setEndpoint(Env.appwriteEndpoint)
    ..setProject(Env.appwriteProjectId);

  static final Account account = Account(client);
  static final TablesDB tables = TablesDB(client);
  static final Teams teams = Teams(client);
  static final Functions functions = Functions(client);
  static final Storage storage = Storage(client);

  static const String dbId = Env.databaseId;
  static const String usersCol = Env.usersTable;
  static const String auditCol = Env.auditTable;
  static const String servicesCol = Env.servicesTable;
  static const String portfolioCol = Env.portfolioTable;
  static const String teamMembersCol = Env.teamMembersTable;
  static const String enquiriesCol = Env.enquiriesTable;
  static const String serviceRequestsCol = Env.serviceRequestsTable;
  static const String messagesCol = Env.messagesTable;
  static const String chatMessagesCol = Env.chatMessagesTable;
  static const String projectsCol = Env.projectsTable;
  static const String vendorsCol = Env.vendorsTable;
  static const String rfqsCol = Env.rfqsTable;
  static const String invoicesCol = Env.invoicesTable;
  static const String financeCol = Env.financeTable;
  static const String complianceCol = Env.complianceTable;
  static const String platformCol = Env.platformTable;
  static const String intelligenceCol = Env.intelligenceTable;
  static const String aiQuotationSuggestFn = Env.aiQuotationSuggestFn;
  static const String aiCostEstimateFn = Env.aiCostEstimateFn;
  static const String aiTimelinePredictFn = Env.aiTimelinePredictFn;
  static const String aiLeadScoreFn = Env.aiLeadScoreFn;
  static const String aiOcrExtractFn = Env.aiOcrExtractFn;
  static const String aiImageAnalyzeFn = Env.aiImageAnalyzeFn;
  static const String aiNaturalLanguageQueryFn = Env.aiNaturalLanguageQueryFn;
  static const String aiEmbedDocumentFn = Env.aiEmbedDocumentFn;
  static const String aiSemanticSearchFn = Env.aiSemanticSearchFn;
  static const String whatsappSendTemplateFn = Env.whatsappSendTemplateFn;
  static const String tenantProvisionFn = Env.tenantProvisionFn;
  static const String syncExchangeRatesFn = Env.syncExchangeRatesFn;
  static const String processPaymentScheduleFn = Env.processPaymentScheduleFn;
  static const String integrationSyncFn = Env.integrationSyncFn;
  static const String createBackupFn = Env.createBackupFn;
  static const String restoreBackupFn = Env.restoreBackupFn;
  static const String computeKpiMetricsFn = Env.computeKpiMetricsFn;
  static const String sendPushNotificationFn = Env.sendPushNotificationFn;
  static const String gstr2bReconcileFn = Env.gstr2bReconcileFn;
  static const String generateEinvoiceIrnFn = Env.generateEinvoiceIrnFn;
  static const String generateEwaybillFn = Env.generateEwaybillFn;
  static const String tdsCalculateFn = Env.tdsCalculateFn;
  static const String generateTdsCertificateFn = Env.generateTdsCertificateFn;
  static const String gstTdsCalculateFn = Env.gstTdsCalculateFn;
  static const String validateFn = Env.validateEmailFn;
  static const String workersAiProxyFn = Env.workersAiProxyFn;
  static const String generateProjectNumberFn = Env.generateProjectNumberFn;
  static const String generateRfqNumberFn = Env.generateRfqNumberFn;
  static const String generatePoNumberFn = Env.generatePoNumberFn;
  static const String generateInvoiceNumberFn = Env.generateInvoiceNumberFn;
  static const String generateCreditNoteNumberFn = Env.generateCreditNoteNumberFn;
  static const String generateDebitNoteNumberFn = Env.generateDebitNoteNumberFn;
  static const String createRazorpayOrderFn = Env.createRazorpayOrderFn;
  static const String verifyRazorpaySignatureFn = Env.verifyRazorpaySignatureFn;
  static const String generateQuotationPdfFn = Env.generateQuotationPdfFn;
  static const String portfolioImagesBucket = Env.portfolioImagesBucket;
  static const String teamPhotosBucket = Env.teamPhotosBucket;
  static const String clientUploadsBucket = Env.clientUploadsBucket;
  static const String teamStaff = Env.teamStaff;
  static const String teamClients = Env.teamClients;
  static const String teamVendors = Env.teamVendors;

  static Future<AppResult<T>> guard<T>(Future<T> Function() body) async {
    try {
      return Success(await body());
    } on AppwriteException catch (error) {
      return Failure(AppwriteErrorMapper.fromAppwrite(error));
    } catch (error) {
      return Failure(AppwriteErrorMapper.unknown(error));
    }
  }
}
