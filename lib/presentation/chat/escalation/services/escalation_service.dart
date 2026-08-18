// lib/presentation/chat/escalation/services/escalation_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/escalation_step.dart';
import '../models/escalation_level.dart';
import '../models/escalation_status.dart';
import '../models/escalation_priority.dart';
import '../models/escalation_rule.dart';

class EscalationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── MÉTHODE MANQUANTE AJOUTÉE ───
  EscalationLevel getCurrentLevelForAgent(String agentId) {
    // Par défaut, on peut retourner Senior. À adapter si tu as une colonne 'level' dans ta table profiles
    return EscalationLevel.senior;
  }

  // 🔍 Rechercher un utilisateur par son handle (username)
  Future<Map<String, dynamic>?> getUserByHandle(String username) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .eq('username', username)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Erreur recherche utilisateur par handle : $e');
      return null;
    }
  }

  // Créer une nouvelle escalade
  Future<EscalationStep> createEscalation({
    required String conversationId,
    required String fromAgentId,
    required String targetAgentId,
    required EscalationLevel toLevel,
    required String reason,
    required EscalationPriority priority,
    String? comment,
    String? fromAgentName,
  }) async {
    try {
      final existingPending = await _supabase
          .from('escalation_steps')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('to_agent_id', targetAgentId)
          .eq('status', EscalationStatus.pending.index)
          .maybeSingle();

      if (existingPending != null) {
        throw Exception('Une escalade est déjà en attente pour cet agent');
      }

      final target = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', targetAgentId)
          .maybeSingle();
      if (target == null) {
        throw Exception('L\'utilisateur cible n\'existe pas');
      }

      final data = {
        'conversation_id': conversationId,
        'from_level': EscalationLevel.agent.index,
        'to_level': toLevel.index,
        'from_agent_id': fromAgentId,
        'to_agent_id': targetAgentId,
        'reason': reason,
        'priority': priority.index,
        'status': EscalationStatus.pending.index,
        'comment': comment,
        'from_agent_name': fromAgentName,
      };

      final response = await _supabase
          .from('escalation_steps')
          .insert(data)
          .select()
          .single();

      await _supabase
          .from('conversations')
          .update({
            'escalation_status': 'escalated',
            'current_level': toLevel.index,
            'is_escalated': true,
            'escalated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      return EscalationStep.fromJson(response);
    } catch (e) {
      print('❌ Erreur création escalade : $e');
      rethrow;
    }
  }

  // Accepter une escalade
  Future<EscalationStep> acceptEscalation(String escalationId, String agentId) async {
    try {
      final response = await _supabase
          .from('escalation_steps')
          .update({
            'status': EscalationStatus.accepted.index,
            'resolved_at': DateTime.now().toIso8601String(),
            'to_agent_id': agentId,
          })
          .eq('id', escalationId)
          .select()
          .single();

      final step = EscalationStep.fromJson(response);

      await _supabase
          .from('conversations')
          .update({
            'assigned_agent_id': agentId,
            'escalation_status': 'accepted',
            'is_escalated': false,
          })
          .eq('id', step.conversationId);

      await _supabase.from('conversation_participants').upsert(
        {
          'conversation_id': step.conversationId,
          'user_id': agentId,
          'role': 'member',
          'last_read_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'conversation_id,user_id',
      );

      return step;
    } catch (e) {
      print('❌ Erreur acceptEscalation : $e');
      rethrow;
    }
  }

  // Refuser une escalade
  Future<EscalationStep> rejectEscalation(String escalationId, String reason) async {
    final response = await _supabase
        .from('escalation_steps')
        .update({
          'status': EscalationStatus.rejected.index,
          'comment': reason,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', escalationId)
        .select()
        .single();

    final step = EscalationStep.fromJson(response);
    await _supabase
        .from('conversations')
        .update({
          'escalation_status': 'active',
          'current_level': EscalationLevel.agent.index,
          'is_escalated': false,
        })
        .eq('id', step.conversationId);

    return step;
  }

  // Résoudre une escalade
  Future<EscalationStep> resolveEscalation(String escalationId) async {
    final response = await _supabase
        .from('escalation_steps')
        .update({
          'status': EscalationStatus.resolved.index,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', escalationId)
        .select()
        .single();

    final step = EscalationStep.fromJson(response);
    await _supabase
        .from('conversations')
        .update({
          'escalation_status': 'resolved',
          'is_escalated': false,
        })
        .eq('id', step.conversationId);

    return step;
  }

  // ─── PAGINATION AJOUTÉE ICI ───
  Future<List<EscalationStep>> getEscalationHistory(
    String conversationId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase
        .from('escalation_steps')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => EscalationStep.fromJson(json))
        .toList();
  }

  // ─── PAGINATION AJOUTÉE ICI ───
  // Utilisé pour un dashboard par niveau (senior, etc.)
  Future<List<EscalationStep>> getPendingEscalations(
    String agentId,
    EscalationLevel agentLevel, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase
        .from('escalation_steps')
        .select()
        .eq('to_level', agentLevel.index)
        .eq('status', EscalationStatus.pending.index)
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => EscalationStep.fromJson(json))
        .toList();
  }

  ///// Toutes les escalades destinées à cet agent (pending + accepted + rejected…).
/// Sert d'historique « Escalades reçues ».
Future<List<EscalationStep>> getReceivedEscalations(
  String agentId, {
  int limit = 20,
  int offset = 0,
}) async {
  final response = await _supabase
      .from('escalation_steps')
      .select()
      .eq('to_agent_id', agentId)
      .order('created_at', ascending: false)
      .range(offset, offset + limit - 1);

  return (response as List)
      .map((json) => EscalationStep.fromJson(json))
      .toList();
}

/// Uniquement les pending (pour le badge).
Future<int> countPendingReceived(String agentId) async {
  final r = await _supabase
      .from('escalation_steps')
      .select('id')
      .eq('to_agent_id', agentId)
      .eq('status', EscalationStatus.pending.index)
      .count();
  return (r.count as int?) ?? 0;
}
  // Récupérer la conversation associée à une escalade
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Erreur getConversation : $e');
      return null;
    }
  }
}
