import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'catch_up_sync.dart';
import 'sync_worker.dart';

class ChatConnectivityListener {
  ChatConnectivityListener({
    required CatchUpSync catchUp,
    required SyncWorker worker,
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Stream<List<ConnectivityResult>>? onConnectivityChanged,
  }) : this._(
          catchUp,
          worker,
          connectivity,
          checkConnectivity,
          onConnectivityChanged,
        );

  ChatConnectivityListener._(
    this._catchUp,
    this._worker,
    this._connectivity,
    this._checkConnectivity,
    this._onConnectivityChanged,
  );

  final CatchUpSync _catchUp;
  final SyncWorker _worker;
  final Connectivity? _connectivity;
  final Future<List<ConnectivityResult>> Function()? _checkConnectivity;
  final Stream<List<ConnectivityResult>>? _onConnectivityChanged;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  var _online = true;

  bool get isOnline => _online;

  Future<void> start() async {
    final probe = _checkConnectivity ?? _connectivity?.checkConnectivity ?? Connectivity().checkConnectivity;
    final current = await probe();
    _online = current.any((item) => item != ConnectivityResult.none);
    final changes = _onConnectivityChanged ?? _connectivity?.onConnectivityChanged ?? Connectivity().onConnectivityChanged;
    _sub ??= changes.listen((results) {
      final next = results.any((item) => item != ConnectivityResult.none);
      final reconnected = next && !_online;
      _online = next;
      if (reconnected) {
        unawaited(_catchUp.run());
        unawaited(_worker.tick());
      }
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
