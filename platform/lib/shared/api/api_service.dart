import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aidvise_platform/shared/api/api_cache.dart';

class ApiService {
  static const String _baseHost = String.fromEnvironment(
    'BASE_HOST',
    defaultValue: 'http://localhost:8000',
  );
  static const String _baseUrl = '$_baseHost/api/v1';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _accountTypeKey = 'account_type'; // 'user' | 'vendor'

  // ── Token helpers ──────────────────────────────────────────────────────────

  static const _tokenIssuedKey = 'token_issued_at';
  static const _logoutNoticeKey = 'logout_notice';

  /// Every request is bounded: an unreachable or wedged host must surface as
  /// an error the UI can show, never as an indefinite wait.
  static const _requestTimeout = Duration(seconds: 15);

  /// Wrap EVERY http call in this. Enforced by test/api_timeouts_test.dart.
  static Future<T> _send<T>(Future<T> request, {Duration? timeout}) {
    return request.timeout(
      timeout ?? _requestTimeout,
      onTimeout: () => throw const ApiException(
          408, 'Could not reach the server. Check your connection.'),
    );
  }

  /// Called whenever the server rejects our token (401), regardless of what
  /// the calling screen does with the exception. Screens routinely swallow
  /// errors for non-critical data, so session death must not depend on them.
  static void Function()? onUnauthorized;

