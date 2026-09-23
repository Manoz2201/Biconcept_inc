import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_assistant/domain/ai_models.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../image_ai/domain/site_photo.dart';
import '../../../multi_firm/domain/tenant.dart';
import '../../../ocr/domain/ocr_models.dart';
import '../../../predictive/domain/predictive_models.dart';
import '../../../rbac/domain/user_role.dart';
import '../../../voice/domain/voice_config.dart';
import '../../../whatsapp/domain/whatsapp_models.dart';
import '../../data/intelligence_repository_impl.dart';

T _unwrap<T>(dynamic result) => result.when(
      success: (data) => data as T,
      failure: (error) => throw Exception(error.userMessage),
    );

final intelligenceRepositoryProvider = Provider<IntelligenceRepositoryImpl>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return IntelligenceRepositoryImpl(
    actorId: () => session.user?.accountId ?? 'unknown',
    isSuperAdmin: () => session.user?.role == UserRole.superAdmin,
  );
});

final currentTenantProvider = FutureProvider<Tenant>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getCurrentTenant());
});

final availableTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getTenants());
});

final tenantUsageProvider = FutureProvider.family<TenantUsage, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getTenantUsage(id));
});

final tenantSubscriptionProvider = FutureProvider.family<TenantSubscription, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getSubscription(id));
});

final aiConversationsProvider = FutureProvider<List<AIConversation>>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getConversations());
});

final aiConversationByIdProvider = FutureProvider.family<AIConversation, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getConversationById(id));
});

class SuggestionQuery {
  const SuggestionQuery({this.entityType, this.entityId, this.status});

  final String? entityType;
  final String? entityId;
  final SuggestionStatus? status;

  @override
  bool operator ==(Object other) =>
      other is SuggestionQuery && other.entityType == entityType && other.entityId == entityId && other.status == status;

  @override
  int get hashCode => Object.hash(entityType, entityId, status);
}

final aiSuggestionsProvider = FutureProvider.family<List<AISuggestion>, SuggestionQuery>((ref, query) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getSuggestions(
        entityType: query.entityType,
        entityId: query.entityId,
        status: query.status,
      ));
});

final semanticSearchProvider = FutureProvider.family<List<SemanticSearchResult>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).semanticSearch(query));
});

final nlpQueryProvider = FutureProvider.family<NlpQueryResult, String>((ref, query) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).naturalLanguageQuery(query));
});

final sitePhotosProvider = FutureProvider.family<List<SitePhoto>, String>((ref, projectId) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getSitePhotos(projectId));
});

final sitePhotoByIdProvider = FutureProvider.family<SitePhoto, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getSitePhotoById(id));
});

final ocrDocumentsProvider = FutureProvider.family<List<OCRDocument>, OCRDocumentType?>((ref, type) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getDocuments(type: type));
});

final ocrDocumentByIdProvider = FutureProvider.family<OCRDocument, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getDocumentById(id));
});

final whatsappMessagesProvider = FutureProvider.family<List<WhatsAppMessage>, String?>((ref, clientId) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getMessages(clientId: clientId));
});

final whatsappTemplatesProvider = FutureProvider<List<WhatsAppTemplate>>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getTemplates());
});

final whatsappConfigProvider = FutureProvider<WhatsAppConfig>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getConfig());
});

final projectRiskProvider = FutureProvider.family<RiskPrediction, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getProjectRisk(id));
});

final maintenanceAlertsProvider = FutureProvider<List<MaintenanceAlert>>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getMaintenanceAlerts());
});

final projectHealthProvider = FutureProvider.family<ProjectHealth, String>((ref, id) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getProjectHealth(id));
});

final trendForecastProvider = FutureProvider<List<double>>((ref) async {
  return _unwrap(await ref.watch(intelligenceRepositoryProvider).getTrendForecast('revenue'));
});

final voiceStateProvider = StateProvider<VoiceState>((ref) => const VoiceState());
