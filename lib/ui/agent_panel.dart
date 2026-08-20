import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../agent/agent_service.dart';
import '../agent/app_tools.dart';
import '../agent/catalog_tools.dart';
import '../agent/document_reader.dart';
import '../agent/estimate_agent.dart';
import '../agent/llm_client.dart';
import '../data/agent_session_store.dart';
import '../data/settings_store.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';

const kAgentName = 'Manoj Singharya';
const kAgentNameLower = 'manoj singharya';
const kAgentInitials = 'MS';
const kAgentRole = 'app operator';

Future<void> showAgentSheet({
  required BuildContext context,
  required Widget panel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final media = MediaQuery.of(context);
      final keyboard = media.viewInsets.bottom;
      final available = (media.size.height - keyboard).clamp(240.0, media.size.height);
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SizedBox(
            height: available * 0.92,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: panel),
              ],
            ),
          ),
        ),
      );
    },
  );
}

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
  bool _busy = false;

  bool get expanded => _expanded;

  @override
  void initState() {
    super.initState();
    unawaited(AgentSessionStore.instance.ensureLoaded());
  }

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
        width: 56,
        child: _CollapsedAgentRail(onExpand: expand),
      );
    }
    return SizedBox(
      width: 336,
      child: ListenableBuilder(
        listenable: AgentSessionStore.instance,
        builder: (context, _) {
          return _AgentChatView(
            catalog: widget.catalog,
            draft: widget.draft,
            actions: widget.actions,
            session: AgentSessionStore.instance,
            input: _input,
            busy: _busy,
            onCollapse: collapse,
            onBusy: (value) => setState(() => _busy = value),
          );
        },
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
      color: AppColors.background,
      child: InkWell(
        onTap: onExpand,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.35))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
                const SizedBox(height: 16),
                const _AgentAvatar(size: 32),
                const SizedBox(height: 16),
                const RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    'manoj',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(AgentSessionStore.instance.ensureLoaded());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AgentSessionStore.instance,
      builder: (context, _) {
        return _AgentChatView(
          catalog: widget.catalog,
          draft: widget.draft,
          actions: widget.actions,
          session: AgentSessionStore.instance,
          input: _input,
          busy: _busy,
          onCollapse: widget.onCollapse,
          onBusy: (value) => setState(() => _busy = value),
        );
      },
    );
  }
}

class _AgentChatView extends StatelessWidget {
  const _AgentChatView({
    required this.catalog,
    required this.input,
    required this.session,
    required this.busy,
    required this.onBusy,
    this.draft,
    this.actions,
    this.onCollapse,
  });

  final EstimateCatalog catalog;
  final EstimateDraft? draft;
  final AgentActions? actions;
  final AgentSessionStore session;
  final TextEditingController input;
  final bool busy;
  final ValueChanged<bool> onBusy;
  final VoidCallback? onCollapse;

