import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/office_models.dart';

class AppNotifications {
  AppNotifications._();
  static final instance = AppNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @visibleForTesting
  final cancelledIds = <String>[];

  static const _androidChannel = AndroidNotificationDetails(
    'biconcept_schedule',
    'Schedule',
    channelDescription: 'Meetings, follow-ups and payment collection reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> initialize() async {
    if (_ready || kIsWeb || Platform.environment['FLUTTER_TEST'] == 'true') return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
      const windows = WindowsInitializationSettings(
        appName: 'BiConcept',
        appUserModelId: 'BiConcept.Interior.Estimate',
        guid: 'a3c1e8f0-4b2d-4e91-9c7a-b1c04ce90001',
      );
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: windows,
      );
      await _plugin.initialize(settings: init);
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {}
  }

  Future<void> cancel(String eventId) async {
    cancelledIds.add(eventId);
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id(eventId));
    } catch (_) {}
  }

  Future<void> scheduleEvent(CalendarEvent event) async {
    if (!_ready || !event.notify || event.done) return;
    var when = event.start;
    if (event.kind == CalendarKind.collect || event.kind == CalendarKind.pay) {
      when = DateTime(when.year, when.month, when.day, 9);
    } else if (event.kind == CalendarKind.meeting) {
      when = when.subtract(const Duration(minutes: 30));
    }
    if (!when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _id(event.id),
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: _androidChannel,
          windows: WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: event.title.isEmpty ? _title(event) : event.title,
        body: _body(event),
      );
    } catch (_) {}
  }

  Future<void> rescheduleAll(Iterable<CalendarEvent> events) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    for (final event in events) {
      await scheduleEvent(event);
    }
  }

  int _id(String value) => value.hashCode & 0x7fffffff;

  String _title(CalendarEvent event) => switch (event.kind) {
        CalendarKind.meeting => 'Meeting${event.client.isEmpty ? '' : ' · ${event.client}'}',
        CalendarKind.followUp => 'Follow-up${event.client.isEmpty ? '' : ' · ${event.client}'}',
        CalendarKind.collect => 'Collect payment${event.project.isEmpty ? '' : ' · ${event.project}'}',
        CalendarKind.pay => 'Outgoing payment${event.project.isEmpty ? '' : ' · ${event.project}'}',
      };

  String _body(CalendarEvent event) {
    final bits = [
      if (event.client.isNotEmpty) event.client,
      if (event.project.isNotEmpty) event.project,
      if (event.notes.isNotEmpty) event.notes,
    ];
    return bits.isEmpty ? 'BiConcept reminder' : bits.join(' · ');
  }

  Future<void> showImmediate({required String title, required String body}) async {
    if (kIsWeb) return;
    if (!_ready) await initialize();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _androidChannel,
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
