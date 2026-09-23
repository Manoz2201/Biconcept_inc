import '../../../core/result/app_result.dart';
import 'gst_settings.dart';

abstract class GSTRepository {
  Future<AppResult<GSTSettings>> getGSTSettings();

  Future<AppResult<GSTSettings>> updateGSTSettings(Map<String, dynamic> data);

  Future<AppResult<List<TaxRate>>> getTaxRates({bool? isActive, String? type});

  Future<AppResult<TaxRate?>> getTaxRateByHsnSac(String hsnSac);

  Future<AppResult<TaxRate>> createTaxRate({
    required String hsnSacCode,
    required String description,
    required double taxRate,
    double? cessRate,
    required TaxRateType type,
  });

  Future<AppResult<TaxRate>> updateTaxRate(String id, Map<String, dynamic> data);

  Future<AppResult<void>> deleteTaxRate(String id);

  Future<AppResult<List<GSTReturn>>> getGSTReturns({
    GSTReturnType? returnType,
    String? financialYear,
    GSTReturnStatus? status,
  });

  Future<AppResult<GSTReturn>> createGSTReturn({
    required GSTReturnType returnType,
    required String period,
    required String financialYear,
  });

  Future<AppResult<GSTReturn>> fileGSTReturn(String id, String acknowledgementNumber);

  Future<AppResult<String>> exportGSTR1(String period, String financialYear);

  Future<AppResult<String>> exportGSTR3B(String period, String financialYear);
}
