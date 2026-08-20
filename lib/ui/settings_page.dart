import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cache_backup.dart';
import '../data/catalog_repository.dart';
import '../data/client_store.dart';
import '../data/draft_store.dart';
import '../data/github_sync.dart';
import '../data/local_cache.dart';
import '../data/settings_store.dart';
import '../models/company_profile.dart';
import '../theme/app_theme.dart';
import '../util/backup_io.dart';
import '../util/format.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.embedded = false, this.onAppDataChanged});

  final bool embedded;
  final Future<void> Function()? onAppDataChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _store = SettingsStore();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  final _brand = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _gst = TextEditingController();
  final _hvacGst = TextEditingController();
  final _githubRepo = TextEditingController();
  final _githubBranch = TextEditingController(text: 'main');
  final _githubToken = TextEditingController();
  bool _loading = true;
  bool _obscure = true;
  bool _obscureGithub = true;
  bool _githubBusy = false;
  DateTime? _githubSyncedAt;
  String _cachePath = '';
  DateTime? _cacheSavedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _store.load();
    final prefs = await LocalCache.instance.loadPrefs();
    await CatalogRepository.instance.load();
    if (!mounted) return;
    _baseUrl.text = settings.baseUrl;
    _model.text = settings.model;
    _apiKey.text = settings.apiKey;
    _brand.text = prefs.brand;
    _address.text = prefs.companyAddress;
    _phone.text = prefs.companyPhone;
    _gst.text = prefs.gstPercent.toStringAsFixed(0);
    _hvacGst.text = prefs.hvacGstPercent.toStringAsFixed(0);
    _cachePath = CatalogRepository.instance.lastCachePath ?? await LocalCache.instance.catalogPath();
    _cacheSavedAt = CatalogRepository.instance.lastCatalogSave ?? prefs.savedAt;
    final github = await _store.loadGitHub();
    if (!mounted) return;
    _githubRepo.text = github.repo;
    _githubBranch.text = github.branch;
    _githubToken.text = github.token;
    _githubSyncedAt = github.lastSyncedAt;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _brand.dispose();
    _address.dispose();
    _phone.dispose();
    _gst.dispose();
    _hvacGst.dispose();
    _githubRepo.dispose();
    _githubBranch.dispose();
    _githubToken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListenableBuilder(
            listenable: CatalogRepository.instance,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
              children: [
                _sectionTitle('Local catalog cache'),
                const Text(
                  'New areas, work types and scopes are saved on this PC. They stay available in New estimate and Rate card after restart.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                _cacheSummary(),
                const SizedBox(height: 16),
                _cachedLists(),
                const SizedBox(height: 28),
                _sectionTitle('Backup & restore'),
                const SizedBox(height: 8),
                const Text(
                  'Save LocalCache (company defaults, recent jobs, and custom catalog) as a CSV file, or restore it on this device.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _backupCache,
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('Backup'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _restoreBackup,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Restore Backup'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _sectionTitle('GitHub sync'),
                const SizedBox(height: 8),
                const Text(
                  'Store clients and estimates in a private GitHub repo so another PC or phone can fetch the same jobs. Use a fine-grained token with Contents read and write. Do not use a public repo.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _githubRepo,
                  decoration: const InputDecoration(
                    labelText: 'Repository',
                    hintText: 'owner/repo or https://github.com/owner/repo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _githubBranch,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    hintText: 'main',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _githubToken,
                  obscureText: _obscureGithub,
                  decoration: InputDecoration(
                    labelText: 'Personal access token',
                    hintText: 'github_pat_…',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureGithub = !_obscureGithub),
                      icon: Icon(_obscureGithub ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _githubSyncedAt == null
                      ? 'Not synced yet'
                      : 'Last synced ${_stamp(_githubSyncedAt!)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _githubBusy ? null : _saveGitHubSettings,
                      child: const Text('Save GitHub settings'),
                    ),
                    FilledButton.icon(
                      onPressed: _githubBusy ? null : () => _runGitHubSync(push: true),
                      icon: _githubBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_outlined),
                      label: const Text('Sync now'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _githubBusy ? null : () => _runGitHubSync(push: false),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Fetch from GitHub'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _sectionTitle('Company defaults'),
                const SizedBox(height: 12),
                TextField(
                  controller: _brand,
                  decoration: const InputDecoration(
                    labelText: 'Brand on quotations',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Company address',
                    hintText: 'Shown under the logo on quotation headings',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact no.',
                    hintText: '+91 8178869148',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gst,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'GST %',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hvacGst,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'HVAC GST %',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saveCompany,
                  child: const Text('Save company defaults'),
                ),
                const SizedBox(height: 28),
                _sectionTitle('DeepSeek agent'),
                const SizedBox(height: 8),
                const Text(
                  'Paste your DeepSeek API key. The agent can search the rate card, list and edit quotations, add scopes, and save estimates.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _baseUrl.text = SettingsStore.defaultBaseUrl;
                        _model.text = SettingsStore.defaultModel;
                      });
                    },
                    child: const Text('Use DeepSeek defaults'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.deepseek.com/v1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'deepseek-chat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'DeepSeek API key',
                    hintText: 'sk-…',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await _store.save(
                      LlmSettings(
                        baseUrl: _baseUrl.text,
                        model: _model.text,
                        apiKey: _apiKey.text,
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('DeepSeek API settings saved on this machine')),
                    );
                  },
                  child: const Text('Save API settings'),
                ),
              ],
            ),
          );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: body,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }

  Widget _cacheSummary() {
    final repo = CatalogRepository.instance;
    final saved = _cacheSavedAt ?? repo.lastCatalogSave;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${repo.cachedAreaCount} areas  ·  ${repo.cachedWorkTypeCount} work types  ·  ${repo.cachedScopeCount} scopes',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            saved == null
                ? 'No custom catalog saved yet. Add from Rate card or New estimate.'
                : 'Last saved ${_stamp(saved)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (_cachePath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_cachePath, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _cachedLists() {
    final repo = CatalogRepository.instance;
    if (repo.cachedAreaCount == 0 && repo.cachedWorkTypeCount == 0 && repo.cachedScopeCount == 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (repo.cachedAreas.isNotEmpty) ...[
          const Text('Cached areas', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final area in repo.cachedAreas)
                Chip(label: Text(area.name), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (repo.cachedWorkTypes.isNotEmpty) ...[
          const Text('Cached work types', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in repo.cachedWorkTypes)
                Chip(
                  label: Text('${type.serialNo}. ${type.name} (${type.scopeCount})'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (repo.cachedScopes.isNotEmpty) ...[
          const Text('Cached scopes', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scope in repo.cachedScopes)
                Chip(
                  label: Text('${scope.workType}: ${scope.name}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _stamp(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  Future<void> _saveCompany() async {
    await LocalCache.instance.updatePrefs((prefs) {
      prefs.brand = _brand.text.trim().isEmpty ? defaultCompanyBrand : _brand.text.trim();
      prefs.companyAddress = _address.text.trim().isEmpty ? defaultCompanyAddress : _address.text.trim();
      prefs.companyPhone = _phone.text.trim().isEmpty ? defaultCompanyPhone : _phone.text.trim();
      prefs.gstPercent = parseNumber(_gst.text) ?? 18;
      prefs.hvacGstPercent = parseNumber(_hvacGst.text) ?? 28;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Company defaults saved on this PC')),
    );
  }

  Future<void> _backupCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup LocalCache'),
        content: const Text(
          'Save company defaults, recent jobs and custom catalog as a CSV file on this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save CSV')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final data = await loadCacheBackup();
      final csv = encodeCacheBackupCsv(prefs: data.prefs, overlay: data.overlay);
      final path = await saveBackupCsv(csv: csv, fileName: suggestedBackupFileName());
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup cancelled')),
        );
        return;
      }
      await _showBackupLocation(path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $error')),
      );
    }
  }

  Future<void> _showBackupLocation(String path) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup saved'),
        content: SelectableText('Saved to:\n$path'),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location copied')),
                );
              }
            },
            child: const Text('Copy location'),
          ),
          TextButton(
            onPressed: () => revealBackupLocation(path),
            child: const Text('Open'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final path = await pickBackupCsv();
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore cancelled')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore LocalCache'),
        content: Text(
          'Replace company defaults, recent jobs and custom catalog on this device with:\n$path',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final csv = await File(path).readAsString();
      final data = decodeCacheBackupCsv(csv);
      await restoreCacheBackup(data);
      await CatalogRepository.instance.reload();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LocalCache restored from backup CSV')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $error')),
      );
    }
  }

  GitHubCloudSettings _githubFromFields() {
    return GitHubCloudSettings(
      repo: _githubRepo.text,
      branch: _githubBranch.text.trim().isEmpty ? 'main' : _githubBranch.text.trim(),
      token: _githubToken.text,
      lastSyncedAt: _githubSyncedAt,
    );
  }

  Future<void> _saveGitHubSettings() async {
    await _store.saveGitHub(_githubFromFields());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GitHub settings saved on this device')),
    );
  }

  Future<void> _runGitHubSync({required bool push}) async {
    final settings = _githubFromFields();
    if (!settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save a private repo (owner/name) and a GitHub token first')),
      );
      return;
    }
    setState(() => _githubBusy = true);
    try {
      await _store.saveGitHub(settings);
      final result = push
          ? await GitHubSync().sync(
              settings: settings,
              localClients: await ClientStore().list(),
              localEstimates: await DraftStore().list(),
              applyLocally: writeCloudSnapshotLocally,
            )
          : await GitHubSync().fetch(
              settings: settings,
              localClients: await ClientStore().list(),
              localEstimates: await DraftStore().list(),
              applyLocally: writeCloudSnapshotLocally,
            );
      final synced = DateTime.now();
      await _store.saveGitHub(settings.copyWith(lastSyncedAt: synced));
      await widget.onAppDataChanged?.call();
      if (!mounted) return;
      setState(() => _githubSyncedAt = synced);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            push
                ? 'Synced ${result.clients} clients and ${result.estimates} estimates to GitHub'
                : 'Fetched ${result.clients} clients and ${result.estimates} estimates from GitHub',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('FormatException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _githubBusy = false);
    }
  }
}
