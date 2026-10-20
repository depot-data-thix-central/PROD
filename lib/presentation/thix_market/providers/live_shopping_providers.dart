// lib/presentation/thix_market/providers/live_shopping_providers.dart
// ============================================================================
// LIVE SHOPPING PROVIDERS — Realtime + Polling
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';
import 'package:thix_id/services/live_shopping_service.dart';

/// Charge les détails complets d'un produit épinglé
final livePinnedProductDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, productId) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('id, title, price, discount_price, currency, image_url, images, stock')
        .eq('id', productId)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));
    return res != null ? Map<String, dynamic>.from(res) : null;
  } catch (e) {
    debugPrint('[LiveProvider] ❌ Fetch product $productId error: $e');
    return null;
  }
});

/// Stream Realtime : liste des produits actuellement épinglés
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

/// Polling 3s : candidats au vote + compteurs
final liveVoteCandidatesProvider =
    FutureProvider.autoDispose.family<List<LiveVoteCandidate>, String>(
        (ref, sessionId) async {
  final service = LiveShoppingService();
  final uid = Supabase.instance.client.auth.currentUser?.id;

  final timer = Timer.periodic(const Duration(seconds: 3), (_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    timer.cancel();
  });

  return service.getVoteCandidates(sessionId, uid);
});

/// ID du produit actuellement "featured"
final liveFeaturedProductIdProvider =
    Provider.family<String?, List<LivePinnedProduct>>((ref, pinned) {
  final featured = pinned.where((p) => p.isFeatured).toList();
  return featured.isEmpty ? null : featured.first.productId;
});
