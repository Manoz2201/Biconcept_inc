import 'package:biconcept/features/projects/domain/milestone.dart';
import 'package:biconcept/features/projects/domain/project_activity.dart';
import 'package:biconcept/features/projects/domain/task.dart';
import 'package:biconcept/features/projects/presentation/widgets/milestone_timeline.dart';
import 'package:biconcept/features/projects/presentation/widgets/project_activity_feed.dart';
import 'package:biconcept/features/projects/presentation/widgets/task_calendar_view.dart';
import 'package:biconcept/features/projects/presentation/widgets/task_kanban_board.dart';
import 'package:biconcept/features/projects/presentation/widgets/task_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TaskKanbanBoard shows status columns and task titles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskKanbanBoard(
            tasks: const [
              Task(id: 't1', projectId: 'p1', title: 'Draw plans', status: TaskStatus.todo, reporterId: 'u1'),
              Task(id: 't2', projectId: 'p1', title: 'Site visit', status: TaskStatus.inProgress, reporterId: 'u1'),
            ],
            onStatus: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Draw plans'), findsOneWidget);
    expect(find.text('Site visit'), findsOneWidget);
  });

  testWidgets('TaskListView groups by status and supports inline change', (tester) async {
    TaskStatus? next;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskListView(
            tasks: const [
              Task(id: 't1', projectId: 'p1', title: 'Draw plans', status: TaskStatus.todo, reporterId: 'u1'),
            ],
            onStatus: (task, status) => next = status,
          ),
        ),
      ),
    );
    expect(find.text('To do'), findsWidgets);
    await tester.tap(find.byType(DropdownButton<TaskStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress').last);
    await tester.pumpAndSettle();
    expect(next, TaskStatus.inProgress);
  });

  testWidgets('TaskCalendarView lists tasks due on the selected day', (tester) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCalendarView(
            tasks: [
              Task(
                id: 't1',
                projectId: 'p1',
                title: 'Due today',
                status: TaskStatus.todo,
                reporterId: 'u1',
                dueDate: DateTime(today.year, today.month, today.day),
                priority: TaskPriority.high,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('MilestoneTimeline shows completion and overdue state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MilestoneTimeline(
            readOnly: true,
            milestones: [
              Milestone(
                id: 'm1',
                projectId: 'p1',
                title: 'Concept',
                dueDate: DateTime.utc(2020, 1, 1),
                status: MilestoneStatus.pending,
              ),
              Milestone(
                id: 'm2',
                projectId: 'p1',
                title: 'Drawings',
                dueDate: DateTime.utc(2026, 12, 1),
                status: MilestoneStatus.completed,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.text('Concept'), findsOneWidget);
    expect(find.text('Drawings'), findsOneWidget);
  });

  testWidgets('ProjectActivityFeed keeps given chronological order', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProjectActivityFeed(
            activities: [
              ProjectActivity(
                id: 'a2',
                projectId: 'p1',
                actorId: 'u1',
                actorName: 'Ada',
                action: 'task_created',
              ),
              ProjectActivity(
                id: 'a1',
                projectId: 'p1',
                actorId: 'u1',
                actorName: 'Ada',
                action: 'project_created',
              ),
            ],
          ),
        ),
      ),
    );
    final first = tester.getTopLeft(find.text('task created'));
    final second = tester.getTopLeft(find.text('project created'));
    expect(first.dy, lessThan(second.dy));
  });
}
