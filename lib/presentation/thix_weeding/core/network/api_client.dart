// lib/presentation/thix_weeding/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'interceptors/auth_interceptor.dart';

part 'api_client.g.dart';

@Riverpod(keepAlive: true)
Dio dioClient(DioClientRef ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.thix.app/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  dio.interceptors.addAll([
    AuthInterceptor(),
    LogInterceptor(requestBody: false, responseBody: false),
  ]);

  return dio;
}
