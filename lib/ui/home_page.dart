import 'package:flutter/material.dart';

import '../agent/catalog_tools.dart';
import '../data/catalog_repository.dart';
import '../data/draft_store.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'agent_panel.dart';
import 'clients_page.dart';
import 'dashboard_page.dart';
import 'estimate_type_picker.dart';
import 'new_estimate_flow.dart';
import 'quotation_editor.dart';
import 'rate_card_page.dart';
import 'settings_page.dart';
import 'widgets/ui_kit.dart';

class EstimateHomePage extends StatefulWidget {
  const EstimateHomePage({super.key});

  @override
  State<EstimateHomePage> createState() => _EstimateHomePageState();
}

class _EstimateHomePageState extends State<EstimateHomePage> {
  late Future<EstimateCatalog> _catalogFuture;
  int _tab = 0;
  String _query = '';
  EstimateStatus? _statusFilter;
  List<EstimateDraft> _drafts = [];
  bool _showAgent = true;
  final _agentKey = GlobalKey<CollapsibleAgentPanelState>();
  final _clientsKey = GlobalKey<ClientsPageState>();

  @override
  void initState() {
    super.initState();
    _catalogFuture = CatalogRepository.instance.load();
    _reloadDrafts();
  }

  Future<void> _reloadDrafts() async {
    final drafts = await DraftStore().list();
    if (!mounted) return;
    setState(() => _drafts = drafts);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EstimateCatalog>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Could not load catalog: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        return ListenableBuilder(
          listenable: CatalogRepository.instance,
          builder: (context, _) => _shell(CatalogRepository.instance.catalog ?? snapshot.data!),
        );
      },
    );
  }

  Widget _shell(EstimateCatalog catalog) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        final wide = constraints.maxWidth >= AppBreakpoints.wide;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                AppSidebar(
                  index: _tab,
                  onSelect: (index) => setState(() {
                    _tab = index;
                    _query = '';
                  }),
                ),
              Expanded(
                child: Column(
                  children: [
                    AppHeader(
                      title: _title,
                      compact: compact,
                      searchHint: _searchHint,
                      onSearch: (_tab == 1 || _tab == 2 || _tab == 3)
                          ? (value) => setState(() => _query = value.trim())
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: (_agentKey.currentState?.expanded ?? _showAgent)
                                ? 'Collapse agent'
                                : 'Expand agent',
                            onPressed: () {
                              if (wide) {
                                _agentKey.currentState?.toggle();
                                setState(() => _showAgent = _agentKey.currentState?.expanded ?? !_showAgent);
                              } else {
                                _openAgentSheet(catalog);
                              }
                            },
                            icon: Icon(
                              (_agentKey.currentState?.expanded ?? _showAgent)
                                  ? Icons.smart_toy
                                  : Icons.smart_toy_outlined,
                              color: AppColors.primarySoft,
                            ),
                          ),
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.cardHover,
                            child: Icon(Icons.person_rounded, color: AppColors.muted, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          DashboardPage(
                            drafts: _drafts,
                            onOpenEstimates: () => setState(() {
                              _tab = 1;
                              _statusFilter = null;
                            }),
                            onOpenStatus: (status) => setState(() {
                              _tab = 1;
                              _statusFilter = status;
                            }),
                          ),
                          _estimatesTab(catalog, compact: compact),
                          ClientsPage(
                            key: _clientsKey,
                            query: _query,
                            drafts: _drafts,
                            compact: compact,
                            catalog: catalog,
                            onEstimatesChanged: _reloadDrafts,
                            onOpenQuotation: (draft) => _openQuotation(catalog, draft),
                          ),
                          RateCardPage(catalog: catalog, query: _query),
                          SettingsPage(
                            embedded: true,
                            onAppDataChanged: () async {
                              await _reloadDrafts();
                              await _clientsKey.currentState?.reload();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (wide) ...[
                const VerticalDivider(width: 1),
                CollapsibleAgentPanel(
                  key: _agentKey,
                  catalog: catalog,
                  initiallyExpanded: _showAgent,
                  onExpandedChanged: (value) => setState(() => _showAgent = value),
                  actions: AgentActions(
                    onNavigate: (screen) => _navigate(screen),
                    onOpenQuotation: (draft) => _openQuotation(catalog, draft),
                    onEstimatesChanged: _reloadDrafts,
                  ),
                ),
              ],
            ],
            ),
          ),
          floatingActionButton: _tab == 1
              ? (compact
                  ? FloatingActionButton(
                      onPressed: () => _newEstimate(catalog),
                      child: const Icon(Icons.add),
                    )
                  : FloatingActionButton.extended(
                      onPressed: () => _newEstimate(catalog),
                      icon: const Icon(Icons.add),
                      label: const Text('New estimate'),
                    ))
              : _tab == 2
                  ? (compact
                      ? FloatingActionButton(
                          onPressed: () => _addClient(),
                          child: const Icon(Icons.person_add_alt_1),
                        )
                      : FloatingActionButton.extended(
                          onPressed: () => _addClient(),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('New client'),
                        ))
                  : _tab == 0
                      ? FloatingActionButton(
                          onPressed: () => _newEstimate(catalog),
                          child: const Icon(Icons.add),
                        )
                      : null,
          bottomNavigationBar: compact
              ? NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (index) => setState(() {
                    _tab = index;
                    _query = '';
                  }),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.request_quote_outlined),
                      selectedIcon: Icon(Icons.request_quote_rounded),
                      label: 'Estimates',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt_rounded),
                      label: 'Clients',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book_rounded),
                      label: 'Rate card',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: 'Settings',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  void _navigate(String screen) {
    setState(() {
      switch (screen) {
        case 'dashboard':
          _tab = 0;
        case 'estimates':
          _tab = 1;
        case 'clients':
        case 'client':
        case 'crm':
          _tab = 2;
        case 'rate_card':
        case 'rate card':
          _tab = 3;
        case 'settings':
          _tab = 4;
      }
    });
  }

  Future<void> _openQuotation(EstimateCatalog catalog, EstimateDraft draft) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuotationEditorPage(catalog: catalog, draft: draft),
      ),
    );
    await _reloadDrafts();
  }

  void _openAgentSheet(EstimateCatalog catalog) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 380,
          height: 560,
          child: AgentPanel(
            catalog: catalog,
            actions: AgentActions(
              onNavigate: (screen) {
                Navigator.pop(context);
                _navigate(screen);
              },
              onOpenQuotation: (draft) async {
                Navigator.pop(context);
                await _openQuotation(catalog, draft);
              },
              onEstimatesChanged: _reloadDrafts,
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_tab) {
        0 => 'dashboard',
        1 => 'estimates',
        2 => 'clients',
        3 => 'rate card',
        _ => 'settings',
      };

  String get _searchHint => switch (_tab) {
        1 => 'Search client or project',
        2 => 'Search client, phone or project',
        3 => 'Search work type, scope or area',
        _ => 'Search',
      };

  Future<void> _addClient() async {
    await _clientsKey.currentState?.addClient();
  }

  Future<void> _newEstimate(EstimateCatalog catalog) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NewEstimateFlow(catalog: catalog)),
    );
    await _reloadDrafts();
  }

  Widget _estimatesTab(EstimateCatalog catalog, {required bool compact}) {
    final q = _query.toLowerCase();
    final items = _drafts.where((draft) {
      final statusOk = _statusFilter == null || draft.status == _statusFilter;
      final queryOk = q.isEmpty ||
          draft.client.toLowerCase().contains(q) ||
          draft.project.toLowerCase().contains(q) ||
          draft.estimateType.toLowerCase().contains(q);
      return statusOk && queryOk;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 4, compact ? 16 : 28, 12),
          child: Wrap(
            spacing: 8,
            children: [
              _filterChip('All', _statusFilter == null, () => setState(() => _statusFilter = null)),
              _filterChip('Drafted', _statusFilter == EstimateStatus.drafted, () {
                setState(() => _statusFilter = EstimateStatus.drafted);
              }),
              _filterChip('Completed', _statusFilter == EstimateStatus.completed, () {
                setState(() => _statusFilter = EstimateStatus.completed);
              }),
              _filterChip('Finalized', _statusFilter == EstimateStatus.finalized, () {
                setState(() => _statusFilter = EstimateStatus.finalized);
              }),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _drafts.isEmpty
                        ? 'No estimates yet. Start a new estimate from areas, work types, then scopes.'
                        : 'No estimates match this filter.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 0, compact ? 16 : 28, 96),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final draft = items[index];
                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => QuotationEditorPage(catalog: catalog, draft: draft),
                          ),
                        );
                        await _reloadDrafts();
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDim,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.description_outlined, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draft.client.isEmpty ? 'Untitled' : draft.client,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    draft.estimateType,
                                    if (draft.project.isNotEmpty) draft.project,
                                    '${draft.lines.length} lines',
                                    '${draft.date.day.toString().padLeft(2, '0')}/${draft.date.month.toString().padLeft(2, '0')}/${draft.date.year}',
                                  ].join('  ·  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(status: draft.status, compact: true),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                inr(draft.totals.grandTotal),
                                maxLines: 1,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            onSelected: (value) async {
                              switch (value) {
                                case 'type':
                                  await _changeEstimateType(draft);
                                case 'delete':
                                  await _deleteEstimate(draft);
                                default:
                                  if (value.startsWith('status:')) {
                                    final name = value.substring(7);
                                    draft.setStatus(EstimateStatus.fromName(name));
                                    await DraftStore().save(draft);
                                    await _reloadDrafts();
                                  }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'type', child: Text('Change type')),
                              const PopupMenuDivider(),
                              for (final status in EstimateStatus.values)
                                PopupMenuItem(value: 'status:${status.name}', child: Text('Mark ${status.label}')),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'delete', child: Text('Delete estimate')),
                            ],
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

  Future<void> _changeEstimateType(EstimateDraft draft) async {
    final next = await showEstimateTypePicker(context, current: draft.estimateType);
    if (next == null || !mounted) return;
    draft.setEstimateType(next);
    await DraftStore().save(draft);
    await _reloadDrafts();
  }

  Future<void> _deleteEstimate(EstimateDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete estimate'),
        content: Text(
          'Delete the estimate for ${draft.client.isEmpty ? 'this client' : draft.client}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DraftStore().delete(draft.id);
    await _reloadDrafts();
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
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
