// lib/presentation/thix_market/providers/live_shopping_providers.dart
// ============================================================================
// LIVE SHOPPING PROVIDERS — Realtime + Polling
// ============================================================================
// Compatible Riverpod 2.6.1
// ============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';
import 'package:thix_id/services/live_shopping_service.dart';

/// Stream Realtime : liste des produits actuellement épinglés (ordonnés par position)
final livePinnedProductsProvider =
    StreamProvider.family<List<LivePinnedProduct>, String>((ref, sessionId) {
  return Supabase.instance.client
      .from('live_pinned_products')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .isFilter('unpinned_at', null)
      .map((rows) => rows
          .map((e) => LivePinnedProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)));
});

/// Polling 3s : candidats au vote + compteurs (via RPC get_live_vote_counts)
/// ✅ Compatible Riverpod 2.6.1 : Timer annulé automatiquement via ref.onDispose
final liveVoteCandidatesProvider =
    FutureProvider.autoDispose.family<List<LiveVoteCandidate>, String>(
        (ref, sessionId) async {
  final service = LiveShoppingService();
  final uid = Supabase.instance.client.auth.currentUser?.id;

  // ✅ CORRECTION : utiliser un Timer + ref.onDispose au lieu de Future.delayed + ref.exists
  final timer = Timer.periodic(const Duration(seconds: 3), (_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    timer.cancel();
  });

  return service.getVoteCandidates(sessionId, uid);
});

/// Dérivé : ID du produit actuellement "featured" (pour auto-scroll du carousel viewer)
final liveFeaturedProductIdProvider =
    Provider.family<String?, List<LivePinnedProduct>>((ref, pinned) {
  final featured = pinned.where((p) => p.isFeatured).toList();
  return featured.isEmpty ? null : featured.first.productId;
});
