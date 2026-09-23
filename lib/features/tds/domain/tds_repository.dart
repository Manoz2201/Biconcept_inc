import 'dart:typed_data';

import '../../../core/result/app_result.dart';
import 'tds_deduction.dart';

abstract class TDSRepository {
  Future<AppResult<List<TDSDeduction>>> getTDSDeductions({
    String? financialYear,
    String? quarter,
    TdsSection? section,
    TDSStatus? status,
  });

  Future<AppResult<TDSDeduction>> getTDSDeductionById(String id);

  Future<AppResult<TDSDeduction>> createTDSDeduction({
    required TdsSection section,
    required String deducteeName,
    required String deducteePan,
    required TdsDeducteeType deducteeType,
    required DateTime invoiceDate,
    required double grossAmount,
    String? deducteeId,
    String? billId,
    String? paymentId,
    DateTime? paymentDate,
    Tds194JKind? kind194j,
    Tds194IKind? kind194i,
  });

  Future<AppResult<TDSDeduction>> markTDSDeducted(String id);

  Future<AppResult<TDSDeduction>> depositTDS(String id, String challanNumber, DateTime challanDate);

  Future<AppResult<Uint8List>> generateTDSCertificate(String id);

  Future<AppResult<TDSSummary>> getTDSSummary(String financialYear, String quarter);

  Future<AppResult<Map<String, dynamic>>> getTDSReturnData(String financialYear, String quarter);

  Future<AppResult<String>> exportTDSRegisterToCsv({String? financialYear, String? quarter});
}

abstract class GSTTDSRepository {
  Future<AppResult<List<GSTTDS>>> getGSTTDS({
    String? financialYear,
    String? period,
    GSTTDSStatus? status,
  });

  Future<AppResult<GSTTDS?>> createGSTTDS({
    required String vendorId,
    required String vendorGstin,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double taxableValue,
    required double contractValue,
    required bool interState,
    String? financialYear,
    String? period,
  });

  Future<AppResult<GSTTDS>> markGSTTDSDeducted(String id);

  Future<AppResult<GSTTDS>> depositGSTTDS(String id, String challanNumber, DateTime challanDate);

  Future<AppResult<GSTTDS>> fileGSTR7(String id, String gstr7Period);

  Future<AppResult<Map<String, double>>> getGSTTDSSummary(String financialYear, String period);

  Future<AppResult<String>> exportGSTR7Data(String financialYear, String period);
}
