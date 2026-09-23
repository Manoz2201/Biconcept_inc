import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';

const chatPrefsKey = 'biconcept.chat.sqlite.json';

Future<ChatDatabase> openChatDatabase() async {
  final db = ChatDatabase();
  await db.open();
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(chatPrefsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) db.restore(decoded);
    }
    db.attachPersister(() async {
      final store = await SharedPreferences.getInstance();
      await store.setString(chatPrefsKey, jsonEncode(db.snapshot()));
    });
  } catch (_) {}
  return db;
}
