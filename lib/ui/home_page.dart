import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/catalog_tools.dart';
import '../data/app_update_service.dart';
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
import 'widgets/app_nav.dart';
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
  final _settingsKey = GlobalKey<SettingsPageState>();
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

  Future<void> _reloadAppData() async {
    await _reloadDrafts();
    await _clientsKey.currentState?.reload();
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
        return Scaffold(
          extendBody: compact,
          resizeToAvoidBottomInset: true,
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
                    if (compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AgentLauncherButton(onPressed: () => _openAgentSheet(catalog)),
                        ),
                      ),
                    if (_tab != 5)
                      ListenableBuilder(
                        listenable: AppUpdateNotice.instance,
                        builder: (context, _) {
                          final notice = AppUpdateNotice.instance;
                          final release = notice.latest;
                          if (!notice.available || release == null) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Material(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                leading: const Icon(Icons.system_update_alt, color: AppColors.primary),
                                title: Text('BiConcept ${release.display} is ready'),
                                subtitle: const Text('Download and install in the app — GitHub will not open'),
                                trailing: TextButton(
                                  onPressed: () {
                                    setState(() => _tab = 5);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      unawaited(_settingsKey.currentState?.installAvailableUpdate() ?? Future<void>.value());
                                    });
                                  },
                                  child: const Text('Install'),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    if (_tab == 2)
                      AppHeader(
                        title: '',
                        muted: true,
                        compact: compact,
                        searchHint: _searchHint,
                        onSearch: (value) => setState(() => _query = value.trim()),
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
                            key: _settingsKey,
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
              if (!compact) ...[
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
                    onAppDataChanged: _reloadAppData,
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
              ? AppBottomNav(
                  selectedIndex: _tab,
                  onSelect: (index) => setState(() {
                    _tab = index;
                    _query = '';
                  }),
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
          onAppDataChanged: _reloadAppData,
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
