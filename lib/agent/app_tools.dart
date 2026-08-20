import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/agent_session_store.dart';
import '../data/appwrite_auto_sync.dart';
import '../data/appwrite_sync.dart';
import '../data/catalog_repository.dart';
import '../data/client_store.dart';
import '../data/draft_store.dart';
import '../data/local_cache.dart';
import '../data/schedule.dart';
import '../data/settings_store.dart';
import '../models/client_record.dart';
import '../models/office_models.dart';
import '../util/when.dart';
import 'agent_service.dart';
import 'catalog_tools.dart';

/// CRM, calendar, accounts, cloud, and search tools on top of [CatalogTools].
class AppTools {
  AppTools({required this.catalogTools});

  final CatalogTools catalogTools;
  final ClientStore _clients = ClientStore();
  final DraftStore _drafts = DraftStore();
  final AppwriteSync _appwrite = AppwriteSync();

  AgentActions? get actions => catalogTools.actions;

  static final definitions = <Map<String, dynamic>>[
    ...CatalogTools.definitions,
    ..._appDefinitions,
  ];

  static final _net = AgentService(accountId: 'local', apiToken: 'local', httpClient: http.Client());

  static const _appDefinitions = <Map<String, dynamic>>[
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description': 'Search the public internet (DuckDuckGo + Wikipedia).',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'web_fetch',
        'description': 'Fetch an http/https page and return readable text.',
        'parameters': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string'},
          },
          'required': ['url'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_app',
        'description': 'Search clients, estimates, calendar events, and the rate card in one pass.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'limit': {'type': 'integer'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_clients',
        'description': 'List CRM clients with stage, phone, and project.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_client',
        'description': 'Get one client by id, name, or phone.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
            'phone': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'save_client',
        'description':
            'Create or update a CRM client after asking the user for details. Ask name first, then phone and project. Pass id to update; otherwise match by name or create.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
            'phone': {'type': 'string'},
            'email': {'type': 'string'},
            'company': {'type': 'string'},
            'project': {'type': 'string'},
            'address': {'type': 'string'},
            'source': {'type': 'string'},
            'stage': {
              'type': 'string',
              'description': 'lead, contacted, siteVisit, quotation, negotiation, won, lost',
            },
            'notes': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_client',
        'description': 'Delete a CRM client by id or name.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_client_follow_up',
        'description':
            'Add a follow-up reminder on a CRM client and the calendar, with a notification. Ask which client and when (tomorrow, in 3 days, next Friday, or a date).',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
            'when': {
              'type': 'string',
              'description': 'ISO datetime, or tomorrow, in 3 days, next Friday, 25/08/2026',
            },
            'kind': {
              'type': 'string',
              'description': 'Call, WhatsApp, Visit, Email, or Other',
            },
            'note': {'type': 'string'},
          },
          'required': ['when'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_calendar',
        'description': 'List calendar events. Optional ISO day, or upcoming undoned items.',
        'parameters': {
          'type': 'object',
          'properties': {
            'day': {'type': 'string', 'description': 'ISO date, e.g. 2026-08-21'},
            'limit': {'type': 'integer'},
            'includeDone': {'type': 'boolean'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_calendar_event',
        'description': 'Add a calendar event. kind: meeting, followUp, collect, pay.',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'start': {
              'type': 'string',
              'description': 'ISO datetime, or tomorrow, in 3 days, next Friday',
            },
            'kind': {'type': 'string'},
            'client': {'type': 'string'},
            'project': {'type': 'string'},
            'notes': {'type': 'string'},
            'notify': {'type': 'boolean'},
          },
          'required': ['title', 'start'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'complete_calendar_event',
        'description': 'Mark a calendar event done or not done.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'done': {'type': 'boolean'},
          },
          'required': ['id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_calendar_event',
        'description': 'Delete a calendar event by id.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
          },
          'required': ['id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_accounts',
        'description': 'List project ledgers: scheduled, received, sent, outstanding.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'record_payment',
        'description': 'Record money received from a client or sent to a vendor.',
        'parameters': {
          'type': 'object',
          'properties': {
            'amount': {'type': 'number'},
            'flow': {'type': 'string', 'description': 'receive or send'},
            'client': {'type': 'string'},
            'project': {'type': 'string'},
            'method': {'type': 'string'},
            'party': {'type': 'string'},
            'note': {'type': 'string'},
            'estimateId': {'type': 'string'},
          },
          'required': ['amount'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'company_profile',
        'description': 'Read company brand, address, and phone. GST percents are read-only.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_company',
        'description': 'Update company brand, address, or phone. Do not change GST.',
        'parameters': {
          'type': 'object',
          'properties': {
            'brand': {'type': 'string'},
            'address': {'type': 'string'},
            'phone': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_session_files',
        'description': 'List PDF, Word, and Excel files attached in this chat session.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_session_file',
        'description': 'Read extracted text from an attached session file by id or name.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'save_file_summary',
        'description': 'Save a short summary of an attached file into the local session cache.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
            'summary': {'type': 'string'},
          },
          'required': ['summary'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'query_database',
        'description':
            'Query Appwrite cloud tables: clients, estimates, company, catalog. Use for live cloud data.',
        'parameters': {
          'type': 'object',
          'properties': {
            'table': {'type': 'string'},
            'contains': {'type': 'string'},
            'limit': {'type': 'integer'},
          },
          'required': ['table'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'sync_cloud',
        'description': 'Sync local clients, estimates, catalog, and company with Appwrite now.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
  ];

  static String workersAiToolPrompt() {
    final names = [
      for (final item in definitions)
        if (item['function'] is Map) (item['function'] as Map)['name']?.toString() ?? '',
    ].where((name) => name.isNotEmpty).join(', ');
    return '''
You operate the full BiConcept app: dashboard, estimates, clients/CRM, calendar, accounts, rate card, settings, and quotations.
Use tools for any in-app action the user asks for. Do not say you are only an estimator.
Interview the user. Ask short questions; do not invent missing details.
New client: ask name, then phone and project/site (email/address optional). Then save_client.
New estimate: ask which client, then which work scope (gypsum, painting, HVAC…). search_rate_card if needed, then create_estimate with client and workScope. If the client is not in CRM, save_client first.
Follow-up reminder: ask which client, when to remind, and Call/WhatsApp/Visit. Then add_client_follow_up so it is stored on the client and on the calendar with a notification.
Internet: web_search and web_fetch (built in). Prefer tools over guessing.
Database: query_database for Appwrite tables clients, estimates, company, catalog. Use sync_cloud to pull/push.
Attached files: list_session_files, read_session_file, save_file_summary. PDF/Word/Excel text is also in session context — summarize when asked and save the summary.
App tools: $names.
Amounts are INR. ${CatalogTools.workersAiToolPrompt()}
''';
  }

  Future<Map<String, dynamic>> snapshot() async {
    final clients = await _clients.list();
    await ScheduleService.instance.store.load();
    final now = DateTime.now();
    final upcoming = [
      for (final event in ScheduleService.instance.store.events)
        if (!event.done && !event.start.isBefore(now.subtract(const Duration(days: 1)))) event,
    ]..sort((a, b) => a.start.compareTo(b.start));
    return {
      'estimate': catalogTools.appSnapshot(),
      'clientCount': clients.length,
      'clients': [
        for (final client in clients.take(15)) _clientSummary(client),
      ],
      'upcomingEvents': [
        for (final event in upcoming.take(8)) _eventSummary(event),
      ],
      'sessionFiles': [
        for (final file in AgentSessionStore.instance.documents)
          {
            'id': file.id,
            'name': file.name,
            'kind': file.kind,
            'chars': file.text.length,
            'hasSummary': file.summary.trim().isNotEmpty,
          },
      ],
    };
  }

  Future<String> execute(String name, Map<String, dynamic> arguments) {
    return executeJson(name, jsonEncode(arguments));
  }

  Future<String> executeJson(String name, String argumentsJson) async {
    Map<String, dynamic> args = {};
    try {
      final decoded = jsonDecode(argumentsJson);
      if (decoded is Map) args = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    try {
      switch (name) {
        case 'web_search':
          final query = args['query']?.toString().trim() ?? '';
          if (query.isEmpty) return jsonEncode({'error': 'query is required'});
          return await _net.runWebSearch(query);
        case 'web_fetch':
          final url = (args['url'] ?? args['uri'] ?? args['link'])?.toString().trim() ?? '';
          if (url.isEmpty) return jsonEncode({'error': 'url is required'});
          return await _net.runWebFetch(url);
        case 'search_app':
          return await _searchApp(args);
        case 'list_clients':
          return await _listClients();
        case 'get_client':
          return await _getClient(args);
        case 'save_client':
          return await _saveClient(args);
        case 'delete_client':
          return await _deleteClient(args);
        case 'add_client_follow_up':
          return await _addClientFollowUp(args);
        case 'list_calendar':
          return await _listCalendar(args);
        case 'add_calendar_event':
          return await _addCalendarEvent(args);
        case 'create_estimate':
          return await _createEstimateForClient(args);
        case 'complete_calendar_event':
          return await _completeCalendarEvent(args);
        case 'delete_calendar_event':
          return await _deleteCalendarEvent(args);
        case 'list_accounts':
          return await _listAccounts();
        case 'record_payment':
          return await _recordPayment(args);
        case 'company_profile':
          return await _companyProfile();
        case 'update_company':
          return await _updateCompany(args);
        case 'list_session_files':
          return _listSessionFiles();
        case 'read_session_file':
          return _readSessionFile(args);
        case 'save_file_summary':
          return _saveFileSummary(args);
        case 'query_database':
          return await _queryDatabase(args);
        case 'sync_cloud':
          return await _syncCloud();
        default:
          return await catalogTools.execute(name, argumentsJson);
      }
    } catch (error) {
      return jsonEncode({'error': error.toString()});
    }
  }

  Future<void> _changed() async {
    await actions?.onEstimatesChanged?.call();
    await actions?.onAppDataChanged?.call();
  }

  Future<String> _searchApp(Map<String, dynamic> args) async {
    final query = args['query']?.toString().trim() ?? '';
    if (query.isEmpty) return jsonEncode({'error': 'Provide a search query'});
    final limit = (args['limit'] as num?)?.toInt() ?? 8;
    final needle = query.toLowerCase();

    final clients = [
      for (final client in await _clients.list())
        if (_matches(needle, [client.name, client.phone, client.project, client.company, client.email]))
          _clientSummary(client),
    ].take(limit).toList();

    final estimates = [
      for (final draft in await _drafts.list())
        if (_matches(needle, [draft.client, draft.project, draft.id]))
          {
            'id': draft.id,
            'client': draft.client,
            'project': draft.project,
            'status': draft.status.name,
            'grandTotal': draft.totals.grandTotal,
          },
    ].take(limit).toList();

    await ScheduleService.instance.store.load();
    final events = [
      for (final event in ScheduleService.instance.store.events)
        if (_matches(needle, [event.title, event.client, event.project, event.notes]))
          _eventSummary(event),
    ].take(limit).toList();

    final scopes = CatalogRepository.instance.searchScopes(
      catalogTools.catalog,
      query: query,
      limit: limit,
    );

    return jsonEncode({
      'query': query,
      'clients': clients,
      'estimates': estimates,
      'events': events,
      'scopes': [
        for (final scope in scopes)
          {
            'id': scope.id,
            'workType': scope.workType,
            'name': scope.name,
            'unit': scope.unit,
            'suggestedRate': scope.suggestedRate,
          },
      ],
    });
  }

  Future<String> _listClients() async {
    final clients = await _clients.list();
    return jsonEncode({
      'count': clients.length,
      'clients': [for (final client in clients.take(40)) _clientSummary(client)],
    });
  }

  Future<String> _getClient(Map<String, dynamic> args) async {
    final client = await _findClient(
      id: args['id']?.toString(),
      name: args['name']?.toString(),
      phone: args['phone']?.toString(),
    );
    if (client == null) return jsonEncode({'error': 'Client not found'});
    return jsonEncode({'ok': true, 'client': client.toJson()});
  }

  Future<String> _saveClient(Map<String, dynamic> args) async {
    var client = await _findClient(id: args['id']?.toString(), name: args['name']?.toString());
    final created = client == null;
    client ??= ClientRecord(name: args['name']?.toString().trim() ?? '');
    if (client.name.trim().isEmpty && (args['name']?.toString().trim().isEmpty ?? true)) {
      return jsonEncode({
        'error': 'Ask the user for the client name before saving',
        'need': 'name',
      });
    }
    if (args['name'] != null) client.name = args['name'].toString().trim();
    if (args['phone'] != null) client.phone = args['phone'].toString().trim();
    if (args['email'] != null) client.email = args['email'].toString().trim();
    if (args['company'] != null) client.company = args['company'].toString().trim();
    if (args['project'] != null) client.project = args['project'].toString().trim();
    if (args['address'] != null) client.address = args['address'].toString().trim();
    if (args['source'] != null) client.source = args['source'].toString().trim();
    if (args['notes'] != null) client.notes = args['notes'].toString();
    if (args['stage'] != null) client.stage = CrmStage.fromName(args['stage'].toString());
    if (client.name.trim().isEmpty) {
      return jsonEncode({
        'error': 'Ask the user for the client name before saving',
        'need': 'name',
      });
    }
    await _clients.save(client);
    await _changed();
    return jsonEncode({
      'ok': true,
      'created': created,
      'client': _clientSummary(client),
    });
  }

  Future<String> _deleteClient(Map<String, dynamic> args) async {
    final client = await _findClient(id: args['id']?.toString(), name: args['name']?.toString());
    if (client == null) return jsonEncode({'error': 'Client not found'});
    await _clients.delete(client.id);
    await _changed();
    return jsonEncode({'ok': true, 'deleted': client.id, 'name': client.name});
  }

  Future<String> _createEstimateForClient(Map<String, dynamic> args) async {
    final name = args['client']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return jsonEncode({
        'error': 'Ask the user which client this estimate is for',
        'need': 'client',
      });
    }
    final found = await _findClient(name: name);
    if (found != null) {
      args['client'] = found.name;
      if ((args['project']?.toString().trim().isEmpty ?? true) && found.project.trim().isNotEmpty) {
        args['project'] = found.project;
      }
    }
    return catalogTools.execute('create_estimate', jsonEncode(args));
  }

  Future<String> _addClientFollowUp(Map<String, dynamic> args) async {
    final client = await _findClient(
      id: args['id']?.toString(),
      name: args['name']?.toString() ?? args['client']?.toString(),
    );
    if (client == null) {
      return jsonEncode({
        'error': 'Ask which client to remind, or add the client first',
        'need': 'client',
      });
    }
    final when = parseWhen(args['when']?.toString() ?? args['start']?.toString() ?? '');
    if (when == null) {
      return jsonEncode({
        'error': 'Ask when to follow up (tomorrow, in 3 days, next Friday, or a date)',
        'need': 'when',
      });
    }
    final kind = _followKind(args['kind']?.toString());
    final note = args['note']?.toString().trim() ?? args['notes']?.toString().trim() ?? '';
    final item = ClientFollowUp(nextFollow: when, kind: kind, note: note);
    client.followUps.insert(0, item);
    await _clients.save(client);
    await ScheduleService.instance.fromFollowUp(client, item);
    await _changed();
    return jsonEncode({
      'ok': true,
      'client': _clientSummary(client),
      'followUp': item.toJson(),
      'nextFollow': when.toIso8601String(),
    });
  }

  Future<String> _listCalendar(Map<String, dynamic> args) async {
    await ScheduleService.instance.store.load();
    final includeDone = args['includeDone'] == true;
    final limit = (args['limit'] as num?)?.toInt() ?? 20;
    final dayRaw = args['day']?.toString().trim() ?? '';
    List<CalendarEvent> events;
    if (dayRaw.isNotEmpty) {
      final day = DateTime.tryParse(dayRaw);
      if (day == null) return jsonEncode({'error': 'Could not parse day'});
      events = ScheduleService.instance.store.eventsOn(day);
    } else {
      events = [...ScheduleService.instance.store.events]..sort((a, b) => a.start.compareTo(b.start));
    }
    if (!includeDone) {
      events = [for (final event in events) if (!event.done) event];
    }
    return jsonEncode({
      'count': events.length,
      'events': [for (final event in events.take(limit)) _eventSummary(event)],
    });
  }

  Future<String> _addCalendarEvent(Map<String, dynamic> args) async {
    final kind = _calendarKind(args['kind']?.toString());
    final clientName = args['client']?.toString().trim() ?? '';
    if (kind == CalendarKind.followUp && clientName.isNotEmpty) {
      return _addClientFollowUp({
        ...args,
        'name': clientName,
        'when': args['when'] ?? args['start'],
        'note': args['notes'] ?? args['note'] ?? args['title'],
      });
    }
    final title = args['title']?.toString().trim() ?? '';
    final start = parseWhen(args['start']?.toString() ?? args['when']?.toString() ?? '');
    if (title.isEmpty) return jsonEncode({'error': 'Title is required'});
    if (start == null) {
      return jsonEncode({'error': 'Ask when (tomorrow, in 3 days, next Friday, or an ISO datetime)'});
    }
    final event = await ScheduleService.instance.saveEvent(
      CalendarEvent(
        kind: _calendarKind(args['kind']?.toString()),
        start: start,
        title: title,
        client: args['client']?.toString().trim() ?? '',
        project: args['project']?.toString().trim() ?? '',
        notes: args['notes']?.toString() ?? '',
        notify: args['notify'] != false,
      ),
    );
    await _changed();
    return jsonEncode({'ok': true, 'event': _eventSummary(event)});
  }

  Future<String> _completeCalendarEvent(Map<String, dynamic> args) async {
    await ScheduleService.instance.store.load();
    final id = args['id']?.toString().trim() ?? '';
    CalendarEvent? event;
    for (final item in ScheduleService.instance.store.events) {
      if (item.id == id) event = item;
    }
    if (event == null) return jsonEncode({'error': 'Event not found'});
    event.done = args['done'] != false;
    await ScheduleService.instance.saveEvent(event);
    await _changed();
    return jsonEncode({'ok': true, 'event': _eventSummary(event)});
  }

  Future<String> _deleteCalendarEvent(Map<String, dynamic> args) async {
    final id = args['id']?.toString().trim() ?? '';
    if (id.isEmpty) return jsonEncode({'error': 'Event id is required'});
    await ScheduleService.instance.deleteEvent(id);
    await _changed();
    return jsonEncode({'ok': true, 'deleted': id});
  }

  Future<String> _listAccounts() async {
    await ScheduleService.instance.store.load();
    final accounts = ScheduleService.instance.store.accounts();
    return jsonEncode({
      'count': accounts.length,
      'accounts': [
        for (final account in accounts)
          {
            'client': account.client,
            'project': account.project,
            'scheduled': account.scheduled,
            'received': account.received,
            'sent': account.sent,
            'outstanding': account.outstanding,
            'balance': account.balance,
          },
      ],
    });
  }

  Future<String> _recordPayment(Map<String, dynamic> args) async {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) {
      return jsonEncode({'error': 'Provide a positive amount'});
    }
    final flowRaw = args['flow']?.toString().trim().toLowerCase() ?? 'receive';
    final flow = flowRaw == MoneyFlow.send.name || flowRaw == 'paid' || flowRaw == 'vendor'
        ? MoneyFlow.send
        : MoneyFlow.receive;
    final entry = PaymentEntry(
      flow: flow,
      amount: amount,
      date: DateTime.now(),
      client: args['client']?.toString().trim() ?? '',
      project: args['project']?.toString().trim() ?? '',
      estimateId: args['estimateId']?.toString(),
      method: args['method']?.toString().trim().isNotEmpty == true
          ? args['method'].toString().trim()
          : 'UPI',
      party: args['party']?.toString().trim() ?? '',
      note: args['note']?.toString() ?? '',
    );
    await ScheduleService.instance.recordPayment(entry);
    await _changed();
    return jsonEncode({
      'ok': true,
      'id': entry.id,
      'flow': entry.flow.name,
      'amount': entry.amount,
      'client': entry.client,
      'project': entry.project,
    });
  }

  Future<String> _companyProfile() async {
    final prefs = await LocalCache.instance.loadPrefs();
    return jsonEncode({
      'brand': prefs.brand,
      'address': prefs.companyAddress,
      'phone': prefs.companyPhone,
      'gstPercent': prefs.gstPercent,
      'hvacGstPercent': prefs.hvacGstPercent,
    });
  }

  Future<String> _updateCompany(Map<String, dynamic> args) async {
    final prefs = await LocalCache.instance.updatePrefs((prefs) {
      if (args['brand'] != null) prefs.brand = args['brand'].toString().trim();
      if (args['address'] != null) prefs.companyAddress = args['address'].toString().trim();
      if (args['phone'] != null) prefs.companyPhone = args['phone'].toString().trim();
    });
    await _changed();
    return jsonEncode({
      'ok': true,
      'brand': prefs.brand,
      'address': prefs.companyAddress,
      'phone': prefs.companyPhone,
    });
  }

  Future<String> _queryDatabase(Map<String, dynamic> args) async {
    final settings = await SettingsStore().loadAppwrite();
    if (!settings.isConfigured) {
      return jsonEncode({
        'error': 'Appwrite is not configured on this device. Add endpoint, project, database, and API key in Settings.',
      });
    }
    final table = args['table']?.toString().trim() ?? '';
    final rows = await _appwrite.queryTable(
      settings,
      tableId: table,
      contains: args['contains']?.toString(),
      limit: (args['limit'] as num?)?.toInt() ?? 25,
    );
    return jsonEncode({'table': table, 'count': rows.length, 'rows': rows});
  }

  Future<String> _syncCloud() async {
    try {
      final result = await AppwriteAutoSync.instance.syncNow(silent: false);
      await _changed();
      if (result == null) {
        return jsonEncode({'error': 'Cloud sync is not available on this device'});
      }
      return jsonEncode({
        'ok': true,
        'clients': result.clients,
        'estimates': result.estimates,
        'catalogItems': result.catalogItems,
      });
    } catch (error) {
      return jsonEncode({'error': error.toString().replaceFirst('FormatException: ', '')});
    }
  }

  String _listSessionFiles() {
    final files = AgentSessionStore.instance.documents;
    return jsonEncode({
      'count': files.length,
      'files': [
        for (final file in files)
          {
            'id': file.id,
            'name': file.name,
            'kind': file.kind,
            'chars': file.text.length,
            'summary': file.summary,
          },
      ],
    });
  }

  String _readSessionFile(Map<String, dynamic> args) {
    final file = AgentSessionStore.instance.findDocument(
      id: args['id']?.toString(),
      name: args['name']?.toString(),
    );
    if (file == null) return jsonEncode({'error': 'No attached file matches'});
    return jsonEncode({
      'ok': true,
      'id': file.id,
      'name': file.name,
      'kind': file.kind,
      'summary': file.summary,
      'text': file.text,
    });
  }

  String _saveFileSummary(Map<String, dynamic> args) {
    final summary = args['summary']?.toString().trim() ?? '';
    if (summary.isEmpty) return jsonEncode({'error': 'summary is required'});
    final file = AgentSessionStore.instance.findDocument(
      id: args['id']?.toString(),
      name: args['name']?.toString(),
    );
    if (file == null) {
      final docs = AgentSessionStore.instance.documents;
      if (docs.isEmpty) return jsonEncode({'error': 'No attached files in this session'});
      AgentSessionStore.instance.saveSummary(docs.first.id, summary);
      return jsonEncode({'ok': true, 'id': docs.first.id, 'name': docs.first.name});
    }
    AgentSessionStore.instance.saveSummary(file.id, summary);
    return jsonEncode({'ok': true, 'id': file.id, 'name': file.name});
  }

  Future<ClientRecord?> _findClient({String? id, String? name, String? phone}) async {
    final clients = await _clients.list();
    final idNeedle = id?.trim() ?? '';
    if (idNeedle.isNotEmpty) {
      for (final client in clients) {
        if (client.id == idNeedle) return client;
      }
    }
    final nameNeedle = name?.trim().toLowerCase() ?? '';
    if (nameNeedle.isNotEmpty) {
      for (final client in clients) {
        if (client.name.trim().toLowerCase() == nameNeedle) return client;
      }
      for (final client in clients) {
        if (client.name.toLowerCase().contains(nameNeedle)) return client;
      }
    }
    final phoneNeedle = phone?.trim() ?? '';
    if (phoneNeedle.isNotEmpty) {
      for (final client in clients) {
        if (client.phone.replaceAll(RegExp(r'\D'), '') == phoneNeedle.replaceAll(RegExp(r'\D'), '')) {
          return client;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _clientSummary(ClientRecord client) => {
        'id': client.id,
        'name': client.name,
        'phone': client.phone,
        'email': client.email,
        'company': client.company,
        'project': client.project,
        'stage': client.stage.name,
        'followUps': client.followUps.length,
        'nextFollow': client.nextFollow?.toIso8601String(),
      };

  String _followKind(String? raw) {
    final needle = (raw ?? 'Call').trim().toLowerCase();
    const kinds = ['Call', 'WhatsApp', 'Visit', 'Email', 'Other'];
    for (final kind in kinds) {
      if (kind.toLowerCase() == needle) return kind;
    }
    if (needle.contains('whats')) return 'WhatsApp';
    if (needle.contains('visit') || needle.contains('site')) return 'Visit';
    if (needle.contains('mail')) return 'Email';
    return 'Call';
  }

  Map<String, dynamic> _eventSummary(CalendarEvent event) => {
        'id': event.id,
        'kind': event.kind.name,
        'start': event.start.toIso8601String(),
        'title': event.title,
        'client': event.client,
        'project': event.project,
        'done': event.done,
      };

  CalendarKind _calendarKind(String? raw) {
    final needle = (raw ?? 'meeting').trim().toLowerCase();
    for (final kind in CalendarKind.values) {
      if (kind.name.toLowerCase() == needle) return kind;
    }
    if (needle.contains('follow')) return CalendarKind.followUp;
    if (needle.contains('collect') || needle.contains('receive')) return CalendarKind.collect;
    if (needle.contains('pay') || needle.contains('vendor')) return CalendarKind.pay;
    return CalendarKind.meeting;
  }

  bool _matches(String needle, List<String> fields) {
    for (final field in fields) {
      if (field.toLowerCase().contains(needle)) return true;
    }
    return false;
  }
}
