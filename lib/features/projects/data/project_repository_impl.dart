import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../../quotations/domain/quotation.dart';
import '../../service_requests/domain/service_request.dart';
import '../domain/project.dart';
import '../domain/project_activity.dart';
import '../domain/project_repository.dart';
import '../domain/project_status.dart';
import 'project_workspace.dart';
import 'project_workspace_store.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({
    TablesDB? tables,
    Functions? functions,
    AuditRepository? audit,
    ProjectWorkspaceStore? store,
    String? databaseId,
    String Function()? actorId,
    String Function()? actorName,
  })  : _tables = tables ?? AppwriteService.tables,
        _functions = functions ?? AppwriteService.functions,
        _audit = audit ?? AuditRepository(),
        _store = store ?? ProjectWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown'),
        _actorName = actorName ?? (() => 'Staff');

  final TablesDB _tables;
  final Functions _functions;
  final AuditRepository _audit;
  final ProjectWorkspaceStore _store;
  final String _databaseId;
  final String Function() _actorId;
  final String Function() _actorName;

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<AppResult<List<Project>>> getProjects({
    String? clientId,
    ProjectStatus? status,
    String? assignedArchitect,
    String? searchTerm,
  }) {
    return AppwriteService.guard(() async {
      final rows = await _store.list(
        clientId: clientId,
        status: status?.toAppwriteString(),
        assignedArchitect: assignedArchitect,
        searchTerm: searchTerm,
      );
      return [for (final row in rows) row.project];
    });
  }

  @override
  Future<AppResult<Project>> getProjectById(String id) {
    return AppwriteService.guard(() async => (await _store.getById(id)).project);
  }

  @override
  Future<AppResult<Project>> createProject({
    required String clientId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? serviceRequestId,
    String? quotationId,
    double? budget,
    String? assignedArchitect,
    List<String>? teamMembers,
    ProjectPriority? priority,
  }) {
    return AppwriteService.guard(() async {
      return _insertProject(
        clientId: clientId,
        title: title,
        startDate: startDate,
        endDate: endDate,
        description: description,
        serviceRequestId: serviceRequestId,
        quotationId: quotationId,
        budget: budget,
        assignedArchitect: assignedArchitect,
        teamMembers: teamMembers,
        priority: priority,
      );
    });
  }

  Future<Project> _insertProject({
    required String clientId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? serviceRequestId,
    String? quotationId,
    double? budget,
    String? assignedArchitect,
    List<String>? teamMembers,
    ProjectPriority? priority,
  }) async {
    if (!endDate.isAfter(startDate)) {
      throw AppwriteException('End date must be after start date', 400);
    }
    final now = _now;
    final draftNumber = await _nextProjectNumber();
    final row = await _tables.createRow(
      databaseId: _databaseId,
      tableId: AppwriteService.projectsCol,
      rowId: ID.unique(),
      data: {
        'projectNumber': draftNumber,
        'clientId': clientId,
        'serviceRequestId': ?serviceRequestId,
        'quotationId': ?quotationId,
        'title': title.trim(),
        'description': ?description?.trim(),
        'status': ProjectStatus.planning.value,
        'priority': ?priority?.value,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        'budget': ?budget,
        'spent': 0,
        'progress': 0,
        'assignedArchitect': ?assignedArchitect,
        'teamMembers': teamMembers ?? const <String>[],
        'workspaceJson': ProjectWorkspace().encode(),
        'createdAt': now,
        'updatedAt': now,
      },
      permissions: projectRowPermissions(clientId),
    );
    final numbered = _numberFromSequence(row.$sequence, fallback: draftNumber);
    models.Row saved = row;
    if (numbered != draftNumber) {
      saved = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.projectsCol,
        rowId: row.$id,
        data: {'projectNumber': numbered, 'updatedAt': now},
      );
    }
    await _audit.log(
      userId: _actorId(),
      action: 'project_created',
      metadata: {'id': saved.$id, 'clientId': clientId, 'projectNumber': numbered},
    );
    await _appendActivity(saved.$id, 'project_created', {'projectNumber': numbered});
    return Project.fromRow(saved.$id, saved.data);
  }

  @override
  Future<AppResult<Project>> updateProject(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final current = await _store.getById(id);
      final payload = Map<String, dynamic>.from(data)..['updatedAt'] = _now;
      if (payload['status'] != null) {
        final next = ProjectStatus.fromString(payload['status'].toString());
        if (current.project.status != next && !current.project.status.canTransitionTo(next)) {
          throw AppwriteException(
            'Cannot change status from ${current.project.status.value} to ${next.value}',
            400,
          );
        }
        payload['status'] = next.value;
      }
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.projectsCol,
        rowId: id,
        data: payload,
      );
      await _audit.log(userId: _actorId(), action: 'project_updated', metadata: {'id': id, ...payload});
      await _appendActivity(id, 'project_updated', payload);
      return Project.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Project>> updateProjectStatus(String id, ProjectStatus status) {
    return AppwriteService.guard(() async {
      final current = await _store.getById(id);
      if (current.project.status != status && !current.project.status.canTransitionTo(status)) {
        throw AppwriteException(
          'Cannot change status from ${current.project.status.value} to ${status.value}',
          400,
        );
      }
      final patch = <String, dynamic>{
        'status': status.value,
        'updatedAt': _now,
        if (status == ProjectStatus.inProgress && current.project.actualStartDate == null)
          'actualStartDate': _now,
        if (status == ProjectStatus.completed) 'actualEndDate': _now,
      };
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.projectsCol,
        rowId: id,
        data: patch,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'project_status_changed',
        metadata: {'id': id, 'from': current.project.status.value, 'to': status.value},
      );
      await _appendActivity(id, 'status_changed', {'from': current.project.status.value, 'to': status.value});
      return Project.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Project>> recalculateProgress(String id) {
    return AppwriteService.guard(() async => _recalculate(id));
  }

  @override
  Future<AppResult<Project>> convertFromServiceRequest(String serviceRequestId) {
    return AppwriteService.guard(() async {
      final requestRow = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: serviceRequestId,
      );
      final request = ServiceRequest.fromRow(requestRow.$id, requestRow.data);
      if (request.status != ServiceRequestStatus.approved) {
        throw AppwriteException('Only approved service requests can become projects', 400);
      }
      final quote = await _approvedQuotation(serviceRequestId);
      final project = await _insertProject(
        clientId: request.clientId,
        title: request.title,
        description: request.description,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        serviceRequestId: request.id,
        quotationId: quote?.id,
        budget: quote?.total,
        assignedArchitect: request.assignedTo,
        priority: ProjectPriority.tryParse(request.priority?.value),
      );
      await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.serviceRequestsCol,
        rowId: request.id,
        data: {
          'status': ServiceRequestStatus.converted.value,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_request_converted_to_project',
        metadata: {
          'serviceRequestId': request.id,
          'projectId': project.id,
          'quotationId': quote?.id,
        },
      );
      await _appendActivity(project.id, 'project_created_from_request', {
        'serviceRequestId': request.id,
      });
      return project;
    });
  }

  @override
  Future<AppResult<Project>> assignArchitect(String id, String architectId) {
    return AppwriteService.guard(() async {
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.projectsCol,
        rowId: id,
        data: {'assignedArchitect': architectId, 'updatedAt': _now},
      );
      await _audit.log(
        userId: _actorId(),
        action: 'project_architect_assigned',
        metadata: {'id': id, 'architectId': architectId},
      );
      await _appendActivity(id, 'architect_assigned', {'architectId': architectId});
      return Project.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Project>> addTeamMember(String id, String userId) {
    return AppwriteService.guard(() async {
      final current = await _store.getById(id);
      final members = [...current.project.teamMembers];
      if (!members.contains(userId)) members.add(userId);
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.projectsCol,
        rowId: id,
        data: {'teamMembers': members, 'updatedAt': _now},
      );
      await _audit.log(
        userId: _actorId(),
        action: 'project_team_member_added',
        metadata: {'id': id, 'userId': userId},
      );
      await _appendActivity(id, 'team_member_added', {'userId': userId});
      return Project.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Project>> removeTeamMember(String id, String userId) {
    return AppwriteService.guard(() async {
      final current = await _store.getById(id);
      final members = [...current.project.teamMembers]..remove(userId);
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.projectsCol,
        rowId: id,
        data: {'teamMembers': members, 'updatedAt': _now},
      );
      await _audit.log(
        userId: _actorId(),
        action: 'project_team_member_removed',
        metadata: {'id': id, 'userId': userId},
      );
      await _appendActivity(id, 'team_member_removed', {'userId': userId});
      return Project.fromRow(row.$id, row.data);
    });
  }

  Future<Project> _recalculate(String id) async {
    final snap = await _store.getById(id);
    final progress = progressFromMilestones([
      for (final item in snap.workspace.milestones) (completed: item.isComplete, weight: item.weight),
    ]);
    final saved = await _store.saveWorkspace(id, snap.workspace, projectPatch: {'progress': progress});
    return saved.project;
  }

  Future<void> _appendActivity(String projectId, String action, Map<String, dynamic> metadata) async {
    try {
      final snap = await _store.getById(projectId);
      final activity = ProjectActivity(
        id: ID.unique(),
        projectId: projectId,
        actorId: _actorId(),
        actorName: _actorName(),
        action: action,
        metadata: metadata.isEmpty ? null : metadata.toString(),
        createdAt: DateTime.now().toUtc(),
      );
      snap.workspace.activities.insert(0, activity);
      await _store.saveWorkspace(projectId, snap.workspace);
    } catch (_) {}
  }

  Future<String> _nextProjectNumber() async {
    try {
      final execution = await _functions.createExecution(functionId: AppwriteService.generateProjectNumberFn);
      final body = execution.responseBody.trim();
      if (body.startsWith('{')) {
        final match = RegExp(r'PRJ-\d{4}-\d+').firstMatch(body);
        if (match != null) return match.group(0)!;
      }
      if (body.startsWith('PRJ-')) return body;
    } catch (_) {}
    final year = DateTime.now().year;
    return 'PRJ-$year-draft';
  }

  String _numberFromSequence(String sequence, {required String fallback}) {
    final parsed = int.tryParse(sequence);
    if (parsed == null || parsed <= 0) return fallback;
    final year = DateTime.now().year;
    return 'PRJ-$year-${parsed.toString().padLeft(4, '0')}';
  }

  Future<Quotation?> _approvedQuotation(String serviceRequestId) async {
    final page = await _tables.listRows(
      databaseId: _databaseId,
      tableId: AppwriteService.messagesCol,
      queries: [
        Query.equal('serviceRequestId', serviceRequestId),
        Query.equal('senderRole', 'quotation'),
        Query.limit(50),
      ],
    );
    Quotation? approved;
    for (final row in page.rows) {
      final quote = Quotation.tryParseMessage(
        row.$id,
        row.data['message']?.toString() ?? '',
        sequence: row.$sequence,
      );
      if (quote == null) continue;
      if (quote.status == QuotationStatus.approved) {
        approved = quote;
        break;
      }
      approved ??= quote;
    }
    return approved;
  }
}
