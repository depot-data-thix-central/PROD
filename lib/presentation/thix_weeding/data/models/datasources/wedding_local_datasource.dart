// lib/presentation/thix_weeding/data/datasources/wedding_local_datasource.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/local_cache_service.dart';

part 'wedding_local_datasource.g.dart';

@Riverpod(keepAlive: true)
WeddingLocalDataSource weddingLocalDataSource(WeddingLocalDataSourceRef ref) {
  return WeddingLocalDataSource(ref.watch(localCacheServiceProvider));
}

class WeddingLocalDataSource {
  final LocalCacheService _cache;
  WeddingLocalDataSource(this._cache);

  Future<void> cacheWedding(String id, Map<String, dynamic> json) {
    return _cache.saveJson('wedding_$id', json, ttl: const Duration(hours: 6));
  }

  Future<Map<String, dynamic>?> getCachedWedding(String id) {
    return _cache.getJson('wedding_$id');
  }
}
