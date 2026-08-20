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
              'A newer build is ready. BiConcept will download the APK or Windows zip and install it here — it will not open GitHub.',
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
            if (latest.assetForPlatform() != null) ...[
              const SizedBox(height: 4),
              Text(
                latest.assetForPlatform()!.name,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
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
          if (available) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : _installUpdate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _updateBusy
                    ? const SizedBox(
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
                        ? const SizedBox(
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
    final release = _latest;
    if (release == null) return;
    final asset = release.assetForPlatform();
    if (asset == null) {
      setState(() => _updateError = 'This release has no installer for ${Platform.operatingSystem}.');
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Platform.isWindows ? 'Restart to update' : 'Install update'),
        content: Text(
          Platform.isWindows
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
      if (Platform.isAndroid) {
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
                child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('agent parameters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Manoj Singharya can search the web, query Appwrite, and act across the app. Cloudflare credentials save to the central Appwrite company table.',
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _agentSaving || _syncBusy
                  ? 'Saving to Appwrite…'
                  : (_lastSyncedAt != null
                      ? 'Saved to Appwrite · ${_ago(_lastSyncedAt!)}'
                      : 'Saves to the central Appwrite company table'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
        borderSide: const BorderSide(color: Color(0xFF5ADACE)),
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

  String _companyCloudStatus() {
    final error = AppwriteAutoSync.instance.lastError;
    if (error != null && error.isNotEmpty) return error;
    if (_companySaving || _syncBusy) return 'Saving to Appwrite…';
    if (_lastSyncedAt != null) return 'Saved to Appwrite · ${_ago(_lastSyncedAt!)}';
    return 'Saves to the Appwrite company table automatically';
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
