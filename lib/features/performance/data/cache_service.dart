import '../domain/cache_config.dart';

class MemoryCacheService implements CacheService {
  final Map<String, _Entry> _store = {};
  final List<OfflineAction> _queue = [];

  @override
  Future<void> init() async {}

  @override
  T? get<T>(String key, {Duration? ttl}) {
    final entry = _store[key];
    if (entry == null) return null;
    final limit = ttl ?? entry.ttl ?? CacheTtl.forKey(key);
    if (DateTime.now().isAfter(entry.storedAt.add(limit))) {
      _store.remove(key);
      return null;
    }
    return entry.value is T ? entry.value as T : null;
  }

  @override
  void put<T>(String key, T value, {Duration? ttl}) {
    _store[key] = _Entry(value, DateTime.now(), ttl ?? CacheTtl.forKey(key));
  }

  @override
  void delete(String key) => _store.remove(key);

  @override
  void clear() => _store.clear();

  @override
  void clearExpired() {
    final now = DateTime.now();
    _store.removeWhere((key, entry) => now.isAfter(entry.storedAt.add(entry.ttl ?? CacheTtl.forKey(key))));
  }

  @override
  void enqueue(OfflineAction action) => _queue.add(action);

  @override
  OfflineAction? dequeue() => _queue.isEmpty ? null : _queue.removeAt(0);

  @override
  List<OfflineAction> getAll() => List.unmodifiable(_queue);

  @override
  void clearQueue() => _queue.clear();
}

class _Entry {
  _Entry(this.value, this.storedAt, this.ttl);
  final Object? value;
  final DateTime storedAt;
  final Duration? ttl;
}

final memoryCache = MemoryCacheService();
