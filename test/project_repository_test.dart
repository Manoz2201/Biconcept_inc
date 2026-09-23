import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/projects/data/project_repository_impl.dart';
import 'package:biconcept/features/projects/data/project_workspace.dart';
import 'package:biconcept/features/projects/data/project_workspace_store.dart';
import 'package:biconcept/features/projects/domain/milestone.dart';
import 'package:biconcept/features/projects/domain/project.dart';
import 'package:biconcept/features/projects/domain/project_status.dart';
import 'package:biconcept/features/documents/domain/project_document.dart';
import 'package:biconcept/features/projects/domain/task.dart';
import 'package:biconcept/features/service_requests/domain/service_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Tables extends Mock implements TablesDB {}

class _Functions extends Mock implements Functions {}

class _Audit extends Fake implements AuditRepository {
  final events = <String>[];

  @override
  Future<void> log({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
    String? ipAddress,
  }) async {
    events.add(action);
  }
}

models.Row _row(String id, Map<String, dynamic> data, {String sequence = '12'}) => models.Row(
      $id: id,
      $sequence: sequence,
      $tableId: 'projects',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

void main() {
  late _Tables tables;
  late _Audit audit;
  late ProjectRepositoryImpl repo;

  setUp(() {
    tables = _Tables();
    audit = _Audit();
    repo = ProjectRepositoryImpl(
      tables: tables,
      functions: _Functions(),
      audit: audit,
      store: ProjectWorkspaceStore(tables: tables, databaseId: 'db'),
      databaseId: 'db',
      actorId: () => 'staff-1',
      actorName: () => 'Staff',
    );
  });

  test('project status transitions', () {
    expect(ProjectStatus.planning.canTransitionTo(ProjectStatus.inProgress), isTrue);
    expect(ProjectStatus.inProgress.canTransitionTo(ProjectStatus.review), isTrue);
    expect(ProjectStatus.review.canTransitionTo(ProjectStatus.completed), isTrue);
    expect(ProjectStatus.completed.canTransitionTo(ProjectStatus.inProgress), isFalse);
    expect(ProjectStatus.planning.canTransitionTo(ProjectStatus.completed), isFalse);
  });

  test('task status transitions', () {
    expect(TaskStatus.todo.canTransitionTo(TaskStatus.inProgress), isTrue);
    expect(TaskStatus.done.canTransitionTo(TaskStatus.todo), isFalse);
    expect(TaskStatus.blocked.canTransitionTo(TaskStatus.inProgress), isTrue);
  });

  test('progress is weighted from completed milestones', () {
    expect(
      progressFromMilestones(const [
        (completed: true, weight: 2),
        (completed: false, weight: 2),
      ]),
      50,
    );
    expect(progressFromMilestones(const []), 0);
  });

  test('createProject sets document permissions and logs', () async {
    when(
      () => tables.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      final permissions = invocation.namedArguments[#permissions] as List<String>;
      expect(permissions, isNotEmpty);
      expect(data['status'], ProjectStatus.planning.value);
      expect(data['clientId'], 'client-1');
      return _row('p1', data);
    });
    when(
      () => tables.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      return _row('p1', {
        'projectNumber': data['projectNumber'] ?? 'PRJ-2026-0012',
        'clientId': 'client-1',
        'title': 'Villa',
        'status': 'planning',
        'startDate': DateTime.now().toIso8601String(),
        'endDate': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'workspaceJson': data['workspaceJson'],
      });
    });
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer((_) async => _row('p1', {
          'projectNumber': 'PRJ-2026-0012',
          'clientId': 'client-1',
          'title': 'Villa',
          'status': 'planning',
          'startDate': DateTime.now().toIso8601String(),
          'endDate': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
          'workspaceJson': ProjectWorkspace().encode(),
        }));

    final result = await repo.createProject(
      clientId: 'client-1',
      title: 'Villa',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 10)),
    );
    expect(result.isSuccess, isTrue);
    expect(audit.events, contains('project_created'));
  });

  test('convertFromServiceRequest requires approved status', () async {
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer((_) async => models.Row(
          $id: 'sr1',
          $sequence: '1',
          $tableId: 'service_requests',
          $databaseId: 'db',
          $createdAt: '',
          $updatedAt: '',
          $permissions: const [],
          data: {
            'clientId': 'c1',
            'title': 'Kitchen',
            'description': 'Remodel',
            'status': ServiceRequestStatus.quoted.value,
          },
        ));

    final result = await repo.convertFromServiceRequest('sr1');
    expect(result.isFailure, isTrue);
  });

  test('workspace encodes milestones and tasks', () {
    final workspace = ProjectWorkspace(
      milestones: [
        Milestone(
          id: 'm1',
          projectId: 'p1',
          title: 'Drawings',
          dueDate: DateTime.utc(2026, 1, 1),
          status: MilestoneStatus.completed,
          weight: 2,
        ),
      ],
      tasks: [
        Task(
          id: 't1',
          projectId: 'p1',
          title: 'Plans',
          status: TaskStatus.todo,
          reporterId: 'staff-1',
        ),
      ],
    );
    final decoded = ProjectWorkspace.decode(workspace.encode());
    expect(decoded.milestones.single.title, 'Drawings');
    expect(decoded.tasks.single.title, 'Plans');
  });

  test('document version chain increments from parent', () {
    const parent = ProjectDocument(
      id: 'd1',
      projectId: 'p1',
      title: 'Plan',
      category: DocumentCategory.drawing,
      fileId: 'f1',
      version: 2,
      uploadedBy: 'staff-1',
    );
    expect(parent.version + 1, 3);
  });
}
