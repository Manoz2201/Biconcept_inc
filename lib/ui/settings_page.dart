import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/permission_gate.dart';
import '../data/app_update_service.dart';
import '../data/app_version.dart';
import '../data/appwrite_auto_sync.dart';
import '../data/cache_backup.dart';
import '../data/catalog_repository.dart';
import '../data/local_cache.dart';
import '../agent/workers_ai_proxy.dart';
import '../data/settings_store.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/rbac/domain/permission.dart';
import '../models/company_profile.dart';
import '../theme/app_theme.dart';
import '../util/backup_io.dart';
import 'widgets/color_theme_selector.dart';
import '../util/format.dart';
import '../util/open_export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.embedded = false, this.onAppDataChanged});

  final bool embedded;
  final Future<void> Function()? onAppDataChanged;

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final _store = SettingsStore();
  final _updates = AppUpdateService();
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
  DateTime? _lastSyncedAt;
  String _cachePath = '';
  DateTime? _cacheSavedAt;
  AppBuildInfo _buildInfo = const AppBuildInfo(appName: 'BiConcept', version: '…', buildNumber: 0);
  AppRelease? _latest;
  String? _updateError;
  bool _updateChecking = false;
  bool _updateBusy = false;
  double? _downloadProgress;
  bool _hydrating = true;
  Timer? _companySaveTimer;
  Timer? _agentSaveTimer;
  Timer? _githubSaveTimer;
  bool _companySaving = false;
  bool _agentSaving = false;
  bool _tokenTesting = false;
  String? _tokenTestResult;

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
      if (!AppwriteAutoSync.instance.busy) {
        _companySaving = false;
        _agentSaving = false;
      }
    });
  }

  void _listenForAutoSave() {
    _brand.addListener(_scheduleCompanySave);
    _address.addListener(_scheduleCompanySave);
    _phone.addListener(_scheduleCompanySave);
    _gst.addListener(_scheduleCompanySave);
    _hvacGst.addListener(_scheduleCompanySave);
    _cfAccount.addListener(_scheduleAgentSave);
    _cfToken.addListener(_scheduleAgentSave);
    _ghToken.addListener(_scheduleGithubSave);
  }

  void _scheduleCompanySave() {
    if (_hydrating) return;
    _companySaveTimer?.cancel();
    _companySaveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveCompany(silent: true));
    });
    if (mounted && !_companySaving) setState(() => _companySaving = true);
  }

  void _scheduleAgentSave() {
    if (_hydrating) return;
    _agentSaveTimer?.cancel();
    _agentSaveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveAgent(silent: true));
    });
    if (mounted && !_agentSaving) setState(() => _agentSaving = true);
  }

  void _scheduleGithubSave() {
    if (_hydrating) return;
    _githubSaveTimer?.cancel();
    _githubSaveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persistGithubToken());
    });
  }

  Future<void> _load() async {
    final prefs = await LocalCache.instance.loadPrefs();
    await CatalogRepository.instance.load();
    if (!mounted) return;
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
    _listenForAutoSave();
    _hydrating = false;
    if (_normalizeGithubToken(_ghToken.text).isNotEmpty) {
      unawaited(_checkForUpdate(silent: true));
    }
  }

  @override
  void dispose() {
    _companySaveTimer?.cancel();
    _agentSaveTimer?.cancel();
    _githubSaveTimer?.cancel();
    _brand.removeListener(_scheduleCompanySave);
    _address.removeListener(_scheduleCompanySave);
    _phone.removeListener(_scheduleCompanySave);
    _gst.removeListener(_scheduleCompanySave);
    _hvacGst.removeListener(_scheduleCompanySave);
    _cfAccount.removeListener(_scheduleAgentSave);
    _cfToken.removeListener(_scheduleAgentSave);
    _ghToken.removeListener(_scheduleGithubSave);
    if (!_hydrating) {
      unawaited(_saveCompany(silent: true));
      unawaited(_saveAgent(silent: true));
      unawaited(_persistGithubToken());
    }
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
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : ListenableBuilder(
            listenable: CatalogRepository.instance,
            builder: (context, _) => ListView(
              padding: EdgeInsets.fromLTRB(pad, compact ? 4 : 8, pad, compact ? AppBreakpoints.navClearance : 32),
              children: [
                _hero(compact: compact),
                const SizedBox(height: 24),
                _versionCard(),
                const SizedBox(height: 16),
                const _AccountCard(),
                const SizedBox(height: 16),
                const _ThemeCard(),
                const SizedBox(height: 16),
                if (compact) ...[
                  _cacheCard(),
                  const SizedBox(height: 16),
                  _backupCard(),
                  const SizedBox(height: 16),
                  _agentCard(),
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
                            _agentCard(),
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
      backgroundColor: AppPalette.of(context).backgroundBase,
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
                  'Manage local caching, data redundancy, organizational defaults, and Cloudflare agent parameters.',
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
    final error = AppwriteAutoSync.instance.lastError;
    final synced = _lastSyncedAt != null && (error == null || error.isEmpty);
    final color = busy
        ? AppColors.primary
        : (error != null && error.isNotEmpty)
            ? AppColors.down
            : (synced ? AppColors.completed : AppColors.muted);
    final label = busy
        ? 'SYNCING'
        : (error != null && error.isNotEmpty)
            ? 'CLOUD ERROR'
            : (synced ? 'CLOUD SYNCED' : 'LOCAL ONLY');
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
          Row(
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
              Expanded(child: _MiniStat(label: 'This device', value: _buildInfo.display)),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Latest release',
                  value: latest?.display ?? '—',
                ),
              ),
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
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
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
              'A newer build is ready. BiConcept will download the APK or Windows zip and install it here — it will not open GitHub.',
              style: TextStyle(color: AppColors.text, fontSize: 13),
            ),
            if (latest.assetForPlatform() != null) ...[
              const SizedBox(height: 4),
              Text(
                latest.assetForPlatform()!.name,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            if (latest.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                latest.notes.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
              ),
            ],
          ],
          if (_updateError != null) ...[
            const SizedBox(height: 10),
            Text(_updateError!, style: TextStyle(color: AppColors.down, fontSize: 12, height: 1.35)),
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
          Padding(
            padding: EdgeInsets.only(left: 8, top: 6),
            child: Text(
              'Required while Manoz2201/Biconcept_inc is private. Saved to the central Appwrite company table.',
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
          if (available && !kIsWeb) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : _installUpdate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _updateBusy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(
                  _updateBusy ? 'Downloading…' : 'Download and install ${latest.display}',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: available
                ? OutlinedButton.icon(
                    onPressed: busy ? null : () => _checkForUpdate(),
                    icon: _updateChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_updateChecking ? 'Checking…' : 'Check again'),
                  )
                : FilledButton.icon(
                    onPressed: busy ? null : () => _checkForUpdate(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_updateChecking ? 'Checking…' : 'Check for update'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<String?> _githubToken() async {
    final typed = _normalizeGithubToken(_ghToken.text);
    if (typed.isNotEmpty) return typed;
    final github = await _store.loadGitHub();
    final token = _normalizeGithubToken(github.token);
    return token.isEmpty ? null : token;
  }

  String _normalizeGithubToken(String raw) {
    var token = raw.trim();
    if (token.length >= 2 &&
        ((token.startsWith('"') && token.endsWith('"')) || (token.startsWith("'") && token.endsWith("'")))) {
      token = token.substring(1, token.length - 1).trim();
    }
    const bearer = 'Bearer ';
    if (token.toLowerCase().startsWith(bearer.toLowerCase())) {
      token = token.substring(bearer.length).trim();
    }
    return token;
  }

  Future<void> _persistGithubToken() async {
    final token = _normalizeGithubToken(_ghToken.text);
    final current = await _store.loadGitHub();
    await _store.saveGitHub(
      current.copyWith(
        repo: current.repo.trim().isEmpty ? defaultUpdateRepo : current.repo,
        token: token,
      ),
    );
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    setState(() {
      _updateChecking = true;
      _updateError = null;
    });
    if (!silent) await _persistGithubToken();
    final result = await _updates.check(current: _buildInfo, token: await _githubToken());
    AppUpdateNotice.instance.apply(result);
    if (!mounted) return;
    setState(() {
      _updateChecking = false;
      _latest = result.latest;
      _updateError = result.error;
    });
    if (!mounted || silent) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    if (result.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BiConcept ${result.latest!.display} is ready to download and install')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You are on ${_buildInfo.display}')),
    );
  }

  Future<void> installAvailableUpdate() => _installUpdate();

  Future<void> _installUpdate() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() => _updateError = 'Install updates from the Android or Windows app.');
      return;
    }
    final release = _latest;
    if (release == null) return;
    final asset = release.assetForPlatform();
    if (asset == null) {
      setState(() => _updateError = kIsWeb
          ? 'Install updates from the Android or Windows app.'
          : 'This release has no installer for ${defaultTargetPlatform.name}.');
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows
            ? 'Restart to update'
            : 'Install update'),
        content: Text(
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
              ? 'BiConcept will download ${release.display} (${asset.name}), close, replace this install, and reopen.'
              : 'BiConcept will download ${release.display} (${asset.name}). Android will then ask you to install the APK.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Download and install')),
        ],
      ),
    );
    if (go != true) return;
    await _persistGithubToken();
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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await installAndroidApk(file.path);
        } on PlatformException catch (error) {
          if (error.code == 'need_install_permission') {
            throw FormatException(error.message ?? 'Allow BiConcept to install updates, then tap Download and install again.');
          }
          rethrow;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Android asked to install the new APK')),
        );
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
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
          Row(
            children: [
              Icon(Icons.storage_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('LOCAL CACHE', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 1.4)),
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
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              Text(
                _syncBusy ? 'Syncing' : (_lastSyncedAt == null ? 'Local' : 'Healthy'),
                style: TextStyle(
                  color: _syncBusy ? AppColors.primary : (_lastSyncedAt == null ? AppColors.muted : AppColors.primary),
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
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (_cachePath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_cachePath, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncBusy ? null : _manualSync,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.28)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _syncBusy
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
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
          Row(
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
            subtitle: kIsWeb
                ? 'CSV export is available in the Android and Windows apps.'
                : 'Download a flat file backup of all localized data.',
            onTap: kIsWeb ? null : _backupCache,
          ),
          const SizedBox(height: 10),
          _BackupTile(
            icon: Icons.cloud_upload_outlined,
            badge: '.CSV',
            title: 'Import Backup',
            subtitle: kIsWeb
                ? 'CSV restore is available in the Android and Windows apps.'
                : 'Restore from a previous system snapshot.',
            onTap: kIsWeb ? null : _restoreBackup,
          ),
        ],
      ),
    );
  }

  Widget _agentCard() {
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
                child: Icon(Icons.smart_toy_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('agent parameters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manoj Singharya uses Cloudflare Workers AI. Production credentials are GitHub secrets copied onto the workers-ai-proxy function. Settings is only a local override when those secrets are missing.',
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
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: Text(
              'Preferred: gh secret set CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN, then run the Appwrite workflow. Optional override: Workers AI API Token (not the Global API Key).',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _tokenTesting ? null : _testToken,
              icon: _tokenTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(_tokenTesting ? 'Testing…' : 'Test token'),
            ),
          ),
          if (_tokenTestResult != null) ...[
            const SizedBox(height: 10),
            Text(
              _tokenTestResult!,
              style: TextStyle(
                color: _tokenTestResult == 'Token is valid.' ? AppColors.primary : AppColors.down,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _agentSaving || _syncBusy
                  ? 'Saving to Appwrite…'
                  : (_lastSyncedAt != null
                      ? 'Saved to Appwrite · ${_ago(_lastSyncedAt!)}'
                      : 'Saves to the central Appwrite company table'),
              style: TextStyle(color: AppColors.muted, fontSize: 12),
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
          Text(
            'Base values applied to all new estimates and generated documents. Saved to Appwrite automatically.',
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
            child: Text(
              _companyCloudStatus(),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppwriteAutoSync.instance.lastError == null ? AppColors.muted : AppColors.down,
                fontSize: 12,
              ),
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
        borderSide: BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _saveAgent({bool silent = false}) async {
    final accountId = _cfAccount.text;
    final apiToken = _cfToken.text;
    await _store.saveCloudflare(
      CloudflareAiSettings(accountId: accountId, apiToken: apiToken),
    );
    if (!mounted) return;
    setState(() => _agentSaving = false);
    if (silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Agent credentials saved to Appwrite')),
    );
  }

  Future<void> _testToken() async {
    setState(() {
      _tokenTesting = true;
      _tokenTestResult = null;
    });
    await _saveAgent(silent: true);
    final result = await verifyWorkersAiToken(apiToken: _cfToken.text);
    if (!mounted) return;
    setState(() {
      _tokenTesting = false;
      _tokenTestResult = result;
    });
  }

  String _companyCloudStatus() {
    final error = AppwriteAutoSync.instance.lastError;
    if (error != null && error.isNotEmpty) return error;
    if (_companySaving || _syncBusy) return 'Saving to Appwrite…';
    if (_lastSyncedAt != null) return 'Saved to Appwrite · ${_ago(_lastSyncedAt!)}';
    return 'Saves to the Appwrite company table automatically';
  }

  String _cacheSizeLabel() {
    if (kIsWeb || _cachePath.isEmpty || _cachePath.startsWith('browser:')) return '—';
    try {
      final file = File(_cachePath);
      if (!file.existsSync()) return '—';
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes b';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kb';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} mb';
    } on Object {
      return '—';
    }
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
          Text('Cached areas', style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
          Text('Cached work types', style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
          Text('Cached scopes', style: TextStyle(color: AppColors.muted, fontSize: 12)),
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

  Future<void> _saveCompany({bool silent = false}) async {
    final brand = _brand.text.trim();
    final address = _address.text.trim();
    final phone = _phone.text.trim();
    final gst = parseNumber(_gst.text);
    final hvacGst = parseNumber(_hvacGst.text);
    await LocalCache.instance.updatePrefs((prefs) {
      if (brand.isNotEmpty) prefs.brand = brand;
      if (address.isNotEmpty) prefs.companyAddress = address;
      if (phone.isNotEmpty) prefs.companyPhone = phone;
      if (gst != null) prefs.gstPercent = gst;
      if (hvacGst != null) prefs.hvacGstPercent = hvacGst;
    });
    if (!mounted) return;
    setState(() => _companySaving = false);
    if (silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Company defaults saved to Appwrite')),
    );
  }

  Future<void> _backupCache() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV backup is not available in the browser.')),
      );
      return;
    }
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
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV restore is not available in the browser.')),
      );
      return;
    }
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

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(child: ColorThemeSelector(compact: MediaQuery.sizeOf(context).width < AppBreakpoints.compact));
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color ?? AppPalette.of(context).surface,
        borderRadius: BorderRadius.circular(24),
      ),
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
          Text(label.toUpperCase(), style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1),
          ),
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
  final VoidCallback? onTap;

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
                    child: Text(badge, style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 13)),
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
          child: Text(label.toUpperCase(), style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3)),
        ),
        child,
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user == null ? 'Account' : user.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (user != null) ...[
            const SizedBox(height: 4),
            Text('${user.email} · ${user.role.label}', style: TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 16),
          PermissionGate(
            permission: Permission.userView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Team members'),
              subtitle: const Text('Invite staff, vendors, and clients'),
              onTap: () => context.push('/users'),
            ),
          ),
          PermissionGate(
            permission: Permission.catalogView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_mosaic_outlined),
              title: const Text('Public catalog'),
              subtitle: const Text('Services, portfolio, and team'),
              onTap: () => context.push('/admin/catalog'),
            ),
          ),
          PermissionGate(
            permission: Permission.enquiryView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inbox_outlined),
              title: const Text('Enquiries'),
              subtitle: const Text('Leads from the public contact form'),
              onTap: () => context.push('/admin/enquiries'),
            ),
          ),
          PermissionGate(
            permission: Permission.serviceRequestView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Service requests'),
              subtitle: const Text('Client work and conversions'),
              onTap: () => context.push('/admin/requests'),
            ),
          ),
          PermissionGate(
            permission: Permission.messageView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Chat'),
              subtitle: const Text('Local-first messages with the team'),
              onTap: () => context.push('/chat'),
            ),
          ),
          PermissionGate(
            permission: Permission.quotationView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.request_quote_outlined),
              title: const Text('Quotations'),
              subtitle: const Text('Draft, send, and track approvals'),
              onTap: () => context.push('/admin/quotations'),
            ),
          ),
          PermissionGate(
            permission: Permission.projectView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Projects'),
              subtitle: const Text('Milestones, tasks, documents, and timesheets'),
              onTap: () => context.push('/admin/projects'),
            ),
          ),
          PermissionGate(
            permission: Permission.vendorView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Vendors'),
              subtitle: const Text('Onboarding, RFQs, POs, and bills'),
              onTap: () => context.push('/admin/vendors'),
            ),
          ),
          PermissionGate(
            permission: Permission.rfqView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('RFQs'),
              subtitle: const Text('Invite vendors and award quotes'),
              onTap: () => context.push('/admin/rfqs'),
            ),
          ),
          PermissionGate(
            permission: Permission.purchaseOrderView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Purchase orders'),
              subtitle: const Text('Issue and track vendor POs'),
              onTap: () => context.push('/admin/purchase-orders'),
            ),
          ),
          PermissionGate(
            permission: Permission.financialReportView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Accounting'),
              subtitle: const Text('Receivables, payables, GST, and cashflow'),
              onTap: () => context.push('/admin/accounting'),
            ),
          ),
          PermissionGate(
            permission: Permission.auditDashboardView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('GST audit'),
              subtitle: const Text('ITC, GSTR-2B, GSTR-9, TDS, e-invoice'),
              onTap: () => context.push('/admin/audit'),
            ),
          ),
          PermissionGate(
            permission: Permission.analyticsView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Analytics'),
              subtitle: const Text('KPIs, funnels, cohorts, and revenue'),
              onTap: () => context.push('/admin/analytics'),
            ),
          ),
          PermissionGate(
            permission: Permission.currencyView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.currency_exchange_outlined),
              title: const Text('Currencies'),
              subtitle: const Text('Base currency and exchange rates'),
              onTap: () => context.push('/admin/currencies'),
            ),
          ),
          PermissionGate(
            permission: Permission.paymentScheduleView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Payment schedules'),
              subtitle: const Text('Approve and batch vendor payments'),
              onTap: () => context.push('/admin/payment-schedules'),
            ),
          ),
          PermissionGate(
            permission: Permission.integrationView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Integrations'),
              subtitle: const Text('Tally, Zoho Books, QuickBooks, calendars'),
              onTap: () => context.push('/admin/integrations'),
            ),
          ),
          PermissionGate(
            permission: Permission.brandingEdit,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Branding'),
              subtitle: const Text('Logo, colors, and email templates'),
              onTap: () => context.push('/admin/branding'),
            ),
          ),
          PermissionGate(
            permission: Permission.backupView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backups'),
              subtitle: const Text('Scheduled backups and restore points'),
              onTap: () => context.push('/admin/backups'),
            ),
          ),
          PermissionGate(
            permission: Permission.notificationPreferenceView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('Inbox, channels, and quiet hours'),
              onTap: () => context.push('/notifications'),
            ),
          ),
          PermissionGate(
            permission: Permission.budgetView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Budgets & forecasts'),
              subtitle: const Text('Budget vs actual and cashflow projection'),
              onTap: () => context.push('/admin/forecasts'),
            ),
          ),
          PermissionGate(
            permission: Permission.invoiceView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_outlined),
              title: const Text('Invoices'),
              subtitle: const Text('GST invoices, payments, credit notes'),
              onTap: () => context.push('/admin/invoices'),
            ),
          ),
          PermissionGate(
            permission: Permission.expenseView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.money_outlined),
              title: const Text('Expenses'),
              subtitle: const Text('Staff expenses and approvals'),
              onTap: () => context.push('/admin/expenses'),
            ),
          ),
          PermissionGate(
            permission: Permission.vendorBillView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Vendor bills'),
              subtitle: const Text('Approve bills and record payments'),
              onTap: () => context.push('/admin/vendor-bills'),
            ),
          ),
          PermissionGate(
            permission: Permission.timesheetView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Timesheets'),
              subtitle: const Text('Log hours and approve weekly time'),
              onTap: () => context.push('/admin/timesheets'),
            ),
          ),
          PermissionGate(
            permission: Permission.changeRequestView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.change_circle_outlined),
              title: const Text('Change requests'),
              subtitle: const Text('Scope changes and client approvals'),
              onTap: () => context.push('/admin/change-requests'),
            ),
          ),
          PermissionGate(
            permission: Permission.aiNaturalLanguageQuery,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI assistant'),
              subtitle: const Text('Quotations, cost, timeline, search, and NLP'),
              onTap: () => context.push('/ai/assistant'),
            ),
          ),
          PermissionGate(
            permission: Permission.ocrUpload,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('OCR documents'),
              subtitle: const Text('Extract invoices, receipts, and contracts'),
              onTap: () => context.push('/ocr/documents'),
            ),
          ),
          PermissionGate(
            permission: Permission.whatsappView,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              subtitle: const Text('Templates and client updates'),
              onTap: () => context.push('/whatsapp/messages'),
            ),
          ),
          PermissionGate(
            permission: Permission.aiTimelinePredict,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Predictive'),
              subtitle: const Text('Project risk, alerts, and health'),
              onTap: () => context.push('/predictive/risk'),
            ),
          ),
          PermissionGate(
            permission: Permission.multiFirmDashboard,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Multi-firm'),
              subtitle: const Text('Tenants, plans, and usage'),
              onTap: () => context.push('/multi-firm/dashboard'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () async {
                await ref.read(sessionControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
