import 'dart:io';

import 'package:biconcept/data/app_notifications.dart';
import 'package:biconcept/data/office_store.dart';
import 'package:biconcept/data/payment_schedule.dart';
import 'package:biconcept/data/schedule.dart';
import 'package:biconcept/models/office_models.dart';
import 'package:biconcept/models/terms_and_conditions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard interior T&C splits 30-20-15-15-15-5 every 20 days', () {
    final plans = buildPaymentSchedule(
      terms: standardInteriorTerms,
      grandTotal: 100000,
      start: DateTime(2026, 1, 1),
      estimateId: 'e1',
      client: 'Asha',
      project: 'Villa',
    );

    expect(plans.map((item) => item.percent).toList(), [30, 20, 15, 15, 15, 5]);
    expect(plans.map((item) => item.amount).toList(), [30000, 20000, 15000, 15000, 15000, 5000]);
    expect(plans.map((item) => item.dueOffsetDays).toList(), [0, 20, 40, 60, 80, 100]);
    expect(plans.first.label, 'Advance');
    expect(plans[1].label, 'Material delivery');
    expect(plans.last.label, 'Finishing');
    expect(plans.last.dueAt, DateTime(2026, 4, 11));
  });

  test('short finishing T&C splits 30-30-20-20 every 10 days', () {
    final plans = buildPaymentSchedule(
      terms: shortFinishingTerms,
      grandTotal: 100000,
      start: DateTime(2026, 1, 1),
    );

    expect(plans.map((item) => item.percent).toList(), [30, 30, 20, 20]);
    expect(plans.map((item) => item.amount).toList(), [30000, 30000, 20000, 20000]);
    expect(plans.map((item) => item.dueOffsetDays).toList(), [0, 10, 20, 30]);
    expect(plans.last.label, isNot('Finishing'));
  });

  test('last installment absorbs rounding remainder', () {
    final plans = buildPaymentSchedule(
      terms: standardInteriorTerms,
      grandTotal: 100001,
      start: DateTime(2026, 1, 1),
    );
    final allocated = plans.fold<double>(0, (sum, item) => sum + item.amount);
    expect(allocated, 100001);
    expect(plans.last.amount, closeTo(5000.05, 0.001));
  });

  test('project account records receive, send and outstanding', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_office');
    addTearDown(() => dir.delete(recursive: true));
    final store = OfficeStore.instance;
    await store.bindTo(dir);

    final plans = buildPaymentSchedule(
      terms: standardInteriorTerms,
      grandTotal: 100000,
      start: DateTime(2026, 1, 1),
      estimateId: 'e1',
      client: 'Asha',
      project: 'Villa',
    );
    await store.replaceInstallments('e1', plans);

    await ScheduleService.instance.recordPayment(
      PaymentEntry(
        flow: MoneyFlow.receive,
        amount: 30000,
        date: DateTime(2026, 1, 2),
        client: 'Asha',
        project: 'Villa',
        estimateId: 'e1',
        installmentId: plans.first.id,
        method: 'UPI',
        party: 'Asha',
      ),
    );
    await ScheduleService.instance.recordPayment(
      PaymentEntry(
        flow: MoneyFlow.send,
        amount: 8000,
        date: DateTime(2026, 1, 3),
        client: 'Asha',
        project: 'Villa',
        party: 'Carpenter',
        note: 'Labour advance',
      ),
    );

    final account = store.accounts().single;
    expect(account.client, 'Asha');
    expect(account.project, 'Villa');
    expect(account.scheduled, 100000);
    expect(account.received, 30000);
    expect(account.sent, 8000);
    expect(account.outstanding, 70000);
    expect(account.balance, 22000);
    expect(store.installments.firstWhere((item) => item.id == plans.first.id).isPaid, isTrue);
  });

  test('paying an installment cancels its collection reminder', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_office');
    addTearDown(() => dir.delete(recursive: true));
    final store = OfficeStore.instance;
    await store.bindTo(dir);
    AppNotifications.instance.cancelledIds.clear();

    const installmentId = 'pay_e1_1';
    await store.upsertEvent(
      CalendarEvent(
        id: 'collect_$installmentId',
        kind: CalendarKind.collect,
        start: DateTime(2026, 9, 1, 9),
        estimateId: 'e1',
        installmentId: installmentId,
        title: 'Advance 30%',
      ),
    );
    await store.saveInstallment(
      PaymentInstallment(
        id: installmentId,
        estimateId: 'e1',
        client: 'Asha',
        project: 'Villa',
        index: 1,
        percent: 30,
        label: 'Advance',
        dueOffsetDays: 0,
        amount: 30000,
        dueAt: DateTime(2026, 9, 1),
      ),
    );

    await ScheduleService.instance.recordPayment(
      PaymentEntry(
        flow: MoneyFlow.receive,
        amount: 30000,
        date: DateTime(2026, 8, 20),
        client: 'Asha',
        project: 'Villa',
        estimateId: 'e1',
        installmentId: installmentId,
      ),
    );

    expect(store.events.single.done, isTrue);
    expect(AppNotifications.instance.cancelledIds, contains('collect_$installmentId'));
  });

  test('replacing a payment plan cancels the old collection reminders', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_office');
    addTearDown(() => dir.delete(recursive: true));
    final store = OfficeStore.instance;
    await store.bindTo(dir);
    AppNotifications.instance.cancelledIds.clear();

    await store.upsertEvent(
      CalendarEvent(
        id: 'collect_pay_e1_6',
        kind: CalendarKind.collect,
        start: DateTime(2026, 10, 1, 9),
        estimateId: 'e1',
        installmentId: 'pay_e1_6',
        title: 'Finishing 5%',
      ),
    );
    await store.upsertEvent(
      CalendarEvent(
        id: 'meet_keep',
        kind: CalendarKind.meeting,
        start: DateTime(2026, 9, 2, 11),
        estimateId: 'e1',
        title: 'Site visit',
      ),
    );

    await store.replaceInstallments('e1', [
      PaymentInstallment(
        id: 'pay_e1_1',
        estimateId: 'e1',
        client: 'Asha',
        project: 'Villa',
        index: 1,
        percent: 100,
        label: 'Full payment',
        dueOffsetDays: 0,
        amount: 100000,
        dueAt: DateTime(2026, 9, 1),
      ),
    ]);

    expect(store.events.single.id, 'meet_keep');
    expect(AppNotifications.instance.cancelledIds, contains('collect_pay_e1_6'));
    expect(AppNotifications.instance.cancelledIds, isNot(contains('meet_keep')));
  });
}
