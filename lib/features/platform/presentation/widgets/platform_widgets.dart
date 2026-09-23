import 'package:flutter/material.dart';

import '../../../analytics/domain/analytics_models.dart';
import '../../../backup/domain/backup_models.dart';
import '../../../currency/domain/money.dart';
import '../../../payment_schedules/domain/payment_schedule.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, this.onTap, this.tone});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: tone)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MoneyDisplay extends StatelessWidget {
  const MoneyDisplay(this.money, {super.key});

  final Money money;

  @override
  Widget build(BuildContext context) => Text(money.format(), style: const TextStyle(fontWeight: FontWeight.w600));
}

class ScheduleStatusBadge extends StatelessWidget {
  const ScheduleStatusBadge({super.key, required this.status});

  final PaymentScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PaymentScheduleStatus.completed => Colors.teal,
      PaymentScheduleStatus.failed || PaymentScheduleStatus.cancelled => Colors.redAccent,
      PaymentScheduleStatus.pendingApproval => Colors.orange,
      PaymentScheduleStatus.scheduled || PaymentScheduleStatus.approved => Colors.blue,
      _ => Colors.blueGrey,
    };
    return Chip(label: Text(status.label), visualDensity: VisualDensity.compact, backgroundColor: color.withValues(alpha: 0.2));
  }
}

class BackupStatusBadge extends StatelessWidget {
  const BackupStatusBadge({super.key, required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) => Chip(label: Text(status.label), visualDensity: VisualDensity.compact);
}

class KpiStatusDot extends StatelessWidget {
  const KpiStatusDot({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'on_track' => Colors.teal,
      'at_risk' => Colors.orange,
      'off_track' => Colors.redAccent,
      _ => Colors.blueGrey,
    };
    return CircleAvatar(radius: 6, backgroundColor: color);
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.queueCount});

  final int queueCount;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(queueCount == 0 ? 'You are offline. Changes will queue.' : 'Offline · $queueCount queued actions'),
      actions: const [SizedBox.shrink()],
    );
  }
}

class FunnelList extends StatelessWidget {
  const FunnelList({super.key, required this.data});

  final FunnelData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final step in data.steps)
          ListTile(
            title: Text(step.stepName),
            trailing: Text('${step.count} · ${(step.conversionFromStart * 100).toStringAsFixed(0)}%'),
          ),
      ],
    );
  }
}

Future<bool> confirmPhrase(BuildContext context, {required String title, required String phrase}) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: 'Type $phrase to confirm'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim() == phrase), child: const Text('Confirm')),
      ],
    ),
  );
  return ok == true;
}
