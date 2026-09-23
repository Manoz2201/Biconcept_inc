import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/quotations/data/quotation_repository_impl.dart';
import 'package:biconcept/features/quotations/domain/quotation.dart';
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

models.Row _row(String id, Map<String, dynamic> data, {String sequence = '7'}) => models.Row(
      $id: id,
      $sequence: sequence,
      $tableId: 'service_request_messages',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

Quotation _sample({QuotationStatus status = QuotationStatus.draft, int revision = 0, String id = 'q1'}) {
  return Quotation(
    id: id,
    serviceRequestId: 'sr1',
    clientId: 'client-1',
    quotationNumber: 'QT-2026-007',
    title: 'Interior',
    items: const [QuotationLineItem(description: 'Design', quantity: 1, unitPrice: 1000)],
    subtotal: 1000,
    taxAmount: 180,
    total: 1180,
    validUntil: DateTime.now().add(const Duration(days: 10)),
    status: status,
    revisionNumber: revision,
  );
}

void main() {
  test('line items calculate GST totals', () {
    const items = [
      QuotationLineItem(description: 'Design', quantity: 2, unitPrice: 1000),
      QuotationLineItem(description: 'Site', quantity: 1, unitPrice: 500),
    ];
    final totals = QuotationTotals.fromItems(items, taxRate: 18);
    expect(items.first.total, 2000);
    expect(totals.subtotal, 2500);
    expect(totals.taxAmount, 450);
    expect(totals.total, 2950);
  });

  test('quotation number uses sequence padding', () {
    expect(Quotation.numberFromSequence('7', DateTime(2026, 9, 12)), 'QT-2026-007');
    expect(Quotation.numberFromSequence('12', DateTime(2026, 1, 1)), 'QT-2026-012');
  });

  late _Tables tables;
  late _Audit audit;
  late QuotationRepositoryImpl repo;

  setUp(() {
    tables = _Tables();
    audit = _Audit();
    repo = QuotationRepositoryImpl(
      tables: tables,
      audit: audit,
      databaseId: 'db',
      actorId: () => 'staff-1',
    );
  });

  test('createQuotation numbers from sequence and stores JSON', () async {
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
      return _row('q1', data, sequence: '7');
    });
    when(
      () => tables.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      return _row('q1', {
        'serviceRequestId': 'sr1',
        'senderId': 'staff-1',
        'senderRole': 'quotation',
        'senderName': data['senderName'],
        'message': data['message'],
      }, sequence: '7');
    });

    final result = await repo.createQuotation(
      serviceRequestId: 'sr1',
      clientId: 'client-1',
      title: 'Interior package',
      items: const [QuotationLineItem(description: 'Design', quantity: 1, unitPrice: 1000)],
      validUntil: DateTime.now().add(const Duration(days: 30)),
    );
    expect(result.dataOrNull?.quotationNumber, 'QT-${DateTime.now().year}-007');
    expect(result.dataOrNull?.total, 1180);
    expect(audit.events, ['quotation_created']);
  });

  test('sent quotations cannot be edited', () async {
    final sent = _sample(status: QuotationStatus.sent);
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer(
      (_) async => _row('q1', {
        'serviceRequestId': 'sr1',
        'senderRole': 'quotation',
        'senderName': sent.quotationNumber,
        'message': jsonEncode(sent.toJson()),
      }),
    );
    final result = await repo.updateQuotation('q1', {'title': 'Nope'});
    expect(result.isFailure, isTrue);
  });

  test('createRevision clones with revisionNumber + 1', () async {
    final source = _sample(status: QuotationStatus.revisionRequested, revision: 0);
    when(
      () => tables.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer(
      (_) async => _row('q1', {
        'serviceRequestId': 'sr1',
        'senderRole': 'quotation',
        'senderName': source.quotationNumber,
        'message': jsonEncode(source.toJson()),
      }),
    );
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
      return _row('q2', data, sequence: '8');
    });
    when(
      () => tables.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      return _row('q2', {
        'serviceRequestId': 'sr1',
        'senderRole': 'quotation',
        'senderName': data['senderName'],
        'message': data['message'],
      }, sequence: '8');
    });
    final result = await repo.createRevision('q1');
    expect(result.dataOrNull?.revisionNumber, 1);
    expect(result.dataOrNull?.status, QuotationStatus.draft);
    expect(audit.events, ['quotation_revision_created']);
  });
}
