import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_data_display.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../intelligence/presentation/providers/intelligence_providers.dart';
import '../../../rbac/domain/permission.dart';
import '../../../voice/presentation/widgets/voice_input_button.dart';
import '../../domain/ai_models.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final _input = TextEditingController();
  String? _conversationId;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversationId == null ? null : ref.watch(aiConversationByIdProvider(_conversationId!));
    return PermissionGate(
      permission: Permission.aiNaturalLanguageQuery,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('AI assistant')),
        body: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Suggest quotation'), onPressed: () => context.push('/ai/quotation-suggest')),
                ActionChip(label: const Text('Estimate cost'), onPressed: () => context.push('/ai/cost-estimate')),
                ActionChip(label: const Text('Predict timeline'), onPressed: () => context.push('/ai/timeline-predict')),
                ActionChip(label: const Text('Score lead'), onPressed: () => context.push('/ai/lead-score')),
                ActionChip(label: const Text('Search everything'), onPressed: () => context.push('/ai/semantic-search')),
              ],
            ),
            Expanded(
              child: conversation == null
                  ? const Center(child: Text('Ask about invoices, quotations, or project risk'))
                  : conversation.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text('$error'),
                      data: (item) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in item.messages)
                            AppChatBubble(text: message.content, mine: message.role == 'user'),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  VoiceInputButton(onTranscription: (text) => _input.text = text),
                  Expanded(child: TextField(controller: _input, decoration: const InputDecoration(hintText: 'Ask in plain language'))),
                  AppIconButton(
                    icon: Icons.send,
                    accent: true,
                    onPressed: () async {
                      final text = _input.text.trim();
                      if (text.isEmpty) return;
                      if (_conversationId == null) {
                        final created = await ref.read(intelligenceRepositoryProvider).createConversation(title: text);
                        _conversationId = created.dataOrNull?.id;
                      }
                      if (_conversationId == null) return;
                      await ref.read(intelligenceRepositoryProvider).sendMessage(_conversationId!, text);
                      _input.clear();
                      ref.invalidate(aiConversationByIdProvider(_conversationId!));
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIQuotationSuggestionScreen extends ConsumerStatefulWidget {
  const AIQuotationSuggestionScreen({super.key});

  @override
  ConsumerState<AIQuotationSuggestionScreen> createState() => _AIQuotationSuggestionScreenState();
}

class _AIQuotationSuggestionScreenState extends ConsumerState<AIQuotationSuggestionScreen> {
  final _requestId = TextEditingController();
  AISuggestion? _suggestion;

  @override
  void dispose() {
    _requestId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.aiQuotationSuggest,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Quotation suggest')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _requestId, decoration: const InputDecoration(labelText: 'Service request ID')),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(intelligenceRepositoryProvider).requestQuotationSuggestion(_requestId.text.trim());
                setState(() => _suggestion = result.dataOrNull);
              },
              child: const Text('Generate'),
            ),
            if (_suggestion != null) ...[
              Text('Confidence ${_suggestion!.confidence ?? 0}'),
              for (final item in (_suggestion!.suggestionData['lineItems'] as List? ?? const []))
                ListTile(title: Text('${item['description']}'), trailing: Text('${item['total']}')),
              FilledButton(
                onPressed: () async {
                  await ref.read(intelligenceRepositoryProvider).acceptSuggestion(_suggestion!.id);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted')));
                },
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: () => ref.read(intelligenceRepositoryProvider).rejectSuggestion(_suggestion!.id, 'Not needed'),
                child: const Text('Reject'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AICostEstimateScreen extends ConsumerStatefulWidget {
  const AICostEstimateScreen({super.key});

  @override
  ConsumerState<AICostEstimateScreen> createState() => _AICostEstimateScreenState();
}

class _AICostEstimateScreenState extends ConsumerState<AICostEstimateScreen> {
  final _projectId = TextEditingController();
  AISuggestion? _suggestion;

  @override
  void dispose() {
    _projectId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.aiCostEstimate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Cost estimate')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _projectId, decoration: const InputDecoration(labelText: 'Project ID')),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(intelligenceRepositoryProvider).requestCostEstimate(_projectId.text.trim(), const {});
                setState(() => _suggestion = result.dataOrNull);
              },
              child: const Text('Estimate'),
            ),
            if (_suggestion != null)
              ...[
                Text('Materials ${_suggestion!.suggestionData['materials']}'),
                Text('Labour ${_suggestion!.suggestionData['labor']}'),
                Text('Overhead ${_suggestion!.suggestionData['overhead']}'),
                Text('Total ${_suggestion!.suggestionData['total']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
          ],
        ),
      ),
    );
  }
}

class AITimelinePredictionScreen extends ConsumerStatefulWidget {
  const AITimelinePredictionScreen({super.key});

  @override
  ConsumerState<AITimelinePredictionScreen> createState() => _AITimelinePredictionScreenState();
}

class _AITimelinePredictionScreenState extends ConsumerState<AITimelinePredictionScreen> {
  final _projectId = TextEditingController();
  AISuggestion? _suggestion;

  @override
  void dispose() {
    _projectId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.aiTimelinePredict,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Timeline predict')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _projectId, decoration: const InputDecoration(labelText: 'Project ID')),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(intelligenceRepositoryProvider).requestTimelinePrediction(_projectId.text.trim());
                setState(() => _suggestion = result.dataOrNull);
              },
              child: const Text('Predict'),
            ),
            if (_suggestion != null) ...[
              Text('Predicted end ${_suggestion!.suggestionData['predictedEnd']}'),
              Text('Buffer ${_suggestion!.suggestionData['bufferDays']} days'),
              Text('Risk ${_suggestion!.suggestionData['riskLevel']}'),
            ],
          ],
        ),
      ),
    );
  }
}

