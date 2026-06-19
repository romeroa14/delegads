/// API configuration for the Delegads CRM backend.
///
/// The base URL can be overridden at runtime via the Settings screen —
/// the override is persisted in secure storage by [ApiService].
class ApiConfig {
  /// Default base URL pointing at the local Laravel CRM (port 8086 in docker-compose).
  static const String baseUrl = 'http://localhost:8086';

  /// Versioned API prefix used by every authenticated endpoint.
  static const String apiPrefix = '/api/v1';

  // Endpoint paths
  static const String login = '/api/login';
  static const String user = '/api/user';
  static const String leads = '$apiPrefix/leads';
  static const String metrics = '$apiPrefix/metrics';
  static const String campaigns = '$apiPrefix/campaigns';
  static const String designJobs = '$apiPrefix/design-jobs';

  /// Runtime override set by the Settings screen. Empty string means "use [baseUrl]".
  static String customBaseUrl = '';

  /// Effective base URL used for every request.
  static String get effectiveBaseUrl =>
      customBaseUrl.isEmpty ? baseUrl : customBaseUrl;

  /// Convenience builder for full URLs.
  static String url(String path) => '$effectiveBaseUrl$path';
}
