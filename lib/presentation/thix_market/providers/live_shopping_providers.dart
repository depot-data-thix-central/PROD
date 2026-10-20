// lib/presentation/thix_market/providers/live_shopping_providers.dart
// AJOUTER À LA FIN DU FICHIER

import '../core/currency_service.dart';
import '../core/african_currencies.dart';

/// Charge les détails complets d'un produit épinglé via jointure Supabase
final livePinnedProductDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, productId) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('id, title, price, discount_price, currency, image_url, images, stock, shop:shops(name)')
        .eq('id', productId)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));
    return res != null ? Map<String, dynamic>.from(res) : null;
  } catch (e) {
    debugPrint('[LiveProvider] ❌ Fetch product $productId error: $e');
    return null;
  }
});

/// Version enrichie du stream pinned products avec détails produit joints
final livePinnedProductsEnrichedProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, sessionId) {
  return Supabase.instance.client
      .from('live_pinned_products')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .isFilter('unpinned_at', null)
      .map((rows) {
        final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        list.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
            .compareTo(((b['position'] as num?)?.toInt() ?? 0)));
        return list;
      });
});