  /// Last user interaction — the AFK monitor in shared/app_frame.dart reads this.
  static DateTime lastActivity = DateTime.now();
  static void recordActivity() => lastActivity = DateTime.now();

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
        key: _tokenIssuedKey, value: DateTime.now().toIso8601String());
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<Duration?> tokenAge() async {
    final raw = await _storage.read(key: _tokenIssuedKey);
    final issued = raw == null ? null : DateTime.tryParse(raw);
    return issued == null ? null : DateTime.now().difference(issued);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenIssuedKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Whether an account is still on file (set at login, cleared on logout).
  /// Together with a missing token this means the session ended abnormally.
  static Future<bool> hasStoredAccount() async =>
      (await _storage.read(key: _accountTypeKey)) != null;


  // ── Auth headers ───────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// The stored token is no longer valid, so keeping it would strand the
  /// user in a logged-in UI where every call fails. Screens detect the 401
  /// via [ApiException.statusCode] and redirect to login.
  static Future<void> _checkSession(http.Response response) async {
    if (response.statusCode == 401) {
      await deleteToken();
      // Survives an app restart: if the user closes the app instead of
      // answering the expiry prompt, the login screen still explains why.
      await _storage.write(
          key: _logoutNoticeKey,
          value: 'You have been logged out. Please log in again.');
      onUnauthorized?.call();
      throw const ApiException(401, 'Session expired. Please log in again.');
    }
  }

  // ── Auth and account ───────────────────────────────────────────────────────

  /// Login with username + password. Saves the token and returns the user map.
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ));

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await saveToken(body['access_token'] as String);
      await _storage.write(
        key: _accountTypeKey,
        value: body['is_vendor'] == true ? 'vendor' : 'user',
      );
      return body as Map<String, dynamic>;
    }

    final detail = body['detail'] ?? 'Login failed';
    throw ApiException(response.statusCode, detail.toString());
  }

  /// Clears the session. [notice] is shown once on the login screen — set it
  /// whenever the app ends the session for the user (idle timeout, expiry)
  /// rather than the user choosing to sign out.
  static Future<void> logout({String? notice}) async {
    ApiCache.clear(); // no data may leak across accounts
    await deleteToken();
    await _storage.delete(key: _accountTypeKey);
    if (notice != null) {
      await _storage.write(key: _logoutNoticeKey, value: notice);
    }
  }

  /// Reads and clears the pending logout notice, so it is shown exactly once.
  static Future<String?> takeLogoutNotice() async {
    final notice = await _storage.read(key: _logoutNoticeKey);
    if (notice != null) await _storage.delete(key: _logoutNoticeKey);
    return notice;
  }

  /// The signed-in user's identity, plan tier, and quota usage.
  static Future<Map<String, dynamic>> getMe({bool refresh = false}) =>
      ApiCache.through('me', const Duration(seconds: 30), _fetchGetMe, refresh: refresh);

  static Future<Map<String, dynamic>> _fetchGetMe() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load account');
  }

  /// Sliding session: trade a still-valid token for a fresh one while the
  /// user is active. Failures are ignored — an expired token surfaces as a
  /// 401 on the next real call and the normal logout flow handles it.
  static Future<void> refreshToken() async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      await saveToken(body['access_token'] as String);
    }
  }

  // ── Shared lookups ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> searchOccupations([String? query]) async {
    final uri = Uri.parse('$_baseUrl/vendor/occupations').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final response = await _send(http.get(uri, headers: await _authHeaders()));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load occupations');
  }

  // ── Admin: failed jobs and vendor approval ─────────────────────────────────

  static Future<List<Map<String, dynamic>>> getFailedGenerationJobs() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/admin/jobs/failed'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to load jobs');
  }

  static Future<void> retryGenerationJob(int jobId) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/admin/jobs/$jobId/retry'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Retry failed');
  }

  static Future<List<Map<String, dynamic>>> getPendingVendorsAdmin() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/admin/vendors/pending'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load vendors');
  }

  static Future<void> setVendorStatusAdmin(int userId, String status) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/admin/vendors/$userId/status'),
      headers: await _authHeaders(),
      body: jsonEncode({'status': status}),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to update vendor');
    }
  }

  // ── Admin panel ────────────────────────────────────────────────────────────

  /// Shared response handling for the admin calls: session check, JSON body
  /// on success, readable message on failure. FastAPI validation errors (a
  /// list of field problems) are flattened into one sentence.
  static Future<dynamic> _decode(http.Response response, String fallback) async {
    await _checkSession(response);
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final detail = body is Map ? body['detail'] : null;
    final message = detail is List
        ? detail.map((e) => e is Map ? e['msg'] : e).join('. ')
        : detail?.toString();
    throw ApiException(response.statusCode, message ?? fallback);
  }

  static String _query(Map<String, Object?> params) {
    final present = {
      for (final e in params.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value.toString(),
    };
    return present.isEmpty ? '' : '?${Uri(queryParameters: present).query}';
  }

  /// Users matching [query] (name, username, company), optionally one
  /// [role]: user | vendor | admin. Returns {items, total}.
  static Future<Map<String, dynamic>> getAdminUsers(
      {String? query, String? role, int skip = 0, int limit = 50}) async {
    final q = _query({'q': query, 'role': role, 'skip': skip, 'limit': limit});
    return await _decode(
        await _send(http.get(Uri.parse('$_baseUrl/admin/users$q'),
            headers: await _authHeaders())),
        'Could not load users') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAdminUser(int userId) async =>
      await _decode(
          await _send(http.get(Uri.parse('$_baseUrl/admin/users/$userId'),
              headers: await _authHeaders())),
          'Could not load this user') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> setUserTierAdmin(int userId, String tier,
          {DateTime? expiresAt}) async =>
      await _decode(
          await _send(http.put(Uri.parse('$_baseUrl/admin/users/$userId/tier'),
              headers: await _authHeaders(),
              body: jsonEncode({
                'tier': tier,
                'expires_at': expiresAt?.toUtc().toIso8601String(),
              }))),
          'Could not change the plan') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> setUserActiveAdmin(int userId, bool isActive) async =>
      await _decode(
          await _send(http.put(Uri.parse('$_baseUrl/admin/users/$userId/active'),
              headers: await _authHeaders(),
              body: jsonEncode({'is_active': isActive}))),
          'Could not update the account') as Map<String, dynamic>;

  static Future<void> resetUserPasswordAdmin(int userId, String newPassword) async =>
      await _decode(
          await _send(http.put(Uri.parse('$_baseUrl/admin/users/$userId/password'),
              headers: await _authHeaders(),
              body: jsonEncode({'new_password': newPassword}))),
          'Could not reset the password');

  /// Every vendor's listings. [isActive] null = both shown and hidden.
  static Future<Map<String, dynamic>> getAdminListings(
      {String? query, bool? isActive, int skip = 0, int limit = 50}) async {
    final q = _query({'q': query, 'is_active': isActive, 'skip': skip, 'limit': limit});
    return await _decode(
        await _send(http.get(Uri.parse('$_baseUrl/admin/listings$q'),
            headers: await _authHeaders())),
        'Could not load job listings') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateListingAdmin(
          int listingId, Map<String, dynamic> fields) async =>
      await _decode(
          await _send(http.put(Uri.parse('$_baseUrl/admin/listings/$listingId'),
              headers: await _authHeaders(), body: jsonEncode(fields))),
          'Could not save the listing') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> setListingActiveAdmin(int listingId, bool isActive) async =>
      await _decode(
          await _send(http.put(Uri.parse('$_baseUrl/admin/listings/$listingId/active'),
              headers: await _authHeaders(),
              body: jsonEncode({'is_active': isActive}))),
          'Could not update the listing') as Map<String, dynamic>;

  static Future<List<Map<String, dynamic>>> getAdminPlans() async =>
      ((await _decode(
                  await _send(http.get(Uri.parse('$_baseUrl/admin/plans'),
                      headers: await _authHeaders())),
                  'Could not load plans')) as List<dynamic>)
          .cast<Map<String, dynamic>>();

  static Future<Map<String, dynamic>> updatePlanAdmin(
          String key, Map<String, dynamic> fields) async =>
      await _decode(
          await _send(http.put(Uri.parse('$_baseUrl/admin/plans/$key'),
              headers: await _authHeaders(), body: jsonEncode(fields))),
          'Could not save the plan') as Map<String, dynamic>;

  /// Send a plan's prices to the stores again (after a failure).
  static Future<Map<String, dynamic>> resendPlanPricesAdmin(String key) async =>
      await _decode(
          await _send(http.post(Uri.parse('$_baseUrl/admin/plans/$key/sync'),
              headers: await _authHeaders())),
          'Could not send the prices') as Map<String, dynamic>;

  /// Run the hourly store price check now.
  static Future<void> checkPlanPricesAdmin() async => await _decode(
      await _send(http.post(Uri.parse('$_baseUrl/admin/plans/check'),
          headers: await _authHeaders())),
      'Could not start the store check');

}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
