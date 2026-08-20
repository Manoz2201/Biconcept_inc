import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/catalog_tools.dart';
import '../data/appwrite_auto_sync.dart';
import '../data/catalog_repository.dart';
import '../data/draft_store.dart';
import '../models/estimate_document.dart';
import '../models/estimate_models.dart';
import '../theme/app_theme.dart';
import 'agent_panel.dart';
import 'clients_page.dart';
import 'dashboard_page.dart';
import 'estimates_page.dart';
import 'new_estimate_flow.dart';
import 'calendar_page.dart';
import 'quotation_editor.dart';
import 'rate_card_page.dart';
import 'settings_page.dart';
import 'widgets/ui_kit.dart';

class EstimateHomePage extends StatefulWidget {
  const EstimateHomePage({super.key});

  @override
  State<EstimateHomePage> createState() => _EstimateHomePageState();
}

class _EstimateHomePageState extends State<EstimateHomePage> with WidgetsBindingObserver {
  late Future<EstimateCatalog> _catalogFuture;
  int _tab = 0;
  String _query = '';
  EstimateStatus? _statusFilter;
  List<EstimateDraft> _drafts = [];
  bool _showAgent = true;
  final _agentKey = GlobalKey<CollapsibleAgentPanelState>();
  final _clientsKey = GlobalKey<ClientsPageState>();
  int _appliedSync = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppwriteAutoSync.instance.addListener(_onAutoSync);
    _catalogFuture = CatalogRepository.instance.load();
    _reloadDrafts();
    unawaited(AppwriteAutoSync.instance.ensureStarted());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppwriteAutoSync.instance.removeListener(_onAutoSync);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppwriteAutoSync.instance.syncOnResume());
    }
  }

  void _onAutoSync() {
    final generation = AppwriteAutoSync.instance.applyGeneration;
    if (generation == _appliedSync || !mounted) return;
    _appliedSync = generation;
    unawaited(_reloadAfterSync());
  }

  Future<void> _reloadAfterSync() async {
    await _reloadDrafts();
    await _clientsKey.currentState?.reload();
    await CatalogRepository.instance.reload();
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
          extendBody: compact,
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
                      title: compact ? 'biconcept' : 'biconcept digital architecture',
                      muted: true,
                      compact: compact,
                      searchHint: _searchHint,
                      onSearch: _tab == 2
                          ? (value) => setState(() => _query = value.trim())
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ask $kAgentName',
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
                          IconButton(
                            tooltip: 'Settings',
                            onPressed: () => setState(() => _tab = 5),
                            icon: const CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.cardHover,
                              child: Icon(Icons.person_rounded, color: AppColors.muted, size: 18),
                            ),
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
                            onOpenCalendar: () => setState(() => _tab = 3),
                          ),
                          EstimatesPage(
                            drafts: _drafts,
                            catalog: catalog,
                            compact: compact,
                            statusFilter: _statusFilter,
                            onStatusFilter: (status) => setState(() => _statusFilter = status),
                            onCreate: () => _newEstimate(catalog),
                            onChanged: _reloadDrafts,
                          ),
                          ClientsPage(
                            key: _clientsKey,
                            query: _query,
                            drafts: _drafts,
                            compact: compact,
                            catalog: catalog,
                            onEstimatesChanged: _reloadDrafts,
                            onOpenQuotation: (draft) => _openQuotation(catalog, draft),
                          ),
                          CalendarPage(drafts: _drafts, compact: compact),
                          RateCardPage(catalog: catalog, query: _query, compact: compact),
                          SettingsPage(
                            embedded: true,
                            onAppDataChanged: () async {
                              await _reloadDrafts();
                              await _clientsKey.currentState?.reload();
                              await CatalogRepository.instance.reload();
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
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: _tab == 1
              ? FloatingActionButton(
                  onPressed: () => _newEstimate(catalog),
                  tooltip: 'New estimate',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.add, size: 28),
                )
              : _tab == 2
                  ? FloatingActionButton(
                      onPressed: () => _addClient(),
                      tooltip: 'New client',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.add, size: 28),
                    )
                  : null,
          bottomNavigationBar: compact
              ? NavigationBar(
                  selectedIndex: _tab,
                  labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: (index) => setState(() {
                    _tab = index;
                    _query = '';
                  }),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Home',
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
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book_rounded),
                      label: 'Rates',
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
        case 'calendar':
        case 'accounts':
        case 'payments':
          _tab = 3;
        case 'rate_card':
        case 'rate card':
          _tab = 4;
        case 'settings':
          _tab = 5;
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
    showAgentSheet(
      context: context,
      panel: AgentPanel(
        catalog: catalog,
        onCollapse: () => Navigator.pop(context),
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
    );
  }

  String get _searchHint => switch (_tab) {
        1 => 'Search client or project',
        2 => 'Search client, phone or project',
        4 => 'Search work type, scope or area',
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
}
