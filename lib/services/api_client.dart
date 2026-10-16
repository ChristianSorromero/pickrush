import 'package:dio/dio.dart';
import 'package:rider_app/config.dart';

/// Single Dio instance used by every service.
final Dio apiClient = _build();

Dio _build() {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));
  return dio;
}

/// Extracts a human-readable message from a Laravel error response.
/// Tries `errors` first (flattens the first message of each field),
/// then falls back to `message`, then a generic string.
String apiErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    final msg = data['message'];
    if (msg is String && msg.isNotEmpty) return msg;
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
