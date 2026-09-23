import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/task.dart';

class TaskKanbanBoard extends StatelessWidget {
  const TaskKanbanBoard({super.key, required this.tasks, required this.onStatus});

  final List<Task> tasks;
  final void Function(Task task, TaskStatus status) onStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in TaskStatus.values)
            _Column(
              status: status,
              tasks: [for (final task in tasks) if (task.status == status) task],
              onAccept: (task) => onStatus(task, status),
            ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.status, required this.tasks, required this.onAccept});

  final TaskStatus status;
  final List<Task> tasks;
  final ValueChanged<Task> onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        return Container(
          width: 240,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: candidate.isEmpty ? AppColors.card : AppColors.cardHover,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(status.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final task in tasks)
                LongPressDraggable<Task>(
                  data: task,
                  feedback: Material(
                    color: AppColors.cardHover,
                    child: SizedBox(width: 220, child: ListTile(title: Text(task.title))),
                  ),
                  child: Card(
                    child: ListTile(
                      dense: true,
                      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        if (task.priority != null) task.priority!.label,
                        if (task.dueDate != null) '${task.dueDate!.day}/${task.dueDate!.month}',
                      ].join(' · ')),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
