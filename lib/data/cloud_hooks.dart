import '../models/client_record.dart';
import '../models/estimate_document.dart';

class CloudHooks {
  static Future<void> Function(ClientRecord client)? afterClientSave;
  static Future<void> Function(String id)? afterClientDelete;
  static Future<void> Function(EstimateDraft draft)? afterEstimateSave;
  static Future<void> Function(String id)? afterEstimateDelete;
  static Future<void> Function(Map<String, dynamic> overlay)? afterCatalogSave;
  static Future<void> Function(Map<String, dynamic> prefs)? afterPrefsSave;
}
