import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.biconcept/export');

String sanitizePhoneNumber(String phone) {
  return phone.replaceAll(RegExp(r'[^\d+]'), '');
}

/// Opens the device dialer. Returns `true` if a dialer was launched.
Future<bool> callPhoneNumber(String phone) async {
  final number = sanitizePhoneNumber(phone);
  if (number.isEmpty) return false;

  if (kIsWeb) {
    await Clipboard.setData(ClipboardData(text: number));
    return true;
  }

  if (Platform.isAndroid) {
    await _channel.invokeMethod<void>('dialPhone', {'number': number});
    return true;
  }

  await Clipboard.setData(ClipboardData(text: number));
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', 'tel:$number']);
    return true;
  }
  return false;
}
