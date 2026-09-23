import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/milestone.dart';

class MilestoneTimeline extends StatelessWidget {
  const MilestoneTimeline({
    super.key,
    required this.milestones,
    this.readOnly = false,
    this.onEdit,
    this.onStatus,
    this.onDelete,
  });

  final List<Milestone> milestones;
  final bool readOnly;
  final ValueChanged<Milestone>? onEdit;
  final void Function(Milestone milestone, MilestoneStatus status)? onStatus;
  final ValueChanged<Milestone>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return Text('No milestones yet', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      children: [
        for (final item in milestones)
          ListTile(
            leading: Icon(
              item.isComplete ? Icons.check_circle : Icons.flag_outlined,
              color: item.effectiveStatus == MilestoneStatus.overdue ? AppColors.down : AppColors.primary,
            ),
            title: Text(item.title),
            subtitle: Text('${item.effectiveStatus.label} · due ${formatDisplayDate(item.dueDate)}'),
            trailing: readOnly
                ? null
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call(item);
                      if (value == 'done') onStatus?.call(item, MilestoneStatus.completed);
                      if (value == 'delete') onDelete?.call(item);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'done', child: Text('Mark complete')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
          ),
      ],
    );
  }
}
