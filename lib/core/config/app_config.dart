class AppConfig {
  static const String appName = 'Apartment Manager';
  static const String apiBaseUrl = 'http://localhost:8080/api/v1';
  static const String wsUrl = 'ws://localhost:8080/ws';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Pagination
  static const int defaultPageSize = 20;

  // Cache duration
  static const Duration cacheExpiry = Duration(minutes: 5);
}
