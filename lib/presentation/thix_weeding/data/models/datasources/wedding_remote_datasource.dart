// lib/presentation/thix_weeding/data/datasources/wedding_remote_datasource.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/failure.dart';
import '../../core/network/api_client.dart';

part 'wedding_remote_datasource.g.dart';

@Riverpod(keepAlive: true)
WeddingRemoteDataSource weddingRemoteDataSource(WeddingRemoteDataSourceRef ref) {
  return WeddingRemoteDataSource(ref.watch(dioClientProvider));
}

class WeddingRemoteDataSource {
  final Dio _dio;
  WeddingRemoteDataSource(this._dio);

  Future<Map<String, dynamic>> fetchWedding(String id) async {
    try {
      final res = await _dio.get('/weddings/$id');
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_mapError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> fetchProgram(String weddingId) async {
    try {
      final res = await _dio.get('/weddings/$weddingId/program');
      return res.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_mapError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<dynamic>> fetchGifts(String weddingId) async {
    try {
      final res = await _dio.get('/weddings/$weddingId/gifts');
      return res.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_mapError(e));
    }
  }

  Future<List<dynamic>> fetchGallery(String weddingId, int page) async {
    try {
      final res = await _dio.get('/weddings/$weddingId/gallery', queryParameters: {'page': page, 'limit': 20});
      return res.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw Failure(_mapError(e));
    }
  }

  Future<void> postRsvp(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/weddings/${payload['wedding_id']}/rsvp', data: payload);
    } on DioException catch (e) {
      throw Failure(_mapError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> postLivreOr(String weddingId, Map<String, dynamic> payload) async {
    try {
      await _dio.post('/weddings/$weddingId/guestbook', data: payload);
    } on DioException catch (e) {
      throw Failure(_mapError(e));
    }
  }

  String _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) return 'Connexion trop lente, réessayez';
    if (e.type == DioExceptionType.connectionError) return 'Pas de connexion internet';
    return e.response?.data?['message'] ?? 'Erreur serveur, réessayez plus tard';
  }
}
