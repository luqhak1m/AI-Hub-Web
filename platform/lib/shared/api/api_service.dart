import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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
  /// an error the UI can show, never as an indefinite wait. Uploads get
  /// longer than reads.
  static const _requestTimeout = Duration(seconds: 15);
  static const _uploadTimeout = Duration(seconds: 60);

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

  /// Whether the signed-in account is a vendor (set at login; vendors get a
  /// listings-only workspace instead of the user home).
  static Future<bool> isVendorAccount() async =>
      (await _storage.read(key: _accountTypeKey)) == 'vendor';

  /// Unique key for retry-safe POSTs. Generate ONCE per logical user
  /// action and reuse it for retries of that action, so the server can
  /// replay the original result instead of running the action twice.
  static String newIdempotencyKey() {
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$rand';
  }

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

  // ── Auth endpoints ─────────────────────────────────────────────────────────

  /// Register a new user. Returns the created user map or throws on error.
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    bool isVendor = false,
    String? companyName,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        if (isVendor) 'is_vendor': true,
        if (isVendor && companyName != null) 'company_name': companyName,
      }),
    ));

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) return body as Map<String, dynamic>;

    final detail = body['detail'] ?? 'Registration failed';
    throw ApiException(response.statusCode, detail.toString());
  }

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

  /// The signed-in user's profile picture. Auth-only, so it is fetched as
  /// bytes rather than handed to Image.network.
  static Future<Uint8List> getAvatar() async {
    final response = await _send(http.get(
      Uri.parse('$_baseHost/api/v1/profile/me/avatar'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) return response.bodyBytes;
    throw ApiException(response.statusCode, 'Could not load profile picture');
  }

  /// Uploads a new profile picture (PNG or JPEG, max 2 MB). Bytes rather
  /// than a path: browsers never reveal a picked file's location.
  static Future<Map<String, dynamic>> uploadAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('$_baseUrl/profile/me/avatar'));
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: fileName));

    final response = await http.Response.fromStream(
        await _send(request.send(), timeout: _uploadTimeout));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      ApiCache.invalidateMany(['profile', 'home.summary']);
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to upload profile picture');
  }

  /// The user's private career dashboard: experience stats, alignment,
  /// history and milestones. Never shared or compared with other users.
  static Future<Map<String, dynamic>> getCareerProgress(
          {bool refresh = false}) =>
      ApiCache.through('profile.progress', const Duration(seconds: 30),
          _fetchCareerProgress, refresh: refresh);

  static Future<Map<String, dynamic>> _fetchCareerProgress() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/profile/me/progress'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to load your career progress');
  }

  /// Everything the home screen's status lines need, in one request.
  static Future<Map<String, dynamic>> getHomeSummary({bool refresh = false}) =>
      ApiCache.through('home.summary', const Duration(seconds: 30),
          _fetchHomeSummary, refresh: refresh);

  static Future<Map<String, dynamic>> _fetchHomeSummary() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/home/summary'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to load your home summary');
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

  /// Grant Pro after a completed StoreKit purchase (demo-mode trust).
  static Future<Map<String, dynamic>> activateProSubscription() async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/subscription/activate'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      ApiCache.invalidate('me');
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Activation failed');
  }

  static Future<Map<String, dynamic>> cancelProSubscription() async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/subscription/cancel'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      ApiCache.invalidate('me');
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Cancellation failed');
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

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/auth/password'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to update password');
  }

  /// Permanently deletes the account server-side, then clears local state.
  static Future<void> deleteAccount() async {
    final response = await _send(http.delete(
      Uri.parse('$_baseUrl/users/me'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      await logout();
      return;
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to delete account');
  }

  // ── Profile endpoints ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createProfile(Map<String, dynamic> data) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/profile/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 201) {
      ApiCache.invalidateMany(['profile', 'eligible', 'me']);
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to create profile');
  }

  static Future<Map<String, dynamic>> getProfile({bool refresh = false}) =>
      ApiCache.through('profile', const Duration(minutes: 2), _fetchGetProfile, refresh: refresh);

  static Future<Map<String, dynamic>> _fetchGetProfile() async {
    final response = await _send(http.get(Uri.parse('$_baseUrl/profile/me'), headers: await _authHeaders()));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load profile');
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/profile/me'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      ApiCache.invalidateMany(['profile', 'eligible', 'me']);
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to update profile');
  }

  // ── Resume endpoints ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getEligibleTemplates({bool refresh = false}) =>
      ApiCache.through('eligible', const Duration(minutes: 2), _fetchGetEligibleTemplates, refresh: refresh);

  static Future<List<Map<String, dynamic>>> _fetchGetEligibleTemplates() async {
    final response = await _send(http.get(Uri.parse('$_baseUrl/resume/eligible-templates'), headers: await _authHeaders()));
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load templates');
  }

  static Future<Map<String, dynamic>> recommendTemplate(List<int> templateIds) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/resume/recommend'),
      headers: await _authHeaders(),
      body: jsonEncode({'template_ids': templateIds}),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to get recommendation');
  }

  /// Enqueues a background generation job. Returns {job_id, status};
  /// poll [getGenerationJob] until status is done or failed.
  static Future<Map<String, dynamic>> generateResume(
    int templateId, {
    String? jobTitle,
    String? jobDescription,
    String? companyName,
    String? idempotencyKey,
    bool force = false,
  }) async {
    final response = await _send(http.post(
          Uri.parse('$_baseUrl/resume/generate'),
          headers: {
            ...await _authHeaders(),
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode({
            'template_id': templateId,
            if (jobTitle != null) 'job_title': jobTitle,
            if (jobDescription != null) 'job_description': jobDescription,
            if (companyName != null) 'company_name': companyName,
            if (force) 'force': true,
          }),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 202) {
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to start generation');
  }

  static Future<Map<String, dynamic>> getGenerationJob(int jobId) async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/resume/jobs/$jobId'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to check generation status');
  }

  /// Deletes a generated resume (used to discard tailored resumes when an
  /// apply flow is abandoned). The server refuses if it's attached to an
  /// application.
  static Future<void> deleteResume(int resumeId) async {
    final response = await _send(http.delete(
      Uri.parse('$_baseUrl/resume/$resumeId'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to delete resume');
    }
  }

  /// All of the user's generated resumes, newest first.
  static Future<List<Map<String, dynamic>>> getResumeHistory() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/resume/history'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (body as List<dynamic>).cast<Map<String, dynamic>>();
    }
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to load resume history');
  }

  static Future<List<int>> downloadPdf(String pdfPath) async {
    final url = pdfPath.startsWith('http') ? pdfPath : '$_baseHost$pdfPath';
    final response = await _send(http.get(Uri.parse(url), headers: await _authHeaders()));
    await _checkSession(response);
    if (response.statusCode == 200) return response.bodyBytes.toList();
    throw ApiException(response.statusCode, 'Failed to download PDF');
  }

  // ── Assessment endpoints ───────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getQuestions({bool refresh = false}) =>
      ApiCache.through('questions', const Duration(hours: 12), _fetchGetQuestions, refresh: refresh);

  static Future<List<Map<String, dynamic>>> _fetchGetQuestions() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/assessment/questions'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    final detail = body['detail'] ?? 'Failed to load questions';
    throw ApiException(response.statusCode, detail.toString());
  }

  /// Latest stored assessment result for the signed-in user, or null if
  /// they have never completed the assessment.
  static Future<Map<String, dynamic>?> getLatestAssessmentResult({bool refresh = false}) =>
      ApiCache.through('assessment.latest', const Duration(minutes: 5), _fetchGetLatestAssessmentResult, refresh: refresh);

  static Future<Map<String, dynamic>?> _fetchGetLatestAssessmentResult() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/assessment/latest'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['result'] as Map<String, dynamic>?;
    }
    final detail = body['detail'] ?? 'Failed to load result';
    throw ApiException(response.statusCode, detail.toString());
  }

  /// Clears the server-side "latest result" flag so the assessment shows
  /// the questions again until a new submission completes.
  static Future<void> startAssessmentRetake() async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/assessment/retake'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(
          response.statusCode, body['detail']?.toString() ?? 'Retake failed');
    }
    ApiCache.invalidateMany(['assessment', 'jobs']);
  }

  static Future<Map<String, dynamic>> submitAssessment(
      List<Map<String, dynamic>> answers) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/assessment/submit'),
      headers: await _authHeaders(),
      body: jsonEncode({'answers': answers}),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      ApiCache.invalidateMany(['assessment', 'jobs']);
      return body as Map<String, dynamic>;
    }
    final detail = body['detail'] ?? 'Submission failed';
    throw ApiException(response.statusCode, detail.toString());
  }

  static Future<String> sendChatMessage({
    required int sessionId,
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/chat/message'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'session_id': sessionId,
        'message': message,
        'history': history,
      }),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body['reply'] as String;
    final detail = body['detail'] ?? 'Chat failed';
    throw ApiException(response.statusCode, detail.toString());
  }

  // ── Vendor endpoints ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getVendorStatus() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/vendor/me'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load vendor status');
  }

  static Future<void> applyVendor(String companyName) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/vendor/apply'),
      headers: await _authHeaders(),
      body: jsonEncode({'company_name': companyName}),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Application failed');
    }
  }

  /// Occupation suggestions for the posting form. The backend caps the list —
  /// this is a suggest-and-confirm flow, not a full taxonomy download.
  /// Filter chips for the browse screen: occupations that actually have live
  /// listings, busiest first, each with a `count`. Distinct from
  /// [searchOccupations], which is the vendor posting form's autocomplete and
  /// with no query just returns occupations alphabetically.
  static Future<List<Map<String, dynamic>>> getJobBrowseFilters() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/jobs/filters'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['occupations'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load filters');
  }

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

  static Future<List<Map<String, dynamic>>> getVendorListings() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/vendor/listings'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load listings');
  }

  static Future<void> createVendorListing(Map<String, dynamic> listing) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/vendor/listings'),
      headers: await _authHeaders(),
      body: jsonEncode(listing),
    ));
    await _checkSession(response);
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to create listing');
    }
  }

  /// Partial edit of a vendor's own listing.
  static Future<Map<String, dynamic>> updateVendorListing(
      int listingId, Map<String, dynamic> fields) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/vendor/listings/$listingId'),
      headers: await _authHeaders(),
      body: jsonEncode(fields),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to update listing');
  }

  /// Attach/replace the screening assessment on a listing.
  static Future<Map<String, dynamic>> setListingAssessment(
      int listingId, Map<String, dynamic> assessment) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/vendor/listings/$listingId/assessment'),
      headers: await _authHeaders(),
      body: jsonEncode(assessment),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to save assessment');
  }

  static Future<void> removeListingAssessment(int listingId) async {
    final response = await _send(http.delete(
      Uri.parse('$_baseUrl/vendor/listings/$listingId/assessment'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to remove assessment');
    }
  }

  /// Vendor: a shortlisted candidate's submitted answers, paired with questions.
  static Future<Map<String, dynamic>> getApplicationAssessmentAnswers(int applicationId) async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/vendor/applications/$applicationId/assessment'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load answers');
  }

  /// Candidate: the pending assessment's questions for an application.
  static Future<Map<String, dynamic>> getCandidateAssessment(int applicationId) async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/applications/$applicationId/assessment'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load assessment');
  }

  /// Candidate: submit screening answers.
  static Future<Map<String, dynamic>> submitCandidateAssessment(
      int applicationId, List<Map<String, dynamic>> answers) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/applications/$applicationId/assessment'),
      headers: await _authHeaders(),
      body: jsonEncode({'answers': answers}),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to submit answers');
  }

  /// Candidate: request a different interview time (when the vendor allows it).
  static Future<void> requestReschedule(int applicationId,
      {required String note, String? proposedTime}) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/applications/$applicationId/reschedule'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'note': note,
        if (proposedTime != null) 'proposed_time': proposedTime,
      }),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Request failed');
    }
  }

  /// Vendor: clear a handled time-change request.
  static Future<void> resolveReschedule(int applicationId) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/vendor/applications/$applicationId/reschedule/resolve'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to resolve');
    }
  }

  /// Vendor: place search for the prep builder — candidate addresses with
  /// coordinates, so the pin lands exactly where intended.
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final uri = Uri.parse('$_baseUrl/vendor/geocode')
        .replace(queryParameters: {'q': query});
    final response = await _send(http.get(uri, headers: await _authHeaders()));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ((body['results'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Search failed');
  }

  /// Attach/replace the interview prep pack on a listing.
  static Future<Map<String, dynamic>> setListingPrep(
      int listingId, Map<String, dynamic> prep) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/vendor/listings/$listingId/prep'),
      headers: await _authHeaders(),
      body: jsonEncode(prep),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to save prep');
  }

  static Future<void> removeListingPrep(int listingId) async {
    final response = await _send(http.delete(
      Uri.parse('$_baseUrl/vendor/listings/$listingId/prep'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to remove prep');
    }
  }

  /// Candidate: the vendor's interview prep pack for an application.
  static Future<Map<String, dynamic>> getInterviewPrep(int applicationId) async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/applications/$applicationId/prep'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load prep');
  }

  /// Pause (hide from users) or reactivate a listing.
  static Future<void> setVendorListingActive(int listingId, bool isActive) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/vendor/listings/$listingId/active?is_active=$isActive'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to update listing');
    }
  }

  static Future<void> deleteVendorListing(int listingId) async {
    final response = await _send(http.delete(
      Uri.parse('$_baseUrl/vendor/listings/$listingId'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to delete listing');
    }
  }

  static Future<void> sendFeedback({
    required String category,
    required String message,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/feedback/'),
      headers: await _authHeaders(),
      body: jsonEncode({'category': category, 'message': message}),
    ));
    await _checkSession(response);
    if (response.statusCode == 201) return;
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to send feedback');
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// {unread: n, notifications: [...]} — newest first.
  static Future<Map<String, dynamic>> getNotifications({bool refresh = false}) =>
      ApiCache.through('notifications.list', const Duration(seconds: 15), _fetchGetNotifications, refresh: refresh);

  static Future<Map<String, dynamic>> _fetchGetNotifications() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/notifications/'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load notifications');
  }

  static Future<int> getUnreadNotificationCount({bool refresh = false}) =>
      ApiCache.through('notifications.count', const Duration(seconds: 15), _fetchGetUnreadNotificationCount, refresh: refresh);

  static Future<int> _fetchGetUnreadNotificationCount() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/notifications/unread-count'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['unread'] as num?)?.toInt() ?? 0;
    }
    return 0; // badge is cosmetic — never break the shell over it
  }

  /// Marks one notification read (opening it counts as reading). Returns the
  /// remaining unread count so the badge can update without a refetch.
  static Future<int> markNotificationRead(int notificationId) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/notifications/$notificationId/read'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      ApiCache.invalidate('notifications');
      return (body['unread'] as num?)?.toInt() ?? 0;
    }
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to mark notification read');
  }

  static Future<void> markNotificationsRead() async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/notifications/read-all'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    ApiCache.invalidate('notifications');
  }

  // ── Job applications ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitJobApplication(
    int listingId, {
    int? resumeId,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$_baseUrl/applications/'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'listing_id': listingId,
        if (resumeId != null) 'resume_id': resumeId,
      }),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 201) {
      ApiCache.invalidateMany(['applications', 'jobs']);
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Application failed');
  }

  /// Apply to a listing with a manually uploaded resume PDF (multipart).
  static Future<Map<String, dynamic>> applyWithUploadedResume({
    required int listingId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST', Uri.parse('$_baseUrl/applications/with-upload'));
    // Only the auth header — multipart sets its own Content-Type boundary.
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['listing_id'] = '$listingId';
    request.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: fileName));

    final response = await http.Response.fromStream(
        await _send(request.send(), timeout: _uploadTimeout));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 201) {
      ApiCache.invalidateMany(['applications', 'jobs']);
      return body as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Application failed');
  }

  static Future<List<Map<String, dynamic>>> getMyApplications({bool refresh = false}) =>
      ApiCache.through('applications.mine', const Duration(seconds: 60), _fetchGetMyApplications, refresh: refresh);

  static Future<List<Map<String, dynamic>>> _fetchGetMyApplications() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/applications/'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load applications');
  }

  static Future<void> withdrawApplication(int applicationId) async {
    final response = await _send(http.delete(
      Uri.parse('$_baseUrl/applications/$applicationId'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to withdraw');
    }
    ApiCache.invalidateMany(['applications', 'jobs']);
  }

  static Future<List<Map<String, dynamic>>> getVendorApplications() async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/vendor/applications'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load applicants');
  }

  static Future<void> setApplicationStatus(int applicationId, String status) async {
    final response = await _send(http.put(
      Uri.parse('$_baseUrl/vendor/applications/$applicationId/status'),
      headers: await _authHeaders(),
      body: jsonEncode({'status': status}),
    ));
    await _checkSession(response);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to update status');
    }
  }

  /// API path for an applicant's resume PDF (vendor-side, auth required).
  static String applicantResumePath(int applicationId) =>
      '/api/v1/vendor/applications/$applicationId/resume';

  // ── Job recommendations ────────────────────────────────────────────────────

  /// Paginated browse over live vendor job listings with optional search
  /// and career-family filter. Returns {jobs, total, page, page_size, has_more}.
  static Future<Map<String, dynamic>> browseJobs({
    String? search,
    int? occupationId,
    int page = 1,
    int pageSize = 10,
    bool refresh = false,
  }) =>
      ApiCache.through(
        'jobs.browse.${search ?? ''}.${occupationId ?? 0}.$page.$pageSize',
        const Duration(minutes: 2),
        () => _fetchBrowseJobs(
            search: search, occupationId: occupationId, page: page, pageSize: pageSize),
        refresh: refresh,
      );

  static Future<Map<String, dynamic>> _fetchBrowseJobs({
    String? search,
    int? occupationId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (search != null && search.isNotEmpty) 'search': search,
      if (occupationId != null) 'occupation_id': '$occupationId',
    };
    final uri = Uri.parse('$_baseUrl/jobs/listings').replace(queryParameters: params);
    final response = await _send(http.get(uri, headers: await _authHeaders()));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load jobs');
  }

  /// Full details for one job listing (job details sheet).
  /// How the signed-in job seeker matches one listing, component by
  /// component (skills, experience, interest fit, description), before
  /// applying.
  static Future<Map<String, dynamic>> getJobMatch(int listingId) async =>
      await _decode(
          await _send(http.get(Uri.parse('$_baseUrl/jobs/listings/$listingId/match'),
              headers: await _authHeaders())),
          'Could not load your match') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getJobListing(int listingId) async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/jobs/listings/$listingId'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode,
        body['detail']?.toString() ?? 'Failed to load job details');
  }

  static Future<List<Map<String, dynamic>>> getJobRecommendations(int sessionId, {bool refresh = false}) =>
      ApiCache.through('jobs.rec.$sessionId', const Duration(minutes: 10),
          () => _fetchJobRecommendations(sessionId), refresh: refresh);

  static Future<List<Map<String, dynamic>>> _fetchJobRecommendations(int sessionId) async {
    final response = await _send(http.get(
      Uri.parse('$_baseUrl/jobs/recommendations/$sessionId'),
      headers: await _authHeaders(),
    ));
    await _checkSession(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['jobs'] ?? [];
      return data.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body);
    throw ApiException(response.statusCode, body['detail']?.toString() ?? 'Failed to load jobs');
  }

  // ── Template endpoints ─────────────────────────────────────────────────────

  /// In-memory cache: previews are static images fetched repeatedly while
  /// scrolling the template list, so avoid refetching within a session.
  static final Map<String, Uint8List> _previewCache = {};

  /// Fetches a template preview PNG by its API path (auth required).
  static Future<Uint8List> getTemplatePreview(String previewPath) async {
    final cached = _previewCache[previewPath];
    if (cached != null) return cached;
    final url =
        previewPath.startsWith('http') ? previewPath : '$_baseHost$previewPath';
    final response = await _send(http.get(Uri.parse(url), headers: await _authHeaders()));
    await _checkSession(response);
    if (response.statusCode == 200) {
      _previewCache[previewPath] = response.bodyBytes;
      return response.bodyBytes;
    }
    throw ApiException(response.statusCode, 'Failed to load preview');
  }

  // ── Subscription plans ─────────────────────────────────────────────────────

  /// Shared response handling: session check, JSON body
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

  /// Plans for the subscription screen, in display order.
  static Future<List<Map<String, dynamic>>> getPlans() async =>
      ((await _decode(
                  await _send(http.get(Uri.parse('$_baseUrl/subscription/plans'),
                      headers: await _authHeaders())),
                  'Could not load plans')) as List<dynamic>)
          .cast<Map<String, dynamic>>();


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
