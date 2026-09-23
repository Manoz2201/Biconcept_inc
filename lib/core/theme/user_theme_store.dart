import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_presets.dart';

class UserThemeStore {
  static const keyPrefix = 'user_color_theme_';
  static const deviceUserKey = 'device';

  String storageKey(String userKey) => '$keyPrefix${_normalize(userKey)}';

  Future<String> load(String? userKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _normalize(userKey);
    return prefs.getString(storageKey(key)) ??
        prefs.getString(storageKey(deviceUserKey)) ??
        AppThemePresets.defaultId;
  }

  Future<void> save({required String? userKey, required String presetId}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = AppThemePresets.byId(presetId).id;
    final key = _normalize(userKey);
    await prefs.setString(storageKey(key), id);
    if (key != deviceUserKey) {
      await prefs.setString(storageKey(deviceUserKey), id);
    }
  }

  String _normalize(String? userKey) {
    final trimmed = userKey?.trim() ?? '';
    return trimmed.isEmpty ? deviceUserKey : trimmed;
  }
}
