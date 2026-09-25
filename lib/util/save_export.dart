import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'download_bytes.dart';
import 'open_export.dart';

/// Writes [bytes] on desktop/Android, or starts a browser download on web.
Future<String> saveAndOpenExport({
  required Uint8List bytes,
  required String filename,
  required String mime,
}) async {
  if (kIsWeb) {
    await downloadBytes(bytes, filename, mime);
    return filename;
  }
  final root = await getApplicationDocumentsDirectory();
  final outDir = Directory('${root.path}/biconcept/exports');
  if (!await outDir.exists()) await outDir.create(recursive: true);
  final file = File('${outDir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await openExportedFile(file);
  return file.path;
}

String estimateExportStem(String client, String id, String dated) {
  final safeClient = client.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return 'estimate_${safeClient.isEmpty ? id : safeClient}_${dated.replaceAll('/', '-')}';
}
