import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('com.example.biconcept/export');

String suggestedBackupFileName([DateTime? now]) {
  final stamp = now ?? DateTime.now();
  final d = stamp.day.toString().padLeft(2, '0');
  final m = stamp.month.toString().padLeft(2, '0');
  return 'biconcept-backup-$d-$m-${stamp.year}.csv';
}

Future<Directory> backupDirectory() async {
  if (kIsWeb) {
    throw const FormatException('CSV backup is not available in the browser.');
  }
  final root = await getApplicationDocumentsDirectory();
  final dir = Directory('${root.path}/biconcept/backups');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Asks where to save, writes [csv], and returns the local path to show the user.
Future<String?> saveBackupCsv({
  required String csv,
  required String fileName,
}) async {
  if (kIsWeb) {
    throw const FormatException('CSV backup is not available in the browser.');
  }
  if (Platform.isWindows) {
    final chosen = await _windowsSavePath(fileName);
    if (chosen == null || chosen.trim().isEmpty) return null;
    final file = File(chosen.endsWith('.csv') ? chosen : '$chosen.csv');
    await file.parent.create(recursive: true);
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  if (Platform.isAndroid) {
    final dir = await backupDirectory();
    final local = File('${dir.path}/$fileName');
    await local.writeAsString(csv, flush: true);
    final saved = await _channel.invokeMethod<String>('saveBackupCsv', {
      'path': local.path,
      'fileName': fileName,
    });
    return saved?.trim().isNotEmpty == true ? saved : local.path;
  }

  final dir = await backupDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv, flush: true);
  return file.path;
}

Future<String?> pickBackupCsv() async {
  if (kIsWeb) return null;
  if (Platform.isWindows) {
    final chosen = await _windowsOpenPath();
    if (chosen == null || chosen.trim().isEmpty) return null;
    return chosen.trim();
  }

  if (Platform.isAndroid) {
    final path = await _channel.invokeMethod<String>('pickBackupCsv');
    if (path == null || path.trim().isEmpty) return null;
    return path.trim();
  }

  return null;
}

Future<void> revealBackupLocation(String path) async {
  if (kIsWeb) return;
  if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', path]);
    return;
  }
  if (Platform.isAndroid) {
    final file = File(path);
    if (await file.exists()) {
      await _channel.invokeMethod<void>('shareFile', {
        'path': file.path,
        'mime': 'text/csv',
      });
    }
  }
}

Future<String?> _windowsSavePath(String fileName) async {
  final result = await Process.run('powershell', [
    '-STA',
    '-NoProfile',
    '-Command',
    _saveDialogScript(fileName),
  ]);
  final lines = (result.stdout as String).trim().split(RegExp(r'\r?\n'));
  final path = lines.isEmpty ? '' : lines.last.trim();
  if (path.isNotEmpty) return path;
  if (result.exitCode != 0) {
    return File('${(await backupDirectory()).path}/$fileName').path;
  }
  return null;
}

Future<String?> _windowsOpenPath() async {
  final result = await Process.run('powershell', [
    '-STA',
    '-NoProfile',
    '-Command',
    _openDialogScript(),
  ]);
  final lines = (result.stdout as String).trim().split(RegExp(r'\r?\n'));
  final path = lines.isEmpty ? '' : lines.last.trim();
  return path.isEmpty ? null : path;
}

String _saveDialogScript(String fileName) {
  final safe = fileName.replaceAll("'", "''");
  return '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.SaveFileDialog
\$dialog.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
\$dialog.FileName = '$safe'
\$dialog.OverwritePrompt = \$true
\$dialog.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { \$dialog.FileName }
''';
}

String _openDialogScript() {
  return r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
$dialog.Multiselect = $false
$dialog.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $dialog.FileName }
''';
}
