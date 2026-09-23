import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/result/app_result.dart';
import '../../auth/data/audit_repository.dart';
import '../domain/built_in_services.dart';
import '../domain/catalog_repository.dart';
import '../domain/portfolio_item.dart';
import '../domain/service_item.dart';
import '../domain/slug.dart';
import '../domain/team_member.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    TablesDB? tables,
    AuditRepository? audit,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _audit = audit ?? AuditRepository(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'public');

  final TablesDB _tables;
  final AuditRepository _audit;
  final String _databaseId;
  final String Function() _actorId;

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<AppResult<List<ServiceItem>>> getServices({bool activeOnly = true}) async {
    final remote = await AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.servicesCol,
        queries: [
          if (activeOnly) Query.equal('isActive', true),
          Query.orderAsc('sortOrder'),
          Query.limit(200),
        ],
      );
      return [for (final row in page.rows) ServiceItem.fromRow(row.$id, row.data)];
    });
    return remote.when(
      success: (items) => Success(mergeCatalogServices(items, activeOnly: activeOnly)),
      failure: (_) => Success(mergeCatalogServices(const [], activeOnly: activeOnly)),
    );
  }

  @override
  Future<AppResult<ServiceItem>> getServiceBySlug(String slug) async {
    final remote = await _bySlug(
      tableId: AppwriteService.servicesCol,
      slug: slug,
      map: ServiceItem.fromRow,
    );
    if (remote.isSuccess) return remote;
    final local = builtInServiceByIdOrSlug(slug);
    return local != null ? Success(local) : remote;
  }

  @override
  Future<AppResult<ServiceItem>> getServiceById(String id) async {
    final local = builtInServiceByIdOrSlug(id);
    if (local != null && id.startsWith('svc_')) return Success(local);
    final remote = await AppwriteService.guard(() async {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.servicesCol,
        rowId: id,
      );
      return ServiceItem.fromRow(row.$id, row.data);
    });
    if (remote.isSuccess) return remote;
    return local != null ? Success(local) : remote;
  }

  @override
  Future<AppResult<ServiceItem>> createService(ServiceItem item) {
    return AppwriteService.guard(() async {
      final slug = await _uniqueSlug(AppwriteService.servicesCol, item.slug.isEmpty ? catalogSlug(item.title) : item.slug);
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.servicesCol,
        rowId: ID.unique(),
        data: {
          ...item.toRow(),
          'slug': slug,
          'createdAt': _now,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_created',
        metadata: {'id': row.$id, 'slug': slug},
      );
      return ServiceItem.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<ServiceItem>> updateService(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final payload = Map<String, dynamic>.from(data);
      if (payload['slug'] is String) {
        payload['slug'] = await _uniqueSlug(
          AppwriteService.servicesCol,
          payload['slug'] as String,
          excludeId: id,
        );
      }
      payload['updatedAt'] = _now;
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.servicesCol,
        rowId: id,
        data: payload,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_updated',
        metadata: {'id': id},
      );
      return ServiceItem.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<void>> deleteService(String id) {
    return AppwriteService.guard(() async {
      await _tables.deleteRow(
        databaseId: _databaseId,
        tableId: AppwriteService.servicesCol,
        rowId: id,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'service_deleted',
        metadata: {'id': id},
      );
    });
  }

  @override
  Future<AppResult<List<PortfolioItem>>> getPortfolioItems({
    bool activeOnly = true,
    bool featuredOnly = false,
  }) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.portfolioCol,
        queries: [
          if (activeOnly) Query.equal('isActive', true),
          if (featuredOnly) Query.equal('isFeatured', true),
          Query.orderAsc('sortOrder'),
          Query.limit(100),
        ],
      );
      return [for (final row in page.rows) PortfolioItem.fromRow(row.$id, row.data)];
    });
  }

  @override
  Future<AppResult<PortfolioItem>> getPortfolioBySlug(String slug) {
    return _bySlug(
      tableId: AppwriteService.portfolioCol,
      slug: slug,
      map: PortfolioItem.fromRow,
    );
  }

  @override
  Future<AppResult<PortfolioItem>> getPortfolioById(String id) {
    return AppwriteService.guard(() async {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.portfolioCol,
        rowId: id,
      );
      return PortfolioItem.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<PortfolioItem>> createPortfolioItem(PortfolioItem item) {
    return AppwriteService.guard(() async {
      final slug = await _uniqueSlug(
        AppwriteService.portfolioCol,
        item.slug.isEmpty ? catalogSlug(item.title) : item.slug,
      );
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.portfolioCol,
        rowId: ID.unique(),
        data: {
          ...item.toRow(),
          'slug': slug,
          'createdAt': _now,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'portfolio_created',
        metadata: {'id': row.$id, 'slug': slug},
      );
      return PortfolioItem.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<PortfolioItem>> updatePortfolioItem(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final payload = Map<String, dynamic>.from(data);
      if (payload['slug'] is String) {
        payload['slug'] = await _uniqueSlug(
          AppwriteService.portfolioCol,
          payload['slug'] as String,
          excludeId: id,
        );
      }
      payload['updatedAt'] = _now;
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.portfolioCol,
        rowId: id,
        data: payload,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'portfolio_updated',
        metadata: {'id': id},
      );
      return PortfolioItem.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<void>> deletePortfolioItem(String id) {
    return AppwriteService.guard(() async {
      await _tables.deleteRow(
        databaseId: _databaseId,
        tableId: AppwriteService.portfolioCol,
        rowId: id,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'portfolio_deleted',
        metadata: {'id': id},
      );
    });
  }

  @override
  Future<AppResult<List<TeamMember>>> getTeamMembers({bool activeOnly = true}) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: AppwriteService.teamMembersCol,
        queries: [
          if (activeOnly) Query.equal('isActive', true),
          Query.orderAsc('sortOrder'),
          Query.limit(100),
        ],
      );
      return [for (final row in page.rows) TeamMember.fromRow(row.$id, row.data)];
    });
  }

  @override
  Future<AppResult<TeamMember>> getTeamMemberById(String id) {
    return AppwriteService.guard(() async {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: AppwriteService.teamMembersCol,
        rowId: id,
      );
      return TeamMember.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<TeamMember>> createTeamMember(TeamMember member) {
    return AppwriteService.guard(() async {
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.teamMembersCol,
        rowId: ID.unique(),
        data: {
          ...member.toRow(),
          'createdAt': _now,
          'updatedAt': _now,
        },
      );
      await _audit.log(
        userId: _actorId(),
        action: 'team_member_created',
        metadata: {'id': row.$id, 'name': member.name},
      );
      return TeamMember.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<TeamMember>> updateTeamMember(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final payload = Map<String, dynamic>.from(data)..['updatedAt'] = _now;
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.teamMembersCol,
        rowId: id,
        data: payload,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'team_member_updated',
        metadata: {'id': id},
      );
      return TeamMember.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<void>> deleteTeamMember(String id) {
    return AppwriteService.guard(() async {
      await _tables.deleteRow(
        databaseId: _databaseId,
        tableId: AppwriteService.teamMembersCol,
        rowId: id,
      );
      await _audit.log(
        userId: _actorId(),
        action: 'team_member_deleted',
        metadata: {'id': id},
      );
    });
  }

  Future<AppResult<T>> _bySlug<T>({
    required String tableId,
    required String slug,
    required T Function(String id, Map<String, dynamic> data) map,
  }) {
    return AppwriteService.guard(() async {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: tableId,
        queries: [Query.equal('slug', slug), Query.limit(1)],
      );
      if (page.rows.isEmpty) {
        throw AppwriteException('Not found', 404);
      }
      final row = page.rows.first;
      return map(row.$id, row.data);
    });
  }

  Future<String> _uniqueSlug(String tableId, String raw, {String? excludeId}) async {
    final base = catalogSlug(raw);
    var candidate = base;
    var n = 2;
    while (true) {
      final page = await _tables.listRows(
        databaseId: _databaseId,
        tableId: tableId,
        queries: [Query.equal('slug', candidate), Query.limit(1)],
      );
      if (page.rows.isEmpty || page.rows.first.$id == excludeId) {
        return candidate;
      }
      candidate = '$base-$n';
      n++;
    }
  }
}
