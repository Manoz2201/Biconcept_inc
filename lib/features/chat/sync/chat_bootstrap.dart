import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/chat_provider.dart';
import 'connectivity_listener.dart';

class ChatBootstrap extends ConsumerStatefulWidget {
  const ChatBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatBootstrap> createState() => _ChatBootstrapState();
}

class _ChatBootstrapState extends ConsumerState<ChatBootstrap> {
  ChatConnectivityListener? _listener;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final testing = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (testing) return;
    ref.read(chatRepositoryProvider).startRealtime();
    final catchUp = ref.read(chatCatchUpProvider);
    final worker = ref.read(chatSyncWorkerProvider);
    _listener = ChatConnectivityListener(catchUp: catchUp, worker: worker);
    await _listener!.start();
    unawaited(catchUp.run());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => worker.tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_listener?.dispose() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
