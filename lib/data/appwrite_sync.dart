import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:http/http.dart' as http;

import '../models/client_record.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import 'catalog_repository.dart';
import 'github_sync.dart';
import 'local_cache.dart';

const appwriteDatabaseIdDefault = '6a86ad9300190bcdd0df';
const appwriteProjectIdDefault = '6a86a3d4001d87aa9809';
const appwriteClientsTableId = 'clients';
const appwriteEstimatesTableId = 'estimates';
const appwriteCompanyTableId = 'company';
const appwriteCatalogTableId = 'catalog';
const appwriteCompanyRowId = 'current';

class AppwriteCloudSettings {
  const AppwriteCloudSettings({
    this.endpoint = AppwriteCloudSettings.defaultEndpoint,
    this.projectId = appwriteProjectIdDefault,
    this.databaseId = appwriteDatabaseIdDefault,
    this.apiKey = '',
    this.lastSyncedAt,
  });

  static const defaultEndpoint = 'https://sgp.cloud.appwrite.io/v1';

  final String endpoint;
  final String projectId;
  final String databaseId;
  final String apiKey;
  final DateTime? lastSyncedAt;

  bool get isConfigured =>
      normalizeAppwriteEndpoint(endpoint).isNotEmpty &&
      projectId.trim().isNotEmpty &&
      databaseId.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;

