import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/config/env.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/storage/token_store.dart';

/// Thin wrapper around Dio for the HisaabChat REST API (`/api/v1`).
///
/// Every method unwraps the `{ "data": ... }` envelope and throws
/// [ApiException] on failure. The access token is attached automatically;
/// a 401 on an authenticated request fires the onUnauthorized callback.
class ApiClient {
  ApiClient(this._dio);

  factory ApiClient.create({
    String? baseUrl,
    TokenStore? tokens,
    void Function()? onUnauthorized,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );
    if (tokens != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final token = tokens.token;
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          },
          onError: (error, handler) {
            final sentToken = error.requestOptions.headers.containsKey('Authorization');
            if (error.response?.statusCode == 401 && sentToken) onUnauthorized?.call();
            handler.next(error);
          },
        ),
      );
    }
    return ApiClient(dio);
  }

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) => _send(() => _dio.post<Object?>(path, data: body));

  Future<T> patch<T>(String path, {Object? body}) => _send(() => _dio.patch<Object?>(path, data: body));

  Future<T> delete<T>(String path) => _send(() => _dio.delete<Object?>(path));

  Future<T> _send<T>(Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      final body = response.data;
      final data = body is Map && body.containsKey('data') ? body['data'] : body;
      return data as T;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Increments whenever the server rejects our token (expired or revoked).
/// The auth controller listens to it and signs the user out.
class SessionExpiredSignal extends Notifier<int> {
  @override
  int build() => 0;

  void fire() => state++;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredSignal, int>(SessionExpiredSignal.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.create(
    tokens: ref.watch(tokenStoreProvider),
    onUnauthorized: () => ref.read(sessionExpiredProvider.notifier).fire(),
  );
});
