import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/schedule.dart';
import '../models/estimate_document.dart';
import '../models/office_models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

class ProjectLedgerPage extends StatefulWidget {
  const ProjectLedgerPage({
    super.key,
    required this.accountKey,
    this.drafts = const [],
    this.onEditSchedule,
  });

  final String accountKey;
  final List<EstimateDraft> drafts;
  final VoidCallback? onEditSchedule;

  @override
  State<ProjectLedgerPage> createState() => _ProjectLedgerPageState();
}

class _ProjectLedgerPageState extends State<ProjectLedgerPage> {
  _LedgerFilter _filter = _LedgerFilter.all;
  int _shown = 8;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return ListenableBuilder(
      listenable: ScheduleService.instance.store,
      builder: (context, _) {
        final account = _account();
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: compact ? _compactBody(account, compact) : _wideBody(account, compact),
          ),
        );
      },
    );
  }

  ProjectAccount _account() {
    return ScheduleService.instance.store.accounts().firstWhere(
          (item) => item.key == widget.accountKey,
          orElse: () => const ProjectAccount(client: '', project: '', installments: [], entries: []),
        );
  }

  EstimateDraft? _linkedDraft(ProjectAccount account) {
    for (final draft in widget.drafts) {
      if (projectAccountKey(draft.client, draft.project) == account.key) return draft;
    }
    return null;
  }

  Widget _compactBody(ProjectAccount account, bool compact) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _topBar(compact: true, account: account),
        _header(account, compact: true),
        const SizedBox(height: 20),
        _kpis(account),
        const SizedBox(height: 28),
        _schedule(account),
        const SizedBox(height: 28),
        _ledger(account, compact: true),
        const SizedBox(height: 16),
        _cashflowCard(account),
      ],
    );
  }

  Widget _wideBody(ProjectAccount account, bool compact) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(compact: false, account: account),
              _header(account, compact: false),
              const SizedBox(height: 20),
              _kpis(account),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 28, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(
                    children: [_schedule(account)],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 7,
                  child: ListView(
                    children: [
                      _ledger(account, compact: false),
                      const SizedBox(height: 16),
                      _cashflowCard(account),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar({required bool compact, required ProjectAccount account}) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Spacer(),
        if (!compact)
          OutlinedButton.icon(
            onPressed: () => showRecordPaymentDialog(
              context,
              flow: MoneyFlow.send,
              account: account,
              drafts: widget.drafts,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.completed,
              side: BorderSide(color: AppColors.completed.withValues(alpha: 0.45)),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.call_made, size: 16),
            label: const Text('send', style: TextStyle(letterSpacing: 0.4)),
          ),
      ],
    );
  }

  Widget _header(ProjectAccount account, {required bool compact}) {
    final label = [
      if (account.client.trim().isNotEmpty) account.client,
      if (account.project.trim().isNotEmpty) account.project,
    ].join(' / ');
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Text(
                label.toUpperCase(),
                style: TextStyle(color: AppColors.primary, fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 6),
            Text(
              'project ledger',
              style: TextStyle(
                color: AppColors.text,
                fontSize: compact ? 32 : 44,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => showRecordPaymentDialog(
            context,
            flow: MoneyFlow.receive,
            account: account,
            drafts: widget.drafts,
          ),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('receive payment', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _kpis(ProjectAccount account) {
    final draft = _linkedDraft(account);
    final contract = (draft?.totals.grandTotal ?? 0) > 0 ? draft!.totals.grandTotal : account.scheduled;
    final received = account.received;
    final pending = account.outstanding;
    final overdue = account.installments
        .where((item) => !item.isPaid && _isOverdue(item.dueAt))
        .fold<double>(0, (sum, item) => sum + item.outstanding);
    final pct = contract <= 0 ? null : (received / contract) * 100;
    final statusLabel = draft?.status.label ?? (pending <= 0.009 && received > 0 ? 'Settled' : 'Open');
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        final cards = [
          _KpiCard(
            label: 'Total Contract Value',
            value: inrCompact(contract),
            icon: Icons.request_quote_outlined,
            iconColor: AppColors.primary,
            footerIcon: Icons.arrow_upward,
            footer: statusLabel,
            footerColor: AppColors.completed,
          ),
          _KpiCard(
            label: 'Received',
            value: inrCompact(received),
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.completed,
            footerIcon: Icons.trending_up_rounded,
            footer: pct == null ? 'no schedule' : '${pct.toStringAsFixed(1)}% of total',
            footerColor: AppColors.completed,
          ),
          _KpiCard(
            label: 'Pending',
            value: inrCompact(pending),
            icon: Icons.hourglass_empty,
            iconColor: AppColors.down,
            footerIcon: overdue > 0.009 ? Icons.warning_amber_rounded : Icons.schedule,
            footer: overdue > 0.009 ? '${inr(overdue)} overdue' : (pending > 0.009 ? 'on schedule' : 'cleared'),
            footerColor: overdue > 0.009 ? AppColors.down : AppColors.muted,
          ),
          _KpiCard(
            label: 'Current Balance',
            value: inrCompact(account.balance),
            icon: Icons.account_balance_outlined,
            footer: 'Available cashflow',
            highlight: true,
          ),
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
        final rows = <List<Widget>>[];
        for (var i = 0; i < cards.length; i += columns) {
          rows.add(cards.sublist(i, i + columns > cards.length ? cards.length : i + columns));
        }
        return Column(
          children: [
            for (final row in rows) ...[
              Row(
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    Expanded(child: i < row.length ? row[i] : const SizedBox.shrink()),
                    if (i != columns - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _schedule(ProjectAccount account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Row(
            children: [
              const Expanded(child: Text('payment schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              if (widget.onEditSchedule != null)
                TextButton.icon(
                  onPressed: widget.onEditSchedule,
                  icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  label: Text('EDIT', style: TextStyle(color: AppColors.primary, letterSpacing: 1.3)),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: account.installments.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No collection schedule yet. Create one from an estimate T&C.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < account.installments.length; i++) ...[
                      _installmentRow(account, account.installments[i], last: i == account.installments.length - 1),
                      if (i != account.installments.length - 1)
                        Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.outline.withValues(alpha: 0.35)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _installmentRow(ProjectAccount account, PaymentInstallment item, {required bool last}) {
    final overdue = !item.isPaid && _isOverdue(item.dueAt);
    final scheduled = !item.isPaid && !overdue;
    final icon = item.isPaid
        ? Icons.check_circle
        : overdue
            ? Icons.warning_amber_rounded
            : last
                ? Icons.flag_outlined
                : Icons.schedule;
    final iconColor = item.isPaid
        ? AppColors.completed
        : overdue
            ? AppColors.down
            : AppColors.muted;
    final badge = item.isPaid
        ? 'Received'
        : overdue
            ? 'Overdue'
            : 'Scheduled';
    return Opacity(
      opacity: scheduled ? 0.72 : 1,
      child: Material(
        color: overdue ? AppColors.down.withValues(alpha: 0.06) : Colors.transparent,
        child: InkWell(
          onTap: item.isPaid ? null : () => showRecordPaymentDialog(context, flow: MoneyFlow.receive, installment: item, account: account, drafts: widget.drafts),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: iconColor.withValues(alpha: 0.12),
                      child: Icon(icon, color: iconColor),
                    ),
                    if (overdue)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.down,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.card, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        'Due ${_prettyDate(item.dueAt)} · ${item.percent.toStringAsFixed(0)}%',
                        style: TextStyle(color: overdue ? AppColors.down : AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(inr(item.amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isPaid
                            ? AppColors.completed.withValues(alpha: 0.16)
                            : overdue
                                ? AppColors.down
                                : AppColors.cardHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: TextStyle(
                          color: item.isPaid
                              ? AppColors.completed
                              : overdue
                                  ? AppColors.onPrimary
                                  : AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ledger(ProjectAccount account, {required bool compact}) {
    final entries = [
      for (final item in account.entries)
        if (_filter == _LedgerFilter.all ||
            (_filter == _LedgerFilter.income && item.flow == MoneyFlow.receive) ||
            (_filter == _LedgerFilter.expense && item.flow == MoneyFlow.send))
          item,
    ]..sort((a, b) => b.date.compareTo(a.date));
    final visible = entries.take(_shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 12),
          child: Row(
            children: [
              const Expanded(child: Text('ledger entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              PopupMenuButton<_LedgerFilter>(
                tooltip: 'Filter',
                initialValue: _filter,
                onSelected: (value) => setState(() {
                  _filter = value;
                  _shown = 8;
                }),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _LedgerFilter.all, child: Text('All')),
                  PopupMenuItem(value: _LedgerFilter.income, child: Text('Income')),
                  PopupMenuItem(value: _LedgerFilter.expense, child: Text('Expense')),
                ],
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.card,
                  child: Icon(Icons.filter_list, size: 18, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: entries.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No ledger entries yet. Record a received or sent payment.', style: TextStyle(color: AppColors.muted)),
                )
              : Column(
                  children: [
                    if (!compact) _ledgerHeader(),
                    for (var i = 0; i < visible.length; i++) ...[
                      _entryRow(visible[i], compact: compact),
                      if (i != visible.length - 1) Divider(height: 1, color: AppColors.outline.withValues(alpha: 0.28)),
                    ],
                    if (entries.length > visible.length)
                      TextButton(
                        onPressed: () => setState(() => _shown += 8),
                        child: Text(
                          'LOAD OLDER ENTRIES',
                          style: TextStyle(color: AppColors.primary, letterSpacing: 1.4),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _ledgerHeader() {
    return Container(
      color: AppColors.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text('DATE', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2))),
          Expanded(child: Text('DESCRIPTION', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2))),
          SizedBox(width: 88, child: Text('CATEGORY', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2))),
          SizedBox(
            width: 120,
            child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(PaymentEntry item, {required bool compact}) {
    final income = item.flow == MoneyFlow.receive;
    final title = item.note.isNotEmpty
        ? item.note
        : income
            ? (item.party.isEmpty ? 'Payment received' : 'Received from ${item.party}')
            : (item.party.isEmpty ? 'Payment sent' : 'Sent to ${item.party}');
    final subtitle = [
      item.method,
      if (item.party.isNotEmpty && item.note.isNotEmpty) item.party,
    ].join(' · ');
    final amount = '${income ? '+' : '-'}${inr(item.amount)}';
    final category = income ? 'Income' : 'Expense';
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${_prettyDate(item.date)}${subtitle.isEmpty ? '' : ' · $subtitle'}',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: TextStyle(color: income ? AppColors.completed : AppColors.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                _categoryPill(category),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(_prettyDate(item.date), style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(width: 88, child: Align(alignment: Alignment.centerLeft, child: _categoryPill(category))),
          SizedBox(
            width: 120,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: TextStyle(color: income ? AppColors.completed : AppColors.text, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.cardHover, borderRadius: BorderRadius.circular(99)),
      child: Text(label.toUpperCase(), style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 0.8)),
    );
  }

  Widget _cashflowCard(ProjectAccount account) {
    final draft = _linkedDraft(account);
    final contract = (draft?.totals.grandTotal ?? 0) > 0 ? draft!.totals.grandTotal : account.scheduled;
    final value = contract <= 0 ? 0.0 : (account.received / contract).clamp(0.0, 1.0);
    return Container(
      height: 160,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, color: AppColors.primary, size: 32),
          const SizedBox(height: 10),
          const Text('cashflow visualization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Received vs pending collections for this project.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.background,
              color: AppColors.completed,
            ),
          ),
        ],
      ),
    );
  }
}

enum _LedgerFilter { all, income, expense }

bool _isOverdue(DateTime dueAt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(dueAt.year, dueAt.month, dueAt.day).isBefore(today);
}

String _prettyDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.footer,
    this.footerIcon,
    this.footerColor,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? footer;
  final IconData? footerIcon;
  final Color? footerColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? AppColors.onPrimary : AppColors.text;
    final muted = highlight ? AppColors.onPrimary.withValues(alpha: 0.7) : AppColors.muted;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(), style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.2)),
              ),
              Icon(icon, size: 20, color: highlight ? fg : iconColor ?? AppColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (footerIcon != null) ...[
                  Icon(footerIcon, size: 14, color: highlight ? fg : footerColor ?? muted),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(footer!, style: TextStyle(color: highlight ? fg : footerColor ?? muted, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showRecordPaymentDialog(
  BuildContext context, {
  required MoneyFlow flow,
  PaymentInstallment? installment,
  ProjectAccount? account,
  List<EstimateDraft> drafts = const [],
}) async {
  final amount = TextEditingController(text: installment == null ? '' : installment.outstanding.toStringAsFixed(0));
  final party = TextEditingController(text: flow == MoneyFlow.receive ? (installment?.client ?? account?.client ?? '') : '');
  final note = TextEditingController();
  final clientField = TextEditingController(
    text: installment?.client ?? account?.client ?? (drafts.isEmpty ? '' : drafts.first.client),
  );
  final projectField = TextEditingController(
    text: installment?.project ?? account?.project ?? (drafts.isEmpty ? '' : drafts.first.project),
  );
  var method = 'UPI';
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(flow == MoneyFlow.receive ? 'Receive payment' : 'Send payment'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (installment == null && account == null) ...[
                TextField(controller: clientField, decoration: const InputDecoration(labelText: 'Client / project account')),
                const SizedBox(height: 12),
                TextField(controller: projectField, decoration: const InputDecoration(labelText: 'Project')),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: party,
                decoration: InputDecoration(labelText: flow == MoneyFlow.receive ? 'From' : 'To'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
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
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
            ],
            ),
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
  final client = (installment?.client ?? account?.client ?? clientField.text).trim();
  final project = (installment?.project ?? account?.project ?? projectField.text).trim();
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
