import '../../../core/result/app_result.dart';
import 'gstr9_return.dart';

abstract class GSTR9Repository {
  Future<AppResult<List<GSTR9Return>>> getGSTR9Returns({String? financialYear, GSTR9Status? status});

  Future<AppResult<GSTR9Return>> getGSTR9ById(String id);

  Future<AppResult<GSTR9Return>> prepareGSTR9(String financialYear);

  Future<AppResult<GSTR9Return>> updateGSTR9(String id, Map<String, dynamic> data);

  Future<AppResult<GSTR9Return>> fileGSTR9(String id, String acknowledgementNumber);

  Future<AppResult<String>> exportGSTR9(String id);
}

abstract class GSTR9CRepository {
  Future<AppResult<List<GSTR9CReconciliation>>> getGSTR9CReconciliations({
    String? financialYear,
    GSTR9CStatus? status,
  });

  Future<AppResult<GSTR9CReconciliation>> prepareGSTR9C(String gstr9Id);

  Future<AppResult<GSTR9CReconciliation>> updateGSTR9C(String id, Map<String, dynamic> data);

  Future<AppResult<GSTR9CReconciliation>> selfCertifyGSTR9C(String id);

  Future<AppResult<GSTR9CReconciliation>> fileGSTR9C(String id);

  Future<AppResult<String>> exportGSTR9C(String id);
}
