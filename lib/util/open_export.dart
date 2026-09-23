import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _exportChannel = MethodChannel('com.example.biconcept/export');

Future<void> openExportedFile(File file) async {
  if (kIsWeb) {
    throw UnsupportedError('Open export is only set up for Android and Windows');
  }
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

Future<void> openHttpUrl(String url) async {
  if (kIsWeb) {
    throw UnsupportedError('Open URL is only set up for Android and Windows');
  }
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', url]);
    return;
  }
  if (!Platform.isAndroid) {
    throw UnsupportedError('Open URL is only set up for Android and Windows');
  }
  await _exportChannel.invokeMethod<void>('openUrl', {'url': url});
}

Future<void> installAndroidApk(String path) async {
  if (kIsWeb || !Platform.isAndroid) {
    throw UnsupportedError('APK install is only set up for Android');
  }
  await _exportChannel.invokeMethod<void>('installApk', {'path': path});
}
