import '../domain/chat_repository.dart';

class SyncWorker {
  SyncWorker(this._repository);

  final ChatRepository _repository;
  var _busy = false;

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await _repository.drainOutbox();
    } finally {
      _busy = false;
    }
  }
}
