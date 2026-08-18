import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thix_id/models/app_user.dart';

class LocalUserStore {
  static const _kUsers = 'thix_users_v1';
  static const _kSessionUserId = 'thix_session_user_id_v1';
  static const _kRememberMe = 'thix_session_remember_me_v1';

  Future<List<AppUser>> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUsers);
      if (raw == null || raw.trim().isEmpty) return const [];
      try {
        final users = AppUser.decodeList(raw);
        return users;
      } catch (e) {
        debugPrint('LocalUserStore: corrupted users payload, resetting. err=$e');
        await prefs.remove(_kUsers);
        return const [];
      }
    } catch (e) {
      debugPrint('LocalUserStore: failed to load users. err=$e');
      return const [];
    }
  }

  Future<void> saveUsers(List<AppUser> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUsers, AppUser.encodeList(users));
    } catch (e) {
      debugPrint('LocalUserStore: failed to save users. err=$e');
    }
  }

  Future<void> saveSession({required String userId, required bool rememberMe}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSessionUserId, userId);
      await prefs.setBool(_kRememberMe, rememberMe);
    } catch (e) {
      debugPrint('LocalUserStore: failed to save session. err=$e');
    }
  }

  Future<String?> loadSessionUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberMe) ?? false;
      if (!remember) return null;
      return prefs.getString(_kSessionUserId);
    } catch (e) {
      debugPrint('LocalUserStore: failed to load session. err=$e');
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionUserId);
      await prefs.remove(_kRememberMe);
    } catch (e) {
      debugPrint('LocalUserStore: failed to clear session. err=$e');
    }
  }
}
