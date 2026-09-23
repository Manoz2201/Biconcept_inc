import 'dart:convert';

import '../../change_requests/domain/change_request.dart';
import '../../documents/domain/project_document.dart';
import '../../timesheets/domain/timesheet.dart';
import '../domain/milestone.dart';
import '../domain/project_activity.dart';
import '../domain/task.dart';

class ProjectWorkspace {
  ProjectWorkspace({
    List<Milestone>? milestones,
    List<Task>? tasks,
    List<Timesheet>? timesheets,
    List<ProjectDocument>? documents,
    List<ChangeRequest>? changeRequests,
    List<ProjectActivity>? activities,
  })  : milestones = milestones ?? <Milestone>[],
        tasks = tasks ?? <Task>[],
        timesheets = timesheets ?? <Timesheet>[],
        documents = documents ?? <ProjectDocument>[],
        changeRequests = changeRequests ?? <ChangeRequest>[],
        activities = activities ?? <ProjectActivity>[];

  final List<Milestone> milestones;
  final List<Task> tasks;
  final List<Timesheet> timesheets;
  final List<ProjectDocument> documents;
  final List<ChangeRequest> changeRequests;
  final List<ProjectActivity> activities;

  factory ProjectWorkspace.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ProjectWorkspace();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ProjectWorkspace();
      final data = Map<String, dynamic>.from(decoded);
      return ProjectWorkspace(
        milestones: _list(data['milestones'], Milestone.fromJson),
        tasks: _list(data['tasks'], Task.fromJson),
        timesheets: _list(data['timesheets'], Timesheet.fromJson),
        documents: _list(data['documents'], ProjectDocument.fromJson),
        changeRequests: _list(data['changeRequests'], ChangeRequest.fromJson),
        activities: _list(data['activities'], ProjectActivity.fromJson),
      );
    } catch (_) {
      return ProjectWorkspace();
    }
  }

  String encode() => jsonEncode({
        'milestones': [for (final item in milestones) item.toJson()],
        'tasks': [for (final item in tasks) item.toJson()],
        'timesheets': [for (final item in timesheets) item.toJson()],
        'documents': [for (final item in documents) item.toJson()],
        'changeRequests': [for (final item in changeRequests) item.toJson()],
        'activities': [for (final item in activities) item.toJson()],
      });

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map) parse(Map<String, dynamic>.from(item)),
    ];
  }
}