  List<String> get _prompts => draft == null
      ? const [
          'add a new client',
          'create an estimate for a client',
          'remind me to follow up',
        ]
      : const [
          'who is this client in CRM',
          'schedule a follow-up for this client',
        ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          const Positioned(
            right: -36,
            top: -48,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x22E8877A),
                ),
                child: SizedBox(width: 140, height: 140),
              ),
            ),
          ),
          const Positioned(
            left: -40,
            bottom: 88,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x145ADACE),
                ),
                child: SizedBox(width: 120, height: 120),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.outline.withValues(alpha: 0.45)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    children: [
                      if (session.messages.isEmpty) _emptyState(context),
                      for (final turn in session.messages) _bubble(turn),
                      if (busy) const _TypingBubble(),
                    ],
                  ),
                ),
                _composer(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
      child: Row(
        children: [
          const _AgentAvatar(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  kAgentNameLower,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.completed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      kAgentRole.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: busy ? null : () => session.clear(),
            icon: const Icon(Icons.add_comment_outlined, size: 20, color: AppColors.muted),
          ),
          if (onCollapse != null)
            IconButton(
              tooltip: 'Collapse $kAgentName',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              onPressed: onCollapse,
              icon: const Icon(Icons.chevron_right, size: 22, color: AppColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft == null
              ? 'Ask about the app, the web, or attach a PDF, Word, or Excel file. Chat stays in this session on this device.'
              : 'This quotation is open. Attach a file, change lines, or ask about the client.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'TRY',
          style: TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final prompt in _prompts)
              _PromptChip(
                label: prompt,
                onTap: busy ? null : () => _send(context, prompt),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bubble(AgentChatTurn turn) {
    final user = turn.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!user) ...[
            const _AgentAvatar(size: 22),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                color: user ? AppColors.primary.withValues(alpha: 0.16) : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(user ? 18 : 5),
                  bottomRight: Radius.circular(user ? 5 : 18),
                ),
                border: Border.all(
                  color: user
                      ? AppColors.primary.withValues(alpha: 0.28)
                      : AppColors.outline.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (turn.attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final file in turn.attachments) _FileChip(label: file.name, kind: file.kind),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    turn.text,
                    style: TextStyle(
                      color: user ? AppColors.primarySoft : AppColors.text,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 12 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.pending.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final file in session.pending)
                  _FileChip(
                    label: file.name,
                    kind: file.kind,
                    onRemove: busy ? null : () => session.removePending(file.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Attach PDF, Word or Excel',
                onPressed: busy ? null : () => _attach(context),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.attach_file_rounded, size: 20, color: AppColors.muted),
              ),
              Expanded(
                child: TextField(
                  controller: input,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 4,
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ask $kAgentName',
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.card,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.4)),
                    ),
                  ),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: busy ? null : () => _send(context),
                tooltip: 'Send',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF1A1010),
                  disabledBackgroundColor: AppColors.cardHover,
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _attach(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      try {
        final bytes = file.bytes ??
            (file.path == null || file.path!.isEmpty ? null : await File(file.path!).readAsBytes());
        if (bytes == null) {
          throw DocumentReadException('Could not read ${file.name}.');
        }
        final extract = DocumentReader.fromBytes(bytes, file.name);
        await session.attachExtract(extract, copyBytes: bytes);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('DocumentReadException: ', ''))),
        );
      }
    }
  }

  Future<void> _send(BuildContext context, [String? preset]) async {
    final pending = session.takePending();
    var text = (preset ?? input.text).trim();
    if (text.isEmpty && pending.isEmpty) return;
    if (text.isEmpty) {
      text = pending.length == 1
          ? 'Read and summarize ${pending.first.name}.'
          : 'Read and summarize the attached files.';
    }
    input.clear();
    await session.addTurn(AgentChatTurn(text: text, user: true, attachments: pending));
    onBusy(true);
    final reply = await _runAgent(text);
    if (!context.mounted) return;
    await session.addTurn(AgentChatTurn(text: reply, user: false));
    onBusy(false);
  }

  Future<String> _runAgent(String text) async {
    final store = SettingsStore();
    final tools = AppTools(
      catalogTools: CatalogTools(catalog: catalog, draft: draft, actions: actions),
    );
    final snapshot = StringBuffer(const JsonEncoder.withIndent('  ').convert(await tools.snapshot()));
    final documents = session.documentsContext();
    if (documents.isNotEmpty) {
      snapshot.write('\n\nSession documents:\n$documents');
    }
    final extra = snapshot.toString();
    final history = session.llmHistory();

    final cloudflare = await store.loadCloudflare();
    if (cloudflare.isConfigured) {
      final agent = AgentService(
        accountId: cloudflare.accountId,
        apiToken: cloudflare.apiToken,
        extraSystem: AppTools.workersAiToolPrompt(),
        onAppTool: (name, arguments) async {
          try {
            return await tools.execute(name, arguments);
          } catch (error) {
            return 'Tool $name failed: $error';
          }
        },
      );
      return agent.chat(text, extraUserContext: extra, history: history);
    }

    final settings = await store.load();
    if (!settings.isConfigured) {
      return 'Add your Cloudflare Account ID and API token in Settings so Manoj Singharya can run.';
    }
    final agent = EstimateAgent(
      catalog: catalog,
      draft: draft,
      client: LlmClient(baseUrl: settings.baseUrl, apiKey: settings.apiKey, model: settings.model),
      actions: actions,
    );
    final result = await agent.chat(text, extraUserContext: extra, history: history);
    return result.message;
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.label, required this.kind, this.onRemove});

  final String label;
  final String kind;
  final VoidCallback? onRemove;

  IconData get _icon => switch (kind) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'word' => Icons.description_outlined,
        'excel' => Icons.table_chart_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 8, right: onRemove == null ? 8 : 2, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.cardHover,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: AppColors.primarySoft),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.primarySoft, fontSize: 11),
            ),
          ),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        kAgentInitials,
        style: TextStyle(
          color: AppColors.primarySoft,
          fontSize: size < 28 ? 8 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
          ),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.primarySoft, fontSize: 11, height: 1.25),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AgentAvatar(size: 22),
          SizedBox(width: 8),
          _TypingDots(),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Opacity(
                  opacity: () {
                    final t = (_controller.value + i / 3) % 1.0;
                    final bounce = t < 0.5 ? t * 2 : (1 - t) * 2;
                    return 0.35 + 0.65 * bounce;
                  }(),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AgentLauncherButton extends StatelessWidget {
  const AgentLauncherButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ask $kAgentName',
      onPressed: onPressed,
      icon: const _AgentAvatar(size: 32),
    );
  }
}
