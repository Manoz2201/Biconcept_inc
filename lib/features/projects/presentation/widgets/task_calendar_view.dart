import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/task.dart';

class TaskCalendarView extends StatefulWidget {
  const TaskCalendarView({super.key, required this.tasks, this.onOpen});

  final List<Task> tasks;
  final ValueChanged<Task>? onOpen;

  @override
  State<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends State<TaskCalendarView> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(_month);
    final selectedTasks = [
      for (final task in widget.tasks)
        if (task.dueDate != null && _sameDay(task.dueDate!, _selected)) task,
    ];
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(child: Text('${_month.month}/${_month.year}', textAlign: TextAlign.center)),
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            children: [
              for (final day in days)
                InkWell(
                  onTap: day == null ? null : () => setState(() => _selected = day),
                  child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _sameDay(day, _selected) ? AppColors.primary.withValues(alpha: 0.2) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      day == null ? '' : '${day.day}',
                      style: TextStyle(
                        color: _hasTask(day) ? AppColors.primary : AppColors.text,
                        fontWeight: _hasTask(day) ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final task in selectedTasks)
            ListTile(
              title: Text(task.title),
              subtitle: Text(task.priority?.label ?? task.status.label),
              onTap: widget.onOpen == null ? null : () => widget.onOpen!(task),
            ),
        ],
      ),
    );
  }

  bool _hasTask(DateTime? day) {
    if (day == null) return false;
    return widget.tasks.any((task) => task.dueDate != null && _sameDay(task.dueDate!, day));
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime?> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return [
      for (var i = 0; i < first.weekday % 7; i++) null,
      for (var day = 1; day <= last.day; day++) DateTime(month.year, month.month, day),
    ];
  }
}
