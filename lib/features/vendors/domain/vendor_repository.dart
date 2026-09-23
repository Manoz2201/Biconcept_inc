import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import 'vendor.dart';
import 'vendor_rate.dart';
import 'vendor_rating.dart';

abstract class VendorRepository {
  Future<AppResult<List<Vendor>>> getVendors({
    String? searchTerm,
    String? category,
    bool? isActive,
    bool? isVerified,
  });

  Future<AppResult<Vendor>> getVendorById(String id);
  Future<AppResult<Vendor?>> getVendorByUserId(String userId);

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
  });

  Future<AppResult<Vendor>> updateVendor(String id, Map<String, dynamic> data);
  Future<AppResult<Vendor>> verifyVendor(String id);
  Future<AppResult<Vendor>> deactivateVendor(String id);
  Future<AppResult<Vendor>> uploadKycDocument(String vendorId, UploadBytes file);
  Future<AppResult<Vendor>> recalculateRating(String vendorId);
}

abstract class VendorRateRepository {
  Future<AppResult<List<VendorRate>>> getVendorRates(String vendorId, {String? category, bool? isActive});
  Future<AppResult<VendorRate>> createVendorRate({
    required String vendorId,
    required String category,
    required String itemName,
    required String unit,
    required double rate,
    String? description,
    double? minimumQuantity,
  });
  Future<AppResult<VendorRate>> updateVendorRate(String id, Map<String, dynamic> data);
  Future<AppResult<void>> deleteVendorRate(String id);
}

abstract class VendorRatingRepository {
  Future<AppResult<List<VendorRating>>> getVendorRatings(String vendorId);
  Future<AppResult<List<VendorRating>>> getProjectVendorRatings(String projectId, String vendorId);
  Future<AppResult<VendorRating>> createVendorRating({
    required String vendorId,
    required String projectId,
    required int qualityScore,
    required int timelinessScore,
    required int communicationScore,
    required int costScore,
    String? comments,
  });
}
