import 'package:flutter_test/flutter_test.dart';
import 'package:aidvise_platform/shared/api/api_cache.dart';

void main() {
  setUp(ApiCache.clear);

  test('fetch-through caches the first result and serves it after', () async {
    var calls = 0;
    Future<String> fetch() async {
      calls++;
      return 'value-$calls';
    }

    final first = await ApiCache.through('k', const Duration(minutes: 1), fetch);
    final second = await ApiCache.through('k', const Duration(minutes: 1), fetch);
    expect(first, 'value-1');
    expect(second, 'value-1'); // served from cache
    expect(calls, 1);
  });

  test('refresh forces a network fetch and replaces the cached value', () async {
    var calls = 0;
    Future<int> fetch() async => ++calls;

    await ApiCache.through('k', const Duration(minutes: 1), fetch);
    final refreshed =
        await ApiCache.through('k', const Duration(minutes: 1), fetch, refresh: true);
    expect(refreshed, 2);
    expect(calls, 2);
  });

  test('expired entries are refetched', () async {
    var calls = 0;
    Future<int> fetch() async => ++calls;

    await ApiCache.through('k', Duration.zero, fetch);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await ApiCache.through('k', Duration.zero, fetch);
    expect(second, 2);
  });

  test('null results are cached (no refetch loop for empty states)', () async {
    var calls = 0;
    Future<String?> fetch() async {
      calls++;
      return null;
    }

    await ApiCache.through<String?>('k', const Duration(minutes: 1), fetch);
    final second =
        await ApiCache.through<String?>('k', const Duration(minutes: 1), fetch);
    expect(second, isNull);
    expect(calls, 1);
  });

  test('prefix invalidation removes matching keys only', () {
    ApiCache.set('jobs.browse.a', 1, const Duration(minutes: 1));
    ApiCache.set('jobs.browse.b', 2, const Duration(minutes: 1));
    ApiCache.set('profile', 3, const Duration(minutes: 1));

    ApiCache.invalidate('jobs.browse');
    expect(ApiCache.has('jobs.browse.a'), isFalse);
    expect(ApiCache.has('jobs.browse.b'), isFalse);
    expect(ApiCache.has('profile'), isTrue);
  });

  test('clear wipes everything (logout must not leak across accounts)', () {
    ApiCache.set('profile', 1, const Duration(minutes: 1));
    ApiCache.set('me', 2, const Duration(minutes: 1));
    ApiCache.clear();
    expect(ApiCache.has('profile'), isFalse);
    expect(ApiCache.has('me'), isFalse);
  });
}
