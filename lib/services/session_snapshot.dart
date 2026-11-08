// lib/services/session_snapshot.dart
//
// Snapshot local (Hive) du dernier AppUser hydraté avec succès.
// Permet à l'app de rester « connectée » après :
//   - un redémarrage hors-ligne
//   - une perte de réseau prolongée qui a fait expirer la session Supabase
//
// Le snapshot n'est effacé QUE par signOut() volontaire (bouton « Se déconnecter »).
// Une déconnexion non-volontaire (jeton refresh refusé) préserve le snapshot
// pour pouvoir restaurer l'état au retour du réseau.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thix_id/models/app_user.dart';

class SessionSnapshot {
  static const String _boxName = 'thix_session_v1';
  static const String _key = 'snapshot';
  static const Duration _maxAge = Duration(days: 30); // snapshot expiré après 30j

  static Box<String>? _box;

  static Future<Box<String>> _open() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Sauvegarde l'AppUser courant. Tolère les erreurs d'écriture Hive
  /// (on ne veut pas casser l'app si Hive a un souci).
  static Future<void> save(AppUser user) async {
    try {
      final box = await _open();
      final payload = jsonEncode({
        'user': user.toJson(),
        'saved_at': DateTime.now().toIso8601String(),
      });
      await box.put(_key, payload);
      debugPrint('[SessionSnapshot] ✓ saved uid=${_mask(user.id)}');
    } catch (e) {
      debugPrint('[SessionSnapshot] ⚠️ save failed: $e');
    }
  }

  /// Lit le snapshot. Retourne null si absent, expiré ou corrompu.
  static AppUser? load() {
    try {
      final box = _box;
      if (box == null || !box.isOpen) return null;
      final raw = box.get(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final savedAtRaw = decoded['saved_at'];
      if (savedAtRaw is String) {
        final savedAt = DateTime.tryParse(savedAtRaw);
        if (savedAt != null &&
            DateTime.now().difference(savedAt) > _maxAge) {
          debugPrint('[SessionSnapshot] snapshot expired, ignored');
          return null;
        }
      }

      final userJson = decoded['user'];
      if (userJson is! Map) return null;

      final user = AppUser.fromJson(userJson.cast<String, dynamic>());
      // Garde-fou : un snapshot sans id valide ne sert à rien
      if (user.id.isEmpty) return null;
      return user;
    } catch (e) {
      debugPrint('[SessionSnapshot] ⚠️ load failed (corrupt?): $e');
      return null;
    }
  }

  /// Efface le snapshot. Appelé UNIQUEMENT par signOut() volontaire.
  static Future<void> clear() async {
    try {
      final box = await _open();
      await box.delete(_key);
      debugPrint('[SessionSnapshot] cleared');
    } catch (e) {
      debugPrint('[SessionSnapshot] ⚠️ clear failed: $e');
    }
  }

  static String _mask(String uid) =>
      uid.length <= 8 ? '***' : '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';
}
