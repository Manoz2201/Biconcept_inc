import '../domain/chat_repository.dart';

class CatchUpSync {
  CatchUpSync(this._repository);

  final ChatRepository _repository;

  Future<void> run() async {
    await _repository.catchUp();
    await _repository.drainOutbox();
  }
}
