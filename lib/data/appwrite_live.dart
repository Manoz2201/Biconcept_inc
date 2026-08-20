import 'dart:async';

import 'appwrite_auto_sync.dart';

void installAppwriteLiveSync() {
  AppwriteAutoSync.instance.installHooks();
  unawaited(AppwriteAutoSync.instance.ensureStarted());
}
