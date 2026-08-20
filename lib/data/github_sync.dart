import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/client_record.dart';
import '../models/estimate_document.dart';
import 'client_store.dart';
import 'draft_store.dart';

const githubSyncFormat = 'biconcept-clients-estimates-v1';
const githubSyncPath = 'biconcept/clients-estimates.json';

class GitHubRepoRef {
  const GitHubRepoRef({required this.owner, required this.name});

  final String owner;
  final String name;

  String get slug => '$owner/$name';
}

class GitHubCloudSettings {
  const GitHubCloudSettings({
    this.repo = '',
    this.branch = 'main',
    this.token = '',
    this.lastSyncedAt,
  });

  final String repo;
  final String branch;
  final String token;
  final DateTime? lastSyncedAt;

  bool get isConfigured => parseGitHubRepo(repo) != null && token.trim().isNotEmpty;

  GitHubCloudSettings copyWith({
    String? repo,
    String? branch,
    String? token,
    DateTime? lastSyncedAt,
  }) {
    return GitHubCloudSettings(
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      token: token ?? this.token,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class CloudSnapshot {
  const CloudSnapshot({
    required this.clients,
    required this.estimates,
    this.updatedAt,
  });

  final List<ClientRecord> clients;
  final List<EstimateDraft> estimates;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'format': githubSyncFormat,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        'clients': [for (final client in clients) client.toJson()],
        'estimates': [for (final draft in estimates) draft.toJson()],
      };

  factory CloudSnapshot.fromJson(Map<String, dynamic> json) {
    return CloudSnapshot(
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      clients: [
        for (final item in json['clients'] as List? ?? const [])
          if (item is Map) ClientRecord.fromJson(Map<String, dynamic>.from(item)),
      ],
      estimates: [
        for (final item in json['estimates'] as List? ?? const [])
          if (item is Map) EstimateDraft.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class CloudSyncResult {
  const CloudSyncResult({
    required this.clients,
    required this.estimates,
    this.catalogItems = 0,
  });

  final int clients;
  final int estimates;
  final int catalogItems;
}

GitHubRepoRef? parseGitHubRepo(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;
  value = value.replaceFirst(RegExp(r'^https?://github\.com/', caseSensitive: false), '');
  value = value.replaceFirst(RegExp(r'^git@github\.com:'), '');
  value = value.replaceAll(RegExp(r'\.git$'), '');
  value = value.replaceAll(RegExp(r'/+$'), '');
  final parts = value.split('/').where((part) => part.trim().isNotEmpty).toList();
  if (parts.length < 2) return null;
  final owner = parts[0].trim();
  final name = parts[1].trim();
  if (owner.isEmpty || name.isEmpty) return null;
  return GitHubRepoRef(owner: owner, name: name);
}

CloudSnapshot mergeCloudSnapshots(CloudSnapshot local, CloudSnapshot remote) {
  return CloudSnapshot(
    updatedAt: DateTime.now(),
    clients: _mergeById(
      local.clients,
      remote.clients,
      idOf: (item) => item.id,
      newer: (a, b) => !a.updatedAt.isBefore(b.updatedAt),
    ),
    estimates: _mergeById(
      local.estimates,
      remote.estimates,
      idOf: (item) => item.id,
      newer: (a, b) => !a.updatedAt.isBefore(b.updatedAt),
    ),
  );
}

List<T> _mergeById<T>(
  List<T> local,
  List<T> remote, {
  required String Function(T item) idOf,
  required bool Function(T localItem, T remoteItem) newer,
}) {
  final merged = <String, T>{
    for (final item in remote) idOf(item): item,
  };
  for (final item in local) {
    final id = idOf(item);
    final existing = merged[id];
    if (existing == null || newer(item, existing)) {
      merged[id] = item;
    }
  }
  return merged.values.toList();
}

class GitHubSync {
  GitHubSync({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<CloudSnapshot> pull(GitHubCloudSettings settings) async {
    final file = await _getFile(settings);
    if (file == null) {
      return const CloudSnapshot(clients: [], estimates: []);
    }
    return _decodeSnapshot(file.content);
  }

  Future<CloudSyncResult> sync({
    required GitHubCloudSettings settings,
    required List<ClientRecord> localClients,
    required List<EstimateDraft> localEstimates,
    required Future<void> Function(CloudSnapshot snapshot) applyLocally,
  }) async {
    final file = await _getFile(settings);
    final remote = file == null
        ? const CloudSnapshot(clients: [], estimates: [])
        : _decodeSnapshot(file.content);
    final merged = mergeCloudSnapshots(
      CloudSnapshot(clients: localClients, estimates: localEstimates),
      remote,
    );
    await _putFile(
      settings,
      content: const JsonEncoder.withIndent('  ').convert(merged.toJson()),
      sha: file?.sha,
      message: 'Sync BiConcept clients and estimates',
    );
    await applyLocally(merged);
    return CloudSyncResult(clients: merged.clients.length, estimates: merged.estimates.length);
  }

  Future<CloudSyncResult> fetch({
    required GitHubCloudSettings settings,
    required List<ClientRecord> localClients,
    required List<EstimateDraft> localEstimates,
    required Future<void> Function(CloudSnapshot snapshot) applyLocally,
  }) async {
    final remote = await pull(settings);
    final merged = mergeCloudSnapshots(
      CloudSnapshot(clients: localClients, estimates: localEstimates),
      remote,
    );
    await applyLocally(merged);
    return CloudSyncResult(clients: merged.clients.length, estimates: merged.estimates.length);
  }

  CloudSnapshot _decodeSnapshot(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('GitHub file is not a BiConcept sync JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    final format = map['format']?.toString();
    if (format != null && format.isNotEmpty && format != githubSyncFormat) {
      throw FormatException('Unsupported GitHub sync format: $format');
    }
    return CloudSnapshot.fromJson(map);
  }

  Future<_GitHubFile?> _getFile(GitHubCloudSettings settings) async {
    final repo = parseGitHubRepo(settings.repo);
    if (repo == null) throw const FormatException('Enter the GitHub repo as owner/name');
    if (settings.token.trim().isEmpty) throw const FormatException('Paste a GitHub personal access token');
    final branch = settings.branch.trim().isEmpty ? 'main' : settings.branch.trim();
    final uri = Uri.https(
      'api.github.com',
      '/repos/${repo.owner}/${repo.name}/contents/$githubSyncPath',
      {'ref': branch},
    );
    final response = await _http.get(uri, headers: _headers(settings.token));
    if (response.statusCode == 404) return null;
    _throwIfFailed(response, 'Could not read GitHub file');
    final body = jsonDecode(response.body);
    if (body is! Map) throw const FormatException('Unexpected GitHub response');
    final map = Map<String, dynamic>.from(body);
    final encoded = map['content']?.toString() ?? '';
    final sha = map['sha']?.toString() ?? '';
    final bytes = base64.decode(encoded.replaceAll(RegExp(r'\s'), ''));
    return _GitHubFile(sha: sha, content: utf8.decode(bytes));
  }

  Future<void> _putFile(
    GitHubCloudSettings settings, {
    required String content,
    required String message,
    String? sha,
  }) async {
    final repo = parseGitHubRepo(settings.repo);
    if (repo == null) throw const FormatException('Enter the GitHub repo as owner/name');
    final branch = settings.branch.trim().isEmpty ? 'main' : settings.branch.trim();
    final uri = Uri.https(
      'api.github.com',
      '/repos/${repo.owner}/${repo.name}/contents/$githubSyncPath',
    );
    final payload = <String, dynamic>{
      'message': message,
      'content': base64.encode(utf8.encode(content)),
      'branch': branch,
      if (sha != null && sha.isNotEmpty) 'sha': sha,
    };
    final response = await _http.put(
      uri,
      headers: _headers(settings.token),
      body: jsonEncode(payload),
    );
    _throwIfFailed(response, 'Could not save to GitHub');
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'biconcept-app',
      };

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final hint = switch (response.statusCode) {
      401 => 'Token was rejected. Create a fine-grained token with Contents read/write on that private repo.',
      403 => 'GitHub blocked this request. Check token permissions and rate limits.',
      404 => 'Repo not found. Use a private repo the token can access, as owner/name.',
      _ => response.body.trim().isEmpty ? 'HTTP ${response.statusCode}' : response.body.trim(),
    };
    throw FormatException('$action: $hint');
  }
}

class _GitHubFile {
  const _GitHubFile({required this.sha, required this.content});

  final String sha;
  final String content;
}

Future<void> writeCloudSnapshotLocally(CloudSnapshot snapshot) async {
  final clients = ClientStore();
  final drafts = DraftStore();
  for (final client in snapshot.clients) {
    await clients.save(client, touch: false, syncToCloud: false);
  }
  for (final draft in snapshot.estimates) {
    await drafts.save(draft, syncToCloud: false);
  }
}
