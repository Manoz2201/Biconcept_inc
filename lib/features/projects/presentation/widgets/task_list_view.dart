import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/task.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({super.key, required this.tasks, this.onStatus, this.onOpen, this.readOnly = false});

  final List<Task> tasks;
  final void Function(Task task, TaskStatus status)? onStatus;
  final ValueChanged<Task>? onOpen;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Text('No tasks yet', style: TextStyle(color: AppColors.muted));
    }
    final grouped = {for (final status in TaskStatus.values) status: <Task>[]};
    for (final task in tasks) {
      grouped[task.status]!.add(task);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final status in TaskStatus.values)
          if (grouped[status]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(status.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final task in grouped[status]!)
              ListTile(
                onTap: onOpen == null ? null : () => onOpen!(task),
                title: Text(task.title),
                subtitle: Text(task.assigneeId ?? 'Unassigned'),
                trailing: readOnly
                    ? Text(task.status.label)
                    : DropdownButton<TaskStatus>(
                        value: task.status,
                        items: [
                          for (final item in TaskStatus.values)
                            DropdownMenuItem(value: item, child: Text(item.label)),
                        ],
                        onChanged: (value) {
                          if (value != null) onStatus?.call(task, value);
                        },
                      ),
              ),
          ],
      ],
    );
  }
}
