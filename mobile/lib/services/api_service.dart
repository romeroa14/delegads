import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Thin wrapper around an API error so the UI can react to specific cases
/// (401 => force logout, 422 => validation, etc).
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic body;

  ApiException(this.statusCode, this.message, [this.body]);

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// HTTP client with Sanctum token authentication.
///
/// - Persists the bearer token in [FlutterSecureStorage].
/// - Exposes typed getters for leads, campaigns, design jobs, metrics, login.
/// - Notifies listeners on auth changes so the root widget can switch screens.
class ApiService extends ChangeNotifier {
  static const _tokenKey = 'delegads_token';
  static const _baseUrlKey = 'delegads_base_url';

  final FlutterSecureStorage _storage;
  String? _token;
  bool _initialized = false;

  ApiService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isInitialized => _initialized;

  /// Lazily load token + custom base URL from secure storage.
  /// Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    try {
      _token = await _storage.read(key: _tokenKey);
      final custom = await _storage.read(key: _baseUrlKey);
      if (custom != null && custom.isNotEmpty) {
        ApiConfig.customBaseUrl = custom;
      }
    } catch (e) {
      // Secure storage failures shouldn't crash the app — just stay unauthenticated.
      if (kDebugMode) {
        debugPrint('ApiService.init failed: $e');
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Attempt login. Returns true on success and stores the token.
  Future<bool> login(String email, String password) async {
    final res = await _post(
      ApiConfig.login,
      body: {'email': email, 'password': password},
      authenticated: false,
    );

    // Sanctum typically returns a plain token string or {token: "..."}.
    final raw = res['token'] ?? res['access_token'] ?? res['plainTextToken'];
    if (raw is String && raw.isNotEmpty) {
      _token = raw;
      await _storage.write(key: _tokenKey, value: raw);
      notifyListeners();
      return true;
    }

    throw ApiException(
      422,
      'Unexpected login response. Expected a token.',
      res,
    );
  }

  /// Clear the token and notify listeners (UI will route back to login).
  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  /// Update the API base URL at runtime and persist it.
  Future<void> setBaseUrl(String url) async {
    ApiConfig.customBaseUrl = url.trim();
    if (ApiConfig.customBaseUrl.isEmpty) {
      await _storage.delete(key: _baseUrlKey);
    } else {
      await _storage.write(key: _baseUrlKey, value: ApiConfig.customBaseUrl);
    }
    notifyListeners();
  }

  // --- Typed fetchers used by the screens ---

  Future<Map<String, dynamic>> fetchMetrics() async {
    return _get(ApiConfig.metrics);
  }

  Future<List<dynamic>> fetchLeads({
    String? search,
    String? stage,
    int page = 1,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '50',
      if (search != null && search.isNotEmpty) 'search': search,
      if (stage != null && stage.isNotEmpty) 'stage': stage,
    };
    final res = await _get(ApiConfig.leads, query: params);
    // Laravel pagination wraps results in {data: [...], ...}
    if (res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> fetchLead(int id) async {
    return _get('${ApiConfig.leads}/$id');
  }

  Future<List<dynamic>> fetchCampaigns({int page = 1}) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '50',
    };
    final res = await _get(ApiConfig.campaigns, query: params);
    if (res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> fetchDesignJobs({int page = 1}) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '50',
    };
    final res = await _get(ApiConfig.designJobs, query: params);
    if (res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    return <dynamic>[];
  }

  // --- Generic HTTP helpers ---

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query);
    final res = await _send(() => http.get(uri, headers: _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path);
    final res = await _send(() => http.post(
          uri,
          headers: _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        ));
    return _decode(res);
  }

  Future<http.Response> _send(Future<http.Response> Function() send) async {
    try {
      return await send();
    } catch (e) {
      throw ApiException(null, 'Network error: $e');
    }
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(ApiConfig.effectiveBaseUrl);
    return base.replace(
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Map<String, String> _headers({bool authenticated = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      body = <String, dynamic>{'raw': res.body};
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    if (res.statusCode == 401) {
      // Token expired or invalid — clear it so the UI routes to login.
      _token = null;
      notifyListeners();
    }
    final message = _extractErrorMessage(body) ??
        'Request failed with status ${res.statusCode}';
    throw ApiException(res.statusCode, message, body);
  }

  String? _extractErrorMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['message'] is String) return body['message'] as String;
      if (body['error'] is String) return body['error'] as String;
      final errors = body['errors'];
      if (errors is Map) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }
    return null;
  }
}
