// lib/presentation/thix_weeding/pages/staff/services/menu_service.dart
// ============================================================================
// MENU SERVICE — CRUD plats + votes invités
// ============================================================================
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuService {
  final _c = Supabase.instance.client;

  // ─── PLATS ─────────────────────────────────────────────────────────────
  /// Tous les plats d'un mariage (avec jointure vendor)
  Future<List<Map<String, dynamic>>> getByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_menu_items')
        .select('*, vendor:thix_weeding_vendors(id, name, category, contact_name)')
        .eq('wedding_id', weddingId)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Plats publics d'un mariage (pour les invités)
  Future<List<Map<String, dynamic>>> getPublicByWedding(String weddingId) async {
    final res = await _c
        .from('thix_weeding_menu_items')
        .select('*, vendor:thix_weeding_vendors(id, name, category)')
        .eq('wedding_id', weddingId)
        .eq('is_public', true)
        .order('position', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Créer un plat
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await _c
        .from('thix_weeding_menu_items')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(res);
  }

  /// Mettre à jour un plat (is_validated, is_public, etc.)
  Future<void> update(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _c.from('thix_weeding_menu_items').update(data).eq('id', id);
  }

  /// Supprimer un plat
  Future<void> delete(String id) async {
    await _c.from('thix_weeding_menu_items').delete().eq('id', id);
  }

  // ─── VOTES ─────────────────────────────────────────────────────────────
  /// Compter les votes par menu_item_id pour un mariage
  Future<Map<String, int>> getVoteCounts(String weddingId) async {
    final res = await _c
        .from('thix_weeding_menu_votes')
        .select('menu_item_id')
        .eq('wedding_id', weddingId);
    final counts = <String, int>{};
    for (final r in List<Map<String, dynamic>>.from(res)) {
      final id = r['menu_item_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// Votes d'un invité spécifique
  Future<Set<String>> getGuestVotes(String weddingId, String guestId) async {
    final res = await _c
        .from('thix_weeding_menu_votes')
        .select('menu_item_id')
        .eq('wedding_id', weddingId)
        .eq('guest_id', guestId);
    return List<Map<String, dynamic>>.from(res)
        .map((e) => e['menu_item_id'] as String)
        .toSet();
  }

  /// Voter / retirer un vote
  Future<void> toggleVote({
    required String weddingId,
    required String menuItemId,
    required String guestId,
    required String guestName,
    required bool vote,
  }) async {
    if (vote) {
      try {
        await _c.from('thix_weeding_menu_votes').insert({
          'wedding_id': weddingId,
          'menu_item_id': menuItemId,
          'guest_id': guestId,
          'guest_name': guestName,
        });
      } catch (e) {
        // UNIQUE constraint : le vote existe déjà → on ignore
        if (!e.toString().contains('duplicate')) rethrow;
      }
    } else {
      await _c
          .from('thix_weeding_menu_votes')
          .delete()
          .eq('wedding_id', weddingId)
          .eq('menu_item_id', menuItemId)
          .eq('guest_id', guestId);
    }
  }
}
