import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/service_requests/data/service_request_repository_impl.dart';
import 'package:biconcept/features/service_requests/domain/service_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Tables extends Mock implements TablesDB {}

class _Storage extends Mock implements Storage {}

class _Teams extends Mock implements Teams {}

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

models.Row _row(String id, Map<String, dynamic> data, {String sequence = '1'}) => models.Row(
      $id: id,
      $sequence: sequence,
      $tableId: 'service_requests',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

void main() {
  late _Tables tables;
  late _Audit audit;
  late ServiceRequestRepositoryImpl repo;

  setUp(() {
    tables = _Tables();
    audit = _Audit();
    repo = ServiceRequestRepositoryImpl(
      tables: tables,
      storage: _Storage(),
      teams: _Teams(),
      audit: audit,
      databaseId: 'db',
      actorId: () => 'staff-1',
    );
  });

  test('status transitions are enforced', () {
    expect(ServiceRequestStatus.draft.canTransitionTo(ServiceRequestStatus.submitted), isTrue);
    expect(ServiceRequestStatus.submitted.canTransitionTo(ServiceRequestStatus.underReview), isTrue);
    expect(ServiceRequestStatus.underReview.canTransitionTo(ServiceRequestStatus.quoted), isTrue);
    expect(ServiceRequestStatus.quoted.canTransitionTo(ServiceRequestStatus.approved), isTrue);
    expect(ServiceRequestStatus.approved.canTransitionTo(ServiceRequestStatus.converted), isTrue);
    expect(ServiceRequestStatus.draft.canTransitionTo(ServiceRequestStatus.approved), isFalse);
    expect(ServiceRequestStatus.converted.canTransitionTo(ServiceRequestStatus.draft), isFalse);
  });

  test('createServiceRequest sets client-owned permissions, lead, and logs', () async {
    when(
      () => tables.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(total: 0, rows: const []),
    );
    when(
      () => tables.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: 'enquiries',
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      expect(data['source'], 'client_portal');
      expect(data['status'], 'new');
      return _row('lead-1', data, sequence: '2');
    });
    when(
      () => tables.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: 'service_requests',
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      expect(data['status'], 'submitted');
      expect(data['enquiryId'], 'lead-1');
      expect(invocation.namedArguments[#permissions], isNull);
      return _row('sr1', data);
    });
    final result = await repo.createServiceRequest(
      clientId: 'client-1',
      title: 'Kitchen remodel',
      description: 'Need a layout',
      clientName: 'Asha',
      clientEmail: 'asha@example.com',
      clientPhone: '+919876543210',
    );
    expect(result.dataOrNull?.status, ServiceRequestStatus.submitted);
    expect(result.dataOrNull?.clientId, 'client-1');
    expect(result.dataOrNull?.enquiryId, 'lead-1');
    expect(audit.events, ['service_request_created']);
  });

  test('invalid status change is rejected', () async {
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer(
      (_) async => _row('sr1', {
        'clientId': 'client-1',
        'title': 'Kitchen',
        'description': 'layout',
        'status': 'draft',
        'attachments': const [],
      }),
    );
    final result = await repo.updateServiceRequest('sr1', {'status': 'approved'});
    expect(result.isFailure, isTrue);
  });

  test('lists can scope by clientId', () async {
    when(
      () => tables.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 1,
        rows: [
          _row('sr1', {
            'clientId': 'client-1',
            'title': 'Kitchen',
            'description': 'layout',
            'status': 'submitted',
            'attachments': const [],
          }),
        ],
      ),
    );
    final result = await repo.getServiceRequests(clientId: 'client-1');
    expect(result.dataOrNull?.single.clientId, 'client-1');
  });
}
