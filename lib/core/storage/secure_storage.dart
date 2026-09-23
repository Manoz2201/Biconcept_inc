import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const sessionKey = 'biconcept.sessionId';

  final FlutterSecureStorage _storage;

  Future<void> writeSessionId(String sessionId) {
    return _storage.write(key: sessionKey, value: sessionId);
  }

  Future<String?> readSessionId() => _storage.read(key: sessionKey);

  Future<void> clear() => _storage.delete(key: sessionKey);
}
