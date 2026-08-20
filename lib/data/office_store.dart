import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/office_models.dart';
import 'app_notifications.dart';

class OfficeStore extends ChangeNotifier {
  OfficeStore._();
  static final instance = OfficeStore._();

  Directory? overrideDirectory;
  final events = <CalendarEvent>[];
  final installments = <PaymentInstallment>[];
  final payments = <PaymentEntry>[];
  bool _loaded = false;

  Future<Directory> _dir() async {
    final root = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/biconcept/office');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file() async => File('${(await _dir()).path}/office.json');

  @visibleForTesting
  Future<void> bindTo(Directory dir) async {
    overrideDirectory = dir;
    _loaded = false;
    events.clear();
    installments.clear();
    payments.clear();
    await load();
  }

  Future<void> load() async {
    if (_loaded && overrideDirectory == null) return;
    events.clear();
    installments.clear();
    payments.clear();
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          events.addAll([
            for (final item in decoded['events'] as List? ?? const [])
              if (item is Map) CalendarEvent.fromJson(Map<String, dynamic>.from(item)),
          ]);
          installments.addAll([
            for (final item in decoded['installments'] as List? ?? const [])
              if (item is Map) PaymentInstallment.fromJson(Map<String, dynamic>.from(item)),
          ]);
          payments.addAll([
            for (final item in decoded['payments'] as List? ?? const [])
              if (item is Map) PaymentEntry.fromJson(Map<String, dynamic>.from(item)),
          ]);
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final payload = {
      'events': [for (final item in events) item.toJson()],
      'installments': [for (final item in installments) item.toJson()],
      'payments': [for (final item in payments) item.toJson()],
    };
    await (await _file()).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    notifyListeners();
  }

  Future<void> upsertEvent(CalendarEvent event) async {
    await load();
    final index = events.indexWhere((item) => item.id == event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.add(event);
    }
    await _persist();
  }

  Future<void> deleteEvent(String id) async {
    await load();
    events.removeWhere((item) => item.id == id);
    await _persist();
  }

  Future<void> replaceInstallments(String estimateId, List<PaymentInstallment> next) async {
    await load();
    final stale = [
      for (final event in events)
        if (event.estimateId == estimateId && event.kind == CalendarKind.collect) event.id,
    ];
    for (final id in stale) {
      await AppNotifications.instance.cancel(id);
    }
    installments.removeWhere((item) => item.estimateId == estimateId);
    installments.addAll(next);
    events.removeWhere(
      (item) => item.estimateId == estimateId && item.kind == CalendarKind.collect,
    );
    await _persist();
  }

  Future<void> saveInstallment(PaymentInstallment installment) async {
    await load();
    final index = installments.indexWhere((item) => item.id == installment.id);
    if (index >= 0) {
      installments[index] = installment;
    } else {
      installments.add(installment);
    }
    await _persist();
  }

  Future<void> addPayment(PaymentEntry entry) async {
    await load();
    payments.add(entry);
    if (entry.installmentId != null && entry.flow == MoneyFlow.receive) {
      final index = installments.indexWhere((item) => item.id == entry.installmentId);
      if (index >= 0) {
        installments[index].collected += entry.amount;
        if (installments[index].isPaid) {
          for (final event in events.where((item) => item.installmentId == entry.installmentId)) {
            event.done = true;
            await AppNotifications.instance.cancel(event.id);
          }
        }
      }
    }
    await _persist();
  }

  List<CalendarEvent> eventsOn(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return [
      for (final event in events)
        if (DateTime(event.start.year, event.start.month, event.start.day) == date) event,
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  List<ProjectAccount> accounts() {
    final keys = <String, ({String client, String project})>{};
    for (final item in installments) {
      keys[projectAccountKey(item.client, item.project)] = (client: item.client, project: item.project);
    }
    for (final item in payments) {
      keys[item.accountKey] = (client: item.client, project: item.project);
    }
    final result = [
      for (final entry in keys.entries)
        ProjectAccount(
          client: entry.value.client,
          project: entry.value.project,
          installments: [
            for (final item in installments)
              if (projectAccountKey(item.client, item.project) == entry.key) item,
          ]..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
          entries: [
            for (final item in payments)
              if (item.accountKey == entry.key) item,
          ]..sort((a, b) => b.date.compareTo(a.date)),
        ),
    ]..sort((a, b) => a.client.toLowerCase().compareTo(b.client.toLowerCase()));
    return result;
  }
}
