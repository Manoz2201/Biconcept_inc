import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/config/env.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../catalog/domain/storage_repository.dart';
import '../domain/vendor.dart';
import '../domain/vendor_rate.dart';
import '../domain/vendor_rating.dart';
import '../domain/vendor_repository.dart';
import 'vendor_workspace.dart';
import 'vendor_workspace_store.dart';

class VendorRepositoryImpl implements VendorRepository, VendorRateRepository, VendorRatingRepository {
  VendorRepositoryImpl({
    TablesDB? tables,
    Storage? storage,
    AuditRepository? audit,
    VendorWorkspaceStore? store,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _storage = storage ?? AppwriteService.storage,
        _audit = audit ?? AuditRepository(),
        _store = store ?? VendorWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown');

  final TablesDB _tables;
  final Storage _storage;
  final AuditRepository _audit;
  final VendorWorkspaceStore _store;
  final String _databaseId;
  final String Function() _actorId;

  @override
  Future<AppResult<List<Vendor>>> getVendors({
    String? searchTerm,
    String? category,
    bool? isActive,
    bool? isVerified,
  }) {
    return AppwriteService.guard(() async {
      final rows = await _store.list(searchTerm: searchTerm, isActive: isActive, isVerified: isVerified);
      return [
        for (final row in rows)
          if (category == null || category.isEmpty || row.vendor.categories.contains(category)) row.vendor,
      ];
    });
  }

  @override
  Future<AppResult<Vendor>> getVendorById(String id) {
    return AppwriteService.guard(() async => (await _store.getById(id)).vendor);
  }

  @override
  Future<AppResult<Vendor?>> getVendorByUserId(String userId) {
    return AppwriteService.guard(() async {
      final rows = await _store.list(userId: userId, limit: 1);
      return rows.isEmpty ? null : rows.first.vendor;
    });
  }

  @override
  Future<AppResult<Vendor>> createVendor({
    required String companyName,
    required String contactPerson,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required List<String> categories,
    String? gstin,
    String? panNumber,
    String? bankName,
    String? bankAccountNumber,
    String? ifscCode,
    String? notes,
    String? userId,
  }) {
    return AppwriteService.guard(() async {
      if (!isValidGstin(gstin)) throw AppwriteException('GSTIN must be a 15-character Indian GSTIN', 400);
      if (!isValidPan(panNumber)) throw AppwriteException('PAN must be a 10-character Indian PAN', 400);
      if (!isValidIfsc(ifscCode)) throw AppwriteException('IFSC must be 11 characters (AAAA0XXXXXX)', 400);
      if (categories.isEmpty) throw AppwriteException('Select at least one category', 400);
      final now = DateTime.now().toUtc().toIso8601String();
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.vendorsCol,
        rowId: ID.unique(),
        data: {
          'userId': ?userId,
          'companyName': companyName.trim(),
          'contactPerson': contactPerson.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'gstin': ?gstin?.toUpperCase(),
          'panNumber': ?panNumber?.toUpperCase(),
          'address': address.trim(),
          'city': city.trim(),
          'state': state.trim(),
          'pincode': pincode.trim(),
          'bankName': ?bankName?.trim(),
          'bankAccountNumber': ?bankAccountNumber?.trim(),
          'ifscCode': ?ifscCode?.toUpperCase(),
          'categories': categories,
          'rating': 0,
          'totalRatings': 0,
          'isActive': true,
          'isVerified': false,
          'kycDocuments': const <String>[],
          'notes': ?notes?.trim(),
          'workspaceJson': VendorWorkspace().encode(),
          'createdAt': now,
          'updatedAt': now,
        },
        permissions: vendorRowPermissions(userId),
      );
      await _audit.log(userId: _actorId(), action: 'vendor_created', metadata: {'id': row.$id});
      await AppNotifications.instance.showImmediate(title: 'Vendor created', body: companyName.trim());
      return Vendor.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Vendor>> updateVendor(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      if (data.containsKey('gstin') && !isValidGstin(data['gstin']?.toString())) {
        throw AppwriteException('GSTIN must be a 15-character Indian GSTIN', 400);
      }
      if (data.containsKey('panNumber') && !isValidPan(data['panNumber']?.toString())) {
        throw AppwriteException('PAN must be a 10-character Indian PAN', 400);
      }
      if (data.containsKey('ifscCode') && !isValidIfsc(data['ifscCode']?.toString())) {
        throw AppwriteException('IFSC must be 11 characters (AAAA0XXXXXX)', 400);
      }
      final current = await _store.getById(id);
      final payload = Map<String, dynamic>.from(data)..['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      final userId = payload['userId']?.toString() ?? current.vendor.userId;
      final row = await _tables.updateRow(
        databaseId: _databaseId,
        tableId: AppwriteService.vendorsCol,
        rowId: id,
        data: payload,
        permissions: vendorRowPermissions(userId),
      );
      await _audit.log(userId: _actorId(), action: 'vendor_updated', metadata: {'id': id, ...payload});
      return Vendor.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Vendor>> verifyVendor(String id) async {
    final result = await updateVendor(id, {'isVerified': true});
    final vendor = result.dataOrNull;
    if (vendor != null) {
      await _audit.log(userId: _actorId(), action: 'vendor_verified', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'Vendor verified', body: vendor.companyName);
    }
    return result;
  }

  @override
  Future<AppResult<Vendor>> deactivateVendor(String id) async {
    final result = await updateVendor(id, {'isActive': false});
    if (result.isSuccess) {
      await _audit.log(userId: _actorId(), action: 'vendor_deactivated', metadata: {'id': id});
    }
    return result;
  }

  @override
  Future<AppResult<Vendor>> uploadKycDocument(String vendorId, UploadBytes file) {
    return AppwriteService.guard(() async {
      final current = await _store.getById(vendorId);
      final filename = sanitizeUploadName(file.filename);
      validateUpload(file.bytes, filename);
      final uploaded = await _storage.createFile(
        bucketId: Env.clientUploadsBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: file.bytes, filename: filename),
        permissions: vendorRowPermissions(current.vendor.userId),
      );
      final docs = [...current.vendor.kycDocuments, uploaded.$id];
      return (await updateVendor(vendorId, {'kycDocuments': docs})).when(
        success: (vendor) => vendor,
        failure: (error) => throw AppwriteException(error.userMessage, 400),
      );
    });
  }

  @override
  Future<AppResult<Vendor>> recalculateRating(String vendorId) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(vendorId);
      final ratings = snap.workspace.ratings;
      final next = await _store.saveWorkspace(
        vendorId,
        snap.workspace,
        vendorPatch: {
          'rating': ratingAverage(ratings),
          'totalRatings': ratings.length,
        },
      );
      return next.vendor;
    });
  }

  @override
  Future<AppResult<List<VendorRate>>> getVendorRates(String vendorId, {String? category, bool? isActive}) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(vendorId);
      return [
        for (final rate in snap.workspace.rates)
          if ((category == null || rate.category == category) && (isActive == null || rate.isActive == isActive)) rate,
      ];
    });
  }

  @override
  Future<AppResult<VendorRate>> createVendorRate({
    required String vendorId,
    required String category,
    required String itemName,
    required String unit,
    required double rate,
    String? description,
    double? minimumQuantity,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(vendorId);
      final row = VendorRate(
        id: ID.unique(),
        vendorId: vendorId,
        category: category,
        itemName: itemName.trim(),
        description: description?.trim(),
        unit: unit.trim(),
        rate: rate,
        minimumQuantity: minimumQuantity,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      snap.workspace.rates.add(row);
      await _store.saveWorkspace(vendorId, snap.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_rate_created', metadata: {'id': row.id, 'vendorId': vendorId});
      return row;
    });
  }

  @override
  Future<AppResult<VendorRate>> updateVendorRate(String id, Map<String, dynamic> data) {
    return AppwriteService.guard(() async {
      final host = await _store.findRateHost(id);
      if (host == null) throw AppwriteException('Rate not found', 404);
      final index = host.workspace.rates.indexWhere((item) => item.id == id);
      final current = host.workspace.rates[index];
      final next = VendorRate(
        id: current.id,
        vendorId: current.vendorId,
        category: data['category']?.toString() ?? current.category,
        itemName: data['itemName']?.toString() ?? current.itemName,
        description: data['description']?.toString() ?? current.description,
        unit: data['unit']?.toString() ?? current.unit,
        rate: (data['rate'] as num?)?.toDouble() ?? current.rate,
        currency: data['currency']?.toString() ?? current.currency,
        minimumQuantity: (data['minimumQuantity'] as num?)?.toDouble() ?? current.minimumQuantity,
        isActive: data['isActive'] as bool? ?? current.isActive,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.rates[index] = next;
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_rate_updated', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<void>> deleteVendorRate(String id) {
    return AppwriteService.guard(() async {
      final host = await _store.findRateHost(id);
      if (host == null) throw AppwriteException('Rate not found', 404);
      host.workspace.rates.removeWhere((item) => item.id == id);
      await _store.saveWorkspace(host.vendor.id, host.workspace);
      await _audit.log(userId: _actorId(), action: 'vendor_rate_deleted', metadata: {'id': id});
    });
  }

  @override
  Future<AppResult<List<VendorRating>>> getVendorRatings(String vendorId) {
    return AppwriteService.guard(() async => (await _store.getById(vendorId)).workspace.ratings);
  }

  @override
  Future<AppResult<List<VendorRating>>> getProjectVendorRatings(String projectId, String vendorId) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(vendorId);
      return [for (final item in snap.workspace.ratings) if (item.projectId == projectId) item];
    });
  }

  @override
  Future<AppResult<VendorRating>> createVendorRating({
    required String vendorId,
    required String projectId,
    required int qualityScore,
    required int timelinessScore,
    required int communicationScore,
    required int costScore,
    String? comments,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _store.getById(vendorId);
      if (snap.workspace.ratings.any((item) => item.projectId == projectId && item.ratedBy == _actorId())) {
        throw AppwriteException('This project already has a rating from you', 400);
      }
      final rating = VendorRating(
        id: ID.unique(),
        vendorId: vendorId,
        projectId: projectId,
        ratedBy: _actorId(),
        qualityScore: qualityScore.clamp(1, 5),
        timelinessScore: timelinessScore.clamp(1, 5),
        communicationScore: communicationScore.clamp(1, 5),
        costScore: costScore.clamp(1, 5),
        overallScore: overallFromScores(
          quality: qualityScore.clamp(1, 5),
          timeliness: timelinessScore.clamp(1, 5),
          communication: communicationScore.clamp(1, 5),
          cost: costScore.clamp(1, 5),
        ),
        comments: comments?.trim(),
        createdAt: DateTime.now().toUtc(),
      );
      snap.workspace.ratings.add(rating);
      await _store.saveWorkspace(
        vendorId,
        snap.workspace,
        vendorPatch: {
          'rating': ratingAverage(snap.workspace.ratings),
          'totalRatings': snap.workspace.ratings.length,
        },
      );
      await _audit.log(userId: _actorId(), action: 'vendor_rating_created', metadata: {'id': rating.id, 'vendorId': vendorId});
      await AppNotifications.instance.showImmediate(title: 'Rating submitted', body: snap.vendor.companyName);
      return rating;
    });
  }
}
