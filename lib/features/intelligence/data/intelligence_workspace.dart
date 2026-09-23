import 'dart:convert';

import '../../../core/config/env.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../image_ai/domain/site_photo.dart';
import '../../multi_firm/domain/tenant.dart';
import '../../ocr/domain/ocr_models.dart';
import '../../predictive/domain/predictive_models.dart';
import '../../whatsapp/domain/whatsapp_models.dart';

class IntelligenceWorkspace {
  IntelligenceWorkspace({
    List<Tenant>? tenants,
    List<TenantSubscription>? subscriptions,
    List<AIConversation>? conversations,
    List<AISuggestion>? suggestions,
    List<SitePhoto>? photos,
    List<OCRDocument>? ocrDocuments,
    List<WhatsAppMessage>? whatsapp,
    List<VectorDocument>? embeddings,
    List<MaintenanceAlert>? alerts,
    WhatsAppConfig? whatsappConfig,
    String? currentTenantId,
    this.aiCallsToday = 0,
    this.ocrThisMonth = 0,
    this.whatsappThisMonth = 0,
  })  : tenants = tenants ?? [defaultTenant()],
        subscriptions = subscriptions ?? [defaultSubscription()],
        conversations = conversations ?? [],
        suggestions = suggestions ?? [],
        photos = photos ?? [],
        ocrDocuments = ocrDocuments ?? [],
        whatsapp = whatsapp ?? [],
        embeddings = embeddings ?? [],
        alerts = alerts ?? [],
        whatsappConfig = whatsappConfig ?? const WhatsAppConfig(),
        currentTenantId = currentTenantId ?? Env.defaultTenantId;

  final List<Tenant> tenants;
  final List<TenantSubscription> subscriptions;
  final List<AIConversation> conversations;
  final List<AISuggestion> suggestions;
  final List<SitePhoto> photos;
  final List<OCRDocument> ocrDocuments;
  final List<WhatsAppMessage> whatsapp;
  final List<VectorDocument> embeddings;
  final List<MaintenanceAlert> alerts;
  final WhatsAppConfig whatsappConfig;
  final String currentTenantId;
  final int aiCallsToday;
  final int ocrThisMonth;
  final int whatsappThisMonth;

  static Tenant defaultTenant([DateTime? now]) {
    final stamp = now ?? DateTime.now().toUtc();
    return Tenant(
      id: Env.defaultTenantId,
      name: 'BiConcept',
      subdomain: 'biconcept',
      subscriptionPlan: 'pro',
      subscriptionStatus: 'active',
      maxUsers: 20,
      maxProjects: 100,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  static TenantSubscription defaultSubscription([DateTime? now]) {
    final stamp = now ?? DateTime.now().toUtc();
    return TenantSubscription(
      id: 'sub_default',
      tenantId: Env.defaultTenantId,
      plan: 'pro',
      status: 'active',
      currentPeriodStart: stamp,
      currentPeriodEnd: stamp.add(const Duration(days: 30)),
      amount: 9999,
      maxUsers: 20,
      maxProjects: 100,
      maxStorageGB: 50,
      features: const ['crm', 'ai', 'whatsapp', 'ocr'],
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  Tenant get current => tenants.firstWhere((item) => item.id == currentTenantId, orElse: () => tenants.first);

  String encode() => jsonEncode({
        'tenants': [for (final item in tenants) item.toJson()],
        'subscriptions': [for (final item in subscriptions) item.toJson()],
        'conversations': [for (final item in conversations.take(50)) item.toJson()],
        'suggestions': [for (final item in suggestions.take(200)) item.toJson()],
        'photos': [for (final item in photos.take(200)) item.toJson()],
        'ocrDocuments': [for (final item in ocrDocuments.take(200)) item.toJson()],
        'whatsapp': [for (final item in whatsapp.take(200)) item.toJson()],
        'embeddings': [for (final item in embeddings.take(300)) item.toJson()],
        'alerts': [for (final item in alerts.take(100)) item.toJson()],
        'whatsappConfig': whatsappConfig.toJson(),
        'currentTenantId': currentTenantId,
        'aiCallsToday': aiCallsToday,
        'ocrThisMonth': ocrThisMonth,
        'whatsappThisMonth': whatsappThisMonth,
      });

  factory IntelligenceWorkspace.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return IntelligenceWorkspace();
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return IntelligenceWorkspace();
      List<Map<String, dynamic>> maps(Object? value) => [
            if (value is List)
              for (final item in value)
                if (item is Map) Map<String, dynamic>.from(item),
          ];
      return IntelligenceWorkspace(
        tenants: [for (final item in maps(data['tenants'])) Tenant.fromJson(item)],
        subscriptions: [for (final item in maps(data['subscriptions'])) TenantSubscription.fromJson(item)],
        conversations: [for (final item in maps(data['conversations'])) AIConversation.fromJson(item)],
        suggestions: [for (final item in maps(data['suggestions'])) AISuggestion.fromJson(item)],
        photos: [for (final item in maps(data['photos'])) SitePhoto.fromJson(item)],
        ocrDocuments: [for (final item in maps(data['ocrDocuments'])) OCRDocument.fromJson(item)],
        whatsapp: [for (final item in maps(data['whatsapp'])) WhatsAppMessage.fromJson(item)],
        embeddings: [for (final item in maps(data['embeddings'])) VectorDocument.fromJson(item)],
        alerts: [for (final item in maps(data['alerts'])) MaintenanceAlert.fromJson(item)],
        whatsappConfig: WhatsAppConfig.fromJson(data['whatsappConfig'] is Map ? Map<String, dynamic>.from(data['whatsappConfig'] as Map) : null),
        currentTenantId: data['currentTenantId']?.toString() ?? Env.defaultTenantId,
        aiCallsToday: (data['aiCallsToday'] as num?)?.toInt() ?? 0,
        ocrThisMonth: (data['ocrThisMonth'] as num?)?.toInt() ?? 0,
        whatsappThisMonth: (data['whatsappThisMonth'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return IntelligenceWorkspace();
    }
  }

  IntelligenceWorkspace copyWith({
    List<Tenant>? tenants,
    List<TenantSubscription>? subscriptions,
    List<AIConversation>? conversations,
    List<AISuggestion>? suggestions,
    List<SitePhoto>? photos,
    List<OCRDocument>? ocrDocuments,
    List<WhatsAppMessage>? whatsapp,
    List<VectorDocument>? embeddings,
    List<MaintenanceAlert>? alerts,
    WhatsAppConfig? whatsappConfig,
    String? currentTenantId,
    int? aiCallsToday,
    int? ocrThisMonth,
    int? whatsappThisMonth,
  }) =>
      IntelligenceWorkspace(
        tenants: tenants ?? this.tenants,
        subscriptions: subscriptions ?? this.subscriptions,
        conversations: conversations ?? this.conversations,
        suggestions: suggestions ?? this.suggestions,
        photos: photos ?? this.photos,
        ocrDocuments: ocrDocuments ?? this.ocrDocuments,
        whatsapp: whatsapp ?? this.whatsapp,
        embeddings: embeddings ?? this.embeddings,
        alerts: alerts ?? this.alerts,
        whatsappConfig: whatsappConfig ?? this.whatsappConfig,
        currentTenantId: currentTenantId ?? this.currentTenantId,
        aiCallsToday: aiCallsToday ?? this.aiCallsToday,
        ocrThisMonth: ocrThisMonth ?? this.ocrThisMonth,
        whatsappThisMonth: whatsappThisMonth ?? this.whatsappThisMonth,
      );
}
