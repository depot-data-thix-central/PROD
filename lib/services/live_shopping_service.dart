// lib/services/live_shopping_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';

class LiveShoppingService {
  final _client = Supabase.instance.client;
  static const _timeout = Duration(seconds: 10);

  // ──────────── PIN / UNPIN (hôte) ────────────
  Future<void> pinProduct(String sessionId, String productId) async {
    final maxPos = await _client
        .from('live_pinned_products')
        .select('position')
        .eq('session_id', sessionId)
        .isFilter('unpinned_at', null)
        .order('position', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(_timeout);
    final next = ((maxPos?['position'] as num?)?.toInt() ?? -1) + 1;

    await _client
        .from('live_pinned_products')
        .insert({
          'session_id': sessionId,
          'product_id': productId,
          'position': next,
          'is_featured': false,
        })
        .timeout(_timeout);
  }

  Future<void> unpinProduct(String pinnedId) async {
    await _client
        .from('live_pinned_products')
        .update({'unpinned_at': DateTime.now().toIso8601String()})
        .eq('id', pinnedId)
        .timeout(_timeout);
  }

  /// Met UN produit en vedette (déclenche l'auto-scroll côté viewer)
  Future<void> setFeatured(String sessionId, String pinnedId) async {
    await _client
        .from('live_pinned_products')
        .update({'is_featured': false})
        .eq('session_id', sessionId)
        .isFilter('unpinned_at', null)
        .timeout(_timeout);
    await _client
        .from('live_pinned_products')
        .update({'is_featured': true})
        .eq('id', pinnedId)
        .timeout(_timeout);
  }

  Future<void> reorderPinned(String sessionId, List<String> orderedPinnedIds) async {
    for (int i = 0; i < orderedPinnedIds.length; i++) {
      await _client
          .from('live_pinned_products')
          .update({'position': i})
          .eq('id', orderedPinnedIds[i])
          .timeout(_timeout);
    }
  }

  // ──────────── PRÉ-PIN (au démarrage du live) ────────────
  Future<void> applyPrePinned(String sessionId, List<String> productIds) async {
    if (productIds.isEmpty) return;
    final rows = [
      for (int i = 0; i < productIds.length; i++)
        {
          'session_id': sessionId,
          'product_id': productIds[i],
          'position': i,
          'is_featured': i == 0,
        },
    ];
    await _client.from('live_pinned_products').insert(rows).timeout(_timeout);
  }

  // ──────────── VOTE CANDIDATES (hôte propose) ────────────
  Future<void> addVoteCandidate(String sessionId, String productId) async {
    try {
      await _client
          .from('live_vote_candidates')
          .insert({'session_id': sessionId, 'product_id': productId})
          .timeout(_timeout);
    } catch (_) {
      // déjà présent → ignorer
    }
  }

  Future<void> removeVoteCandidate(String sessionId, String productId) async {
    await _client
        .from('live_vote_candidates')
        .delete()
        .eq('session_id', sessionId)
        .eq('product_id', productId)
        .timeout(_timeout);
  }

  // ──────────── VOTES (spectateur) ────────────
  Future<void> toggleVote(String sessionId, String productId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    final existing = await _client
        .from('live_votes')
        .select('id')
        .eq('session_id', sessionId)
        .eq('voter_id', uid)
        .eq('product_id', productId)
        .maybeSingle()
        .timeout(_timeout);

    if (existing != null) {
      await _client.from('live_votes').delete().eq('id', existing['id']).timeout(_timeout);
    } else {
      await _client
          .from('live_votes')
          .insert({'session_id': sessionId, 'voter_id': uid, 'product_id': productId})
          .timeout(_timeout);
    }
  }

  Future<List<LiveVoteCandidate>> getVoteCandidates(
    String sessionId,
    String? currentUserId,
  ) async {
    final candidates = await _client
        .from('live_vote_candidates')
        .select('product_id')
        .eq('session_id', sessionId)
        .timeout(_timeout);

    final countsRes = await _client
        .rpc('get_live_vote_counts', params: {'p_session_id': sessionId})
        .timeout(_timeout);
    final counts = <String, int>{};
    if (countsRes is List) {
      for (final row in countsRes) {
        counts[(row as Map)['product_id'].toString()] =
            (row['vote_count'] as num).toInt();
      }
    }

    Set<String> myVotes = {};
    if (currentUserId != null) {
      final v = await _client
          .from('live_votes')
          .select('product_id')
          .eq('session_id', sessionId)
          .eq('voter_id', currentUserId)
          .timeout(_timeout);
      if (v is List) {
        myVotes = v.map((e) => (e as Map)['product_id'].toString()).toSet();
      }
    }

    final list = (candidates as List)
        .map((e) {
          final pid = (e as Map)['product_id'].toString();
          return LiveVoteCandidate(
            productId: pid,
            voteCount: counts[pid] ?? 0,
            viewerVoted: myVotes.contains(pid),
          );
        })
        .toList();
    list.sort((a, b) => b.voteCount.compareTo(a.voteCount));
    return list;
  }
}
