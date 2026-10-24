// lib/services/chat/call_block_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Blocage des appels PAR CONVERSATION.
/// - Le premier qui bloque enregistre une ligne (clé primaire = conversation_id).
/// - Seul celui qui a bloqué peut supprimer la ligne (réactiver).
class CallBlockService {
  static const String _table = 'chat_call_blocks';
  SupabaseClient get _db => Supabase.instance.client;

  /// Id de celui qui a désactivé les appels, ou null si les appels sont actifs.
  Future<String?> fetch(String conversationId) async {
    final row = await _db
        .from(_table)
        .select('blocked_by')
        .eq('conversation_id', conversationId)
        .maybeSingle();
    return row?['blocked_by'] as String?;
  }

  /// Flux temps réel (insertions/mises à jour). Les suppressions sont
  /// rattrapées par le rafraîchissement périodique de l'écran.
  Stream<String?> watch(String conversationId) {
    return _db
        .from(_table)
        .stream(primaryKey: ['conversation_id'])
        .eq('conversation_id', conversationId)
        .map((rows) => rows.isEmpty ? null : rows.first['blocked_by'] as String?);
  }

  /// true = blocage créé ; false = quelqu'un avait déjà bloqué.
  Future<bool> block(String conversationId, String me) async {
    try {
      await _db.from(_table).insert({'conversation_id': conversationId, 'blocked_by': me});
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return false; // déjà bloqué (premier arrivé = propriétaire)
      rethrow;
    }
  }

  /// Ne supprime que si c'est moi qui ai bloqué (aussi imposé par la base).
  Future<void> unblock(String conversationId, String me) async {
    await _db.from(_table).delete().eq('conversation_id', conversationId).eq('blocked_by', me);
  }
}
