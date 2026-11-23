// lib/services/chat/status_service.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat/user_status_story.dart';

class StatusService {
  final SupabaseClient _supabase;

  StatusService(this._supabase);

  String get _uid => _supabase.auth.currentUser?.id ?? '';

  /// Liste des statuts visibles (moi + connexions)
  Future<List<UserStatusStory>> getVisibleStatuses() async {
    try {
      final res = await _supabase.rpc('rpc_get_visible_statuses');
      if (res == null) return [];
      return (res as List)
          .map((e) => UserStatusStory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ getVisibleStatuses: $e');
      return [];
    }
  }

  /// Créer un statut texte
  Future<String?> createTextStatus({
    required String content,
    String background = '#1D4ED8',
  }) async {
    try {
      final id = await _supabase.rpc('rpc_create_status', params: {
        'p_content': content,
        'p_media_url': null,
        'p_media_type': 'text',
        'p_background': background,
      });
      return id?.toString();
    } catch (e) {
      debugPrint('❌ createTextStatus: $e');
      return null;
    }
  }

  /// Créer un statut image
  Future<String?> createImageStatus({
    required Uint8List bytes,
    required String extension,
    String? caption,
  }) async {
    try {
      if (_uid.isEmpty) return null;

      final name = '${const Uuid().v4()}.$extension';
      final path = 'statuses/$_uid/$name';

      await _supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final url = _supabase.storage.from('chat-media').getPublicUrl(path);

      final id = await _supabase.rpc('rpc_create_status', params: {
        'p_content': caption,
        'p_media_url': url,
        'p_media_type': 'image',
        'p_background': '#000000',
      });
      return id?.toString();
    } catch (e) {
      debugPrint('❌ createImageStatus: $e');
      return null;
    }
  }

  /// ✅ Créer un statut vidéo.
  /// Même logique que [createImageStatus] mais avec media_type = 'video'.
  Future<String?> createVideoStatus({
    required Uint8List bytes,
    required String extension,
    String? caption,
  }) async {
    try {
      if (_uid.isEmpty) return null;

      final name = '${const Uuid().v4()}.$extension';
      final path = 'statuses/$_uid/$name';

      await _supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final url = _supabase.storage.from('chat-media').getPublicUrl(path);

      final id = await _supabase.rpc('rpc_create_status', params: {
        'p_content': caption,
        'p_media_url': url,
        'p_media_type': 'video',
        'p_background': '#000000',
      });
      return id?.toString();
    } catch (e) {
      debugPrint('❌ createVideoStatus: $e');
      return null;
    }
  }

  /// Marquer comme vu
  Future<void> markViewed(String statusId) async {
    try {
      await _supabase.rpc('rpc_mark_status_viewed', params: {
        'p_status_id': statusId,
      });
    } catch (e) {
      debugPrint('❌ markViewed: $e');
    }
  }

  /// Supprimer mon statut
  Future<void> deleteStatus(String statusId) async {
    try {
      await _supabase.rpc('rpc_delete_status', params: {
        'p_status_id': statusId,
      });
    } catch (e) {
      debugPrint('❌ deleteStatus: $e');
      rethrow;
    }
  }

  // ============================================================
  // NOUVELLES MÉTHODES (Réactions, Repost, Vues, Réponse)
  // ============================================================

  /// Réagir à un statut
  Future<void> react(String statusId, String reaction) async {
    try {
      await _supabase.rpc('rpc_react_to_status', params: {
        'p_status_id': statusId,
        'p_reaction': reaction,
      });
    } catch (e) {
      debugPrint('❌ react: $e');
    }
  }

  /// Reposter un statut
  Future<String?> repost(UserStatusStory source) async {
    return createTextStatus(
      content: (source.content != null && source.content!.trim().isNotEmpty)
          ? source.content!
          : (source.mediaUrl ?? 'Statut'),
      background: source.background,
    );
  }

  /// Récupérer la liste des personnes qui ont vu un statut
  Future<List<Map<String, dynamic>>> getViewers(String statusId) async {
    try {
      final res = await _supabase.rpc(
        'rpc_get_status_viewers',
        params: {'p_status_id': statusId},
      );
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('❌ getViewers: $e');
      return [];
    }
  }

  /// ✅ Réponse à un statut → message privé au propriétaire (façon WhatsApp).
  Future<void> replyToStatus({required String statusId, required String text}) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw StateError('Non connecté');

      // 1) Récupération du statut pour trouver le propriétaire
      final row = await _supabase
          .from('status_stories')
          .select('user_id, content, media_type')
          .eq('id', statusId)
          .single();
          
      final ownerId = row['user_id'] as String;
      if (ownerId == uid) throw StateError('own_status');

      // 2) Création ou récupération de la conversation 1:1
      // On utilise la même RPC que dans ChatService pour éviter la duplication
      final convIdRaw = await _supabase
          .rpc('create_direct_conversation', params: {'p_other_user_id': ownerId});
          
      final convId = convIdRaw?.toString();
      if (convId == null || convId.isEmpty) {
        throw StateError('Impossible de créer la conversation');
      }

      // 3) Construction de la citation (façon WhatsApp)
      final original = (row['content'] as String?)?.trim() ?? '';
      final excerpt = original.length > 80 ? '${original.substring(0, 80)}…' : original;
      final isMedia = row['media_type'] != null && row['media_type'] != 'text';
      final quote = isMedia ? '↩️ Statut (média)' : '↩️ Statut : « $excerpt »';

      // 4) Envoi du message
      await _supabase.from('messages').insert({
        'conversation_id': convId,
        'sender_id': uid,
        'content': '$quote\n\n$text',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      debugPrint('✅ replyToStatus envoyé dans la conv $convId');
    } catch (e) {
      debugPrint('❌ replyToStatus: $e');
      rethrow;
    }
  }
}
