import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/client_store.dart';
import '../data/draft_store.dart';
import '../data/schedule.dart';
import '../export/quotation_layout.dart';
import '../models/client_record.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/call_phone.dart';
import '../util/format.dart';
import 'new_estimate_flow.dart';

const _followKinds = ['Call', 'WhatsApp', 'Visit', 'Email', 'Other'];

Future<ClientFollowUp?> showAddFollowUpDialog(BuildContext context) async {
  var date = DateTime.now();
  DateTime? next = date.add(const Duration(days: 3));
  var kind = 'Call';
  final note = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add follow-up'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: [
                      for (final item in _followKinds) DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => kind = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Followed on ${quotationDate(date)}'),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) setDialogState(() => date = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(next == null ? 'No next follow-up' : 'Next follow-up ${quotationDate(next!)}'),
                    trailing: const Icon(Icons.event_repeat),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: next ?? date.add(const Duration(days: 3)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) setDialogState(() => next = picked);
                    },
                  ),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          );
        },
      );
    },
  );
  final text = note.text.trim();
  note.dispose();
  if (saved != true) return null;
  return ClientFollowUp(date: date, nextFollow: next, kind: kind, note: text);
}

class ClientsPage extends StatefulWidget {
  const ClientsPage({
    super.key,
    required this.query,
    required this.drafts,
    required this.compact,
    required this.catalog,
    this.onEstimatesChanged,
    this.onOpenQuotation,
  });

  final String query;
  final List<EstimateDraft> drafts;
  final bool compact;
  final EstimateCatalog catalog;
  final Future<void> Function()? onEstimatesChanged;
  final Future<void> Function(EstimateDraft draft)? onOpenQuotation;

  @override
  State<ClientsPage> createState() => ClientsPageState();
}

