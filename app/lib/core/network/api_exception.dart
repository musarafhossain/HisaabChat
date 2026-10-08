import 'package:dio/dio.dart';

/// A failed API call, normalized from the AdonisJS error format:
/// `{ "errors": [{ "message": "...", "field": "amount", "rule": "positive" }] }`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.isNetworkError = false,
  });

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(
        message: 'Waiting for network…',
        isNetworkError: true,
      );
    }

    final fieldErrors = <String, String>{};
    var message = 'Something went wrong (${response.statusCode})';
    final body = response.data;
    if (body is Map && body['errors'] is List) {
      for (final item in (body['errors'] as List).whereType<Map<dynamic, dynamic>>()) {
        final text = item['message']?.toString();
        if (text == null) continue;
        final field = item['field']?.toString();
        if (field != null) {
          fieldErrors.putIfAbsent(field, () => text);
        } else {
          message = text;
        }
      }
      if (fieldErrors.isNotEmpty && message.startsWith('Something')) {
        message = fieldErrors.values.first;
      }
    } else if (body is Map && body['message'] is String) {
      message = body['message'] as String;
    }

    return ApiException(
      message: message,
      statusCode: response.statusCode,
      fieldErrors: fieldErrors,
    );
  }

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
