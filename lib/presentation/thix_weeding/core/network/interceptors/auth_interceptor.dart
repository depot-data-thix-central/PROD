// lib/presentation/thix_weeding/core/network/interceptors/auth_interceptor.dart
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Token récupéré depuis SecureStorage en prod
    const token = String.fromEnvironment('THIX_API_TOKEN', defaultValue: '');
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Retry automatique sur 502/503 pour haute dispo
    if (err.response?.statusCode == 502 || err.response?.statusCode == 503) {
      // Logique retry avec backoff pourrait être ajoutée ici
    }
    super.onError(err, handler);
  }
}
