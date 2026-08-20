import 'dart:io';

import 'package:flutter/services.dart';

const _exportChannel = MethodChannel('com.example.biconcept/export');

Future<void> openExportedFile(File file) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', file.path]);
    return;
  }

  if (!Platform.isAndroid) {
    throw UnsupportedError('Open export is only set up for Android and Windows');
  }

  final lower = file.path.toLowerCase();
  final mime = lower.endsWith('.pdf')
      ? 'application/pdf'
      : lower.endsWith('.xlsx')
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'application/octet-stream';
  await _exportChannel.invokeMethod<void>('shareFile', {
    'path': file.path,
    'mime': mime,
  });
}
