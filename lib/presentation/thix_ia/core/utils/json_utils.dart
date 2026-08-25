// lib/presentation/thix_ia/core/utils/json_utils.dart
import 'dart:convert';

/// ============================================================================
/// JSON UTILS - Parsing safe pour API instable / millions d'users
/// ============================================================================

class JsonUtils {
  JsonUtils._();

  /// Accepte Map, Map<dynamic,dynamic> (Supabase) et String JSON.
  static Map<String, dynamic> asMap(dynamic json) {
    if (json == null) return {};

    // Map<String,dynamic> OU Map<dynamic,dynamic> (cas Supabase / web)
    if (json is Map) {
      return Map<String, dynamic>.from(json);
    }

    if (json is String) {
      final s = json.trim();
      if (s.isEmpty) return {};
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return {};
  }

  static List<T> asList<T>(
    dynamic json, {
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((e) => fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (json is Map && json['data'] is List) {
      return asList(json['data'], fromMap: fromMap);
    }
    return [];
  }

  static String stringValue(Map map, String key, {String fallback = ''}) {
    final v = map[key];
    if (v == null) return fallback;
    return v.toString();
  }

  static int intValue(Map map, String key, {int fallback = 0}) {
    final v = map[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double doubleValue(Map map, String key, {double fallback = 0.0}) {
    final v = map[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool boolValue(Map map, String key, {bool fallback = false}) {
    final v = map[key];
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1';
    }
    return fallback;
  }

  static DateTime? dateTimeValue(Map map, String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) {
      // timestamp ms
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  static List<String> stringList(Map map, String key) {
    final v = map[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, dynamic> cleanNulls(Map<String, dynamic> map) {
    final cleaned = <String, dynamic>{};
    map.forEach((k, v) {
      if (v != null) cleaned[k] = v;
    });
    return cleaned;
  }
}
