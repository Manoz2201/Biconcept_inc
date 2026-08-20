import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/client_store.dart';
import '../export/quotation_layout.dart';
import '../models/client_record.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/call_phone.dart';
import 'new_estimate_flow.dart';
import 'widgets/ui_kit.dart';

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
    _reload();
  }

  @override
  void didUpdateWidget(covariant ClientsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drafts.length != widget.drafts.length) {
      _reload();
    }
  }

  Future<void> _reload() async {
    await _store.syncFromEstimates(widget.drafts);
    final clients = await _store.list();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _loading = false;
    });
  }

  Future<void> reload() => _reload();

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

  int _estimateCount(ClientRecord client) {
    return _linkedEstimates(client).length;
  }

  List<EstimateDraft> _linkedEstimates(ClientRecord client) {
    final name = client.name.trim().toLowerCase();
    if (name.isEmpty) return const [];
    return widget.drafts.where((draft) => draft.client.trim().toLowerCase() == name).toList();
  }

  Future<void> addClient() async {
    final created = await _editClient();
    if (created == null) return;
    await _store.save(created);
    await _reload();
  }

  Future<void> _saveClient(ClientRecord client) async {
    await _store.save(client);
    await _reload();
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
          estimateCount: _estimateCount(client),
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
    final pad = widget.compact ? 16.0 : 28.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('All', _stageFilter == null, () => setState(() => _stageFilter = null)),
              for (final stage in CrmStage.values)
                _chip(stage.label, _stageFilter == stage, () => setState(() => _stageFilter = stage)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _clients.isEmpty
                        ? 'No clients yet. Add a client or create an estimate.'
                        : 'No clients match this filter.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = items[index];
                    final next = client.nextFollow;
                    final canCall = sanitizePhoneNumber(client.phone).isNotEmpty;
                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _openViewer(client),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDim,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.person_outline, color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.name.isEmpty ? 'Untitled' : client.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (client.phone.isNotEmpty) client.phone,
                                          if (client.project.isNotEmpty) client.project,
                                          '${_estimateCount(client)} estimates',
                                          if (next != null) 'Next: ${quotationDate(next)}',
                                        ].join('  ·  '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                _StageChip(stage: client.stage),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LeadActions(
                            compact: widget.compact,
                            canCall: canCall,
                            onViewer: () => _openViewer(client),
                            onCall: () => _callLead(client),
                            onFollowUp: () => _followUp(client),
                            onEstimate: () => _createEstimate(client),
                            onEdit: () => _openEditor(client),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1A1010) : AppColors.text,
        fontWeight: FontWeight.w600,
      ),
    );
  }
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
    final next = client.nextFollow;
    final drafts = widget.linkedEstimates();
    return Scaffold(
      appBar: AppBar(
        title: Text(client.name.isEmpty ? 'Client viewer' : client.name),
        actions: [
          IconButton(
            tooltip: 'Call',
            onPressed: () => _refreshAfter(widget.onCall),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StageChip(stage: client.stage),
              if (next != null)
                Chip(
                  label: Text('Next follow-up ${quotationDate(next)}'),
                  backgroundColor: AppColors.card,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _LeadActions(
            compact: MediaQuery.sizeOf(context).width < AppBreakpoints.compact,
            canCall: sanitizePhoneNumber(client.phone).isNotEmpty,
            onViewer: null,
            onCall: () => _refreshAfter(widget.onCall),
            onFollowUp: () => _refreshAfter(widget.onFollowUp),
            onEstimate: () => _refreshAfter(widget.onCreateEstimate),
            onEdit: _edit,
          ),
          const SizedBox(height: 20),
          const Text('Client details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Column(
              children: [
                _InfoRow(label: 'Name', value: client.name),
                _InfoRow(
                  label: 'Phone',
                  value: client.phone,
                  action: sanitizePhoneNumber(client.phone).isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Call',
                          onPressed: () => _refreshAfter(widget.onCall),
                          icon: const Icon(Icons.call, color: AppColors.primary),
                        ),
                ),
                _InfoRow(label: 'Email', value: client.email),
                _InfoRow(label: 'Company', value: client.company),
                _InfoRow(label: 'Project / site', value: client.project),
                _InfoRow(label: 'Address', value: client.address),
                _InfoRow(label: 'Source', value: client.source),
                _InfoRow(label: 'Stage', value: client.stage.label),
                _InfoRow(label: 'Notes', value: client.notes),
                _InfoRow(label: 'Created', value: quotationDate(client.createdAt)),
                _InfoRow(label: 'Updated', value: quotationDate(client.updatedAt)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Follow-up (${client.followUps.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          if (client.followUps.isEmpty)
            const Text('No follow-ups yet.', style: TextStyle(color: AppColors.muted))
          else
            for (final item in client.followUps) ...[
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.kind, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(quotationDate(item.date), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                    if (item.nextFollow != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Next: ${quotationDate(item.nextFollow!)}',
                        style: const TextStyle(color: AppColors.primarySoft, fontSize: 12),
                      ),
                    ],
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(item.note),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 10),
          Text('Estimates (${drafts.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          if (drafts.isEmpty)
            const Text('No estimates for this lead yet.', style: TextStyle(color: AppColors.muted))
          else
            for (final draft in drafts) ...[
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                onTap: widget.onOpenQuotation == null ? null : () => widget.onOpenQuotation!(draft),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.project.isEmpty ? draft.estimateType : draft.project,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${draft.status.label}  ·  ${quotationDate(draft.date)}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class ClientWorkspacePage extends StatefulWidget {
  const ClientWorkspacePage({
    super.key,
    required this.client,
    required this.estimateCount,
    required this.onSave,
    required this.onDelete,
  });

  final ClientRecord client;
  final int estimateCount;
  final Future<void> Function(ClientRecord client) onSave;
  final Future<void> Function() onDelete;

  @override
  State<ClientWorkspacePage> createState() => _ClientWorkspacePageState();
}

class _ClientWorkspacePageState extends State<ClientWorkspacePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _company;
  late final TextEditingController _project;
  late final TextEditingController _address;
  late final TextEditingController _source;
  late final TextEditingController _notes;

  ClientRecord get client => widget.client;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _name = TextEditingController(text: client.name);
    _phone = TextEditingController(text: client.phone);
    _email = TextEditingController(text: client.email);
    _company = TextEditingController(text: client.company);
    _project = TextEditingController(text: client.project);
    _address = TextEditingController(text: client.address);
    _source = TextEditingController(text: client.source);
    _notes = TextEditingController(text: client.notes);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _company.dispose();
    _project.dispose();
    _address.dispose();
    _source.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    client.name = _name.text.trim();
    client.phone = _phone.text.trim();
    client.email = _email.text.trim();
    client.company = _company.text.trim();
    client.project = _project.text.trim();
    client.address = _address.text.trim();
    client.source = _source.text.trim();
    client.notes = _notes.text.trim();
    await widget.onSave(client);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _addFollowUp() async {
    final item = await showAddFollowUpDialog(context);
    if (item == null) return;
    client.followUps.insert(0, item);
    await _persist();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(client.name.isEmpty ? 'Edit client' : 'Edit ${client.name}'),
        actions: [
          IconButton(tooltip: 'Delete', onPressed: _confirmDelete, icon: const Icon(Icons.delete_outline)),
          IconButton(tooltip: 'Save', onPressed: _persist, icon: const Icon(Icons.check)),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Follow-up'),
            Tab(text: 'CRM'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          if (_tabs.index != 1) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _addFollowUp,
            icon: const Icon(Icons.add),
            label: const Text('Follow-up'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _detailsTab(),
          _followTab(),
          _crmTab(),
        ],
      ),
    );
  }

  Widget _detailsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('${widget.estimateCount} linked estimates', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        _field(_name, 'Client name'),
        _field(_phone, 'Phone', keyboard: TextInputType.phone),
        _field(_email, 'Email', keyboard: TextInputType.emailAddress),
        _field(_company, 'Company'),
        _field(_project, 'Project / site'),
        _field(_address, 'Address', lines: 2),
        _field(_source, 'Lead source'),
        _field(_notes, 'Notes', lines: 4),
        const SizedBox(height: 8),
        FilledButton(onPressed: _persist, child: const Text('Save details')),
      ],
    );
  }

  Widget _followTab() {
    if (client.followUps.isEmpty) {
      return const Center(
        child: Text('No follow-ups yet. Log a call, visit or WhatsApp.', style: TextStyle(color: AppColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: client.followUps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = client.followUps[index];
        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(item.kind, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                Text(item.note),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _crmTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text('Pipeline stage', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
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
                  await _persist();
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: client.stage == stage ? const Color(0xFF1A1010) : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CRM snapshot', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _snap('Stage', client.stage.label),
              _snap('Source', client.source.isEmpty ? '—' : client.source),
              _snap('Project', client.project.isEmpty ? '—' : client.project),
              _snap('Follow-ups', '${client.followUps.length}'),
              _snap('Next follow-up', client.nextFollow == null ? '—' : quotationDate(client.nextFollow!)),
              _snap('Estimates', '${widget.estimateCount}'),
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

  Widget _field(TextEditingController controller, String label, {int lines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        keyboardType: keyboard,
        inputFormatters: keyboard == TextInputType.phone ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))] : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _LeadActions extends StatelessWidget {
  const _LeadActions({
    required this.compact,
    required this.canCall,
    this.onViewer,
    required this.onCall,
    required this.onFollowUp,
    required this.onEstimate,
    required this.onEdit,
  });

  final bool compact;
  final bool canCall;
  final VoidCallback? onViewer;
  final VoidCallback onCall;
  final VoidCallback onFollowUp;
  final VoidCallback onEstimate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onViewer != null)
          _action(
            icon: Icons.visibility_outlined,
            label: 'Viewer',
            onPressed: onViewer!,
            filled: true,
          ),
        _action(
          icon: Icons.call_outlined,
          label: 'Call',
          onPressed: canCall ? onCall : null,
        ),
        _action(
          icon: Icons.event_repeat_outlined,
          label: 'Follow-up',
          onPressed: onFollowUp,
        ),
        _action(
          icon: Icons.request_quote_outlined,
          label: compact ? 'Estimate' : 'New estimate',
          onPressed: onEstimate,
        ),
        _action(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onPressed: onEdit,
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    );
    if (filled) {
      return FilledButton(onPressed: onPressed, style: style, child: child);
    }
    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.action});

  final String label;
  final String value;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final CrmStage stage;

  Color get _color => switch (stage) {
        CrmStage.won => AppColors.up,
        CrmStage.lost => AppColors.down,
        CrmStage.quotation || CrmStage.negotiation => AppColors.primary,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
      ),
      child: Text(
        stage.label,
        style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
