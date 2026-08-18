import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thix_id/models/thix_profile.dart';

/// Local cache + outbox for profile data.
///
/// Goal: allow the app to work even when Supabase is temporarily unreachable
/// (offline, network issues, RLS transient errors), while keeping Supabase as
/// the source of truth whenever available.
class LocalProfileStore {
  static const _kMyPrefix = 'thix_profile_my_v1:';
  static const _kPublicPrefix = 'thix_profile_public_v1:';
  static const _kPendingPrefix = 'thix_profile_pending_patches_v1:';

  String _myKey(String userId) => '$_kMyPrefix$userId';
  String _publicKey(String thixId) => '$_kPublicPrefix${thixId.trim().toUpperCase()}';
  String _pendingKey(String userId) => '$_kPendingPrefix$userId';

  Future<ThixProfile?> loadMyProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_myKey(userId));
      if (raw == null || raw.trim().isEmpty) return null;
      final row = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ThixProfile.fromPrivateRow(row);
    } catch (e) {
      debugPrint('LocalProfileStore.loadMyProfile failed userId=$userId err=$e');
      return null;
    }
  }

  Future<void> saveMyProfile(ThixProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_myKey(profile.userId), jsonEncode(profile.toPrivateRowJson()));
    } catch (e) {
      debugPrint('LocalProfileStore.saveMyProfile failed userId=${profile.userId} err=$e');
    }
  }

  Future<ThixProfile?> loadPublicProfile(String thixId) async {
    final normalized = thixId.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_publicKey(normalized));
      if (raw == null || raw.trim().isEmpty) return null;
      final row = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ThixProfile.fromPrivateRow(row);
    } catch (e) {
      debugPrint('LocalProfileStore.loadPublicProfile failed thixId=$normalized err=$e');
      return null;
    }
  }

  Future<void> savePublicProfile(ThixProfile profile) async {
    if (profile.thixId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_publicKey(profile.thixId), jsonEncode(profile.toPrivateRowJson()));
    } catch (e) {
      debugPrint('LocalProfileStore.savePublicProfile failed thixId=${profile.thixId} err=$e');
    }
  }

  Future<List<Map<String, dynamic>>> loadPendingPatches(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey(userId));
      if (raw == null || raw.trim().isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    } catch (e) {
      debugPrint('LocalProfileStore.loadPendingPatches failed userId=$userId err=$e');
      return const [];
    }
  }

  Future<void> enqueuePendingPatch(String userId, Map<String, dynamic> patch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadPendingPatches(userId);
      final next = [...current, patch];
      await prefs.setString(_pendingKey(userId), jsonEncode(next));
    } catch (e) {
      debugPrint('LocalProfileStore.enqueuePendingPatch failed userId=$userId err=$e');
    }
  }

  Future<void> setPendingPatches(String userId, List<Map<String, dynamic>> patches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (patches.isEmpty) {
        await prefs.remove(_pendingKey(userId));
      } else {
        await prefs.setString(_pendingKey(userId), jsonEncode(patches));
      }
    } catch (e) {
      debugPrint('LocalProfileStore.setPendingPatches failed userId=$userId err=$e');
    }
  }
}
