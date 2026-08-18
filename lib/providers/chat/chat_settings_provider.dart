// ============================================================
// 📁 lib/providers/chat/chat_settings_provider.dart
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/chat/chat_user.dart';
import '../../models/chat/chat_settings.dart';
import '../../services/chat/chat_settings_service.dart';

class ChatSettingsProvider extends ChangeNotifier {
  final ChatSettingsService _service = ChatSettingsService();

  ChatUser? _chatUser;
  ChatSettings? _settings;
  bool _isLoading = false;
  String? _error;
  
  String? _currentUserId; 

  ChatUser? get chatUser => _chatUser;
  ChatSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load(String userId) async {
    _currentUserId = userId; 
    _setLoading(true);
    _error = null;

    try {
      _chatUser = await _service.getChatUser(userId);
    } catch (e) {
      print('⚠️ Erreur Supabase (getChatUser) : $e');
      _error = 'Erreur Profil: $e';
    }

    try {
      _settings = await _service.getSettings(userId);
    } catch (e) {
      print('⚠️ Erreur Supabase (getSettings) : $e');
      _settings = ChatSettings.fromJson({});
    }

    _setLoading(false);
  }

  // ============================================================
  // 🔥 MISE À JOUR OPTIMISTE (L'interface change instantanément)
  // ============================================================
  Future<bool> updateSettings(ChatSettings newSettings) async {
    if (_currentUserId == null) return false;

    // 1. On sauvegarde l'ancien état au cas où Supabase refuse
    final backupSettings = _settings;
    
    // 2. On met à jour l'interface IMMÉDIATEMENT !
    _settings = newSettings;
    notifyListeners();

    try {
      // 3. On envoie à Supabase en arrière-plan
      await _service.updateSettings(_currentUserId!, newSettings);
      return true;
    } catch (e) {
      print('❌ Erreur de sauvegarde Supabase : $e');
      
      // 4. Si Supabase échoue, on annule et on remet l'ancienne valeur
      _settings = backupSettings;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateChatUser(ChatUser user) async {
    if (_currentUserId == null) return false;
    _setLoading(true);
    try {
      await _service.updateChatUser(_currentUserId!, user);
      _chatUser = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<String?> uploadAvatar(File image) async {
    if (_currentUserId == null || _chatUser == null) return null;
    _setLoading(true);
    try {
      final url = await _service.uploadAvatar(_currentUserId!, image);
      _chatUser = _chatUser!.copyWith(avatarUrl: url);
      _setLoading(false);
      return url;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