class ClientsPageState extends State<ClientsPage> {
  final _store = ClientStore();
  List<ClientRecord> _clients = [];
  CrmStage? _stageFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload(importFromEstimates: true);
  }

  @override
  void didUpdateWidget(covariant ClientsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drafts.length != widget.drafts.length) {
      _reload(importFromEstimates: true);
    }
  }

  Future<void> _reload({bool importFromEstimates = false}) async {
    if (importFromEstimates) {
      await _store.syncFromEstimates(widget.drafts);
    }
    final clients = await _store.list();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _loading = false;
    });
  }

  Future<void> reload() => _reload(importFromEstimates: true);

  List<ClientRecord> get _filtered {
    final q = widget.query.toLowerCase();
    return _clients.where((client) {
      final stageOk = _stageFilter == null || client.stage == _stageFilter;
      final queryOk = q.isEmpty ||
          client.name.toLowerCase().contains(q) ||
          client.phone.toLowerCase().contains(q) ||
          client.project.toLowerCase().contains(q) ||
          client.email.toLowerCase().contains(q);
      return stageOk && queryOk;
    }).toList();
  }

  List<EstimateDraft> _linkedEstimates(ClientRecord client) {
    final name = client.name.trim().toLowerCase();
    if (name.isEmpty) return const [];
    return widget.drafts.where((draft) => draft.client.trim().toLowerCase() == name).toList();
  }

  Future<void> addClient() async {
    final created = await _editClient();
    if (created == null) return;
    final existing = await _store.findByName(created.name);
    if (existing != null) {
      _copyDetails(from: created, onto: existing);
      await _saveClient(existing);
      return;
    }
    await _store.save(created);
    await _reload();
  }

  Future<void> _saveClient(ClientRecord client, {String? previousName}) async {
    await _store.save(client);
    await _relinkEstimates(previousName ?? client.name, client.name);
    await _reload();
  }

  void _copyDetails({required ClientRecord from, required ClientRecord onto}) {
    if (from.phone.trim().isNotEmpty) onto.phone = from.phone.trim();
    if (from.email.trim().isNotEmpty) onto.email = from.email.trim();
    if (from.company.trim().isNotEmpty) onto.company = from.company.trim();
    if (from.project.trim().isNotEmpty) onto.project = from.project.trim();
    if (from.address.trim().isNotEmpty) onto.address = from.address.trim();
    if (from.source.trim().isNotEmpty) onto.source = from.source.trim();
    if (from.notes.trim().isNotEmpty) onto.notes = from.notes.trim();
  }

  Future<void> _relinkEstimates(String previousName, String newName) async {
    final from = previousName.trim().toLowerCase();
    final to = newName.trim();
    if (from.isEmpty || to.isEmpty || from == to.toLowerCase()) return;
    final store = DraftStore();
    final drafts = await store.list();
    var changed = false;
    for (final draft in drafts) {
      if (draft.client.trim().toLowerCase() != from) continue;
      draft.client = to;
      await store.save(draft);
      changed = true;
    }
    if (changed) await widget.onEstimatesChanged?.call();
  }

  Future<void> _deleteClient(ClientRecord client) async {
    await _store.delete(client.id);
    await _reload();
  }

  Future<void> _callLead(ClientRecord client) async {
    if (sanitizePhoneNumber(client.phone).isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a phone number before calling.')),
      );
      return;
    }
    try {
      final opened = await callPhoneNumber(client.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened ? 'Calling ${client.name.isEmpty ? client.phone : client.name}' : 'Number copied: ${client.phone}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start a call. Number: ${client.phone}')),
      );
    }
  }

  Future<void> _followUp(ClientRecord client) async {
    final item = await showAddFollowUpDialog(context);
    if (item == null) return;
    client.followUps.insert(0, item);
    await _saveClient(client);
    await ScheduleService.instance.fromFollowUp(client, item);
  }

  Future<void> _createEstimate(ClientRecord client) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewEstimateFlow(
          catalog: widget.catalog,
          initialClient: client.name,
          initialProject: client.project,
        ),
      ),
    );
    await widget.onEstimatesChanged?.call();
    await _reload();
  }

  Future<void> _openViewer(ClientRecord client) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientViewerPage(
          client: client,
          linkedEstimates: () => _linkedEstimates(client),
          onCall: () => _callLead(client),
          onFollowUp: () => _followUp(client),
          onCreateEstimate: () => _createEstimate(client),
          onOpenQuotation: widget.onOpenQuotation,
          onEdit: () => _openEditor(client),
        ),
      ),
    );
    await _reload();
  }

  Future<bool> _openEditor(ClientRecord client) async {
    var deleted = false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientWorkspacePage(
          client: client,
          linkedEstimates: () => _linkedEstimates(client),
          onSave: _saveClient,
          onDelete: () async {
            deleted = true;
            await _deleteClient(client);
          },
        ),
      ),
    );
    await _reload();
    return deleted;
  }

  Future<ClientRecord?> _editClient([ClientRecord? current]) async {
    final name = TextEditingController(text: current?.name ?? '');
    final phone = TextEditingController(text: current?.phone ?? '');
    final project = TextEditingController(text: current?.project ?? '');
    final source = TextEditingController(text: current?.source ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current == null ? 'New client' : 'Edit client'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Client name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: project,
                decoration: const InputDecoration(labelText: 'Project / site', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: source,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'Referral, Instagram, walk-in…',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final trimmed = name.text.trim();
    final phoneValue = phone.text.trim();
    final projectValue = project.text.trim();
    final sourceValue = source.text.trim();
    name.dispose();
    phone.dispose();
    project.dispose();
    source.dispose();
    if (saved != true || trimmed.isEmpty) return null;
    final record = current ?? ClientRecord();
    record.name = trimmed;
    record.phone = phoneValue;
    record.project = projectValue;
    record.source = sourceValue;
    return record;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final items = _filtered;
    final pad = widget.compact ? 16.0 : 24.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, widget.compact ? 4 : 8, pad, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClientsHero(compact: widget.compact),
                const SizedBox(height: 16),
                _StageFilters(
                  selected: _stageFilter,
                  onSelected: (stage) => setState(() => _stageFilter = stage),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ClientsEmpty(
              noneAtAll: _clients.isEmpty,
              onCreate: addClient,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, widget.compact ? AppBreakpoints.navClearance : 32),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 1100 ? 3 : width >= 700 ? 2 : 1;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 248,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final client = items[index];
                      return _ClientCard(
                        client: client,
                        onOpen: () => _openViewer(client),
                        onCall: () => _callLead(client),
                        onFollowUp: () => _followUp(client),
                        onEstimate: () => _createEstimate(client),
                        onEdit: () => _openEditor(client),
                      );
                    },
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ClientsHero extends StatelessWidget {
  const _ClientsHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'clients',
        children: const [
          TextSpan(text: '.', style: TextStyle(color: AppColors.primary)),
        ],
      ),
      style: TextStyle(
        color: AppColors.text,
        fontSize: compact ? 32 : 48,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
    );
  }
}

class _StageFilters extends StatelessWidget {
  const _StageFilters({required this.selected, required this.onSelected});

  final CrmStage? selected;
  final ValueChanged<CrmStage?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StageFilterChip(label: 'all', selected: selected == null, onTap: () => onSelected(null)),
          for (final stage in CrmStage.values) ...[
            const SizedBox(width: 10),
            _StageFilterChip(
              label: stage.label.toLowerCase(),
              selected: selected == stage,
              onTap: () => onSelected(stage),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageFilterChip extends StatelessWidget {
  const _StageFilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1A1010) : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientsEmpty extends StatelessWidget {
  const _ClientsEmpty({required this.noneAtAll, required this.onCreate});

  final bool noneAtAll;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: AppColors.muted.withValues(alpha: 0.45)),
          const SizedBox(height: 16),
          const Text(
            'no clients found',
            style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            noneAtAll
                ? 'Add a client or create an estimate to start the CRM pipeline.'
                : 'No clients match this filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('new client'),
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatefulWidget {
  const _ClientCard({
    required this.client,
    required this.onOpen,
    required this.onCall,
    required this.onFollowUp,
    required this.onEstimate,
    required this.onEdit,
  });

  final ClientRecord client;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onFollowUp;
  final VoidCallback onEstimate;
  final VoidCallback onEdit;

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final lost = client.stage == CrmStage.lost;
    final canCall = sanitizePhoneNumber(client.phone).isNotEmpty;
    final dim = lost ? 0.5 : 1.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _hover ? AppColors.cardHover : AppColors.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -48,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: _hover ? 0.08 : 0.04),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: widget.onOpen,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Opacity(
                          opacity: dim,
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.cardHover,
                            child: Text(
                              _clientInitials(client.name),
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Opacity(
                            opacity: dim,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.name.isEmpty ? 'untitled' : client.name.toLowerCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  canCall ? client.phone : 'no phone',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: canCall ? AppColors.muted : AppColors.muted.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontStyle: canCall ? FontStyle.normal : FontStyle.italic,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CrmStageBadge(stage: client.stage),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: dim,
                    child: Column(
                      children: [
                        _MetaRow(
                          label: 'project',
                          value: client.project.isEmpty ? '—' : client.project,
                          strike: lost,
                        ),
                        const SizedBox(height: 8),
                        _NextRow(client: client),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.35)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CardAction(
                          icon: Icons.call_outlined,
                          enabled: canCall,
                          onTap: widget.onCall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CardAction(
                          icon: Icons.schedule_rounded,
                          onTap: widget.onFollowUp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CardAction(
                          icon: Icons.request_quote_outlined,
                          onTap: widget.onEstimate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: _CardAction(
                          icon: Icons.edit_outlined,
                          onTap: widget.onEdit,
                        ),
                      ),
                    ],
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value, this.strike = false});

  final String label;
  final String value;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              decoration: strike ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.client});

  final ClientRecord client;

  @override
  Widget build(BuildContext context) {
    final lost = client.stage == CrmStage.lost;
    final next = client.nextFollow;
    final latestKind = client.followUps.isEmpty ? '' : client.followUps.first.kind;
    final visit = latestKind.toLowerCase() == 'visit';
    Widget trailing;
    if (lost) {
      trailing = const Text('Archived', style: TextStyle(color: AppColors.muted, fontSize: 15));
    } else if (next != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visit ? Icons.location_on_outlined : Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _shortMonthDay(next),
            style: const TextStyle(color: AppColors.primary, fontSize: 15),
          ),
        ],
      );
    } else if (latestKind.isNotEmpty) {
      trailing = Text(latestKind, style: const TextStyle(color: AppColors.text, fontSize: 15));
    } else {
      trailing = const Text('—', style: TextStyle(color: AppColors.muted, fontSize: 15));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'next',
          style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.onTap, this.enabled = true});

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.background : AppColors.cardHover.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.text : AppColors.muted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _CrmStageBadge extends StatelessWidget {
  const _CrmStageBadge({required this.stage});

  final CrmStage stage;

  (Color bg, Color fg) get _colors => switch (stage) {
        CrmStage.won => (AppColors.completed.withValues(alpha: 0.2), AppColors.completed),
        CrmStage.lost => (AppColors.down.withValues(alpha: 0.12), AppColors.down),
        CrmStage.quotation || CrmStage.negotiation => (
            const Color(0xFF01A89D).withValues(alpha: 0.2),
            const Color(0xFF5ADACE),
          ),
        _ => (AppColors.cardHover, AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        stage.label.toLowerCase(),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4),
      ),
    );
  }
}

String _clientInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final value = parts.first;
    return (value.length >= 2 ? value.substring(0, 2) : value).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _shortMonthDay(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}';
}

