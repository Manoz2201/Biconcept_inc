import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../../enquiries/domain/enquiry.dart';
import '../../image_ai/domain/site_photo.dart';
import '../../intelligence/domain/intelligence_math.dart';
import '../../invoices/data/invoice_workspace_store.dart';
import '../../invoices/domain/invoice.dart';
import '../../multi_firm/domain/tenant.dart';
import '../../ocr/domain/ocr_models.dart';
import '../../predictive/domain/predictive_models.dart';
import '../../projects/domain/project.dart';
import '../../voice/domain/voice_config.dart';
import '../../whatsapp/domain/whatsapp_models.dart';
import 'intelligence_workspace.dart';
import 'intelligence_workspace_store.dart';

class IntelligenceRepositoryImpl
    implements
        TenantRepository,
        SubscriptionRepository,
        AIRepository,
        OCRRepository,
        ImageAIService,
        WhatsAppRepository,
        PredictiveRepository {
  IntelligenceRepositoryImpl({
    IntelligenceWorkspaceStore? store,
    InvoiceWorkspaceStore? invoices,
    Functions? functions,
    TablesDB? tables,
    AuditRepository? audit,
    String Function()? actorId,
    bool Function()? isSuperAdmin,
  })  : _store = store ?? IntelligenceWorkspaceStore(),
        _invoices = invoices ?? InvoiceWorkspaceStore(),
        _functions = functions ?? AppwriteService.functions,
        _tables = tables ?? AppwriteService.tables,
        _audit = audit ?? AuditRepository(),
        _actorId = actorId ?? (() => 'unknown'),
        _isSuperAdmin = isSuperAdmin ?? (() => false);

  final IntelligenceWorkspaceStore _store;
  final InvoiceWorkspaceStore _invoices;
  final Functions _functions;
  final TablesDB _tables;
  final AuditRepository _audit;
  final String Function() _actorId;
  final bool Function() _isSuperAdmin;
  final RateLimiter _limiter = RateLimiter();

  Future<IntelligenceWorkspace> _ws() async => (await _store.ensure()).workspace;

  Future<IntelligenceWorkspace> _save(IntelligenceWorkspace workspace) async =>
      (await _store.save(workspace)).workspace;

  Future<void> _log(String action, [Map<String, dynamic>? metadata]) async {
    await _audit.log(userId: _actorId(), action: action, metadata: {'tenantId': (await _ws()).currentTenantId, ...?metadata});
  }

  T _require<T>(T? item, String label) {
    if (item == null) throw AppwriteException('$label not found', 404);
    return item;
  }

  bool _owns(String tenantId, String current) => tenantId == current || _isSuperAdmin();

  Future<Map<String, dynamic>?> _fn(String id, Map<String, dynamic> body) async {
    try {
      final execution = await _functions.createExecution(functionId: id, body: jsonEncode(body));
      final decoded = jsonDecode(execution.responseBody);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  void _guardAi(IntelligenceWorkspace ws) {
    if (!_limiter.canProceed('ai:${ws.currentTenantId}', maxCalls: dailyAiLimit(ws.current.subscriptionPlan), window: const Duration(days: 1))) {
      throw AppwriteException('AI daily limit reached for this plan', 429);
    }
  }

  @override
  Future<AppResult<Tenant>> getCurrentTenant() {
    return AppwriteService.guard(() async => (await _ws()).current);
  }

  @override
  Future<AppResult<Tenant>> switchTenant(String tenantId) {
    return AppwriteService.guard(() async {
      if (!_isSuperAdmin()) throw AppwriteException('Only super admin can switch firms', 403);
      final ws = await _ws();
      final tenant = _require(ws.tenants.cast<Tenant?>().firstWhere((item) => item?.id == tenantId, orElse: () => null), 'Tenant');
      await _save(ws.copyWith(currentTenantId: tenant.id));
      return tenant;
    });
  }

  @override
  Future<AppResult<List<Tenant>>> getTenants() {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      if (_isSuperAdmin()) return ws.tenants;
      return [ws.current];
    });
  }

  @override
  Future<AppResult<Tenant>> getTenantById(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final tenant = _require(ws.tenants.cast<Tenant?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Tenant');
      if (!_owns(tenant.id, ws.currentTenantId)) throw AppwriteException('Cross-tenant access blocked', 403);
      return tenant;
    });
  }

  @override
  Future<AppResult<Tenant>> createTenant({required String name, required String subdomain, required String adminEmail, String plan = 'basic'}) {
    return AppwriteService.guard(() async {
      if (!_isSuperAdmin()) throw AppwriteException('Only super admin can create firms', 403);
      final remote = await _fn(AppwriteService.tenantProvisionFn, {'tenantName': name, 'subdomain': subdomain, 'adminEmail': adminEmail, 'plan': plan});
      final now = DateTime.now().toUtc();
      final limits = plan == 'enterprise' ? (999, 9999, 24999.0) : plan == 'pro' ? (20, 100, 9999.0) : (5, 10, 2999.0);
      final tenant = Tenant(
        id: remote?['tenantId']?.toString() ?? ID.unique(),
        name: name,
        subdomain: subdomain,
        subscriptionPlan: plan,
        subscriptionStatus: 'trial',
        trialEndsAt: now.add(const Duration(days: 14)),
        maxUsers: limits.$1,
        maxProjects: limits.$2,
        createdAt: now,
        updatedAt: now,
      );
      final sub = TenantSubscription(
        id: ID.unique(),
        tenantId: tenant.id,
        plan: plan,
        status: 'trial',
        currentPeriodStart: now,
        currentPeriodEnd: now.add(const Duration(days: 14)),
        amount: limits.$3,
        maxUsers: limits.$1,
        maxProjects: limits.$2,
        maxStorageGB: plan == 'enterprise' ? 500 : plan == 'pro' ? 50 : 5,
        createdAt: now,
        updatedAt: now,
      );
      final ws = await _ws();
      await _save(ws.copyWith(tenants: [...ws.tenants, tenant], subscriptions: [...ws.subscriptions, sub]));
      await _log('tenant_created', {'id': tenant.id, 'adminEmail': adminEmail});
      return tenant;
    });
  }

  @override
  Future<AppResult<Tenant>> updateTenant(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.tenants.cast<Tenant?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Tenant');
      if (!_owns(current.id, ws.currentTenantId)) throw AppwriteException('Cross-tenant access blocked', 403);
      final next = Tenant.fromJson({...current.toJson(), ...data, 'id': id, 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(tenants: [for (final item in ws.tenants) item.id == id ? next : item]));
      await _log('tenant_updated', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteTenant(String id) {
    return AppwriteService.guard(() async {
      if (id == Env.defaultTenantId) throw AppwriteException('The default firm cannot be deleted', 400);
      if (!_isSuperAdmin()) throw AppwriteException('Only super admin can delete firms', 403);
      final ws = await _ws();
      await _save(ws.copyWith(
        tenants: [for (final item in ws.tenants) if (item.id != id) item],
        currentTenantId: ws.currentTenantId == id ? Env.defaultTenantId : ws.currentTenantId,
      ));
      await _log('tenant_deleted', {'id': id});
    });
  }

  @override
  Future<AppResult<TenantUsage>> getTenantUsage(String tenantId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      if (!_owns(tenantId, ws.currentTenantId)) throw AppwriteException('Cross-tenant access blocked', 403);
      final tenant = _require(ws.tenants.cast<Tenant?>().firstWhere((item) => item?.id == tenantId, orElse: () => null), 'Tenant');
      var users = 0;
      var projects = 0;
      try {
        users = (await _tables.listRows(databaseId: AppwriteService.dbId, tableId: AppwriteService.usersCol, queries: [Query.limit(1)])).total;
        projects = (await _tables.listRows(databaseId: AppwriteService.dbId, tableId: AppwriteService.projectsCol, queries: [Query.limit(1)])).total;
      } catch (_) {}
      return TenantUsage(
        users: users,
        projects: projects,
        storageGB: 0.2,
        aiTokens: ws.aiCallsToday,
        whatsappMessages: ws.whatsapp.where((item) => item.tenantId == tenantId).length,
        userLimit: tenant.maxUsers,
        projectLimit: tenant.maxProjects,
        storageLimitGB: 50,
      );
    });
  }

  @override
  Future<AppResult<TenantSubscription>> getSubscription(String tenantId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return _require(ws.subscriptions.cast<TenantSubscription?>().firstWhere((item) => item?.tenantId == tenantId, orElse: () => null), 'Subscription');
    });
  }

  @override
  Future<AppResult<TenantSubscription>> createSubscription({required String tenantId, required String plan}) {
    return upgradePlan(tenantId, plan);
  }

  TenantSubscription _planSub(String tenantId, String plan) {
    final now = DateTime.now().toUtc();
    final limits = plan == 'enterprise' ? (999, 9999, 24999.0, 500) : plan == 'pro' ? (20, 100, 9999.0, 50) : (5, 10, 2999.0, 5);
    return TenantSubscription(
      id: ID.unique(),
      tenantId: tenantId,
      plan: plan,
      status: 'active',
      currentPeriodStart: now,
      currentPeriodEnd: now.add(const Duration(days: 30)),
      amount: limits.$3,
      maxUsers: limits.$1,
      maxProjects: limits.$2,
      maxStorageGB: limits.$4,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<AppResult<TenantSubscription>> upgradePlan(String tenantId, String newPlan) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final next = _planSub(tenantId, newPlan);
      await _save(ws.copyWith(
        subscriptions: [for (final item in ws.subscriptions) if (item.tenantId != tenantId) item, next],
        tenants: [
          for (final item in ws.tenants)
            item.id == tenantId ? Tenant.fromJson({...item.toJson(), 'subscriptionPlan': newPlan, 'maxUsers': next.maxUsers, 'maxProjects': next.maxProjects}) : item,
        ],
      ));
      await _log('subscription_upgraded', {'tenantId': tenantId, 'plan': newPlan});
      return next;
    });
  }

  @override
  Future<AppResult<TenantSubscription>> downgradePlan(String tenantId, String newPlan) => upgradePlan(tenantId, newPlan);

  @override
  Future<AppResult<TenantSubscription>> cancelSubscription(String id, {String? reason}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.subscriptions.cast<TenantSubscription?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Subscription');
      final next = TenantSubscription.fromJson({...current.toJson(), 'status': 'cancelled', 'updatedAt': DateTime.now().toUtc().toIso8601String()});
      await _save(ws.copyWith(subscriptions: [for (final item in ws.subscriptions) item.id == id ? next : item]));
      await _log('subscription_cancelled', {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<List<AIConversation>>> getConversations() {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return ws.conversations.where((item) => item.tenantId == ws.currentTenantId && item.userId == _actorId()).toList();
    });
  }

  @override
  Future<AppResult<AIConversation>> getConversationById(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final row = _require(ws.conversations.cast<AIConversation?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Conversation');
      if (!_owns(row.tenantId, ws.currentTenantId)) throw AppwriteException('Cross-tenant access blocked', 403);
      return row;
    });
  }

  @override
  Future<AppResult<AIConversation>> createConversation({String? title}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final now = DateTime.now().toUtc();
      final row = AIConversation(
        id: ID.unique(),
        tenantId: ws.currentTenantId,
        userId: _actorId(),
        sessionId: ID.unique(),
        title: title ?? 'New chat',
        createdAt: now,
        updatedAt: now,
      );
      await _save(ws.copyWith(conversations: [row, ...ws.conversations]));
      await _log('ai_conversation_created', {'id': row.id});
      return row;
    });
  }

  @override
  Future<AppResult<AIConversation>> sendMessage(String conversationId, String message, {Map<String, dynamic>? context}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      _guardAi(ws);
      final current = _require(ws.conversations.cast<AIConversation?>().firstWhere((item) => item?.id == conversationId, orElse: () => null), 'Conversation');
      final now = DateTime.now().toUtc();
      final remote = await _fn(AppwriteService.aiNaturalLanguageQueryFn, {'query': message, 'tenantId': ws.currentTenantId});
      final reply = remote?['reply']?.toString() ?? assistantReply(message);
      final next = AIConversation.fromJson({
        ...current.toJson(),
        'messages': [
          ...current.messages.map((item) => item.toJson()),
          AIMessage(role: 'user', content: message, timestamp: now).toJson(),
          AIMessage(role: 'assistant', content: reply, timestamp: now).toJson(),
        ],
        'updatedAt': now.toIso8601String(),
      });
      await _save(ws.copyWith(conversations: [for (final item in ws.conversations) item.id == conversationId ? next : item], aiCallsToday: ws.aiCallsToday + 1));
      await _log('ai_message_sent', {'id': conversationId});
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteConversation(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _save(ws.copyWith(conversations: [for (final item in ws.conversations) if (item.id != id) item]));
    });
  }

  @override
  Future<AppResult<List<AISuggestion>>> getSuggestions({String? entityType, String? entityId, SuggestionStatus? status}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return ws.suggestions.where((item) {
        if (item.tenantId != ws.currentTenantId) return false;
        if (entityType != null && item.entityType != entityType) return false;
        if (entityId != null && item.entityId != entityId) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  Future<AISuggestion> _storeSuggestion(IntelligenceWorkspace ws, AISuggestion row) async {
    await _save(ws.copyWith(suggestions: [row, ...ws.suggestions], aiCallsToday: ws.aiCallsToday + 1));
    await _log('ai_suggestion_created', {'id': row.id, 'type': row.suggestionType.value});
    await AppNotifications.instance.showImmediate(title: 'AI suggestion ready', body: row.suggestionType.label);
    return row;
  }

  @override
  Future<AppResult<AISuggestion>> requestQuotationSuggestion(String serviceRequestId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      _guardAi(ws);
      await _fn(AppwriteService.aiQuotationSuggestFn, {'serviceRequestId': serviceRequestId, 'tenantId': ws.currentTenantId});
      final now = DateTime.now().toUtc();
      final data = {
        'lineItems': [
          {'description': 'Concept design and drawings', 'quantity': 1, 'unitPrice': 85000, 'total': 85000},
          {'description': 'Working drawings', 'quantity': 1, 'unitPrice': 120000, 'total': 120000},
          {'description': 'Site visits (lumpsum)', 'quantity': 8, 'unitPrice': 7500, 'total': 60000},
        ],
        'confidence': 72,
        'notes': 'Heuristic draft from similar architecture scopes. Review rates before sending.',
      };
      return _storeSuggestion(
        ws,
        AISuggestion(
          id: ID.unique(),
          tenantId: ws.currentTenantId,
          entityType: 'quotation',
          entityId: serviceRequestId,
          suggestionType: SuggestionType.lineItem,
          suggestionData: data,
          confidence: 72,
          status: SuggestionStatus.pending,
          model: 'local-heuristic',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<AppResult<AISuggestion>> requestCostEstimate(String projectId, Map<String, dynamic> params) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      _guardAi(ws);
      await _fn(AppwriteService.aiCostEstimateFn, {'projectId': projectId, 'tenantId': ws.currentTenantId, ...params});
      final project = await _project(projectId);
      final materials = (project?.budget ?? 500000) * 0.45;
      final labor = (project?.budget ?? 500000) * 0.35;
      final overhead = (project?.budget ?? 500000) * 0.2;
      final now = DateTime.now().toUtc();
      return _storeSuggestion(
        ws,
        AISuggestion(
          id: ID.unique(),
          tenantId: ws.currentTenantId,
          entityType: 'project',
          entityId: projectId,
          suggestionType: SuggestionType.costEstimate,
          suggestionData: {
            'materials': materials,
            'labor': labor,
            'overhead': overhead,
            'total': materials + labor + overhead,
            'assumptions': ['18% GST extra', 'Chennai labour rates'],
          },
          confidence: 68,
          status: SuggestionStatus.pending,
          model: 'local-heuristic',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<AppResult<AISuggestion>> requestTimelinePrediction(String projectId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      _guardAi(ws);
      await _fn(AppwriteService.aiTimelinePredictFn, {'projectId': projectId, 'tenantId': ws.currentTenantId});
      final project = await _project(projectId);
      final risk = project == null ? null : projectRisk(project);
      final now = DateTime.now().toUtc();
      return _storeSuggestion(
        ws,
        AISuggestion(
          id: ID.unique(),
          tenantId: ws.currentTenantId,
          entityType: 'project',
          entityId: projectId,
          suggestionType: SuggestionType.timeline,
          suggestionData: {
            'predictedEnd': (project?.endDate ?? now).add(Duration(days: risk?.predictedDelayDays ?? 7)).toIso8601String(),
            'bufferDays': risk?.predictedDelayDays ?? 7,
            'riskLevel': risk?.riskLevel ?? 'medium',
            'factors': risk?.factors ?? const ['Insufficient history'],
          },
          confidence: risk?.confidence ?? 0.6,
          status: SuggestionStatus.pending,
          model: 'local-heuristic',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<AppResult<AISuggestion>> requestLeadScore(String enquiryId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      _guardAi(ws);
      await _fn(AppwriteService.aiLeadScoreFn, {'enquiryId': enquiryId, 'tenantId': ws.currentTenantId});
      final enquiry = await _enquiry(enquiryId);
      final score = enquiry == null
          ? {'budget': 10, 'timeline': 10, 'location': 8, 'service': 8, 'engagement': 5, 'total': 41}
          : scoreLead(enquiry);
      final now = DateTime.now().toUtc();
      return _storeSuggestion(
        ws,
        AISuggestion(
          id: ID.unique(),
          tenantId: ws.currentTenantId,
          entityType: 'lead',
          entityId: enquiryId,
          suggestionType: SuggestionType.leadScore,
          suggestionData: {...score, 'priority': leadPriority(score['total'] ?? 0)},
          confidence: 70,
          status: SuggestionStatus.pending,
          model: 'local-heuristic',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<AppResult<AISuggestion>> acceptSuggestion(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.suggestions.cast<AISuggestion?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Suggestion');
      final next = current.copyWith(status: SuggestionStatus.accepted, acceptedBy: _actorId(), acceptedAt: DateTime.now().toUtc(), updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(suggestions: [for (final item in ws.suggestions) item.id == id ? next : item]));
      await _log('ai_suggestion_accepted', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<AISuggestion>> rejectSuggestion(String id, String reason) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.suggestions.cast<AISuggestion?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Suggestion');
      final next = current.copyWith(status: SuggestionStatus.rejected, rejectedReason: reason, updatedAt: DateTime.now().toUtc());
      await _save(ws.copyWith(suggestions: [for (final item in ws.suggestions) item.id == id ? next : item]));
      await _log('ai_suggestion_rejected', {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<List<SemanticSearchResult>>> semanticSearch(String query, {String? sourceType}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      await _fn(AppwriteService.aiSemanticSearchFn, {'queryText': query, 'sourceType': sourceType, 'tenantId': ws.currentTenantId});
      await _log('semantic_search_performed', {'query': query});
      return rankDocuments(query, ws.embeddings.where((item) => item.tenantId == ws.currentTenantId).toList(), sourceType: sourceType);
    });
  }

  @override
  Future<AppResult<VectorDocument>> embedDocument({required String sourceType, required String sourceId, required String text}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final row = VectorDocument(id: ID.unique(), tenantId: ws.currentTenantId, sourceType: sourceType, sourceId: sourceId, text: text, createdAt: DateTime.now().toUtc());
      await _save(ws.copyWith(embeddings: [row, ...ws.embeddings]));
      await _log('ai_embed_document', {'id': row.id});
      return row;
    });
  }

  @override
  Future<AppResult<NlpQueryResult>> naturalLanguageQuery(String query) {
    return AppwriteService.guard(() async {
      final invoices = [for (final row in await _invoices.list()) {'id': row.invoice.id, 'status': row.invoice.status.value, 'amount': '${row.invoice.grandTotal}', 'label': row.invoice.invoiceNumber}];
      final projects = [
        for (final row in await _listProjects()) {'id': row.id, 'status': row.status.value, 'amount': '${row.budget ?? 0}', 'label': row.title},
      ];
      await _log('natural_language_query_performed', {'query': query});
      return parseNaturalLanguage(query, invoices: invoices, projects: projects);
    });
  }

  Future<List<Project>> _listProjects() async {
    try {
      final page = await _tables.listRows(databaseId: AppwriteService.dbId, tableId: AppwriteService.projectsCol, queries: [Query.limit(100)]);
      return [for (final row in page.rows) Project.fromRow(row.$id, row.data)];
    } catch (_) {
      return const [];
    }
  }

  Future<Project?> _project(String id) async {
    try {
      final row = await _tables.getRow(databaseId: AppwriteService.dbId, tableId: AppwriteService.projectsCol, rowId: id);
      return Project.fromRow(row.$id, row.data);
    } catch (_) {
      return null;
    }
  }

  Future<Enquiry?> _enquiry(String id) async {
    try {
      final row = await _tables.getRow(databaseId: AppwriteService.dbId, tableId: AppwriteService.enquiriesCol, rowId: id);
      return Enquiry.fromRow(row.$id, row.data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppResult<OCRDocument>> uploadAndExtract(UploadBytes file, OCRDocumentType type) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      if (ws.ocrThisMonth >= monthlyOcrLimit(ws.current.subscriptionPlan)) {
        throw AppwriteException('OCR monthly limit reached', 429);
      }
      validateUpload(file.bytes, file.filename);
      final created = await AppwriteService.storage.createFile(
        bucketId: AppwriteService.portfolioImagesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: Uint8List.fromList(file.bytes), filename: sanitizeUploadName(file.filename)),
        permissions: [Permission.read(Role.team(AppwriteService.teamStaff))],
      );
      final raw = utf8.decode(file.bytes, allowMalformed: true);
      final extracted = type == OCRDocumentType.receipt ? parseReceiptText(raw) : parseInvoiceText(raw);
      await _fn(AppwriteService.aiOcrExtractFn, {'fileId': created.$id, 'documentType': type.value, 'tenantId': ws.currentTenantId});
      final now = DateTime.now().toUtc();
      final row = OCRDocument(
        id: ID.unique(),
        tenantId: ws.currentTenantId,
        documentType: type,
        fileId: created.$id,
        extractedData: extracted,
        rawText: raw.length > 4000 ? raw.substring(0, 4000) : raw,
        confidence: extracted.values.where((value) => value != null).length / 4,
        status: OCRStatus.completed,
        uploadedBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      await _save(ws.copyWith(ocrDocuments: [row, ...ws.ocrDocuments], ocrThisMonth: ws.ocrThisMonth + 1));
      await _log('ocr_extraction_completed', {'id': row.id});
      return row;
    });
  }

  @override
  Future<AppResult<List<OCRDocument>>> getDocuments({OCRDocumentType? type, OCRStatus? status}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return ws.ocrDocuments.where((item) {
        if (item.tenantId != ws.currentTenantId) return false;
        if (type != null && item.documentType != type) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<OCRDocument>> getDocumentById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).ocrDocuments.cast<OCRDocument?>().firstWhere((item) => item?.id == id, orElse: () => null), 'OCR document');
    });
  }

  @override
  Future<AppResult<OCRDocument>> verifyDocument(String id, Map<String, dynamic> correctedData) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.ocrDocuments.cast<OCRDocument?>().firstWhere((item) => item?.id == id, orElse: () => null), 'OCR document');
      final next = OCRDocument.fromJson({
        ...current.toJson(),
        'extractedData': correctedData,
        'status': OCRStatus.verified.value,
        'verifiedBy': _actorId(),
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _save(ws.copyWith(ocrDocuments: [for (final item in ws.ocrDocuments) item.id == id ? next : item]));
      await _log('ocr_document_verified', {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<OCRDocument>> linkToEntity(String documentId, String entityType, String entityId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.ocrDocuments.cast<OCRDocument?>().firstWhere((item) => item?.id == documentId, orElse: () => null), 'OCR document');
      if (current.status != OCRStatus.verified) throw AppwriteException('Verify the document before linking', 400);
      final next = OCRDocument.fromJson({...current.toJson(), 'linkedEntityType': entityType, 'linkedEntityId': entityId});
      await _save(ws.copyWith(ocrDocuments: [for (final item in ws.ocrDocuments) item.id == documentId ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<Map<String, dynamic>>> extractInvoiceData(String text) {
    return AppwriteService.guard(() async => parseInvoiceText(text));
  }

  @override
  Future<AppResult<SitePhoto>> uploadPhoto({required String projectId, required UploadBytes file, String? caption, String? milestoneId}) {
    return AppwriteService.guard(() async {
      validateUpload(file.bytes, file.filename);
      final created = await AppwriteService.storage.createFile(
        bucketId: AppwriteService.portfolioImagesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: Uint8List.fromList(file.bytes), filename: sanitizeUploadName(file.filename)),
        permissions: [Permission.read(Role.team(AppwriteService.teamStaff)), Permission.read(Role.team(AppwriteService.teamClients))],
      );
      final labels = analyzeCaption('${caption ?? ''} ${file.filename}');
      final now = DateTime.now().toUtc();
      final ws = await _ws();
      final row = SitePhoto(
        id: ID.unique(),
        tenantId: ws.currentTenantId,
        projectId: projectId,
        milestoneId: milestoneId,
        fileId: created.$id,
        caption: caption,
        capturedAt: now,
        capturedBy: _actorId(),
        aiLabels: labels.labels,
        aiProgressEstimate: labels.progress,
        aiSafetyFlags: labels.safety,
        aiMaterialDetected: labels.materials,
        createdAt: now,
      );
      await _save(ws.copyWith(photos: [row, ...ws.photos]));
      await _log('site_photo_uploaded', {'id': row.id, 'projectId': projectId});
      if (labels.safety.isNotEmpty) await _log('safety_flag_detected', {'id': row.id});
      return row;
    });
  }

  @override
  Future<AppResult<List<SitePhoto>>> getSitePhotos(String projectId) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return ws.photos.where((item) => item.tenantId == ws.currentTenantId && item.projectId == projectId).toList();
    });
  }

  @override
  Future<AppResult<SitePhoto>> getSitePhotoById(String id) {
    return AppwriteService.guard(() async {
      return _require((await _ws()).photos.cast<SitePhoto?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Photo');
    });
  }

  @override
  Future<AppResult<ImageAnalysis>> analyzeImage(String photoId) {
    return AppwriteService.guard(() async {
      final photo = _require((await _ws()).photos.cast<SitePhoto?>().firstWhere((item) => item?.id == photoId, orElse: () => null), 'Photo');
      await _fn(AppwriteService.aiImageAnalyzeFn, {'fileId': photo.fileId, 'projectId': photo.projectId});
      await _log('site_photo_analyzed', {'id': photoId});
      return ImageAnalysis(
        labels: photo.aiLabels ?? const [],
        progressEstimate: photo.aiProgressEstimate ?? 0,
        safetyFlags: photo.aiSafetyFlags ?? const [],
        materials: photo.aiMaterialDetected ?? const [],
      );
    });
  }

  @override
  Future<AppResult<List<WhatsAppMessage>>> getMessages({String? clientId, String? projectId, WhatsAppStatus? status}) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      return ws.whatsapp.where((item) {
        if (item.tenantId != ws.currentTenantId) return false;
        if (clientId != null && item.clientId != clientId) return false;
        if (projectId != null && item.projectId != projectId) return false;
        if (status != null && item.status != status) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<WhatsAppMessage>> sendTextMessage({required String clientId, required String text, String? referenceType, String? referenceId}) {
    return _sendWhatsApp(clientId: clientId, type: 'text', content: {'text': text}, referenceType: referenceType, referenceId: referenceId);
  }

  @override
  Future<AppResult<WhatsAppMessage>> sendTemplateMessage({required String clientId, required String templateName, required List<String> variables}) {
    return _sendWhatsApp(clientId: clientId, type: 'template', templateName: templateName, content: {'templateName': templateName, 'variables': variables});
  }

  Future<AppResult<WhatsAppMessage>> _sendWhatsApp({
    required String clientId,
    required String type,
    required Map<String, dynamic> content,
    String? templateName,
    String? referenceType,
    String? referenceId,
  }) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      if (ws.whatsappThisMonth >= monthlyWhatsappLimit(ws.current.subscriptionPlan)) {
        throw AppwriteException('WhatsApp monthly limit reached', 429);
      }
      final remote = await _fn(AppwriteService.whatsappSendTemplateFn, {
        'clientId': clientId,
        'templateName': templateName,
        'variables': content['variables'],
        'tenantId': ws.currentTenantId,
      });
      final now = DateTime.now().toUtc();
      final row = WhatsAppMessage(
        id: ID.unique(),
        tenantId: ws.currentTenantId,
        clientId: clientId,
        templateName: templateName,
        messageType: type,
        direction: 'outbound',
        status: remote?['success'] == true ? WhatsAppStatus.sent : WhatsAppStatus.queued,
        content: content,
        referenceType: referenceType,
        referenceId: referenceId,
        sentAt: now,
        createdAt: now,
      );
      await _save(ws.copyWith(whatsapp: [row, ...ws.whatsapp], whatsappThisMonth: ws.whatsappThisMonth + 1));
      await _log('whatsapp_message_sent', {'id': row.id, 'template': templateName});
      return row;
    });
  }

  @override
  Future<AppResult<List<WhatsAppTemplate>>> getTemplates() {
    return AppwriteService.guard(() async => kWhatsAppTemplates);
  }

  @override
  Future<AppResult<WhatsAppConfig>> getConfig() {
    return AppwriteService.guard(() async => (await _ws()).whatsappConfig);
  }

  @override
  Future<AppResult<WhatsAppConfig>> updateConfig(Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final cleaned = {
        if (data['phoneNumberId'] != null) 'phoneNumberId': data['phoneNumberId'],
        if (data['webhookUrl'] != null) 'webhookUrl': data['webhookUrl'],
      };
      final next = WhatsAppConfig.fromJson(cleaned);
      final ws = await _ws();
      await _save(ws.copyWith(whatsappConfig: next));
      return next;
    });
  }

  @override
  Future<AppResult<RiskPrediction>> getProjectRisk(String projectId) {
    return AppwriteService.guard(() async {
      final project = await _project(projectId);
      if (project == null) throw AppwriteException('Project not found', 404);
      final risk = projectRisk(project);
      await _log('risk_detected', {'projectId': projectId, 'score': risk.riskScore});
      return risk;
    });
  }

  @override
  Future<AppResult<List<MaintenanceAlert>>> getMaintenanceAlerts({String? projectId, bool? isResolved}) {
    return AppwriteService.guard(() async {
      var ws = await _ws();
      if (ws.alerts.isEmpty) {
        final projects = await _listProjects();
        final generated = <MaintenanceAlert>[];
        for (final project in projects) {
          final risk = projectRisk(project);
          if (risk.riskScore < 40) continue;
          generated.add(
            MaintenanceAlert(
              id: ID.unique(),
              tenantId: ws.currentTenantId,
              projectId: project.id,
              alertType: risk.riskLevel == 'high' ? 'timeline_delay' : 'budget_overrun',
              severity: risk.riskLevel,
              description: risk.factors.join('; '),
              suggestedAction: risk.recommendations.join('; '),
              createdAt: DateTime.now().toUtc(),
            ),
          );
        }
        ws = await _save(ws.copyWith(alerts: generated));
      }
      return ws.alerts.where((item) {
        if (item.tenantId != ws.currentTenantId) return false;
        if (projectId != null && item.projectId != projectId) return false;
        if (isResolved != null && item.isResolved != isResolved) return false;
        return true;
      }).toList();
    });
  }

  @override
  Future<AppResult<MaintenanceAlert>> resolveAlert(String id) {
    return AppwriteService.guard(() async {
      final ws = await _ws();
      final current = _require(ws.alerts.cast<MaintenanceAlert?>().firstWhere((item) => item?.id == id, orElse: () => null), 'Alert');
      final next = current.copyWith(isResolved: true);
      await _save(ws.copyWith(alerts: [for (final item in ws.alerts) item.id == id ? next : item]));
      return next;
    });
  }

  @override
  Future<AppResult<ProjectHealth>> getProjectHealth(String projectId) {
    return AppwriteService.guard(() async {
      final project = await _project(projectId);
      if (project == null) throw AppwriteException('Project not found', 404);
      return projectHealth(project);
    });
  }

  @override
  Future<AppResult<List<double>>> getTrendForecast(String metric, {int periods = 6}) {
    return AppwriteService.guard(() async {
      final invoices = [for (final row in await _invoices.list()) row.invoice];
      final history = <double>[];
      final grouped = <String, double>{};
      for (final invoice in invoices) {
        if (invoice.status == InvoiceStatus.voided) continue;
        final key = '${invoice.invoiceDate.year}-${invoice.invoiceDate.month}';
        grouped[key] = (grouped[key] ?? 0) + invoice.grandTotal;
      }
      history.addAll(grouped.values);
      return linearForecast(history, periods);
    });
  }
}
