import '../../../core/result/app_result.dart';
import 'e_way_bill.dart';

abstract class EWayBillRepository {
  Future<AppResult<List<EWayBill>>> getEWayBills({String? financialYear, EWayBillStatus? status});

  Future<AppResult<EWayBill>> getEWayBillById(String id);

  Future<AppResult<EWayBill?>> generateEWayBill({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required EwbSupplyType supplyType,
    required EwbSubSupplyType subSupplyType,
    required EwbDocumentType documentType,
    required String fromGstin,
    required String fromAddress,
    required String fromPlace,
    required String fromPincode,
    required String fromStateCode,
    required String toAddress,
    required String toPlace,
    required String toPincode,
    required String toStateCode,
    required double totalValue,
    required double taxableValue,
    required String hsnCode,
    String? eInvoiceId,
    String? invoiceId,
    String? fromTradeName,
    String? toGstin,
    String? toTradeName,
    String? transporterId,
    String? transporterName,
    EwbTransportMode? transportMode,
    String? vehicleNumber,
    String? vehicleType,
    int? distance,
  });

  Future<AppResult<EWayBill>> cancelEWayBill(String id, String reason);

  Future<AppResult<EWayBill>> extendEWayBill(String id, int additionalDistance);

  Future<AppResult<EWayBill>> updatePartB(String id, String vehicleNumber, String transporterId, int distance);

  Future<AppResult<DateTime?>> getEWayBillValidity(String id);

  Future<AppResult<String>> exportEWayBillsToCsv({String? financialYear});
}
