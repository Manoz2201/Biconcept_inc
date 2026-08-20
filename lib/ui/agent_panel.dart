import 'package:flutter/material.dart';

import '../agent/catalog_tools.dart';
import '../agent/estimate_agent.dart';
import '../agent/llm_client.dart';
import '../data/settings_store.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';

class CollapsibleAgentPanel extends StatefulWidget {
  const CollapsibleAgentPanel({
    super.key,
    required this.catalog,
    this.draft,
    this.actions,
    this.initiallyExpanded = true,
    this.onExpandedChanged,
  });

  final EstimateCatalog catalog;
  final EstimateDraft? draft;
  final AgentActions? actions;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<CollapsibleAgentPanel> createState() => CollapsibleAgentPanelState();
}

class CollapsibleAgentPanelState extends State<CollapsibleAgentPanel> {
  late bool _expanded = widget.initiallyExpanded;
  final _input = TextEditingController();
  final _messages = <_ChatTurn>[];
  bool _busy = false;

  bool get expanded => _expanded;

  void toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  void expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    widget.onExpandedChanged?.call(true);
  }

  void collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    widget.onExpandedChanged?.call(false);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return SizedBox(
        width: 48,
        child: _CollapsedAgentRail(onExpand: expand),
      );
    }
    return SizedBox(
      width: 320,
      child: _AgentChatView(
        catalog: widget.catalog,
        draft: widget.draft,
        actions: widget.actions,
        input: _input,
        messages: _messages,
        busy: _busy,
        onCollapse: collapse,
        onBusy: (value) => setState(() => _busy = value),
        onMessages: () => setState(() {}),
      ),
    );
  }
}

class _CollapsedAgentRail extends StatelessWidget {
  const _CollapsedAgentRail({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: InkWell(
        onTap: onExpand,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(Icons.chevron_left, size: 22),
              SizedBox(height: 12),
              Icon(Icons.smart_toy_outlined, color: AppColors.primarySoft, size: 20),
              SizedBox(height: 12),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'Agent',
                  style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgentPanel extends StatefulWidget {
  const AgentPanel({
    super.key,
    required this.catalog,
    this.draft,
    this.actions,
    this.onCollapse,
  });

  final EstimateCatalog catalog;
  final EstimateDraft? draft;
  final AgentActions? actions;
  final VoidCallback? onCollapse;

  @override
  State<AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<AgentPanel> {
  final _input = TextEditingController();
  final _messages = <_ChatTurn>[];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AgentChatView(
      catalog: widget.catalog,
      draft: widget.draft,
      actions: widget.actions,
      input: _input,
      messages: _messages,
      busy: _busy,
      onCollapse: widget.onCollapse,
      onBusy: (value) => setState(() => _busy = value),
      onMessages: () => setState(() {}),
    );
  }
}

class _AgentChatView extends StatelessWidget {
  const _AgentChatView({
    required this.catalog,
    required this.input,
    required this.messages,
    required this.busy,
    required this.onBusy,
    required this.onMessages,
    this.draft,
    this.actions,
    this.onCollapse,
  });

  final EstimateCatalog catalog;
  final EstimateDraft? draft;
  final AgentActions? actions;
  final TextEditingController input;
  final List<_ChatTurn> messages;
  final bool busy;
  final ValueChanged<bool> onBusy;
  final VoidCallback onMessages;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'DeepSeek agent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onCollapse != null)
                  IconButton(
                    tooltip: 'Collapse agent',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                    onPressed: onCollapse,
                    icon: const Icon(Icons.chevron_right, size: 22),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              draft == null
                  ? 'Ask about estimates, the rate card, or to create/edit a quotation. Add your DeepSeek API key in Settings.'
                  : 'This quotation is open. Ask to change quantities, rates, add/delete scopes, or save.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (messages.isEmpty)
                  Text(
                    draft == null
                        ? 'Try: “list estimates”, “open OM CRE”, or “create an estimate for ABC with civil work”.'
                        : 'Try: “use max rate for gypsum partition” or “add a flooring scope at ₹180/sqft”.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final turn in messages) ...[
                  Align(
                    alignment: turn.user ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: turn.user ? AppColors.primaryDim : AppColors.cardHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(turn.text),
                    ),
                  ),
                ],
                if (busy) const LinearProgressIndicator(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      hintText: 'Ask DeepSeek',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(context),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: busy ? null : () => _send(context),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    input.clear();
    messages.add(_ChatTurn(text, user: true));
    onBusy(true);
    onMessages();
    final settings = await SettingsStore().load();
    LlmClient? client;
    if (settings.isConfigured) {
      client = LlmClient(baseUrl: settings.baseUrl, apiKey: settings.apiKey, model: settings.model);
    }
    final agent = EstimateAgent(
      catalog: catalog,
      draft: draft,
      client: client,
      actions: actions,
    );
    final result = await agent.chat(text);
    if (!context.mounted) return;
    messages.add(_ChatTurn(result.message, user: false));
    onBusy(false);
    onMessages();
  }
}

class _ChatTurn {
  const _ChatTurn(this.text, {required this.user});
  final String text;
  final bool user;
}
