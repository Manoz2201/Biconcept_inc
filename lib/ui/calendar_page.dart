import 'package:flutter/material.dart';

import '../data/schedule.dart';
import '../models/estimate_document.dart';
import '../models/office_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'project_ledger_page.dart';

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

class _CalendarPageState extends State<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _panel = 0;

  @override
  void initState() {
    super.initState();
    ScheduleService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 16.0 : 24.0;
    return ListenableBuilder(
      listenable: ScheduleService.instance.store,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, widget.compact ? 4 : 8, pad, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'financial overview',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: widget.compact ? 32 : 48,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'manage your project timelines and payment schedules across active digital architecture bids.',
                        style: TextStyle(color: AppColors.muted, fontSize: widget.compact ? 14 : 16, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PanelToggle(
                        calendar: _panel == 0,
                        onCalendar: () => setState(() => _panel = 0),
                        onAccounts: () => setState(() => _panel = 1),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
              sliver: SliverToBoxAdapter(
                child: _panel == 0 ? _calendarPanel() : _accountsPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _calendarPanel() {
    final events = List<CalendarEvent>.of(ScheduleService.instance.store.eventsOn(_selected));
    final calendar = _calendarCard();
    final agenda = _agendaCard(events);
    if (widget.compact) {
      return Column(children: [calendar, const SizedBox(height: 16), agenda]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: calendar),
        const SizedBox(width: 16),
        SizedBox(width: 360, child: agenda),
      ],
    );
  }

  Widget _calendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                ),
                Expanded(
                  child: Text(
                    '${_monthName(_month.month).toLowerCase()} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.4),
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 16),
                  const _LegendDot(color: AppColors.primary, label: 'bid deadline'),
                  const SizedBox(width: 12),
                  const _LegendDot(color: AppColors.completed, label: 'client meeting'),
                  const SizedBox(width: 12),
                  const _LegendDot(color: Color(0xFF5ADACE), label: 'payment due'),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _monthGrid(),
          ),
        ],
      ),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday % 7;
    final store = ScheduleService.instance.store;
    const labels = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    return Column(
      children: [
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < 6; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Builder(
                        builder: (context) {
                          final date = DateTime(_month.year, _month.month, 1 - leading + row * 7 + col);
                          final inMonth = date.month == _month.month;
                          final selected = date.year == _selected.year && date.month == _selected.month && date.day == _selected.day;
                          final dayEvents = store.eventsOn(date);
                          final cell = Material(
                            color: inMonth ? AppColors.sidebar : AppColors.background.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => setState(() {
                                _selected = DateTime(date.year, date.month, date.day);
                                if (!inMonth) _month = DateTime(date.year, date.month);
                              }),
                              borderRadius: BorderRadius.circular(12),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: selected ? Border.all(color: AppColors.primary.withValues(alpha: 0.45)) : null,
                                  boxShadow: selected
                                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.16), blurRadius: 16)]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: selected
                                            ? AppColors.primarySoft
                                            : inMonth
                                                ? AppColors.text
                                                : AppColors.muted.withValues(alpha: 0.35),
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        for (final color in _dayDots(dayEvents).take(3))
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                            child: Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          return widget.compact ? SizedBox(height: 48, child: cell) : AspectRatio(aspectRatio: 1, child: cell);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Color> _dayDots(List<CalendarEvent> events) {
    final colors = <Color>{};
    for (final event in events) {
      colors.add(_kindColor(event.kind));
    }
    return colors.toList();
  }

  Widget _agendaCard(List<CalendarEvent> events) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_monthName(_selected.month).toLowerCase()} ${_selected.day}',
                style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('nothing scheduled this day.', style: TextStyle(color: AppColors.muted)),
            )
          else
            for (final event in events) _eventCard(event),
          _addEventTile(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallAction(label: 'follow-up', icon: Icons.phone_callback_outlined, onTap: _addFollowUp),
              _SmallAction(label: 'payment plan', icon: Icons.percent_outlined, onTap: _createPaymentPlan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addEventTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _addMeeting,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: 0.55,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      '--:--',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted.withValues(alpha: 0.8), fontSize: 12, letterSpacing: 0.8),
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.outline.withValues(alpha: 0.5)),
                  const SizedBox(width: 14),
                  const Text('add event', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventCard(CalendarEvent event) {
    final color = _kindColor(event.kind);
    final hour = event.start.hour % 12 == 0 ? 12 : event.start.hour % 12;
    final minute = event.start.minute.toString().padLeft(2, '0');
    final ampm = event.start.hour >= 12 ? 'pm' : 'am';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: event.done
              ? null
              : () {
                  event.done = true;
                  ScheduleService.instance.saveEvent(event);
                },
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: event.done ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Column(
                      children: [
                        Text(
                          '${hour.toString().padLeft(2, '0')}:$minute',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.6),
                        ),
                        Text(ampm, style: TextStyle(color: AppColors.muted.withValues(alpha: 0.55), fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.outline.withValues(alpha: 0.5)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title.toLowerCase(),
                          style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _kindLabel(event),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: color, fontSize: 12, letterSpacing: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!event.done)
                    const Icon(Icons.check_circle_outline, size: 18, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountsPanel() {
    final accounts = ScheduleService.instance.store.accounts();
    final now = DateTime.now();
    var ytd = 0.0;
    var lastYtd = 0.0;
    var outstanding = 0.0;
    for (final account in accounts) {
      outstanding += account.outstanding;
      for (final entry in account.entries) {
        if (entry.flow != MoneyFlow.receive) continue;
        if (entry.date.year == now.year) ytd += entry.amount;
        if (entry.date.year == now.year - 1) lastYtd += entry.amount;
      }
    }
    final ytdDelta = lastYtd == 0 ? (ytd == 0 ? 0.0 : 100.0) : ((ytd - lastYtd) / lastYtd) * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : 1;
            final cards = [
              _StatCard(
                label: 'total received (ytd)',
                value: inrCompact(ytd),
                delta: '${ytdDelta >= 0 ? '+' : ''}${ytdDelta.toStringAsFixed(0)}%',
                up: ytdDelta >= 0,
              ),
              _StatCard(
                label: 'outstanding receivables',
                value: inrCompact(outstanding),
                delta: outstanding > 0 ? '${accounts.where((a) => a.outstanding > 0).length} open' : 'cleared',
                up: outstanding <= 0,
              ),
              _GenerateCard(onTap: _createPaymentPlan),
            ];
            if (columns == 1) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i != cards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Flex(
          direction: widget.compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: widget.compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            Text(
              'recent activity',
              style: TextStyle(color: AppColors.text, fontSize: widget.compact ? 22 : 28, fontWeight: FontWeight.w600),
            ),
            if (widget.compact) const SizedBox(height: 12) else const Spacer(),
            Row(
              children: [
                _SmallAction(label: 'receive', icon: Icons.call_received, onTap: () => _addMoney(MoneyFlow.receive)),
                const SizedBox(width: 8),
                _SmallAction(label: 'send', icon: Icons.call_made, onTap: () => _addMoney(MoneyFlow.send)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No project accounts yet. Create a payment schedule from an estimate.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 700 ? 2 : 1;
              if (columns == 1) {
                return Column(
                  children: [
                    for (final account in accounts) ...[
                      _accountCard(account),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              final rows = <List<ProjectAccount>>[];
              for (var i = 0; i < accounts.length; i += columns) {
                rows.add(accounts.sublist(i, i + columns > accounts.length ? accounts.length : i + columns));
              }
              return Column(
                children: [
                  for (final row in rows) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < columns; i++) ...[
                          Expanded(child: i < row.length ? _accountCard(row[i]) : const SizedBox.shrink()),
                          if (i != columns - 1) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _accountCard(ProjectAccount account) {
    final status = account.outstanding > 0.009
        ? 'outstanding'
        : account.received > 0
            ? 'received'
            : account.scheduled > 0
                ? 'scheduled'
                : 'drafted';
    final amount = account.outstanding > 0.009
        ? account.outstanding
        : account.received > 0
            ? account.received
            : account.scheduled;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _openLedger(account),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.cardHover,
                    child: Text(
                      _initials(account.client),
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.client.isEmpty ? 'untitled client' : account.client.toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          account.installments.isEmpty
                              ? 'ledger'
                              : '${account.installments.length} installment${account.installments.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _AccountBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.45)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PROJECT', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text(
                          account.project.isEmpty ? 'no project name' : account.project.toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    amount == 0 ? '—' : inr(amount),
                    style: TextStyle(
                      color: status == 'scheduled' || status == 'drafted' ? AppColors.muted : AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _kindColor(CalendarKind kind) => switch (kind) {
        CalendarKind.meeting => AppColors.completed,
        CalendarKind.followUp => AppColors.primary,
        CalendarKind.collect => const Color(0xFF5ADACE),
        CalendarKind.pay => AppColors.down,
      };

  String _kindLabel(CalendarEvent event) {
    final extra = event.kind == CalendarKind.collect && event.notes.isNotEmpty ? ' · ${event.notes}' : '';
    return switch (event.kind) {
          CalendarKind.meeting => 'client meeting',
          CalendarKind.followUp => 'bid deadline',
          CalendarKind.collect => 'payment due',
          CalendarKind.pay => 'payout',
        } +
        extra;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final value = parts.first;
      return (value.length >= 2 ? value.substring(0, 2) : value).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _openLedger(ProjectAccount account) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProjectLedgerPage(
          accountKey: account.key,
          drafts: widget.drafts,
          onEditSchedule: _createPaymentPlan,
        ),
      ),
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

  Future<void> _addMoney(MoneyFlow flow, {PaymentInstallment? installment, ProjectAccount? account}) {
    return showRecordPaymentDialog(
      context,
      flow: flow,
      installment: installment,
      account: account,
      drafts: widget.drafts,
    );
  }

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

class _PanelToggle extends StatelessWidget {
  const _PanelToggle({required this.calendar, required this.onCalendar, required this.onAccounts});

  final bool calendar;
  final VoidCallback onCalendar;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('Calendar', calendar, onCalendar),
          _pill('Accounts', !calendar, onAccounts),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: selected ? const Color(0xFF1A1010) : AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardHover,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: AppColors.text)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardHover.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.delta, required this.up});

  final String label;
  final String value;
  final String delta;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? AppColors.up : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.6),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: color),
                    const SizedBox(width: 2),
                    Text(delta, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: const Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 40, color: AppColors.muted),
              SizedBox(height: 8),
              Text('generate invoice', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'received' => (AppColors.completed.withValues(alpha: 0.12), AppColors.completed),
      'outstanding' => (AppColors.primary.withValues(alpha: 0.18), AppColors.primarySoft),
      'scheduled' => (AppColors.cardHover, AppColors.muted),
      _ => (AppColors.cardHover.withValues(alpha: 0.5), AppColors.muted.withValues(alpha: 0.7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
    );
  }
}
