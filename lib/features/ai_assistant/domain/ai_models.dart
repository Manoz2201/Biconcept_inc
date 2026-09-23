import '../../../core/result/app_result.dart';

class AIMessage {
  const AIMessage({required this.role, required this.content, required this.timestamp});

  final String role;
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory AIMessage.fromJson(Map<String, dynamic> data) => AIMessage(
        role: data['role']?.toString() ?? 'user',
        content: data['content']?.toString() ?? '',
        timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AIConversation {
  const AIConversation({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.sessionId,
    this.title,
    this.messages = const [],
    this.context,
    this.model = 'local-heuristic',
    this.tokensUsed,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String userId;
  final String sessionId;
  final String? title;
  final List<AIMessage> messages;
  final Map<String, dynamic>? context;
  final String model;
  final int? tokensUsed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'userId': userId,
        'sessionId': sessionId,
        'title': ?title,
        'messages': [for (final item in messages) item.toJson()],
        'context': ?context,
        'model': model,
        'tokensUsed': ?tokensUsed,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory AIConversation.fromJson(Map<String, dynamic> data) => AIConversation(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        sessionId: data['sessionId']?.toString() ?? '',
        title: data['title']?.toString(),
        messages: [
          if (data['messages'] is List)
            for (final item in data['messages'] as List)
              if (item is Map) AIMessage.fromJson(Map<String, dynamic>.from(item)),
        ],
        context: data['context'] is Map ? Map<String, dynamic>.from(data['context'] as Map) : null,
        model: data['model']?.toString() ?? 'local-heuristic',
        tokensUsed: (data['tokensUsed'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

enum SuggestionStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected'),
  expired('expired', 'Expired');

  const SuggestionStatus(this.value, this.label);
  final String value;
  final String label;

  static SuggestionStatus fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => SuggestionStatus.pending,
      );
}

enum SuggestionType {
  costEstimate('cost_estimate', 'Cost estimate'),
  timeline('timeline', 'Timeline'),
  lineItem('line_item', 'Line items'),
  risk('risk', 'Risk'),
  leadScore('lead_score', 'Lead score');

  const SuggestionType(this.value, this.label);
  final String value;
  final String label;

  static SuggestionType fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => SuggestionType.lineItem,
      );
}

class AISuggestion {
  const AISuggestion({
    required this.id,
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.suggestionType,
    required this.suggestionData,
    this.confidence,
    required this.status,
    this.acceptedBy,
    this.acceptedAt,
    this.rejectedReason,
    this.model,
    this.tokensUsed,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String entityType;
  final String entityId;
  final SuggestionType suggestionType;
  final Map<String, dynamic> suggestionData;
  final double? confidence;
  final SuggestionStatus status;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final String? rejectedReason;
  final String? model;
  final int? tokensUsed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'entityType': entityType,
        'entityId': entityId,
        'suggestionType': suggestionType.value,
        'suggestionData': suggestionData,
        'confidence': ?confidence,
        'status': status.value,
        'acceptedBy': ?acceptedBy,
        'acceptedAt': ?acceptedAt?.toUtc().toIso8601String(),
        'rejectedReason': ?rejectedReason,
        'model': ?model,
        'tokensUsed': ?tokensUsed,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory AISuggestion.fromJson(Map<String, dynamic> data) => AISuggestion(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        entityType: data['entityType']?.toString() ?? '',
        entityId: data['entityId']?.toString() ?? '',
        suggestionType: SuggestionType.fromString(data['suggestionType']?.toString()),
        suggestionData: data['suggestionData'] is Map ? Map<String, dynamic>.from(data['suggestionData'] as Map) : const {},
        confidence: (data['confidence'] as num?)?.toDouble(),
        status: SuggestionStatus.fromString(data['status']?.toString()),
        acceptedBy: data['acceptedBy']?.toString(),
        acceptedAt: DateTime.tryParse(data['acceptedAt']?.toString() ?? ''),
        rejectedReason: data['rejectedReason']?.toString(),
        model: data['model']?.toString(),
        tokensUsed: (data['tokensUsed'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  AISuggestion copyWith({
    SuggestionStatus? status,
    String? acceptedBy,
    DateTime? acceptedAt,
    String? rejectedReason,
    DateTime? updatedAt,
  }) =>
      AISuggestion(
        id: id,
        tenantId: tenantId,
        entityType: entityType,
        entityId: entityId,
        suggestionType: suggestionType,
        suggestionData: suggestionData,
        confidence: confidence,
        status: status ?? this.status,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        rejectedReason: rejectedReason ?? this.rejectedReason,
        model: model,
        tokensUsed: tokensUsed,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class SemanticSearchResult {
  const SemanticSearchResult({
    required this.sourceType,
    required this.sourceId,
    required this.text,
    required this.similarity,
  });

  final String sourceType;
  final String sourceId;
  final String text;
  final double similarity;
}

class NlpQueryResult {
  const NlpQueryResult({required this.interpreted, required this.entity, required this.filters, required this.rows});

  final String interpreted;
  final String entity;
  final Map<String, dynamic> filters;
  final List<Map<String, String>> rows;
}

class VectorDocument {
  const VectorDocument({
    required this.id,
    required this.tenantId,
    required this.sourceType,
    required this.sourceId,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String sourceType;
  final String sourceId;
  final String text;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'text': text,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory VectorDocument.fromJson(Map<String, dynamic> data) => VectorDocument(
        id: data['id']?.toString() ?? '',
        tenantId: data['tenantId']?.toString() ?? '',
        sourceType: data['sourceType']?.toString() ?? '',
        sourceId: data['sourceId']?.toString() ?? '',
        text: data['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

abstract class AIRepository {
  Future<AppResult<List<AIConversation>>> getConversations();
  Future<AppResult<AIConversation>> getConversationById(String id);
  Future<AppResult<AIConversation>> createConversation({String? title});
  Future<AppResult<AIConversation>> sendMessage(String conversationId, String message, {Map<String, dynamic>? context});
  Future<AppResult<void>> deleteConversation(String id);
  Future<AppResult<List<AISuggestion>>> getSuggestions({String? entityType, String? entityId, SuggestionStatus? status});
  Future<AppResult<AISuggestion>> requestQuotationSuggestion(String serviceRequestId);
  Future<AppResult<AISuggestion>> requestCostEstimate(String projectId, Map<String, dynamic> params);
  Future<AppResult<AISuggestion>> requestTimelinePrediction(String projectId);
  Future<AppResult<AISuggestion>> requestLeadScore(String enquiryId);
  Future<AppResult<AISuggestion>> acceptSuggestion(String id);
  Future<AppResult<AISuggestion>> rejectSuggestion(String id, String reason);
  Future<AppResult<List<SemanticSearchResult>>> semanticSearch(String query, {String? sourceType});
  Future<AppResult<VectorDocument>> embedDocument({required String sourceType, required String sourceId, required String text});
  Future<AppResult<NlpQueryResult>> naturalLanguageQuery(String query);
}