class AILeadScoreScreen extends ConsumerStatefulWidget {
  const AILeadScoreScreen({super.key});

  @override
  ConsumerState<AILeadScoreScreen> createState() => _AILeadScoreScreenState();
}

class _AILeadScoreScreenState extends ConsumerState<AILeadScoreScreen> {
  final _enquiryId = TextEditingController();

  @override
  void dispose() {
    _enquiryId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(aiSuggestionsProvider(const SuggestionQuery(entityType: 'lead')));
    return PermissionGate(
      permission: Permission.aiLeadScore,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Lead scores')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _enquiryId, decoration: const InputDecoration(labelText: 'Enquiry ID')),
            FilledButton(
              onPressed: () async {
                await ref.read(intelligenceRepositoryProvider).requestLeadScore(_enquiryId.text.trim());
                ref.invalidate(aiSuggestionsProvider(const SuggestionQuery(entityType: 'lead')));
              },
              child: const Text('Score'),
            ),
            rows.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('${item.suggestionData['priority']} · ${item.suggestionData['total']}'),
                      subtitle: Text('Budget ${item.suggestionData['budget']} · Service ${item.suggestionData['service']}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SemanticSearchScreen extends ConsumerStatefulWidget {
  const SemanticSearchScreen({super.key});

  @override
  ConsumerState<SemanticSearchScreen> createState() => _SemanticSearchScreenState();
}

class _SemanticSearchScreenState extends ConsumerState<SemanticSearchScreen> {
  final _query = TextEditingController();
  var _submitted = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(semanticSearchProvider(_submitted));
    return PermissionGate(
      permission: Permission.aiSemanticSearch,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Semantic search')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _query,
              decoration: InputDecoration(
                labelText: 'Search projects, invoices, notes',
                suffixIcon: IconButton(onPressed: () => setState(() => _submitted = _query.text.trim()), icon: const Icon(Icons.search)),
              ),
              onSubmitted: (value) => setState(() => _submitted = value.trim()),
            ),
            results.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item.text),
                      subtitle: Text('${item.sourceType} · ${(item.similarity * 100).toStringAsFixed(0)}%'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NaturalLanguageQueryScreen extends ConsumerStatefulWidget {
  const NaturalLanguageQueryScreen({super.key});

  @override
  ConsumerState<NaturalLanguageQueryScreen> createState() => _NaturalLanguageQueryScreenState();
}

class _NaturalLanguageQueryScreenState extends ConsumerState<NaturalLanguageQueryScreen> {
  final _query = TextEditingController(text: 'Show unpaid invoices over 50000');
  var _submitted = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _submitted.isEmpty ? null : ref.watch(nlpQueryProvider(_submitted));
    return PermissionGate(
      permission: Permission.aiNaturalLanguageQuery,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Natural language query')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _query, decoration: const InputDecoration(labelText: 'Query')),
            FilledButton(onPressed: () => setState(() => _submitted = _query.text.trim()), child: const Text('Run')),
            if (result != null)
              result.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('$error'),
                data: (item) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.interpreted, style: const TextStyle(fontWeight: FontWeight.w600)),
                    for (final row in item.rows) ListTile(title: Text(row['label'] ?? row['id'] ?? ''), subtitle: Text('${row['status']} · ${row['amount']}')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
