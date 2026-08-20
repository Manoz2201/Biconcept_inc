import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'appwrite_backend.dart';
import 'appwrite_sync.dart';
import 'github_sync.dart';

class LlmSettings {
  const LlmSettings({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final String baseUrl;
  final String model;
  final String apiKey;

  bool get isConfigured => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;
}

class SettingsStore {
  SettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _baseUrlKey = 'llm_base_url';
  static const _modelKey = 'llm_model';
  static const _apiKeyKey = 'llm_api_key';
  static const _githubRepoKey = 'github_repo';
  static const _githubBranchKey = 'github_branch';
  static const _githubTokenKey = 'github_token';
  static const _githubSyncedAtKey = 'github_synced_at';
  static const _appwriteKeyKey = 'appwrite_api_key';
  static const _appwriteSyncedAtKey = 'appwrite_synced_at';

  static const defaultBaseUrl = 'https://api.deepseek.com/v1';
  static const defaultModel = 'deepseek-chat';

  final FlutterSecureStorage _storage;

  Future<LlmSettings> load() async {
    final baseUrl = await _storage.read(key: _baseUrlKey);
    final model = await _storage.read(key: _modelKey);
    final apiKey = await _storage.read(key: _apiKeyKey);
    return LlmSettings(
      baseUrl: (baseUrl == null || baseUrl.trim().isEmpty) ? defaultBaseUrl : baseUrl.trim(),
      model: (model == null || model.trim().isEmpty) ? defaultModel : model.trim(),
      apiKey: apiKey ?? '',
    );
  }

  Future<void> save(LlmSettings settings) async {
    await _storage.write(key: _baseUrlKey, value: settings.baseUrl.trim());
    await _storage.write(key: _modelKey, value: settings.model.trim());
    await _storage.write(key: _apiKeyKey, value: settings.apiKey.trim());
  }

  Future<GitHubCloudSettings> loadGitHub() async {
    final repo = await _storage.read(key: _githubRepoKey);
    final branch = await _storage.read(key: _githubBranchKey);
    final token = await _storage.read(key: _githubTokenKey);
    final synced = await _storage.read(key: _githubSyncedAtKey);
    return GitHubCloudSettings(
      repo: repo ?? '',
      branch: (branch == null || branch.trim().isEmpty) ? 'main' : branch.trim(),
      token: token ?? '',
      lastSyncedAt: DateTime.tryParse(synced ?? ''),
    );
  }

  Future<void> saveGitHub(GitHubCloudSettings settings) async {
    await _storage.write(key: _githubRepoKey, value: settings.repo.trim());
    await _storage.write(key: _githubBranchKey, value: settings.branch.trim().isEmpty ? 'main' : settings.branch.trim());
    await _storage.write(key: _githubTokenKey, value: settings.token.trim());
    if (settings.lastSyncedAt == null) {
      await _storage.delete(key: _githubSyncedAtKey);
    } else {
      await _storage.write(key: _githubSyncedAtKey, value: settings.lastSyncedAt!.toIso8601String());
    }
  }

  Future<AppwriteCloudSettings> loadAppwrite() async {
    final synced = await _storage.read(key: _appwriteSyncedAtKey);
    var apiKey = AppwriteBackend.compiledApiKey.trim();
    if (apiKey.isEmpty) {
      apiKey = (await _storage.read(key: _appwriteKeyKey))?.trim() ?? '';
    }
    if (apiKey.isEmpty) {
      apiKey = await _cliApiKeyFor(AppwriteBackend.endpoint);
      if (apiKey.isNotEmpty) {
        await _storage.write(key: _appwriteKeyKey, value: apiKey);
      }
    }
    return AppwriteBackend.settings(
      apiKey: apiKey,
      lastSyncedAt: DateTime.tryParse(synced ?? ''),
    );
  }

  Future<void> saveAppwrite(AppwriteCloudSettings settings) async {
    if (settings.apiKey.trim().isNotEmpty) {
      await _storage.write(key: _appwriteKeyKey, value: settings.apiKey.trim());
    }
    if (settings.lastSyncedAt == null) {
      await _storage.delete(key: _appwriteSyncedAtKey);
    } else {
      await _storage.write(key: _appwriteSyncedAtKey, value: settings.lastSyncedAt!.toIso8601String());
    }
  }

  Future<String> _cliApiKeyFor(String endpoint) async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return '';
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home == null || home.isEmpty) return '';
      final file = File('$home/.appwrite/prefs.json');
      if (!await file.exists()) return '';
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return '';
      final want = normalizeAppwriteEndpoint(endpoint);
      for (final value in decoded.values) {
        if (value is! Map) continue;
        final item = Map<String, dynamic>.from(value);
        if (normalizeAppwriteEndpoint(item['endpoint']?.toString() ?? '') != want) continue;
        final key = item['key']?.toString().trim() ?? '';
        if (key.isNotEmpty) return key;
      }
    } catch (_) {}
    return '';
  }
}
