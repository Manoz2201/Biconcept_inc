import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Directory?> tryApplicationSupportDirectory() async {
  if (kIsWeb) return null;
  try {
    return await getApplicationSupportDirectory();
  } on MissingPluginException {
    return null;
  } catch (_) {
    return null;
  }
}

Future<Directory?> tryApplicationDocumentsDirectory() async {
  if (kIsWeb) return null;
  try {
    return await getApplicationDocumentsDirectory();
  } on MissingPluginException {
    return null;
  } catch (_) {
    return null;
  }
}

/// JSON files on disk, or SharedPreferences when path_provider is missing (web).
class JsonDisk {
  JsonDisk({
    required this.relativePath,
    required this.prefsPrefix,
    this.useSupport = false,
  });

  /// When set, this folder is used directly (tests / LocalCache override).
  Directory? overrideDataDir;

  /// When set, files live under `[overrideRoot]/[relativePath]`.
  Directory? overrideRoot;

  final String relativePath;
  final String prefsPrefix;
  final bool useSupport;

  Future<Directory?> folder() async {
    if (overrideDataDir != null) {
      if (!await overrideDataDir!.exists()) {
        await overrideDataDir!.create(recursive: true);
      }
      return overrideDataDir;
    }
    final root = overrideRoot ??
        (useSupport ? await tryApplicationSupportDirectory() : await tryApplicationDocumentsDirectory());
    if (root == null) return null;
    final dir = Directory('${root.path}/$relativePath');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> pathOf(String name) async {
    final dir = await folder();
    if (dir != null) return '${dir.path}/$name';
    return 'browser:$prefsPrefix$name';
  }

  Future<void> write(String name, String contents) async {
    final dir = await folder();
    if (dir != null) {
      await File('${dir.path}/$name').writeAsString(contents, flush: true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$prefsPrefix$name', contents);
  }

  Future<void> writeJson(String name, Map<String, dynamic> json) async {
    await write(name, const JsonEncoder.withIndent('  ').convert(json));
  }

  Future<String?> read(String name) async {
    final dir = await folder();
    if (dir != null) {
      final file = File('${dir.path}/$name');
      if (!await file.exists()) return null;
      return file.readAsString();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$prefsPrefix$name');
  }

  Future<Map<String, dynamic>?> readJson(String name) async {
    final raw = await read(name);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> delete(String name) async {
    final dir = await folder();
    if (dir != null) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$prefsPrefix$name');
  }

  /// File names in this folder (e.g. `c1.json`).
  Future<List<String>> listNames({String suffix = '.json'}) async {
    final dir = await folder();
    if (dir != null) {
      return [
        for (final entity in dir.listSync())
          if (entity is File && entity.path.endsWith(suffix)) _fileName(entity),
      ];
    }
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final key in prefs.getKeys())
        if (key.startsWith(prefsPrefix) && key.endsWith(suffix)) key.substring(prefsPrefix.length),
    ];
  }

  String _fileName(File file) {
    final name = file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;
    return name;
  }
}