  AppwriteCloudSettings copyWith({
    String? endpoint,
    String? projectId,
    String? databaseId,
    String? apiKey,
    DateTime? lastSyncedAt,
  }) {
    return AppwriteCloudSettings(
      endpoint: endpoint ?? this.endpoint,
      projectId: projectId ?? this.projectId,
      databaseId: databaseId ?? this.databaseId,
      apiKey: apiKey ?? this.apiKey,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

String normalizeAppwriteEndpoint(String raw) {
  var value = raw.trim();
  if (value.endsWith('/')) {
    value = value.replaceFirst(RegExp(r'/+$'), '');
  }
  return value;
}

String appwriteRowId(String id) {
  var value = id.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (value.isEmpty) {
    throw const FormatException('Record is missing an id');
  }
  if (RegExp(r'^[._-]').hasMatch(value)) {
    value = 'r$value';
  }
  if (value.length > 36) {
    value = value.substring(0, 36);
  }
  return value;
}

Map<String, dynamic> clientToAppwriteRow(ClientRecord client) {
  return {
    'name': _clip(client.name, 255),
    'phone': _clip(client.phone, 64),
    'email': _clip(client.email, 255),
    'project': _clip(client.project, 255),
    'stage': _clip(client.stage.name, 32),
    'updatedAt': client.updatedAt.toUtc().toIso8601String(),
    'payload': jsonEncode(client.toJson()),
  };
}

Map<String, dynamic> estimateToAppwriteRow(EstimateDraft draft) {
  return {
    'client': _clip(draft.client, 255),
    'project': _clip(draft.project, 255),
    'status': _clip(draft.status.name, 32),
    'updatedAt': draft.updatedAt.toUtc().toIso8601String(),
    'payload': jsonEncode(draft.toJson()),
  };
}

ClientRecord clientFromAppwriteRow(Map<String, dynamic> data, {String? rowId}) {
  final payload = _decodePayload(data['payload']);
  if (payload != null) {
    payload['id'] = clientIdFromJson(payload) ?? rowId ?? data[r'$id']?.toString();
    return ClientRecord.fromJson(payload);
  }
  return ClientRecord(
    id: rowId ?? data[r'$id']?.toString() ?? clientIdFromJson(data),
    name: data['name']?.toString() ?? '',
    phone: data['phone']?.toString() ?? '',
    email: data['email']?.toString() ?? '',
    project: data['project']?.toString() ?? '',
    stage: CrmStage.fromName(data['stage']?.toString()),
    updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
  );
}

EstimateDraft estimateFromAppwriteRow(Map<String, dynamic> data) {
  final payload = _decodePayload(data['payload']);
  if (payload != null) return EstimateDraft.fromJson(payload);
  return EstimateDraft(
    id: data['\$id']?.toString(),
    client: data['client']?.toString() ?? '',
    project: data['project']?.toString() ?? '',
    status: EstimateStatus.fromName(data['status']?.toString()),
    updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
  );
}

Map<String, dynamic>? _decodePayload(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is! String || raw.trim().isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  return Map<String, dynamic>.from(decoded);
}

String _clip(String value, int max) {
  if (value.length <= max) return value;
  return value.substring(0, max);
}

Map<String, dynamic> companyToAppwriteRow(AppPrefsCache prefs) {
  final updatedAt = (prefs.savedAt ?? DateTime.now()).toUtc();
  return {
    'brand': _clip(prefs.brand, 255),
    'phone': _clip(prefs.companyPhone, 64),
    'updatedAt': updatedAt.toIso8601String(),
    'payload': jsonEncode(prefs.toJson()),
  };
}

AppPrefsCache companyFromAppwriteRow(Map<String, dynamic> data) {
  final payload = _decodePayload(data['payload']);
  if (payload != null) return AppPrefsCache.fromJson(payload);
  return AppPrefsCache(
    brand: data['brand']?.toString() ?? defaultCompanyBrand,
    companyPhone: data['phone']?.toString() ?? '',
    savedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
  );
}

Map<String, dynamic> catalogItemToAppwriteRow({
  required String kind,
  required Map<String, dynamic> item,
  DateTime? updatedAt,
}) {
  final stamp = updatedAt ?? DateTime.tryParse(item['updatedAt']?.toString() ?? '') ?? DateTime.now();
  return {
    'kind': _clip(kind, 32),
    'name': _clip(item['name']?.toString() ?? '', 255),
    'updatedAt': stamp.toUtc().toIso8601String(),
    'payload': jsonEncode({...item, 'updatedAt': stamp.toIso8601String()}),
  };
}

Map<String, dynamic> mergeCatalogOverlays(Map<String, dynamic> local, Map<String, dynamic> remote) {
  return {
    'areas': mergeCatalogItems(local['areas'], remote['areas']),
    'workTypes': mergeCatalogItems(local['workTypes'], remote['workTypes']),
    'scopes': mergeCatalogItems(local['scopes'], remote['scopes']),
    'savedAt': DateTime.now().toIso8601String(),
  };
}

List<Map<String, dynamic>> mergeCatalogItems(dynamic local, dynamic remote) {
  DateTime stamp(Map<String, dynamic> item) {
    return DateTime.tryParse(item['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, Map<String, dynamic>> asMap(dynamic raw) {
    final items = <String, Map<String, dynamic>>{};
    if (raw is! List) return items;
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      items[id] = map;
    }
    return items;
  }

  final merged = asMap(remote);
  for (final entry in asMap(local).entries) {
    final existing = merged[entry.key];
    if (existing == null || !stamp(entry.value).isBefore(stamp(existing))) {
      merged[entry.key] = entry.value;
    }
  }
  return merged.values.toList();
}

AppPrefsCache mergeCompanyPrefs(AppPrefsCache local, AppPrefsCache remote) {
  final localAt = local.savedAt;
  final remoteAt = remote.savedAt;
  if (remoteAt == null) return local;
  if (localAt == null) return remote;
  return localAt.isBefore(remoteAt) ? remote : local;
}

class AppwriteSync {
  AppwriteSync({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<CloudSnapshot> pull(AppwriteCloudSettings settings) async {
    final tables = _tables(settings);
    final databaseId = settings.databaseId.trim();
    return CloudSnapshot(
      updatedAt: DateTime.now(),
      clients: [
        for (final row in await _listAll(tables, databaseId, appwriteClientsTableId))
          clientFromAppwriteRow(row.data, rowId: row.$id),
      ],
      estimates: [
        for (final row in await _listAll(tables, databaseId, appwriteEstimatesTableId))
          estimateFromAppwriteRow(row.data),
      ],
    );
  }

  /// Read rows from an Appwrite table for the in-app agent.
  ///
  /// [tableId] must be one of `clients`, `estimates`, `company`, or `catalog`.
  /// [contains] is an optional case-insensitive substring filter on the JSON.
  Future<List<Map<String, dynamic>>> queryTable(
    AppwriteCloudSettings settings, {
    required String tableId,
    String? contains,
    int limit = 25,
  }) async {
    const allowed = {
      appwriteClientsTableId,
      appwriteEstimatesTableId,
      appwriteCompanyTableId,
      appwriteCatalogTableId,
    };
    final id = tableId.trim().toLowerCase();
    if (!allowed.contains(id)) {
      throw FormatException(
        'Unknown table "$tableId". Use clients, estimates, company, or catalog.',
      );
    }
    final rows = await _listAll(_tables(settings), settings.databaseId.trim(), id);
    var maps = <Map<String, dynamic>>[
      for (final row in rows) {...Map<String, dynamic>.from(row.data), 'id': row.$id},
    ];
    final needle = contains?.trim().toLowerCase() ?? '';
    if (needle.isNotEmpty) {
      maps = [
        for (final row in maps)
          if (jsonEncode(row).toLowerCase().contains(needle)) row,
      ];
    }
    final cap = limit.clamp(1, 100);
    if (maps.length > cap) maps = maps.take(cap).toList();
    return maps;
  }

  Future<CloudSyncResult> sync({
    required AppwriteCloudSettings settings,
    required List<ClientRecord> localClients,
    required List<EstimateDraft> localEstimates,
    required Future<void> Function(CloudSnapshot snapshot) applyLocally,
    bool setupTables = false,
  }) async {
    if (setupTables) await ensureSchema(settings);
    final remote = await pull(settings);
    final merged = mergeCloudSnapshots(
      CloudSnapshot(clients: localClients, estimates: localEstimates),
      remote,
    );
    await _pushSnapshot(settings, merged);
    await applyLocally(merged);
    final catalogItems = await _syncCatalogAndCompany(settings, push: true);
    return CloudSyncResult(
      clients: merged.clients.length,
      estimates: merged.estimates.length,
      catalogItems: catalogItems,
    );
  }

  Future<CloudSyncResult> fetch({
    required AppwriteCloudSettings settings,
    required List<ClientRecord> localClients,
    required List<EstimateDraft> localEstimates,
    required Future<void> Function(CloudSnapshot snapshot) applyLocally,
    bool setupTables = false,
  }) async {
    if (setupTables) await ensureSchema(settings);
    final remote = await pull(settings);
    final merged = mergeCloudSnapshots(
      CloudSnapshot(clients: localClients, estimates: localEstimates),
      remote,
    );
    await applyLocally(merged);
    final catalogItems = await _syncCatalogAndCompany(settings, push: false);
    return CloudSyncResult(
      clients: merged.clients.length,
      estimates: merged.estimates.length,
      catalogItems: catalogItems,
    );
  }

  Future<void> upsertClient(AppwriteCloudSettings settings, ClientRecord client) {
    return _upsert(
      settings,
      tableId: appwriteClientsTableId,
      rowId: appwriteRowId(client.id),
      data: clientToAppwriteRow(client),
    );
  }

  Future<void> upsertEstimate(AppwriteCloudSettings settings, EstimateDraft draft) {
    return _upsert(
      settings,
      tableId: appwriteEstimatesTableId,
      rowId: appwriteRowId(draft.id),
      data: estimateToAppwriteRow(draft),
    );
  }

  Future<void> upsertCompany(AppwriteCloudSettings settings, AppPrefsCache prefs) {
    return _upsert(
      settings,
      tableId: appwriteCompanyTableId,
      rowId: appwriteCompanyRowId,
      data: companyToAppwriteRow(prefs),
    );
  }

  Future<void> upsertCatalogOverlay(AppwriteCloudSettings settings, Map<String, dynamic> overlay) async {
    final stamp = DateTime.tryParse(overlay['savedAt']?.toString() ?? '') ?? DateTime.now();
    Future<void> upsertKind(String kind, dynamic items) async {
      if (items is! List) return;
      for (final item in items) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await _upsert(
          settings,
          tableId: appwriteCatalogTableId,
          rowId: appwriteRowId('${kind[0]}_$id'),
          data: catalogItemToAppwriteRow(kind: kind, item: map, updatedAt: stamp),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }

    await upsertKind('area', overlay['areas']);
    await upsertKind('workType', overlay['workTypes']);
    await upsertKind('scope', overlay['scopes']);
  }

  Future<void> deleteClient(AppwriteCloudSettings settings, String id) {
    return _delete(settings, tableId: appwriteClientsTableId, rowId: appwriteRowId(id));
  }

  Future<void> deleteEstimate(AppwriteCloudSettings settings, String id) {
    return _delete(settings, tableId: appwriteEstimatesTableId, rowId: appwriteRowId(id));
  }

  Future<void> ensureSchema(AppwriteCloudSettings settings) async {
    _assertConfigured(settings);
    final databaseId = settings.databaseId.trim();
    final database = await _getJson(settings, '/tablesdb/$databaseId');
    if (database == null) {
      await _putJson(
        settings,
        'POST',
        '/tablesdb',
        {
          'databaseId': databaseId,
          'name': 'BiConcept',
          'enabled': true,
        },
        ignoreConflict: true,
        ignoreForbidden: true,
      );
    }
    await _ensureTable(
      settings,
      tableId: appwriteClientsTableId,
      name: 'Clients',
      columns: [
        _Column.varchar('name', 255),
        _Column.varchar('phone', 64),
        _Column.varchar('email', 255),
        _Column.varchar('project', 255),
        _Column.varchar('stage', 32),
        _Column.datetime('updatedAt'),
        _Column.mediumtext('payload'),
      ],
    );
    await _ensureTable(
      settings,
      tableId: appwriteEstimatesTableId,
      name: 'Estimates',
      columns: [
        _Column.varchar('client', 255),
        _Column.varchar('project', 255),
        _Column.varchar('status', 32),
        _Column.datetime('updatedAt'),
        _Column.mediumtext('payload'),
      ],
    );
    await _ensureTable(
      settings,
      tableId: appwriteCompanyTableId,
      name: 'Company',
      columns: [
        _Column.varchar('brand', 255),
        _Column.varchar('phone', 64),
        _Column.datetime('updatedAt'),
        _Column.mediumtext('payload'),
      ],
    );
    await _ensureTable(
      settings,
      tableId: appwriteCatalogTableId,
      name: 'Catalog',
      columns: [
        _Column.varchar('kind', 32),
        _Column.varchar('name', 255),
        _Column.datetime('updatedAt'),
        _Column.mediumtext('payload'),
      ],
    );
  }

  Client _client(AppwriteCloudSettings settings) {
    _assertConfigured(settings);
    return Client()
        .setEndpoint(normalizeAppwriteEndpoint(settings.endpoint))
        .setProject(settings.projectId.trim())
        .addHeader('X-Appwrite-Key', settings.apiKey.trim());
  }

  TablesDB _tables(AppwriteCloudSettings settings) => TablesDB(_client(settings));

  Future<void> _pushSnapshot(AppwriteCloudSettings settings, CloudSnapshot snapshot) async {
    for (final client in snapshot.clients) {
      await upsertClient(settings, client);
      await Future<void>.delayed(Duration.zero);
    }
    for (final draft in snapshot.estimates) {
      await upsertEstimate(settings, draft);
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<int> _syncCatalogAndCompany(AppwriteCloudSettings settings, {required bool push}) async {
    final localOverlay = await LocalCache.instance.loadCatalogOverlay();
    final localPrefs = await LocalCache.instance.loadPrefs();
    final remoteOverlay = await _pullCatalog(settings);
    final remotePrefs = await _pullCompany(settings);
    final mergedOverlay = mergeCatalogOverlays(localOverlay, remoteOverlay);
    final mergedPrefs = mergeCompanyPrefs(localPrefs, remotePrefs);
    if (push) {
      await upsertCatalogOverlay(settings, mergedOverlay);
      await upsertCompany(settings, mergedPrefs);
    }
    await LocalCache.instance.saveCatalogOverlay(mergedOverlay, syncToCloud: false);
    await LocalCache.instance.savePrefs(mergedPrefs, syncToCloud: false);
    await CatalogRepository.instance.reload();
    return mergeCatalogItems(mergedOverlay['areas'], const []).length +
        mergeCatalogItems(mergedOverlay['workTypes'], const []).length +
        mergeCatalogItems(mergedOverlay['scopes'], const []).length;
  }

  Future<Map<String, dynamic>> _pullCatalog(AppwriteCloudSettings settings) async {
    final overlay = <String, dynamic>{
      'areas': <Map<String, dynamic>>[],
      'workTypes': <Map<String, dynamic>>[],
      'scopes': <Map<String, dynamic>>[],
    };
    try {
      final rows = await _listAll(_tables(settings), settings.databaseId.trim(), appwriteCatalogTableId);
      for (final row in rows) {
        final kind = row.data['kind']?.toString() ?? '';
        final payload = _decodePayload(row.data['payload']);
        if (payload == null) continue;
        final bucket = switch (kind) {
          'area' => overlay['areas'],
          'workType' => overlay['workTypes'],
          'scope' => overlay['scopes'],
          _ => null,
        };
        if (bucket is List<Map<String, dynamic>>) bucket.add(payload);
      }
    } on FormatException {
      return overlay;
    }
    return overlay;
  }

  Future<AppPrefsCache> _pullCompany(AppwriteCloudSettings settings) async {
    try {
      final row = await _tables(settings).getRow(
        databaseId: settings.databaseId.trim(),
        tableId: appwriteCompanyTableId,
        rowId: appwriteCompanyRowId,
      );
      return companyFromAppwriteRow(row.data);
    } on AppwriteException catch (error) {
      if (error.code == 404) return AppPrefsCache();
      throw FormatException(_describe(error, 'Could not read Appwrite company defaults'));
    }
  }

  Future<void> _upsert(
    AppwriteCloudSettings settings, {
    required String tableId,
    required String rowId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _tables(settings).upsertRow(
        databaseId: settings.databaseId.trim(),
        tableId: tableId,
        rowId: rowId,
        data: data,
      );
    } on AppwriteException catch (error) {
      throw FormatException(_describe(error, 'Could not save to Appwrite'));
    }
  }

  Future<void> _delete(
    AppwriteCloudSettings settings, {
    required String tableId,
    required String rowId,
  }) async {
    try {
      await _tables(settings).deleteRow(
        databaseId: settings.databaseId.trim(),
        tableId: tableId,
        rowId: rowId,
      );
    } on AppwriteException catch (error) {
      if (error.code == 404) return;
      throw FormatException(_describe(error, 'Could not delete from Appwrite'));
    }
  }

  Future<List<models.Row>> _listAll(TablesDB tables, String databaseId, String tableId) async {
    final rows = <models.Row>[];
    String? cursor;
    try {
      while (true) {
        final page = await tables.listRows(
          databaseId: databaseId,
          tableId: tableId,
          queries: [
            Query.limit(100),
            if (cursor != null) Query.cursorAfter(cursor),
          ],
        );
        if (page.rows.isEmpty) break;
        rows.addAll(page.rows);
        if (page.rows.length < 100) break;
        cursor = page.rows.last.$id;
      }
    } on AppwriteException catch (error) {
      throw FormatException(_describe(error, 'Could not read Appwrite tables'));
    }
    return rows;
  }

  Future<void> _ensureTable(
    AppwriteCloudSettings settings, {
    required String tableId,
    required String name,
    required List<_Column> columns,
  }) async {
    final databaseId = settings.databaseId.trim();
    final existing = await _getJson(settings, '/tablesdb/$databaseId/tables/$tableId');
    if (existing == null) {
      await _putJson(
        settings,
        'POST',
        '/tablesdb/$databaseId/tables',
        {
          'tableId': tableId,
          'name': name,
          'enabled': true,
          'rowSecurity': false,
        },
        ignoreConflict: true,
        ignoreForbidden: true,
      );
    }
    for (final column in columns) {
      await _ensureColumn(settings, tableId: tableId, column: column);
    }
  }

  Future<void> _ensureColumn(
    AppwriteCloudSettings settings, {
    required String tableId,
    required _Column column,
  }) async {
    final databaseId = settings.databaseId.trim();
    final existing = await _getJson(
      settings,
      '/tablesdb/$databaseId/tables/$tableId/columns/${column.key}',
    );
    if (existing != null) return;

    final created = await _createColumn(settings, tableId: tableId, column: column);
    if (!created) return;
    await _waitForColumn(settings, tableId: tableId, key: column.key);
  }

  Future<bool> _createColumn(
    AppwriteCloudSettings settings, {
    required String tableId,
    required _Column column,
  }) async {
    final databaseId = settings.databaseId.trim();
    for (final type in column.types) {
      final body = Map<String, dynamic>.from(column.body);
      if (type == 'string' && body['size'] == null) {
        body['size'] = 16383;
      }
      if (type == 'mediumtext' || type == 'text') {
        body.remove('size');
      }
      final ok = await _putJson(
        settings,
        'POST',
        '/tablesdb/$databaseId/tables/$tableId/columns/$type',
        body,
        ignoreConflict: true,
        ignoreNotFound: true,
        ignoreForbidden: true,
      );
      if (ok) return true;
    }
    return false;
  }

  Future<void> _waitForColumn(
    AppwriteCloudSettings settings, {
    required String tableId,
    required String key,
  }) async {
    final databaseId = settings.databaseId.trim();
    for (var i = 0; i < 20; i++) {
      final column = await _getJson(
        settings,
        '/tablesdb/$databaseId/tables/$tableId/columns/$key',
      );
      final status = column?['status']?.toString();
      if (status == 'available' || status == 'failed') return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<bool> _putJson(
    AppwriteCloudSettings settings,
    String method,
    String path,
    Map<String, dynamic> body, {
    bool ignoreConflict = false,
    bool ignoreNotFound = false,
    bool ignoreForbidden = false,
  }) async {
    final request = http.Request(method, _uri(settings, path))
      ..headers.addAll(_headers(settings, json: true))
      ..body = jsonEncode(body);
    final response = await _http.send(request);
    final text = utf8.decode(await response.stream.toBytes());
    if (response.statusCode >= 200 && response.statusCode < 300) return true;
    if (ignoreConflict && response.statusCode == 409) return true;
    if (ignoreForbidden && response.statusCode == 403) return false;
    if (ignoreNotFound && response.statusCode == 404) return false;
    throw FormatException(_httpHint(response.statusCode, text, 'Could not set up Appwrite tables'));
  }

  Future<Map<String, dynamic>?> _getJson(AppwriteCloudSettings settings, String path) async {
    final response = await _http.get(_uri(settings, path), headers: _headers(settings));
    if (response.statusCode == 404 || response.statusCode == 403) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(_httpHint(response.statusCode, response.body, 'Could not read Appwrite schema'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Uri _uri(AppwriteCloudSettings settings, String path) {
    final endpoint = normalizeAppwriteEndpoint(settings.endpoint);
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$endpoint$suffix');
  }

  Map<String, String> _headers(AppwriteCloudSettings settings, {bool json = false}) => {
        'X-Appwrite-Project': settings.projectId.trim(),
        'X-Appwrite-Key': settings.apiKey.trim(),
        'X-Appwrite-Response-Format': '1.8.0',
        'accept': 'application/json',
        if (json) 'content-type': 'application/json',
      };

  void _assertConfigured(AppwriteCloudSettings settings) {
    if (!settings.isConfigured) {
      throw const FormatException('Cloud sync is not configured on this device');
    }
  }

  String _describe(AppwriteException error, String action) {
    return _httpHint(error.code ?? 0, error.message ?? error.toString(), action);
  }

  String _httpHint(int status, String body, String action) {
    final hint = switch (status) {
      401 => 'API key was rejected. Create a key with databases/tables read and write.',
      403 => 'Appwrite blocked this request. The API key needs tables/rows read and write. Table create can stay off because the database already exists.',
      404 => 'Database or table not found. Use database ID biconcept, or tap Sync now to create tables.',
      409 => 'A table or column already exists with that name.',
      _ => body.trim().isEmpty ? 'HTTP $status' : body.trim(),
    };
    return '$action: $hint';
  }
}

class _Column {
  const _Column({
    required this.key,
    required this.types,
    required this.body,
  });

  factory _Column.varchar(String key, int size) {
    return _Column(
      key: key,
      types: const ['varchar', 'string'],
      body: {
        'key': key,
        'size': size,
        'required': false,
      },
    );
  }

  factory _Column.datetime(String key) {
    return _Column(
      key: key,
      types: const ['datetime'],
      body: {
        'key': key,
        'required': false,
      },
    );
  }

  factory _Column.mediumtext(String key) {
    return _Column(
      key: key,
      types: const ['mediumtext', 'text', 'string'],
      body: {
        'key': key,
        'required': false,
      },
    );
  }

  final String key;
  final List<String> types;
  final Map<String, dynamic> body;
}
