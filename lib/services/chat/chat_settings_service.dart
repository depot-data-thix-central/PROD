// ============================================================
// 📁 lib/services/chat/chat_settings_service.dart
// ============================================================

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat/chat_user.dart';
import '../../models/chat/chat_settings.dart';

class ChatSettingsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ChatUser> getChatUser(String userId) async {
    final response = await _supabase
        .from('profiles')
        // Si Supabase crash ici, c'est qu'une de ces colonnes manque dans ta DB !
        .select('id, display_name, username, avatar_url, chat_display_name, chat_avatar, chat_status, last_seen_at, is_online')
        .eq('id', userId)
        .single();
    return ChatUser.fromJson(response);
  }

  Future<void> updateChatUser(String userId, ChatUser user) async {
    await _supabase
        .from('profiles')
        .update({
          'chat_display_name': user.displayName,
          'chat_avatar': user.avatarUrl,
          'chat_status': user.status,
        })
        .eq('id', userId);
  }

  Future<String> uploadAvatar(String userId, File image) async {
    final bytes = await image.readAsBytes();
    final ext = image.path.split('.').last;
    final path = 'avatars/$userId.$ext';

    await _supabase.storage.from('profiles').uploadBinary(path, bytes, fileOptions: FileOptions(
      upsert: true,
      contentType: 'image/$ext',
    ));

    final publicUrl = _supabase.storage.from('profiles').getPublicUrl(path);
    return publicUrl;
  }

  Future<ChatSettings> getSettings(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('chat_settings')
        .eq('id', userId)
        .maybeSingle(); // Utilisation de maybeSingle pour éviter le crash si la ligne n'existe pas
        
    if (response == null || response['chat_settings'] == null) {
      return ChatSettings.fromJson({}); // Si vide, retourne les valeurs par défaut
    }

    final raw = response['chat_settings'] as Map<String, dynamic>;
    return ChatSettings.fromJson(raw);
  }

  Future<void> updateSettings(String userId, ChatSettings settings) async {
    await _supabase
        .from('profiles')
        .update({
          'chat_settings': settings.toJson(),
        })
        .eq('id', userId);
  }
}
