// lib/presentation/chat/providers/chat_settings_provider.dart
import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/utils/logger.dart'; // Assurez-vous d'avoir un logger ou utilisez debugPrint
import 'package:thix_id/models/chat/chat_user.dart';
import 'package:thix_id/models/chat/chat_settings.dart';
import 'package:thix_id/services/chat/chat_settings_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 1;

// ============================================================================
// STATE
// ============================================================================

class ChatSettingsState {
  final ChatUser? chatUser;
  final ChatSettings? settings;
  final bool isLoading;
  final String? error;
  final String? currentUserId;

  const ChatSettingsState({
    this.chatUser,
    this.settings,
    this.isLoading = false,
    this.error,
    this.currentUserId,
  });

  ChatSettingsState copyWith({
    ChatUser? chatUser,
    ChatSettings? settings,
    bool? isLoading,
    String? error,
    String? currentUserId,
  }) {
    return ChatSettingsState(
      chatUser: chatUser ?? this.chatUser,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Reset error on new data usually, but keep if specific
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class ChatSettingsNotifier extends StateNotifier<ChatSettingsState> {
  final ChatSettingsService _service;

  ChatSettingsNotifier(this._service) : super(const ChatSettingsState());

  // ── LOAD ────────────────────────────────────────────────────────────────

  Future<void> load(String userId) async {
    if (userId.isEmpty) {
      state = state.copyWith(error: 'ID utilisateur invalide');
      Logger.e('[Settings] ❌ Load failed: Invalid User ID');
      return;
    }

    state = state.copyWith(isLoading: true, error: null, currentUserId: userId);
    Logger.i('[Settings] 🔄 Loading settings for user: $userId');

    ChatUser? loadedUser;
    ChatSettings? loadedSettings;
    String? errorMsg;

    try {
      // Parallel fetch for performance
      final results = await Future.wait([
        _service.getChatUser(userId).timeout(_kRequestTimeout),
        _service.getSettings(userId).timeout(_kRequestTimeout),
      ]);

      loadedUser = results[0] as ChatUser?;
      loadedSettings = results[1] as ChatSettings?;

      Logger.i('[Settings] ✓ Data loaded successfully');
    } on TimeoutException {
      errorMsg = 'Délai dépassé. Vérifiez votre connexion.';
      Logger.e('[Settings] ⏱️ Timeout during load');
    } catch (e) {
      errorMsg = _friendlyError(e, 'chargement');
      Logger.e('[Settings]  Load error: $e');
    }

    if (!mounted) return;

    state = state.copyWith(
      chatUser: loadedUser,
      settings: loadedSettings ?? ChatSettings.empty(), // Fallback safe object
      isLoading: false,
      error: errorMsg,
    );
  }

  // ── UPDATE SETTINGS (OPTIMISTIC) ────────────────────────────────────────

  Future<bool> updateSettings(ChatSettings newSettings) async {
    if (state.currentUserId == null) {
      Logger.w('[Settings] ⚠️ Update skipped: No user ID');
      return false;
    }

    // 1. Backup current state for rollback
    final previousSettings = state.settings;
    final previousUserId = state.currentUserId;

    // 2. Optimistic UI Update
    state = state.copyWith(settings: newSettings, error: null);
    Logger.i('[Settings] 💾 Optimistic update applied');

    try {
      await _service
          .updateSettings(state.currentUserId!, newSettings)
          .timeout(_kRequestTimeout);
      
      Logger.i('[Settings] ✓ Settings saved to server');
      return true;
    } catch (e) {
      Logger.e('[Settings] ❌ Save failed, rolling back: $e');
      
      if (!mounted) return false;

      // 3. Rollback on failure
      state = state.copyWith(
        settings: previousSettings,
        error: _friendlyError(e, 'sauvegarde'),
      );
      return false;
    }
  }

  // ── UPDATE USER PROFILE ─────────────────────────────────────────────────

  Future<bool> updateChatUser(ChatUser user) async {
    if (state.currentUserId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final previousUser = state.chatUser;

    try {
      await _service
          .updateChatUser(state.currentUserId!, user)
          .timeout(_kRequestTimeout);
      
      state = state.copyWith(chatUser: user, isLoading: false);
      Logger.i('[Settings] ✓ Profile updated');
      return true;
    } catch (e) {
      Logger.e('[Settings] ❌ Profile update failed: $e');
      if (mounted) {
        state = state.copyWith(
          chatUser: previousUser,
          isLoading: false,
          error: _friendlyError(e, 'mise à jour du profil'),
        );
      }
      return false;
    }
  }

  // ── UPLOAD AVATAR ───────────────────────────────────────────────────────

  Future<String?> uploadAvatar(File image) async {
    if (state.currentUserId == null) {
      Logger.w('[Settings] ⚠️ Upload skipped: No user ID');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);
    final previousUser = state.chatUser;

    try {
      final url = await _service
          .uploadAvatar(state.currentUserId!, image)
          .timeout(Duration(seconds: 60)); // Longer timeout for uploads
      
      if (state.chatUser != null) {
        state = state.copyWith(
          chatUser: state.chatUser!.copyWith(avatarUrl: url),
          isLoading: false,
        );
        Logger.i('[Settings] ✓ Avatar uploaded: $url');
      }
      return url;
    } catch (e) {
      Logger.e('[Settings] ❌ Avatar upload failed: $e');
      if (mounted) {
        state = state.copyWith(
          chatUser: previousUser,
          isLoading: false,
          error: _friendlyError(e, 'téléchargement de l\'avatar'),
        );
      }
      return null;
    }
  }

  // ─ HELPERS ─────────────────────────────────────────────────────────────

  void clearError() {
    state = state.copyWith(error: null);
  }

  String _friendlyError(dynamic e, String context) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé lors du $context.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('storage') || msg.contains('file')) return 'Erreur de fichier. Vérifiez le format.';
    return 'Une erreur est survenue lors du $context.';
  }
}

// ============================================================================
// PROVIDER DEFINITION
// ============================================================================

final chatSettingsServiceProvider = Provider<ChatSettingsService>((ref) {
  return ChatSettingsService();
});

final chatSettingsProvider =
    StateNotifierProvider<ChatSettingsNotifier, ChatSettingsState>((ref) {
  final service = ref.watch(chatSettingsServiceProvider);
  return ChatSettingsNotifier(service);
});
