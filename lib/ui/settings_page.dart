import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_update_service.dart';
import '../data/app_version.dart';
import '../data/appwrite_auto_sync.dart';
import '../data/cache_backup.dart';
import '../data/catalog_repository.dart';
import '../data/local_cache.dart';
import '../data/settings_store.dart';
import '../models/company_profile.dart';
import '../theme/app_theme.dart';
import '../util/backup_io.dart';
import '../util/format.dart';
import '../util/open_export.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.embedded = false, this.onAppDataChanged});

  final bool embedded;
  final Future<void> Function()? onAppDataChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _store = SettingsStore();
  final _updates = AppUpdateService();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  final _cfAccount = TextEditingController();
  final _cfToken = TextEditingController();
  final _ghToken = TextEditingController();
  final _brand = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _gst = TextEditingController();
  final _hvacGst = TextEditingController();
  bool _loading = true;
  bool _obscure = true;
  bool _syncBusy = false;
  bool _customModel = false;
  DateTime? _lastSyncedAt;
  String _cachePath = '';
  DateTime? _cacheSavedAt;
  AppBuildInfo _buildInfo = const AppBuildInfo(appName: 'BiConcept', version: '…', buildNumber: 0);
  AppRelease? _latest;
  String? _updateError;
  bool _updateChecking = false;
  bool _updateBusy = false;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    AppwriteAutoSync.instance.addListener(_onAutoSync);
    _load();
  }

  void _onAutoSync() {
    if (!mounted) return;
    setState(() {
      _syncBusy = AppwriteAutoSync.instance.busy;
      _lastSyncedAt = AppwriteAutoSync.instance.lastSyncedAt ?? _lastSyncedAt;
    });
  }

  Future<void> _load() async {
    final settings = await _store.load();
    final prefs = await LocalCache.instance.loadPrefs();
    await CatalogRepository.instance.load();
    if (!mounted) return;
    _baseUrl.text = settings.baseUrl;
    _model.text = settings.model;
    _customModel = settings.model.trim().isNotEmpty && settings.model.trim() != SettingsStore.defaultModel;
    _apiKey.text = settings.apiKey;
    final cloudflare = await _store.loadCloudflare();
    _cfAccount.text = cloudflare.accountId;
    _cfToken.text = cloudflare.apiToken;
    final github = await _store.loadGitHub();
    _ghToken.text = github.token;
    _brand.text = prefs.brand;
    _address.text = prefs.companyAddress;
    _phone.text = prefs.companyPhone;
    _gst.text = prefs.gstPercent.toStringAsFixed(0);
    _hvacGst.text = prefs.hvacGstPercent.toStringAsFixed(0);
    _cachePath = CatalogRepository.instance.lastCachePath ?? await LocalCache.instance.catalogPath();
    _cacheSavedAt = CatalogRepository.instance.lastCatalogSave ?? prefs.savedAt;
    _lastSyncedAt = AppwriteAutoSync.instance.lastSyncedAt ?? (await _store.loadAppwrite()).lastSyncedAt;
    final buildInfo = await AppBuildInfo.load();
    if (!mounted) return;
    setState(() {
      _buildInfo = buildInfo;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _cfAccount.dispose();
    _cfToken.dispose();
    _ghToken.dispose();
    _brand.dispose();
    _address.dispose();
    _phone.dispose();
    _gst.dispose();
    _hvacGst.dispose();
    _updates.close();
    AppwriteAutoSync.instance.removeListener(_onAutoSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final pad = compact ? 16.0 : 28.0;
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : ListenableBuilder(
            listenable: CatalogRepository.instance,
            builder: (context, _) => ListView(
              padding: EdgeInsets.fromLTRB(pad, compact ? 4 : 8, pad, compact ? AppBreakpoints.navClearance : 32),
              children: [
                _hero(compact: compact),
                const SizedBox(height: 24),
                _versionCard(),
                const SizedBox(height: 16),
                if (compact) ...[
                  _cacheCard(),
                  const SizedBox(height: 16),
                  _backupCard(),
                  const SizedBox(height: 16),
                  _agentCard(compact: compact),
                  const SizedBox(height: 16),
                  _companyCard(compact: compact),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _cacheCard(),
                            const SizedBox(height: 16),
                            _backupCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            _agentCard(compact: compact),
                            const SizedBox(height: 16),
                            _companyCard(compact: compact),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: body,
    );
  }

  Widget _hero({required bool compact}) {
    final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'configuration',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 32 : 48,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Manage local caching, data redundancy, organizational defaults, and agent parameters. Ensure secure storage for API keys.',
                  style: TextStyle(color: AppColors.muted, fontSize: compact ? 14 : 16, height: 1.4),
                ),
              ),
            ],
          );
    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        if (compact) title else Expanded(child: title),
        if (compact) const SizedBox(height: 14) else const SizedBox(width: 16),
        _statusPill(),
      ],
    );
  }

  Widget _statusPill() {
    final busy = _syncBusy;
    final synced = _lastSyncedAt != null;
    final color = busy ? AppColors.primary : (synced ? AppColors.completed : AppColors.muted);
    final label = busy ? 'SYNCING' : (synced ? 'CLOUD SYNCED' : 'LOCAL ONLY');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(99),
        border: Border(left: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _versionCard() {
    final latest = _latest;
    final available = latest != null &&
        isRemoteNewer(
          currentVersion: _buildInfo.version,
          currentBuild: _buildInfo.buildNumber,
          remoteVersion: latest.version,
          remoteBuild: latest.build,
        );
    final busy = _updateChecking || _updateBusy;
    String status;
    Color statusColor;
    if (_updateBusy) {
      status = _downloadProgress == null || _downloadProgress! < 0
          ? 'Downloading'
          : 'Downloading ${((_downloadProgress ?? 0) * 100).round()}%';
      statusColor = AppColors.primary;
    } else if (_updateChecking) {
      status = 'Checking GitHub Releases';
      statusColor = AppColors.primary;
    } else if (_updateError != null) {
      status = 'Check failed';
      statusColor = AppColors.down;
    } else if (available) {
      status = 'Update ready';
      statusColor = AppColors.primary;
    } else if (latest != null) {
      status = 'Up to date';
      statusColor = AppColors.completed;
    } else {
      status = 'CI/CD';
      statusColor = AppColors.muted;
    }

    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.system_update_alt, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('UPDATES', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('app version', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Version', value: _buildInfo.version)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Build', value: '${_buildInfo.buildNumber}')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_buildInfo.channel} · ${_buildInfo.shortSha} · $defaultUpdateRepo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (available) ...[
            const SizedBox(height: 10),
            Text(
              'GitHub Release ${latest.display} is ready for this device.',
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
            if (latest.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                latest.notes.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
              ),
            ],
          ],
          if (_updateError != null) ...[
            const SizedBox(height: 10),
            Text(_updateError!, style: const TextStyle(color: AppColors.down, fontSize: 12, height: 1.35)),
          ],
          const SizedBox(height: 16),
          _LabeledField(
            label: 'GitHub token (private repo)',
            child: TextField(
              controller: _ghToken,
              obscureText: _obscure,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
              decoration: _fieldDecoration(
                hint: 'ghp_… Contents: Read',
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 6),
            child: Text(
              'Required while Manoz2201/Biconcept_inc is private. Token stays on this device.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          if (_downloadProgress != null) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: _downloadProgress! < 0 ? null : _downloadProgress,
              color: AppColors.primary,
              backgroundColor: AppColors.outline,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : (available ? _installUpdate : _checkForUpdate),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                    )
                  : Icon(available ? Icons.download : Icons.refresh, size: 18),
              label: Text(
                _updateBusy
                    ? 'Updating…'
                    : _updateChecking
                        ? 'Checking…'
                        : available
                            ? 'Update app'
                            : 'Check for update',
              ),
            ),
          ),
          if (latest != null && latest.htmlUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy ? null : () => openHttpUrl(latest.htmlUrl),
                child: const Text('Open GitHub Release'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _githubToken() async {
    final github = await _store.loadGitHub();
    final token = github.token.trim();
    return token.isEmpty ? null : token;
  }

  Future<void> _persistGithubToken() async {
    final current = await _store.loadGitHub();
    await _store.saveGitHub(
      current.copyWith(
        repo: current.repo.trim().isEmpty ? defaultUpdateRepo : current.repo,
        token: _ghToken.text.trim(),
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateError = null;
    });
    await _persistGithubToken();
    final result = await _updates.check(current: _buildInfo, token: await _githubToken());
    if (!mounted) return;
    setState(() {
      _updateChecking = false;
      _latest = result.latest;
      _updateError = result.error;
    });
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    if (!result.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are on ${_buildInfo.display}')),
      );
    }
  }

  Future<void> _installUpdate() async {
    final release = _latest;
    if (release == null) return;
    final asset = release.assetForPlatform();
    if (asset == null) {
      setState(() => _updateError = 'This release has no installer for ${Platform.operatingSystem}.');
      return;
    }
    if (Platform.isWindows) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restart to update'),
          content: Text(
            'BiConcept will download ${release.display}, close, replace this install, and reopen.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update app')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() {
      _updateBusy = true;
      _updateError = null;
      _downloadProgress = -1;
    });
    try {
      final file = await _updates.download(
        release: release,
        token: await _githubToken(),
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _downloadProgress = value);
        },
      );
      if (Platform.isAndroid) {
        try {
          await installAndroidApk(file.path);
        } on PlatformException catch (error) {
          if (error.code == 'need_install_permission') {
            throw FormatException(error.message ?? 'Allow BiConcept to install updates, then tap Update app again.');
          }
          rethrow;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Android asked to install the new APK')),
        );
      } else if (Platform.isWindows) {
        final extracted = await _updates.extractWindowsZip(file);
        await _updates.applyWindowsUpdate(extracted);
      } else {
        throw FormatException('Updates are only set up for Android and Windows.');
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('FormatException: ', '');
      setState(() => _updateError = message);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    if (!mounted) return;
    setState(() {
      _updateBusy = false;
      _downloadProgress = null;
    });
  }

  Widget _cacheCard() {
    final repo = CatalogRepository.instance;
    final catalog = repo.catalog;
    final items = catalog == null
        ? 0
        : catalog.areas.length + catalog.workTypes.length + catalog.allScopes().length;
    final custom = repo.cachedAreaCount + repo.cachedWorkTypeCount + repo.cachedScopeCount;
    final saved = _cacheSavedAt ?? repo.lastCatalogSave;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storage_outlined, size: 18, color: Color(0xFF5ADACE)),
              SizedBox(width: 8),
              Text('LOCAL CACHE', style: TextStyle(color: Color(0xFF5ADACE), fontSize: 11, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('catalog storage', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Items', value: '$items')),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Size', value: _cacheSizeLabel())),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _lastSyncedAt == null
                      ? (saved == null ? 'No custom catalog saved yet' : 'Last saved ${_ago(saved)}')
                      : 'Last sync: ${_ago(_lastSyncedAt!)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              Text(
                _syncBusy ? 'Syncing' : (_lastSyncedAt == null ? 'Local' : 'Healthy'),
                style: TextStyle(
                  color: _syncBusy ? AppColors.primary : (_lastSyncedAt == null ? AppColors.muted : const Color(0xFF5ADACE)),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (custom > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$custom custom overlay item${custom == 1 ? '' : 's'} on this PC',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (_cachePath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_cachePath, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncBusy ? null : _manualSync,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5ADACE),
                side: BorderSide(color: const Color(0xFF5ADACE).withValues(alpha: 0.28)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _syncBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5ADACE)))
                  : const Icon(Icons.sync, size: 18),
              label: Text(_syncBusy ? 'Syncing…' : 'Sync Now'),
            ),
          ),
          if (custom > 0) ...[
            const SizedBox(height: 16),
            _cachedLists(),
          ],
        ],
      ),
    );
  }

  Widget _backupCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.backup_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('REDUNDANCY', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 16),
          _BackupTile(
            icon: Icons.cloud_download_outlined,
            badge: '.CSV',
            title: 'Export Catalog',
            subtitle: 'Download a flat file backup of all localized data.',
            onTap: _backupCache,
          ),
          const SizedBox(height: 10),
          _BackupTile(
            icon: Icons.cloud_upload_outlined,
            badge: '.CSV',
            title: 'Import Backup',
            subtitle: 'Restore from a previous system snapshot.',
            onTap: _restoreBackup,
          ),
        ],
      ),
    );
  }

  Widget _agentCard({required bool compact}) {
    final model = _model.text.trim().isEmpty ? SettingsStore.defaultModel : _model.text.trim();
    final chatSelected = !_customModel;
    return _SettingsCard(
      color: AppColors.cardHover,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('agent parameters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Manoj Singharya can search the web, query Appwrite, and act across the app. Account ID and API token stay on this machine.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'Cloudflare Account ID',
            child: TextField(
              controller: _cfAccount,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
              decoration: _fieldDecoration(hint: '32-character account id'),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Cloudflare API Token',
            child: TextField(
              controller: _cfToken,
              obscureText: _obscure,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
              decoration: _fieldDecoration(
                hint: 'Workers AI token',
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 6),
            child: Text(
              'Needs Workers AI permission. Model: @cf/meta/llama-3.2-3b-instruct.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'DeepSeek API Key (fallback)',
            child: TextField(
              controller: _apiKey,
              obscureText: _obscure,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
              decoration: _fieldDecoration(
                hint: 'sk-…',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 6),
            child: Text(
              'Stored locally on this machine. Used only for agent requests from this app.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Base URL',
            child: TextField(
              controller: _baseUrl,
              decoration: _fieldDecoration(hint: SettingsStore.defaultBaseUrl),
            ),
          ),
          const SizedBox(height: 16),
          const Text('MODEL SELECTION', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4)),
          const SizedBox(height: 10),
          if (compact) ...[
            _ModelOption(
              title: SettingsStore.defaultModel,
              subtitle: 'Default for catalog search, quotations, and estimate edits.',
              selected: chatSelected,
              onTap: () => setState(() {
                _customModel = false;
                _model.text = SettingsStore.defaultModel;
              }),
            ),
            const SizedBox(height: 10),
            _ModelOption(
              title: chatSelected ? 'custom model' : model,
              subtitle: 'Use another DeepSeek-compatible model id.',
              selected: !chatSelected,
              onTap: () => setState(() => _customModel = true),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ModelOption(
                    title: SettingsStore.defaultModel,
                    subtitle: 'Default for catalog search, quotations, and estimate edits.',
                    selected: chatSelected,
                    onTap: () => setState(() {
                      _customModel = false;
                      _model.text = SettingsStore.defaultModel;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModelOption(
                    title: chatSelected ? 'custom model' : model,
                    subtitle: 'Use another DeepSeek-compatible model id.',
                    selected: !chatSelected,
                    onTap: () => setState(() => _customModel = true),
                  ),
                ),
              ],
            ),
          if (!chatSelected) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(hint: 'model id'),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _baseUrl.text = SettingsStore.defaultBaseUrl;
                  _model.text = SettingsStore.defaultModel;
                  _customModel = false;
                });
              },
              child: const Text('Use DeepSeek defaults'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveAgent,
              child: const Text('save agent config'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyCard({required bool compact}) {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('organizational defaults', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Base values applied to all new estimates and generated documents.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'Brand Name',
            child: TextField(controller: _brand, decoration: _fieldDecoration()),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Headquarters Address',
            child: TextField(controller: _address, minLines: 3, maxLines: 4, decoration: _fieldDecoration()),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Contact no.',
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(hint: defaultCompanyPhone),
            ),
          ),
          const SizedBox(height: 16),
          if (compact) ...[
            _LabeledField(
              label: 'GST %',
              child: TextField(
                controller: _gst,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration(),
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'HVAC GST %',
              child: TextField(
                controller: _hvacGst,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration(),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'GST %',
                    child: TextField(
                      controller: _gst,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldDecoration(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LabeledField(
                    label: 'HVAC GST %',
                    child: TextField(
                      controller: _hvacGst,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldDecoration(),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Currency',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: const Text('INR (₹)', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _saveCompany,
              child: const Text('update defaults'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.background,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF5ADACE)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _saveAgent() async {
    await _store.saveCloudflare(
      CloudflareAiSettings(accountId: _cfAccount.text, apiToken: _cfToken.text),
    );
    await _store.save(
      LlmSettings(
        baseUrl: _baseUrl.text,
        model: _customModel
            ? (_model.text.trim().isEmpty ? SettingsStore.defaultModel : _model.text)
            : SettingsStore.defaultModel,
        apiKey: _apiKey.text,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manoj Singharya agent settings saved on this machine')),
    );
  }

  String _cacheSizeLabel() {
    if (_cachePath.isEmpty) return '—';
    final file = File(_cachePath);
    if (!file.existsSync()) return '—';
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes b';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kb';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} mb';
  }

  String _ago(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    return _stamp(value);
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
      unawaited(AppwriteAutoSync.instance.syncNow(silent: true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $error')),
      );
    }
  }

  Future<void> _manualSync() async {
    setState(() => _syncBusy = true);
    try {
      final result = await AppwriteAutoSync.instance.syncNow(silent: false);
      await widget.onAppDataChanged?.call();
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud sync is not available on this device')),
        );
        return;
      }
      setState(() => _lastSyncedAt = AppwriteAutoSync.instance.lastSyncedAt);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${result.clients} clients, ${result.estimates} estimates and ${result.catalogItems} catalog items',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('FormatException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _syncBusy = AppwriteAutoSync.instance.busy);
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.color = AppColors.card});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1)),
        ],
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardHover,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.text),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Text(badge, style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(label.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3)),
        ),
        child,
      ],
    );
  }
}

class _ModelOption extends StatelessWidget {
  const _ModelOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.outline.withValues(alpha: 0.5), width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.check_circle, size: 18, color: selected ? AppColors.primary : Colors.transparent),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