class ClientViewerPage extends StatefulWidget {
  const ClientViewerPage({
    super.key,
    required this.client,
    required this.linkedEstimates,
    required this.onCall,
    required this.onFollowUp,
    required this.onCreateEstimate,
    required this.onEdit,
    this.onOpenQuotation,
  });

  final ClientRecord client;
  final List<EstimateDraft> Function() linkedEstimates;
  final Future<void> Function() onCall;
  final Future<void> Function() onFollowUp;
  final Future<void> Function() onCreateEstimate;
  final Future<bool> Function() onEdit;
  final Future<void> Function(EstimateDraft draft)? onOpenQuotation;

  @override
  State<ClientViewerPage> createState() => _ClientViewerPageState();
}

class _ClientViewerPageState extends State<ClientViewerPage> {
  ClientRecord get client => widget.client;

  Future<void> _refreshAfter(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final deleted = await widget.onEdit();
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final drafts = widget.linkedEstimates();
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final canCall = sanitizePhoneNumber(client.phone).isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 12, compact ? 16 : 28, 32),
          children: [
            _viewerHero(compact: compact, canCall: canCall),
            const SizedBox(height: 24),
            if (compact) ...[
              _leadActionsCard(),
              const SizedBox(height: 16),
              _intelligenceCard(),
              const SizedBox(height: 16),
              _estimatesCard(drafts),
              const SizedBox(height: 16),
              _engagementsCard(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: Column(
                      children: [
                        _leadActionsCard(),
                        const SizedBox(height: 16),
                        _intelligenceCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _estimatesCard(drafts),
                        const SizedBox(height: 16),
                        _engagementsCard(),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _viewerHero({required bool compact, required bool canCall}) {
    final quarter = ((client.createdAt.month - 1) ~/ 3) + 1;
    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                client.name.isEmpty ? 'untitled client' : client.name.toLowerCase(),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 32 : 48,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(99)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF5ADACE), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (client.company.isNotEmpty ? client.company : client.stage.label).toUpperCase(),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            Text('|', style: TextStyle(color: AppColors.muted.withValues(alpha: 0.45))),
            Text(
              'ACQUIRED: Q$quarter ${client.createdAt.year}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.1),
            ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('CLIENTS', style: TextStyle(letterSpacing: 1.6, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (compact) nameBlock else Expanded(child: nameBlock),
            if (compact) const SizedBox(height: 16) else const SizedBox(width: 16),
            Row(
              children: [
                Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _edit,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.edit_outlined, color: AppColors.text),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: canCall ? () => _refreshAfter(widget.onCall) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1010),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                  label: const Text('call direct', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _leadActionsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: AppColors.muted),
              SizedBox(width: 8),
              Text('LEAD ACTIONS', style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 560;
              final actions = [
                _ViewerAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'schedule f/u',
                  color: AppColors.primary,
                  onTap: () => _refreshAfter(widget.onFollowUp),
                ),
                _ViewerAction(
                  icon: Icons.request_quote_outlined,
                  label: 'new estimate',
                  color: const Color(0xFF5ADACE),
                  onTap: () => _refreshAfter(widget.onCreateEstimate),
                ),
                _ViewerAction(
                  icon: Icons.description_outlined,
                  label: 'view dossier',
                  color: AppColors.text,
                  filled: true,
                  onTap: _openDossier,
                ),
              ];
              if (stack) {
                return Column(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      actions[i],
                      if (i != actions.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    Expanded(child: actions[i]),
                    if (i != actions.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _intelligenceCard() {
    final progress = client.stage == CrmStage.lost
        ? 1.0
        : ((client.stage.index + 1) / (CrmStage.values.length - 1)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fingerprint, size: 16, color: AppColors.muted),
              SizedBox(width: 8),
              Text('INTELLIGENCE PROFILE', style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.4)),
              SizedBox(width: 12),
              Expanded(child: Divider(height: 1)),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final two = constraints.maxWidth >= 520;
              final fields = [
                _IntelField(
                  label: 'Primary Contact',
                  value: client.email.isEmpty ? (client.name.isEmpty ? '—' : client.name) : client.email,
                  onCopy: client.email.isEmpty ? null : () => _copy(client.email),
                ),
                _IntelField(
                  label: 'Direct Line',
                  value: client.phone.isEmpty ? '—' : client.phone,
                  mono: true,
                ),
                _IntelField(
                  label: 'HQ Location',
                  value: client.address.isEmpty
                      ? (client.project.isEmpty ? '—' : client.project)
                      : client.address,
                ),
                _pipelineField(progress),
              ];
              if (!two) {
                return Column(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      fields[i],
                      if (i != fields.length - 1) const SizedBox(height: 20),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 20),
                      Expanded(child: fields[1]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields[2]),
                      const SizedBox(width: 20),
                      Expanded(child: fields[3]),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          _sitePanel(),
        ],
      ),
    );
  }

  Widget _pipelineField(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CURRENT PIPELINE STAGE',
          style: TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.background,
                  color: client.stage == CrmStage.lost ? AppColors.down : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              client.stage.label,
              style: TextStyle(
                color: client.stage == CrmStage.lost ? AppColors.down : AppColors.primarySoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sitePanel() {
    final location = client.address.isEmpty ? client.project : client.address;
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: AppColors.cardHover,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x332C3348), Color(0x00000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primarySoft),
                const Spacer(),
                Text(
                  location.isEmpty ? 'No site address on file' : location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (client.source.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Source · ${client.source}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: location.isEmpty ? null : () => _copy(location),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.navigation_rounded, size: 18, color: Color(0xFF1A1010)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimatesCard(List<EstimateDraft> drafts) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.architecture_outlined, size: 16, color: Color(0xFF5ADACE)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ACTIVE ESTIMATES',
                  style: TextStyle(color: AppColors.text, fontSize: 12, letterSpacing: 1.4),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.cardHover, shape: BoxShape.circle),
                child: Text('${drafts.length}', style: const TextStyle(fontSize: 11, fontFamily: 'Consolas')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (drafts.isEmpty)
            const Text('No estimates for this lead yet.', style: TextStyle(color: AppColors.muted))
          else
            for (final draft in drafts) ...[
              _viewerEstimateTile(draft),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _viewerEstimateTile(EstimateDraft draft) {
    final drafted = draft.status == EstimateStatus.drafted;
    final accent = switch (draft.status) {
      EstimateStatus.finalized => AppColors.primary,
      EstimateStatus.completed => AppColors.completed,
      EstimateStatus.drafted => AppColors.outline,
    };
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onOpenQuotation == null ? null : () => widget.onOpenQuotation!(draft),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(width: 4, height: 78, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (draft.project.isEmpty ? draft.estimateType : draft.project).toLowerCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: drafted ? AppColors.muted : AppColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _MiniStatus(status: draft.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '#${_estimateCode(draft)}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12, fontFamily: 'Consolas'),
                          ),
                          const Spacer(),
                          Text(
                            drafted && draft.totals.grandTotal == 0 ? 'TBD' : inr(draft.totals.grandTotal),
                            style: TextStyle(
                              color: drafted ? AppColors.muted : AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _engagementsCard() {
    final now = DateTime.now();
    final items = [...client.followUps]..sort((a, b) {
      final da = a.nextFollow ?? a.date;
      final db = b.nextFollow ?? b.date;
      final aPast = da.isBefore(now);
      final bPast = db.isBefore(now);
      if (aPast != bPast) return aPast ? 1 : -1;
      return da.compareTo(db);
    });
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, size: 16, color: AppColors.muted),
              SizedBox(width: 8),
              Text('ENGAGEMENTS', style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const Text('No follow-ups yet.', style: TextStyle(color: AppColors.muted))
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.outline.withValues(alpha: 0.45))),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _engagementTile(items[i], highlight: i == 0),
                        if (i != items.length - 1) const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _engagementTile(ClientFollowUp item, {required bool highlight}) {
    final when = item.nextFollow ?? item.date;
    return Opacity(
      opacity: highlight ? 1 : 0.65,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -25,
            top: 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: highlight ? AppColors.primary : AppColors.outline,
                shape: BoxShape.circle,
                boxShadow: highlight ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 10)] : null,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _engagementWhen(when),
                style: TextStyle(
                  color: highlight ? AppColors.primarySoft : AppColors.muted,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontFamily: 'Consolas',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.kind.isEmpty ? 'Follow-up' : item.kind,
                style: const TextStyle(color: AppColors.text, fontSize: 15),
              ),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Future<void> _openDossier() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dossier'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dossierLine('Company', client.company),
              _dossierLine('Source', client.source),
              _dossierLine('Project', client.project),
              _dossierLine('Notes', client.notes),
              _dossierLine('Created', quotationDate(client.createdAt)),
              _dossierLine('Updated', quotationDate(client.updatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(onPressed: () { Navigator.pop(context); _edit(); }, child: const Text('Edit')),
        ],
      ),
    );
  }

  Widget _dossierLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _engagementWhen(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'TODAY, $time';
    if (day == today.add(const Duration(days: 1))) return 'TOMORROW, $time';
    return '${_shortMonthDay(date).toUpperCase()}, $time';
  }

  String _estimateCode(EstimateDraft draft) {
    final yy = (draft.date.year % 100).toString().padLeft(2, '0');
    final digits = draft.id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length >= 3 ? digits.substring(digits.length - 3) : digits.padLeft(3, '0');
    return 'EST-$yy-$tail';
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: filled ? AppColors.cardHover : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: filled ? null : Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: filled ? AppColors.text : color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? AppColors.text : color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class _IntelField extends StatelessWidget {
  const _IntelField({
    required this.label,
    required this.value,
    this.onCopy,
    this.mono = false,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1.2),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontFamily: mono ? 'Consolas' : null,
                ),
              ),
            ),
            if (onCopy != null)
              IconButton(
                onPressed: onCopy,
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.content_copy, size: 18, color: AppColors.muted),
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.status});

  final EstimateStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      EstimateStatus.finalized => (AppColors.primary.withValues(alpha: 0.2), AppColors.primary),
      EstimateStatus.completed => (AppColors.completed.withValues(alpha: 0.2), AppColors.completed),
      EstimateStatus.drafted => (AppColors.cardHover, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ClientWorkspacePage extends StatefulWidget {
  const ClientWorkspacePage({
    super.key,
    required this.client,
    required this.linkedEstimates,
    required this.onSave,
    required this.onDelete,
  });

  final ClientRecord client;
  final List<EstimateDraft> Function() linkedEstimates;
  final Future<void> Function(ClientRecord client, {String? previousName}) onSave;
  final Future<void> Function() onDelete;

  @override
  State<ClientWorkspacePage> createState() => _ClientWorkspacePageState();
}

class _ClientWorkspacePageState extends State<ClientWorkspacePage> {
  var _tab = 0;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _company;
  late final TextEditingController _project;
  late final TextEditingController _address;
  late final TextEditingController _source;
  late final TextEditingController _notes;

  ClientRecord get client => widget.client;

  String get _composedName {
    return [_first.text.trim(), _last.text.trim()].where((part) => part.isNotEmpty).join(' ');
  }

  bool get _dirty {
    return _composedName != client.name ||
        _phone.text.trim() != client.phone ||
        _email.text.trim() != client.email ||
        _company.text.trim() != client.company ||
        _project.text.trim() != client.project ||
        _address.text.trim() != client.address ||
        _source.text.trim() != client.source ||
        _notes.text.trim() != client.notes;
  }

  @override
  void initState() {
    super.initState();
    final parts = client.name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    _first = TextEditingController(text: parts.isEmpty ? '' : parts.first);
    _last = TextEditingController(text: parts.length <= 1 ? '' : parts.skip(1).join(' '));
    _phone = TextEditingController(text: client.phone);
    _email = TextEditingController(text: client.email);
    _company = TextEditingController(text: client.company);
    _project = TextEditingController(text: client.project);
    _address = TextEditingController(text: client.address);
    _source = TextEditingController(text: client.source);
    _notes = TextEditingController(text: client.notes);
    for (final controller in [_first, _last, _phone, _email, _company, _project, _address, _source, _notes]) {
      controller.addListener(_onFieldsChanged);
    }
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [_first, _last, _phone, _email, _company, _project, _address, _source, _notes]) {
      controller.removeListener(_onFieldsChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _resetFields() {
    final parts = client.name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    _first.text = parts.isEmpty ? '' : parts.first;
    _last.text = parts.length <= 1 ? '' : parts.skip(1).join(' ');
    _phone.text = client.phone;
    _email.text = client.email;
    _company.text = client.company;
    _project.text = client.project;
    _address.text = client.address;
    _source.text = client.source;
    _notes.text = client.notes;
  }

  Future<void> _persist({bool notify = true}) async {
    final previousName = client.name;
    client.name = _composedName;
    client.phone = _phone.text.trim();
    client.email = _email.text.trim();
    client.company = _company.text.trim();
    client.project = _project.text.trim();
    client.address = _address.text.trim();
    client.source = _source.text.trim();
    client.notes = _notes.text.trim();
    await widget.onSave(client, previousName: previousName);
    if (!mounted) return;
    setState(() {});
    if (notify) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client saved')));
    }
  }

  void _discard() {
    if (!_dirty) {
      Navigator.of(context).maybePop();
      return;
    }
    _resetFields();
  }

  Future<void> _addFollowUp() async {
    final item = await showAddFollowUpDialog(context);
    if (item == null) return;
    client.followUps.insert(0, item);
    await _persist(notify: false);
    await ScheduleService.instance.fromFollowUp(client, item);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client'),
        content: Text('Delete ${client.name.isEmpty ? 'this client' : client.name}? Follow-ups will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onDelete();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 8, compact ? 16 : 28, 8),
              child: _workspaceHeader(compact: compact),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 8, compact ? 16 : 28, compact ? 96 : 32),
                children: [
                  if (_tab == 0) _detailsBody(compact: compact),
                  if (_tab == 1) _followBody(),
                  if (_tab == 2) _crmBody(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: compact
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(height: 48, child: _saveButton()),
              ),
            )
          : null,
    );
  }

  Widget _workspaceHeader({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 4),
        Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            if (compact)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _WorkspaceTabs(
                  index: _tab,
                  onChanged: (index) => setState(() => _tab = index),
                ),
              )
            else
              _WorkspaceTabs(
                index: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
            if (compact) const SizedBox(height: 12) else const Spacer(),
            if (!compact)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.down),
                  ),
                  TextButton(
                    onPressed: _discard,
                    style: TextButton.styleFrom(foregroundColor: AppColors.primarySoft),
                    child: const Text('DISCARD', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  _saveButton(),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.down),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _saveButton() {
    return FilledButton.icon(
      onPressed: _persist,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF1A1010),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text('SAVE CLIENT', style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.w700)),
    );
  }

  Widget _detailsBody({required bool compact}) {
    final drafts = widget.linkedEstimates();
    final total = drafts.fold<double>(0, (sum, draft) => sum + draft.totals.grandTotal);
    final drafted = drafts.where((draft) => draft.status == EstimateStatus.drafted).length;
    final left = Column(
      children: [
        _profileCard(compact: compact),
        const SizedBox(height: 16),
        _contactCard(compact: compact),
        const SizedBox(height: 16),
        _projectCard(),
      ],
    );
    final right = Column(
      children: [
        _statCard(
          label: 'Total Value',
          value: drafts.isEmpty ? '—' : inrCompact(total),
          footerIcon: Icons.schedule,
          footer: 'updated ${quotationDate(client.updatedAt)}',
        ),
        const SizedBox(height: 12),
        _statCard(
          label: 'Active Estimates',
          value: '${drafts.length}',
          footerIcon: Icons.pending_actions_outlined,
          footer: drafted == 0 ? 'none drafted' : '$drafted awaiting review',
        ),
        const SizedBox(height: 12),
        _siteCard(),
        const SizedBox(height: 12),
        _tagsCard(),
      ],
    );
    if (compact) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 8, child: left),
        const SizedBox(width: 20),
        Expanded(flex: 4, child: right),
      ],
    );
  }

  Widget _profileCard({required bool compact}) {
    final displayName = _composedName.isEmpty ? 'untitled client' : _composedName.toLowerCase();
    final role = _company.text.trim().isNotEmpty
        ? _company.text.trim()
        : (_project.text.trim().isEmpty ? 'no company on file' : _project.text.trim());
    final lost = client.stage == CrmStage.lost;
    final avatar = CircleAvatar(
      radius: compact ? 40 : 52,
      backgroundColor: AppColors.cardHover,
      child: Text(
        _clientInitials(_composedName),
        style: TextStyle(color: AppColors.primarySoft, fontSize: compact ? 22 : 28, fontWeight: FontWeight.w700),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
              child: Text(
                'CLIENT ID: ${_clientCode()}',
                style: const TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1.4),
              ),
            ),
            Container(width: 1, height: 14, color: AppColors.outline),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (lost ? AppColors.down : const Color(0xFF5ADACE)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: lost ? AppColors.down : const Color(0xFF5ADACE),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lost ? 'LOST' : (client.stage == CrmStage.won ? 'WON' : 'ACTIVE'),
                    style: TextStyle(
                      color: lost ? AppColors.down : const Color(0xFF5ADACE),
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          displayName,
          style: TextStyle(color: AppColors.text, fontSize: compact ? 24 : 28, fontWeight: FontWeight.w600, height: 1.1),
        ),
        const SizedBox(height: 6),
        Text(role, style: const TextStyle(color: AppColors.muted, fontSize: 16)),
      ],
    );
    return _WsCard(
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [avatar, const SizedBox(height: 16), identity])
          : Row(children: [avatar, const SizedBox(width: 20), Expanded(child: identity)]),
    );
  }

  Widget _contactCard({required bool compact}) {
    return _WsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WsSectionTitle(icon: Icons.assignment_ind_outlined, title: 'contact information'),
          const SizedBox(height: 20),
          if (compact) ...[
            _WsField(label: 'First Name', controller: _first),
            const SizedBox(height: 16),
            _WsField(label: 'Last Name', controller: _last),
            const SizedBox(height: 16),
            _WsField(label: 'Email Address', controller: _email, keyboard: TextInputType.emailAddress, icon: Icons.mail_outline),
            const SizedBox(height: 16),
            _WsField(label: 'Phone Number', controller: _phone, keyboard: TextInputType.phone, icon: Icons.call_outlined),
            const SizedBox(height: 16),
            _WsField(label: 'Company', controller: _company, icon: Icons.domain_outlined),
          ] else ...[
            Row(
              children: [
                Expanded(child: _WsField(label: 'First Name', controller: _first)),
                const SizedBox(width: 16),
                Expanded(child: _WsField(label: 'Last Name', controller: _last)),
              ],
            ),
            const SizedBox(height: 16),
            _WsField(label: 'Email Address', controller: _email, keyboard: TextInputType.emailAddress, icon: Icons.mail_outline),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _WsField(label: 'Phone Number', controller: _phone, keyboard: TextInputType.phone, icon: Icons.call_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _WsField(label: 'Company', controller: _company, icon: Icons.domain_outlined)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _projectCard() {
    return _WsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WsSectionTitle(icon: Icons.architecture_outlined, title: 'project specifics'),
          const SizedBox(height: 20),
          _WsField(label: 'Current Project / Site', controller: _project, icon: Icons.location_on_outlined),
          const SizedBox(height: 16),
          _WsField(label: 'Address', controller: _address, icon: Icons.home_outlined, lines: 2),
          const SizedBox(height: 16),
          _WsField(label: 'Lead Source', controller: _source),
          const SizedBox(height: 16),
          _WsField(label: 'Internal Notes', controller: _notes, lines: 4),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData footerIcon,
    required String footer,
  }) {
    return _WsCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppColors.text, fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(footerIcon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(footer, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _siteCard() {
    final location = _address.text.trim().isEmpty ? _project.text.trim() : _address.text.trim();
    return Container(
      height: 168,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x332C3348), Color(0xFF1C2030)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text('SITE LOCATION', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  location.isEmpty ? 'No address on file' : location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 16),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Material(
              color: AppColors.cardHover,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: location.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: location));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      },
                child: const SizedBox(width: 32, height: 32, child: Icon(Icons.open_in_new, size: 16, color: AppColors.text)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagsCard() {
    return _WsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CLASSIFICATION TAGS', style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(client.stage.label),
              if (_source.text.trim().isNotEmpty) _tag(_source.text.trim()),
              if (_project.text.trim().isNotEmpty) _tag(_project.text.trim()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 0.8)),
    );
  }

  Widget _followBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('follow-up log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            FilledButton.icon(
              onPressed: _addFollowUp,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Follow-up'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (client.followUps.isEmpty)
          const _WsCard(
            child: Text('No follow-ups yet. Log a call, visit or WhatsApp.', style: TextStyle(color: AppColors.muted)),
          )
        else
          for (final item in client.followUps) ...[
            _WsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.kind, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      Text(quotationDate(item.date), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                  if (item.nextFollow != null) ...[
                    const SizedBox(height: 6),
                    Text('Next: ${quotationDate(item.nextFollow!)}', style: const TextStyle(color: AppColors.primarySoft, fontSize: 12)),
                  ],
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(item.note, style: const TextStyle(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _crmBody() {
    final drafts = widget.linkedEstimates();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WsSectionTitle(icon: Icons.hub_outlined, title: 'pipeline stage'),
              const SizedBox(height: 16),
              Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in CrmStage.values)
                ChoiceChip(
                  label: Text(stage.label),
                  selected: client.stage == stage,
                  onSelected: (_) async {
                    client.stage = stage;
                    await _persist(notify: false);
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: client.stage == stage ? const Color(0xFF1A1010) : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _WsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('crm snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              _snap('Stage', client.stage.label),
              _snap('Source', _source.text.trim().isEmpty ? '—' : _source.text.trim()),
              _snap('Project', _project.text.trim().isEmpty ? '—' : _project.text.trim()),
              _snap('Follow-ups', '${client.followUps.length}'),
              _snap('Next follow-up', client.nextFollow == null ? '—' : quotationDate(client.nextFollow!)),
              _snap('Estimates', '${drafts.length}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _snap(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _clientCode() {
    final digits = client.id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length >= 5 ? digits.substring(digits.length - 5) : (digits.isEmpty ? client.id : digits);
    return '#$tail';
  }
}

class _WorkspaceTabs extends StatelessWidget {
  const _WorkspaceTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Details', 'Follow-up', 'CRM'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            Material(
              color: index == i ? AppColors.cardHover : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          labels[i].toUpperCase(),
                          style: TextStyle(
                            color: index == i ? AppColors.text : AppColors.muted,
                            fontSize: 12,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: index == i ? AppColors.primary : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WsCard extends StatelessWidget {
  const _WsCard({required this.child, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

class _WsSectionTitle extends StatelessWidget {
  const _WsSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
    );
  }
}

class _WsField extends StatelessWidget {
  const _WsField({
    required this.label,
    required this.controller,
    this.icon,
    this.keyboard,
    this.lines = 1,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboard;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines,
          keyboardType: keyboard,
          inputFormatters: keyboard == TextInputType.phone ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))] : null,
          style: const TextStyle(color: AppColors.text, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            prefixIcon: icon == null ? null : Icon(icon, color: AppColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF5ADACE)),
            ),
            contentPadding: EdgeInsets.fromLTRB(icon == null ? 16 : 12, 16, 16, 16),
          ),
        ),
      ],
    );
  }
}
