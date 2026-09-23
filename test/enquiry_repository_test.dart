import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/enquiries/data/enquiry_repository_impl.dart';
import 'package:biconcept/features/enquiries/domain/enquiry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Tables extends Mock implements TablesDB {}

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

models.Row _row(String id, Map<String, dynamic> data) => models.Row(
      $id: id,
      $sequence: '1',
      $tableId: 'enquiries',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

void main() {
  late _Tables tables;
  late _Audit audit;
  late EnquiryRepositoryImpl repo;

  setUp(() {
    tables = _Tables();
    audit = _Audit();
    repo = EnquiryRepositoryImpl(
      tables: tables,
      audit: audit,
      databaseId: 'db',
      actorId: () => 'public',
    );
  });

  test('submitEnquiry stores status new and logs enquiry_submitted', () async {
    when(
      () => tables.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      return _row('e1', data);
    });
    final result = await repo.submitEnquiry(
      name: 'Asha',
      email: 'asha@example.com',
      message: 'Need a 3BHK interior',
    );
    expect(result.dataOrNull?.status, EnquiryStatus.newLead);
    expect(audit.events, ['enquiry_submitted']);
  });

  test('updateEnquiryStatus, assign, and note each write audit events', () async {
    when(
      () => tables.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      return _row('e1', {
        'name': 'Asha',
        'email': 'asha@example.com',
        'message': 'hi',
        'status': data['status'] ?? 'new',
        'assignedTo': data['assignedTo'],
        'notes': data['notes'],
      });
    });
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer(
      (_) async => _row('e1', {
        'name': 'Asha',
        'email': 'asha@example.com',
        'message': 'hi',
        'status': 'new',
        'notes': '',
      }),
    );

    await repo.updateEnquiryStatus('e1', EnquiryStatus.contacted);
    await repo.assignEnquiry('e1', 'acc-1');
    await repo.addEnquiryNote('e1', 'Called the client');
    expect(
      audit.events,
      ['enquiry_status_changed', 'enquiry_assigned', 'enquiry_note_added'],
    );
  });
}
