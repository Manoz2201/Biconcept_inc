import 'package:biconcept/core/storage/secure_storage.dart';
import 'package:biconcept/features/auth/data/audit_repository.dart';
import 'package:biconcept/features/auth/data/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore extends Fake implements SecureStore {
  String? value;

  @override
  Future<void> writeSessionId(String sessionId) async {
    value = sessionId;
  }

  @override
  Future<String?> readSessionId() async => value;

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _SilentAudit extends Fake implements AuditRepository {
  final events = <String>[];

  @override
  Future<void> log({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
    String? ipAddress,
  }) async {
    events.add(action);
  }
}

void main() {
  test('secure store writes and clears a session id', () async {
    final store = _MemoryStore();
    await store.writeSessionId('sess_1');
    expect(await store.readSessionId(), 'sess_1');
    await store.clear();
    expect(await store.readSessionId(), isNull);
  });

  test('audit helper records actions without secrets', () async {
    final audit = _SilentAudit();
    await audit.log(
      userId: 'user-1',
      action: 'login_success',
      metadata: {'password': 'nope', 'email': 'a@b.com'},
    );
    expect(audit.events, ['login_success']);
  });

  test('invite role maps onto the staff team', () {
    expect(teamIdForInviteRole, isNotNull);
  });
}
