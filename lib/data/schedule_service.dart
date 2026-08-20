import '../models/client_record.dart';
import '../models/estimate_document.dart';
import '../models/office_models.dart';
import '../util/format.dart';
import 'app_notifications.dart';
import 'office_store.dart';
import 'payment_schedule.dart';

class ScheduleService {
  ScheduleService._();
  static final instance = ScheduleService._();

  final store = OfficeStore.instance;

  Future<void> start() async {
    await store.load();
    await AppNotifications.instance.initialize();
    await AppNotifications.instance.rescheduleAll(store.events.where((item) => !item.done));
  }

  Future<CalendarEvent> saveEvent(CalendarEvent event) async {
    await store.upsertEvent(event);
    if (event.notify && !event.done) {
      await AppNotifications.instance.scheduleEvent(event);
    } else {
      await AppNotifications.instance.cancel(event.id);
    }
    return event;
  }

  Future<void> deleteEvent(String id) async {
    await AppNotifications.instance.cancel(id);
    await store.deleteEvent(id);
  }

  Future<void> fromFollowUp(ClientRecord client, ClientFollowUp followUp) async {
    final when = followUp.nextFollow;
    if (when == null) return;
    await saveEvent(
      CalendarEvent(
        id: 'follow_${client.id}_${followUp.id}',
        kind: CalendarKind.followUp,
        start: when,
        title: 'Follow-up · ${client.name}',
        client: client.name,
        project: client.project,
        notes: followUp.note.isEmpty ? followUp.kind : '${followUp.kind}: ${followUp.note}',
      ),
    );
  }

  Future<List<PaymentInstallment>> createPaymentPlan(EstimateDraft draft, {DateTime? start}) async {
    final plans = buildPaymentSchedule(
      terms: draft.effectiveTerms,
      grandTotal: draft.totals.grandTotal,
      start: start ?? draft.date,
      estimateId: draft.id,
      client: draft.client,
      project: draft.project,
    );
    await store.replaceInstallments(draft.id, plans);
    for (final plan in plans) {
      await saveEvent(
        CalendarEvent(
          id: 'collect_${plan.id}',
          kind: CalendarKind.collect,
          start: DateTime(plan.dueAt.year, plan.dueAt.month, plan.dueAt.day, 9),
          title: '${plan.label} ${plan.percent.toStringAsFixed(0)}% · ${inr(plan.amount)}',
          client: draft.client,
          project: draft.project,
          estimateId: draft.id,
          installmentId: plan.id,
          notes: 'Collect ${plan.percent.toStringAsFixed(0)}% (${inr(plan.amount)}) for ${draft.project}',
        ),
      );
    }
    return plans;
  }

  Future<void> recordPayment(PaymentEntry entry) async {
    await store.addPayment(entry);
    if (entry.flow == MoneyFlow.send) {
      await saveEvent(
        CalendarEvent(
          id: 'pay_${entry.id}',
          kind: CalendarKind.pay,
          start: entry.date,
          title: 'Paid ${inr(entry.amount)} · ${entry.project}',
          client: entry.client,
          project: entry.project,
          estimateId: entry.estimateId,
          notes: entry.note.isEmpty ? 'To ${entry.party}' : entry.note,
          notify: false,
          done: true,
        ),
      );
    }
  }
}
