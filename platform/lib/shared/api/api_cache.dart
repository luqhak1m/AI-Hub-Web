/// In-memory TTL cache for API responses.
///
/// Navigating back to a screen serves data instantly from memory instead of
/// refetching over the network. The trade-off is bounded staleness (each key
/// has its own TTL); mutations invalidate the affected prefixes so the user
/// always sees their own changes immediately.
class ApiCache {
  ApiCache._();

  static final Map<String, _Entry> _store = {};

  static bool has(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  static void set(String key, Object? value, Duration ttl) {
    _store[key] = _Entry(value, DateTime.now().add(ttl));
  }

  /// Fetch-through: serve the cached value when fresh, otherwise run [fetch]
  /// and cache its result. [refresh] forces a network fetch (pull-to-refresh).
  static Future<T> through<T>(
    String key,
    Duration ttl,
    Future<T> Function() fetch, {
    bool refresh = false,
  }) async {
    if (!refresh && has(key)) return _store[key]!.value as T;
    final value = await fetch();
    set(key, value, ttl);
    return value;
  }

  /// Remove every entry whose key starts with [prefix].
  static void invalidate(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  static void invalidateMany(List<String> prefixes) {
    for (final prefix in prefixes) {
      invalidate(prefix);
    }
  }

  /// Wipe everything — call on logout so no data leaks across accounts.
  static void clear() => _store.clear();
}

class _Entry {
  final Object? value;
  final DateTime expiresAt;
  _Entry(this.value, this.expiresAt);
}
