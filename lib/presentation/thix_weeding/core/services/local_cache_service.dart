// lib/presentation/thix_weeding/core/services/local_cache_service.dart
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'local_cache_service.g.dart';

@Riverpod(keepAlive: true)
LocalCacheService localCacheService(LocalCacheServiceRef ref) {
  return LocalCacheService();
}

class LocalCacheService {
  static const _prefix = 'thix_weeding_';

  Future<void> saveJson(String key, Map<String, dynamic> json, {Duration ttl = const Duration(hours: 2)}) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {'data': json, 'exp': DateTime.now().add(ttl).toIso8601String()};
    await prefs.setString('$_prefix$key', jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final exp = DateTime.parse(decoded['exp'] as String);
    if (DateTime.now().isAfter(exp)) {
      await prefs.remove('$_prefix$key');
      return null;
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
