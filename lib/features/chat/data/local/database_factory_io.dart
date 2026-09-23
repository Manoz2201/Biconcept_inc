import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'database.dart';
import 'database_factory_stub.dart' as stub;

Future<ChatDatabase> openChatDatabase() async {
  if (kIsWeb) return stub.openChatDatabase();
  final db = ChatDatabase();
  await db.open();
  try {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'biconcept_chat.db.json'));
    if (await file.exists()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) db.restore(decoded);
    }
    db.attachPersister(() async {
      await file.writeAsString(jsonEncode(db.snapshot()));
    });
    sqlite3.openInMemory().dispose();
    return db;
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(stub.chatPrefsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) db.restore(decoded);
    }
    db.attachPersister(() async {
      final store = await SharedPreferences.getInstance();
      await store.setString(stub.chatPrefsKey, jsonEncode(db.snapshot()));
    });
  } catch (_) {}
  return db;
}
