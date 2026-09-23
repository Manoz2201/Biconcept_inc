import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../domain/itc_ledger_entry.dart';

class ComplianceSummaryCard extends StatelessWidget {
  const ComplianceSummaryCard({super.key, required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = Colors.blueGrey});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: tone.withValues(alpha: 0.12),
      side: BorderSide(color: tone.withValues(alpha: 0.4)),
    );
  }
}

class ItcStatusBadge extends StatelessWidget {
  const ItcStatusBadge({super.key, required this.status});

  final ITCStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      ITCStatus.claimed => Colors.green,
      ITCStatus.reversed => Colors.orange,
      ITCStatus.ineligible => Colors.red,
      ITCStatus.eligible => Colors.teal,
      ITCStatus.pending => Colors.blueGrey,
    };
    return StatusChip(label: status.label, tone: tone);
  }
}

class MatchStatusBadge extends StatelessWidget {
  const MatchStatusBadge({super.key, required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      MatchStatus.exactMatch || MatchStatus.matched => Colors.green,
      MatchStatus.suggestedMatch => Colors.amber,
      MatchStatus.mismatched => Colors.red,
      MatchStatus.missingIn2b || MatchStatus.missingInBooks => Colors.orange,
    };
    return StatusChip(label: status.label, tone: tone);
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key});

  final double value;

  @override
  Widget build(BuildContext context) => Text(formatMoney(value), style: const TextStyle(fontWeight: FontWeight.w600));
}
