import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/messaging/data/message_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Tables extends Mock implements TablesDB {}

class _Storage extends Mock implements Storage {}

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
      $tableId: 'service_request_messages',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

void main() {
  late _Tables tables;
  late _Audit audit;
  late MessageRepositoryImpl repo;

  setUp(() {
    tables = _Tables();
    audit = _Audit();
    repo = MessageRepositoryImpl(
      tables: tables,
      storage: _Storage(),
      audit: audit,
      databaseId: 'db',
      actorId: () => 'client-1',
      actorName: () => 'Asha',
      actorRole: () => 'client',
    );
  });

  test('getMessages filters quotation records and orders chat', () async {
    when(
      () => tables.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 2,
        rows: [
          _row('m1', {
            'serviceRequestId': 'sr1',
            'senderId': 'client-1',
            'senderRole': 'client',
            'senderName': 'Asha',
            'message': 'Hello',
            'isRead': true,
          }),
          _row('q1', {
            'serviceRequestId': 'sr1',
            'senderId': 'staff-1',
            'senderRole': 'quotation',
            'senderName': 'QT-2026-001',
            'message': '{}',
            'isRead': false,
          }),
        ],
      ),
    );
    final result = await repo.getMessages('sr1');
    expect(result.dataOrNull?.length, 1);
    expect(result.dataOrNull?.single.message, 'Hello');
  });

  test('unread count ignores own messages and quotation rows', () async {
    when(
      () => tables.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 3,
        rows: [
          _row('m1', {'senderRole': 'admin', 'senderId': 'staff-1', 'isRead': false}),
          _row('m2', {'senderRole': 'client', 'senderId': 'client-1', 'isRead': false}),
          _row('q1', {'senderRole': 'quotation', 'senderId': 'staff-1', 'isRead': false}),
        ],
      ),
    );
    final result = await repo.getUnreadCount('sr1');
    expect(result.dataOrNull, 1);
  });
}
