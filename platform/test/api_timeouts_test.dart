import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the rule that cost us an app that hung forever on an unreachable
/// host, then let an unauthenticated user into the home page: every network
/// call in ApiService must be bounded by ApiService._send.
///
/// This reads the source rather than exercising the client, because the bug
/// is one of omission — a new endpoint added without a timeout — and only a
/// source-level check catches that.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/shared/api/api_service.dart').readAsStringSync();
  });

  test('every http call goes through _send', () {
    final unwrapped = <String>[];
    final callSite = RegExp(r'(\w+\s*)?http\.(get|post|put|delete|patch)\s*\(');

    for (final match in callSite.allMatches(source)) {
      final start = match.start;
      // The wrapper must appear immediately before the http call.
      final before = source.substring((start - 12).clamp(0, start), start);
      if (!before.contains('_send(')) {
        final line = '\n'.allMatches(source.substring(0, start)).length + 1;
        unwrapped.add('line $line: ${match.group(0)}');
      }
    }

    expect(
      unwrapped,
      isEmpty,
      reason: 'Unbounded network call(s) — wrap them in _send(...) so an '
          'unreachable server fails instead of hanging:\n'
          '${unwrapped.join('\n')}',
    );
  });

  test('multipart uploads are bounded too', () {
    final sends = RegExp(r'request\.send\(\)').allMatches(source);
    expect(sends, isNotEmpty, reason: 'expected multipart uploads to exist');

    for (final match in sends) {
      final before =
          source.substring((match.start - 20).clamp(0, match.start), match.start);
      expect(before.contains('_send('), isTrue,
          reason: 'request.send() must be wrapped in _send(...) with an '
              'upload timeout');
    }
  });

  test('_send throws instead of waiting forever', () {
    expect(source.contains('static Future<T> _send<T>('), isTrue,
        reason: '_send is the single choke point for network timeouts');
    expect(source.contains('onTimeout:'), isTrue,
        reason: '_send must convert a timeout into an ApiException');
  });
}
