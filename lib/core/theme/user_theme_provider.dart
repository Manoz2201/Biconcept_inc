import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import 'app_theme_presets.dart';
import 'user_theme_store.dart';

final userThemeStoreProvider = Provider<UserThemeStore>((ref) => UserThemeStore());

final userThemeProvider = NotifierProvider<UserThemeController, String>(UserThemeController.new);

class UserThemeController extends Notifier<String> {
  @override
  String build() {
    ref.listen(sessionControllerProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id) {
        unawaited(_hydrate());
      }
    });
    Future.microtask(_hydrate);
    return AppThemePresets.defaultId;
  }

  Future<void> select(String presetId) async {
    final id = AppThemePresets.byId(presetId).id;
    state = id;
    final userId = ref.read(sessionControllerProvider).user?.id;
    await ref.read(userThemeStoreProvider).save(userKey: userId, presetId: id);
  }

  Future<void> _hydrate() async {
    final userId = ref.read(sessionControllerProvider).user?.id;
    final id = await ref.read(userThemeStoreProvider).load(userId);
    state = id;
  }
}
