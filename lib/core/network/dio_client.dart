import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio));

    if (Env.isDevelopment) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint('[DIO] $o'),
        ),
      );
    }

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle token expiration
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        if (Env.hasSupabase) {
          final res = await Supabase.instance.client.auth.refreshSession();
          final session = res.session;
          if (session == null) {
            await SecureStorage.clearTokens();
            handler.next(err);
            return;
          }
          await SecureStorage.saveTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
          );
          err.requestOptions.headers['Authorization'] =
              'Bearer ${session.accessToken}';
        } else {
          final refreshToken = await SecureStorage.getRefreshToken();

          if (refreshToken == null || refreshToken.isEmpty) {
            await SecureStorage.clearTokens();
            handler.next(err);
            return;
          }

          final response = await _dio.post(
            '/api/auth/refresh-token',
            data: {'refreshToken': refreshToken},
            options: Options(headers: {'Authorization': null}),
          );

          final newAccessToken = response.data['accessToken'];
          final newRefreshToken = response.data['refreshToken'];

          await SecureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          err.requestOptions.headers['Authorization'] =
              'Bearer $newAccessToken';
        }

        final retryResponse = await _dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);
      } catch (e) {
        await SecureStorage.clearTokens();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }

      return;
    }

    handler.next(err);
  }
}