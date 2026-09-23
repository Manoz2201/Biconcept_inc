import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/catalog/data/catalog_repository_impl.dart';
import 'package:biconcept/features/catalog/domain/service_item.dart';
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
      $tableId: 'services',
      $databaseId: 'db',
      $createdAt: '',
      $updatedAt: '',
      $permissions: const [],
      data: data,
    );

void main() {
  late _Tables tables;
  late _Audit audit;
  late CatalogRepositoryImpl repo;

  setUp(() {
    tables = _Tables();
    audit = _Audit();
    repo = CatalogRepositoryImpl(
      tables: tables,
      audit: audit,
      databaseId: 'db',
      actorId: () => 'admin-1',
    );
  });

  test('getServices filters active rows and maps models', () async {
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
          _row('s1', {
            'title': 'Interiors',
            'slug': 'interiors',
            'category': 'Interior',
            'shortDescription': 'Full-home interiors',
            'isActive': true,
          }),
        ],
      ),
    );
    final result = await repo.getServices();
    expect(result.dataOrNull?.single.title, 'Interiors');
  });

  test('createService unique-slugs and writes an audit event', () async {
    var lists = 0;
    when(
      () => tables.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer((_) async {
      lists++;
      if (lists == 1) {
        return models.RowList(total: 1, rows: [_row('other', {'slug': 'kitchen'})]);
      }
      return models.RowList(total: 0, rows: const []);
    });
    when(
      () => tables.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = Map<String, dynamic>.from(invocation.namedArguments[#data]! as Map);
      return _row('s2', data);
    });

    final result = await repo.createService(
      const ServiceItem(
        id: '',
        title: 'Kitchen',
        slug: 'kitchen',
        category: 'Interior',
        shortDescription: 'Kitchen interiors',
      ),
    );
    expect(result.dataOrNull?.slug, 'kitchen-2');
    expect(audit.events, ['service_created']);
  });

  test('deleteService logs service_deleted', () async {
    when(
      () => tables.deleteRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer((_) async => {});
    final result = await repo.deleteService('s1');
    expect(result.isSuccess, isTrue);
    expect(audit.events, ['service_deleted']);
  });
}
