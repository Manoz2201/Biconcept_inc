import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'appwrite_sync.dart';
import 'client_store.dart';
import 'cloud_hooks.dart';
import 'draft_store.dart';
import 'github_sync.dart';
import 'local_cache.dart';
import 'settings_store.dart';

/// Background Appwrite sync. Local saves stay instant; network work is queued
/// off the tap path so the UI does not wait on HTTP.
class AppwriteAutoSync extends ChangeNotifier {
  AppwriteAutoSync._();

  static final instance = AppwriteAutoSync._();

  static const startupDelay = Duration(seconds: 2);
  static const periodicInterval = Duration(minutes: 3);

  final _store = SettingsStore();
  final _sync = AppwriteSync();

  Timer? _periodic;
  Future<void> _queue = Future<void>.value();
  bool _started = false;
  bool _hooksInstalled = false;
  bool busy = false;
  DateTime? lastSyncedAt;
  String? lastError;
  int applyGeneration = 0;
  CloudSyncResult? lastResult;

  void installHooks() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;

    CloudHooks.afterClientSave = (client) => _enqueueSilent(() async {
          final settings = await _configured();
          if (settings == null) return;
          await _sync.upsertClient(settings, client);
        });
    CloudHooks.afterClientDelete = (id) => _enqueueSilent(() async {
          final settings = await _configured();
          if (settings == null) return;
          await _sync.deleteClient(settings, id);
        });
    CloudHooks.afterEstimateSave = (draft) => _enqueueSilent(() async {
          final settings = await _configured();
          if (settings == null) return;
          await _sync.upsertEstimate(settings, draft);
        });
    CloudHooks.afterEstimateDelete = (id) => _enqueueSilent(() async {
          final settings = await _configured();
          if (settings == null) return;
          await _sync.deleteEstimate(settings, id);
        });
    CloudHooks.afterCatalogSave = (overlay) => _enqueueSilent(() async {
          final settings = await _configured();
          if (settings == null) return;
          await _sync.upsertCatalogOverlay(settings, overlay);
        });
    CloudHooks.afterPrefsSave = (prefs) => _enqueueSilent(() async {
          final settings = await _configured();
          if (settings == null) return;
          await _sync.upsertCompany(settings, AppPrefsCache.fromJson(prefs));
          lastSyncedAt = DateTime.now();
          await _store.saveAppwrite(settings.copyWith(lastSyncedAt: lastSyncedAt));
          notifyListeners();
        });
  }

  Future<void> ensureStarted() async {
    if (_started) return;
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    _started = true;
    installHooks();
    final settings = await _store.loadAppwrite();
    lastSyncedAt = settings.lastSyncedAt;
    notifyListeners();
    _periodic = Timer.periodic(periodicInterval, (_) {
      unawaited(syncNow(silent: true));
    });
    unawaited(Future<void>.delayed(startupDelay, () => syncNow(silent: true)));
  }

  Future<void> syncOnResume() async {
    if (!_started) return;
    await syncNow(silent: true);
  }

  Future<CloudSyncResult?> syncNow({bool silent = true}) {
    return _enqueue(() async {
      final settings = await _configured();
      if (settings == null) {
        if (!silent) {
          throw const FormatException('Cloud sync is not available on this device');
        }
        return null;
      }
      busy = true;
      lastError = null;
      notifyListeners();
      try {
        final result = await _sync.sync(
          settings: settings,
          localClients: await ClientStore().list(),
          localEstimates: await DraftStore().list(),
          applyLocally: writeCloudSnapshotLocally,
          setupTables: false,
        );
        lastResult = result;
        lastSyncedAt = DateTime.now();
        await _store.saveAppwrite(settings.copyWith(lastSyncedAt: lastSyncedAt));
        applyGeneration++;
        return result;
      } catch (error) {
        lastError = error.toString().replaceFirst('FormatException: ', '');
        if (!silent) rethrow;
        return null;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
  }

  Future<AppwriteCloudSettings?> _configured() async {
    final settings = await _store.loadAppwrite();
    return settings.isConfigured ? settings : null;
  }

  Future<T> _enqueue<T>(Future<T> Function() job) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await job());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> _enqueueSilent(Future<void> Function() job) {
    return _enqueue(() async {
      try {
        await job();
        if (lastError != null) {
          lastError = null;
          notifyListeners();
        }
      } catch (error) {
        lastError = error.toString().replaceFirst('FormatException: ', '');
        notifyListeners();
      }
    });
  }

  @visibleForTesting
  void debugReset() {
    _periodic?.cancel();
    _periodic = null;
    _started = false;
    _hooksInstalled = false;
    _queue = Future<void>.value();
    busy = false;
    lastSyncedAt = null;
    lastError = null;
    applyGeneration = 0;
    lastResult = null;
    CloudHooks.afterClientSave = null;
    CloudHooks.afterClientDelete = null;
    CloudHooks.afterEstimateSave = null;
    CloudHooks.afterEstimateDelete = null;
    CloudHooks.afterCatalogSave = null;
    CloudHooks.afterPrefsSave = null;
  }
}

Future<CloudSyncResult?> syncAppwriteDatabase({bool silent = true}) {
  return AppwriteAutoSync.instance.syncNow(silent: silent);
}
