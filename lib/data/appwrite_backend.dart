import 'appwrite_sync.dart';

/// Public Appwrite project coordinates. The API key is never shown in Settings;
/// it is loaded from `--dart-define=APPWRITE_API_KEY=…`, this device's secure
/// store, or the Appwrite CLI prefs already saved on the machine.
class AppwriteBackend {
  const AppwriteBackend._();

  static const endpoint = AppwriteCloudSettings.defaultEndpoint;
  static const projectId = appwriteProjectIdDefault;
  static const databaseId = appwriteDatabaseIdDefault;

  static const compiledApiKey = String.fromEnvironment('APPWRITE_API_KEY');

  static AppwriteCloudSettings settings({
    required String apiKey,
    DateTime? lastSyncedAt,
  }) {
    return AppwriteCloudSettings(
      endpoint: endpoint,
      projectId: projectId,
      databaseId: databaseId,
      apiKey: apiKey,
      lastSyncedAt: lastSyncedAt,
    );
  }
}
