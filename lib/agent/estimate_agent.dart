import 'dart:convert';

import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import 'catalog_tools.dart';
import 'llm_client.dart';

class AgentResult {
  const AgentResult({required this.message, this.error = false});
  final String message;
  final bool error;
}

class EstimateAgent {
  EstimateAgent({
    required this.catalog,
    this.draft,
    this.client,
    this.actions,
  });

  final EstimateCatalog catalog;
  final EstimateDraft? draft;
  final LlmClient? client;
  final AgentActions? actions;

  static const _system = '''
You are Manoj Singharya, the BiConcept estimate co-pilot for a Windows interior-estimate app.
You can use tools to:
- search the rate card and work types
- add scopes to the catalog
- list, open, create, save, and edit quotations
- add, update, or delete quotation lines (Quantity × unitRate = Amount; Dart calculates GST)
- fill rates from the catalog
- summarize the dashboard
- navigate to dashboard, estimates, clients, calendar, rate_card, settings, or quotation

Never invent unit rates. Look up suggestedRate / minRate / maxRate with tools.
If you set a rate it must stay within minRate and maxRate when those exist.
Do not compute GST yourself. Ask to open or create an estimate before editing lines.
Be concise. After changing a quotation, mention totals from tools.
''';

  /// Catalog rates and descriptions now; quantities stay unconfirmed suggestions.
  void fillFromCatalog() {
    final current = draft;
    if (current == null) return;
    for (final line in current.lines) {
      if (line.custom) continue;
      final scope = catalog.scopeById(line.scopeId);
      if (scope == null) continue;
      if (scope.description.isNotEmpty) line.description = scope.description;
      if (scope.unit.isNotEmpty) line.unit = scope.unit;
      line.unitRate = scope.suggestedRate ?? line.unitRate;
      final qty = suggestQuantity(scope: scope, carpetArea: current.carpetArea, area: line.area);
      line.suggestedQuantity = qty;
      line.quantity ??= qty;
      line.quantityConfirmed = false;
      line.source = LineSource.agent;
      line.agentReason = qty == null
          ? 'Catalog rate applied. Quantity needs a site measurement.'
          : 'Catalog rate applied. Quantity suggested from samples / carpet area.';
    }
    current.markChanged();
  }

  Future<AgentResult> chat(String userMessage) async {
    final llm = client;
    if (llm == null) {
      return const AgentResult(
        message:
            'Add your DeepSeek API key in Settings. Catalog Fill still works offline on an open quotation.',
        error: true,
      );
    }
    final tools = CatalogTools(catalog: catalog, draft: draft, actions: actions);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _system},
      {
        'role': 'user',
        'content': 'App context:\n${const JsonEncoder.withIndent('  ').convert(tools.appSnapshot())}\n\n$userMessage',
      },
    ];
    try {
      for (var round = 0; round < 8; round++) {
        final response = await llm.chat(messages: messages, tools: CatalogTools.definitions);
        if (!response.hasToolCalls) {
          return AgentResult(message: (response.content ?? 'Done.').trim());
        }
        messages.add({
          'role': 'assistant',
          'content': response.content,
          'tool_calls': [
            for (final call in response.toolCalls)
              {
                'id': call.id,
                'type': 'function',
                'function': {'name': call.name, 'arguments': call.argumentsJson},
              },
          ],
        });
        for (final call in response.toolCalls) {
          final result = await tools.execute(call.name, call.argumentsJson);
          messages.add({'role': 'tool', 'tool_call_id': call.id, 'content': result});
        }
      }
      return const AgentResult(
        message: 'Stopped after 8 tool rounds. Review the quotation and try a narrower request.',
        error: true,
      );
    } on LlmException catch (error) {
      return AgentResult(message: error.message, error: true);
    }
  }
}
