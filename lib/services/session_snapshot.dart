// lib/services/session_snapshot.dart
// Snapshot local du dernier AppUser hydraté, permet de rester "connecté"
// après redémarrage offline.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thix_id/models/app_user.dart';

class SessionSnapshot {
  static const String _boxName = 'thix_session_v1';
  static const String _key = 'snapshot';

  static Box<String>? _box;

  static Future<Box<String>> _open() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  static Future<void> save(AppUser user) async {
    try {
      final box = await _open();
      await box.put(_key, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('[SessionSnapshot] save failed: $e');
    }
  }

  static AppUser? load() {
    try {
      final box = _box;
      if (box == null || !box.isOpen) return null;
      final raw = box.get(_key);
      if (raw == null || raw.isEmpty) return null;
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SessionSnapshot] load failed: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final box = await _open();
      await box.delete(_key);
    } catch (e) {
      debugPrint('[SessionSnapshot] clear failed: $e');
    }
  }
}
