import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/schedule_service.dart';
import '../models/estimate_document.dart';
import '../models/office_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'widgets/ui_kit.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.drafts,
    this.compact = false,
  });

  final List<EstimateDraft> drafts;
  final bool compact;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    ScheduleService.instance.start();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 16.0 : 28.0;
    return ListenableBuilder(
      listenable: ScheduleService.instance.store,
      builder: (context, _) {
        return Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Calendar'),
                Tab(text: 'Accounts'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _calendarTab(pad),
                  _accountsTab(pad),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _calendarTab(double pad) {
    final events = ScheduleService.instance.store.eventsOn(_selected);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 96),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthName(_month.month)} ${_month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _monthGrid(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _addMeeting,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: const Text('Meeting'),
            ),
            OutlinedButton.icon(
              onPressed: _addFollowUp,
              icon: const Icon(Icons.phone_callback_outlined, size: 18),
              label: const Text('Follow-up'),
            ),
            OutlinedButton.icon(
              onPressed: _createPaymentPlan,
              icon: const Icon(Icons.percent_outlined, size: 18),
              label: const Text('Payment schedule'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Schedule for ${_selected.day}/${_selected.month}/${_selected.year}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('Nothing scheduled this day.', style: TextStyle(color: AppColors.muted))
        else
          for (final event in events) _eventCard(event),
      ],
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final store = ScheduleService.instance.store;
    return Column(
      children: [
        Row(
          children: [
            for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final index = row * 7 + col - leading + 1;
                      if (index < 1 || index > daysInMonth) return const SizedBox(height: 40);
                      final day = DateTime(_month.year, _month.month, index);
                      final selected = day == _selected;
                      final marked = store.eventsOn(day).isNotEmpty;
                      return InkWell(
                        onTap: () => setState(() => _selected = day),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$index',
                                style: TextStyle(
                                  color: selected ? const Color(0xFF1A1010) : AppColors.text,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              if (marked)
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF1A1010) : AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _eventCard(CalendarEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(_kindIcon(event.kind), color: AppColors.primarySoft, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (event.notes.isNotEmpty)
                    Text(event.notes, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            if (!event.done)
              IconButton(
                tooltip: 'Mark done',
                onPressed: () {
                  event.done = true;
                  ScheduleService.instance.saveEvent(event);
                },
                icon: const Icon(Icons.check_circle_outline, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _accountsTab(double pad) {
    final accounts = ScheduleService.instance.store.accounts();
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 96),
      children: [
        const Text(
          'Project accounts track money received from the client and money sent out for that project.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _addMoney(MoneyFlow.receive),
              icon: const Icon(Icons.call_received, size: 18),
              label: const Text('Receive'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addMoney(MoneyFlow.send),
              icon: const Icon(Icons.call_made, size: 18),
              label: const Text('Send'),
            ),
            OutlinedButton.icon(
              onPressed: _createPaymentPlan,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('From estimate T&C'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (accounts.isEmpty)
          const Text('No project accounts yet. Create a payment schedule from an estimate.', style: TextStyle(color: AppColors.muted))
        else
          for (final account in accounts) _accountCard(account),
      ],
    );
  }

  Widget _accountCard(ProjectAccount account) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        onTap: () => _openLedger(account),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.client.isEmpty ? 'Untitled client' : account.client, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(account.project.isEmpty ? 'No project name' : account.project, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _moneyChip('Scheduled', inr(account.scheduled)),
                _moneyChip('Received', inr(account.received)),
                _moneyChip('Sent', inr(account.sent)),
                _moneyChip('Outstanding', inr(account.outstanding)),
                _moneyChip('Balance', inr(account.balance)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _openLedger(ProjectAccount account) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: ScheduleService.instance.store,
          builder: (context, _) {
            final latest = ScheduleService.instance.store.accounts().firstWhere(
                  (item) => item.key == account.key,
                  orElse: () => account,
                );
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              builder: (context, controller) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: ListView(
                    controller: controller,
                    children: [
                      Text('${latest.client} · ${latest.project}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Outstanding ${inr(latest.outstanding)}  ·  Balance ${inr(latest.balance)}', style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 16),
                      const Text('Collection schedule', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      for (final item in latest.installments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item.label} · ${item.percent.toStringAsFixed(0)}%'),
                          subtitle: Text('Due ${item.dueAt.day}/${item.dueAt.month}/${item.dueAt.year} · ${inr(item.amount)}'),
                          trailing: Text(item.isPaid ? 'Paid' : inr(item.outstanding)),
                          onTap: item.isPaid ? null : () => _addMoney(MoneyFlow.receive, installment: item, account: latest),
                        ),
                      const SizedBox(height: 12),
                      const Text('Ledger', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      for (final item in latest.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(item.flow == MoneyFlow.receive ? Icons.call_received : Icons.call_made, color: item.flow == MoneyFlow.receive ? AppColors.up : AppColors.down),
                          title: Text('${item.flow == MoneyFlow.receive ? 'Received' : 'Sent'} ${inr(item.amount)}'),
                          subtitle: Text([
                            item.method,
                            if (item.party.isNotEmpty) item.party,
                            if (item.note.isNotEmpty) item.note,
                          ].join(' · ')),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addMeeting() async {
    final event = await _eventDialog(kind: CalendarKind.meeting, title: 'Meeting');
    if (event == null) return;
    await ScheduleService.instance.saveEvent(event);
  }

  Future<void> _addFollowUp() async {
    final event = await _eventDialog(kind: CalendarKind.followUp, title: 'Follow-up');
    if (event == null) return;
    await ScheduleService.instance.saveEvent(event);
  }

  Future<CalendarEvent?> _eventDialog({required CalendarKind kind, required String title}) async {
    final client = TextEditingController();
    final project = TextEditingController();
    final notes = TextEditingController();
    var when = DateTime(_selected.year, _selected.month, _selected.day, 11);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: client, decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: project, decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${when.day}/${when.month}/${when.year}  ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: when, firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
                        setDialogState(() {
                          when = DateTime(date.year, date.month, date.day, time?.hour ?? 11, time?.minute ?? 0);
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
    final event = CalendarEvent(
      kind: kind,
      start: when,
      title: '$title${client.text.trim().isEmpty ? '' : ' · ${client.text.trim()}'}',
      client: client.text.trim(),
      project: project.text.trim(),
      notes: notes.text.trim(),
    );
    client.dispose();
    project.dispose();
    notes.dispose();
    if (saved != true) return null;
    return event;
  }

  Future<void> _createPaymentPlan() async {
    if (widget.drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save an estimate first')));
      return;
    }
    EstimateDraft? selected = widget.drafts.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Payment schedule from T&C'),
              content: SizedBox(
                width: 460,
                child: DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estimate', border: OutlineInputBorder()),
                  items: [
                    for (final draft in widget.drafts)
                      DropdownMenuItem(
                        value: draft.id,
                        child: Text(
                          '${draft.client} · ${draft.project} · ${inr(draft.totals.grandTotal)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selected = widget.drafts.firstWhere((item) => item.id == value));
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || selected == null || !mounted) return;
    final plans = await ScheduleService.instance.createPaymentPlan(selected!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scheduled ${plans.length} collections totalling ${inr(selected!.totals.grandTotal)}')),
    );
  }

  Future<void> _addMoney(MoneyFlow flow, {PaymentInstallment? installment, ProjectAccount? account}) async {
    final amount = TextEditingController(text: installment == null ? '' : installment.outstanding.toStringAsFixed(0));
    final party = TextEditingController(text: flow == MoneyFlow.receive ? (installment?.client ?? account?.client ?? '') : '');
    final note = TextEditingController();
    final clientField = TextEditingController(text: installment?.client ?? account?.client ?? (widget.drafts.isEmpty ? '' : widget.drafts.first.client));
    final projectField = TextEditingController(text: installment?.project ?? account?.project ?? (widget.drafts.isEmpty ? '' : widget.drafts.first.project));
    var method = 'UPI';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(flow == MoneyFlow.receive ? 'Receive payment' : 'Send payment'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (installment == null && account == null) ...[
                  TextField(controller: clientField, decoration: const InputDecoration(labelText: 'Client / project account', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: projectField, decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(controller: party, decoration: InputDecoration(labelText: flow == MoneyFlow.receive ? 'From' : 'To', border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'NEFT', child: Text('NEFT / IMPS')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  ],
                  onChanged: (value) {
                    if (value != null) method = value;
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        );
      },
    );
    final value = parseNumber(amount.text) ?? 0;
    final partyName = party.text.trim();
    final noteText = note.text.trim();
    final client = clientField.text.trim();
    final project = projectField.text.trim();
    amount.dispose();
    party.dispose();
    note.dispose();
    clientField.dispose();
    projectField.dispose();
    if (saved != true || value <= 0) return;
    await ScheduleService.instance.recordPayment(
      PaymentEntry(
        flow: flow,
        amount: value,
        date: DateTime.now(),
        client: client,
        project: project,
        estimateId: installment?.estimateId,
        installmentId: installment?.id,
        method: method,
        party: partyName,
        note: noteText,
      ),
    );
  }

  IconData _kindIcon(CalendarKind kind) => switch (kind) {
        CalendarKind.meeting => Icons.event_outlined,
        CalendarKind.followUp => Icons.phone_callback_outlined,
        CalendarKind.collect => Icons.call_received,
        CalendarKind.pay => Icons.call_made,
      };

  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];
}
