// lib/presentation/thix_market/widgets/products/shop_products_section.dart
// ============================================================================
// SECTION "PLUS DE PRODUITS DE CETTE BOUTIQUE"
// À intégrer en bas de la fiche produit (product_details_page.dart)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/widgets/products/product_card.dart';

const Duration _kShopProductsTimeout = Duration(seconds: 12);
const int _kMaxShopProducts = 12;

/// Produits actifs d'une boutique (12 max, plus récents d'abord)
final shopProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, shopId) async {
  final res = await Supabase.instance.client
      .from('products')
      .select(
        'id, title, price, discount_price, currency, image_url, images, stock, '
        'city, brand, category, is_flash_sale, expires_at, created_at, shop:shops(name)',
      )
      .eq('shop_id', shopId)
      .eq('status', 'active')
      .order('created_at', ascending: false)
      .limit(_kMaxShopProducts)
      .timeout(_kShopProductsTimeout);
  return List<Map<String, dynamic>>.from(res);
});

class ShopProductsSection extends ConsumerWidget {
  final String shopId;
  final String? excludeProductId;

  const ShopProductsSection({
    super.key,
    required this.shopId,
    this.excludeProductId,
  });

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shopId.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final async = ref.watch(shopProductsProvider(shopId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        // Exclut le produit actuellement consulté
        final list = products
            .where((p) => p['id']?.toString() != excludeProductId)
            .toList();

        // Masque la section si pas assez de produits
        if (list.length < 2) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ThixPolicy.domainMarket.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        size: 14, color: ThixPolicy.domainMarket),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tr(l10n, 'product_more_from_shop',
                          'Plus de produits de cette boutique'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ThixPolicy.textMain,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/market/shop/$shopId');
                    },
                    child: Text(
                      _tr(l10n, 'common_see_all', 'Voir tout'),
                      style: const TextStyle(
                          color: ThixPolicy.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final id = p['id']?.toString() ?? '';
                  return SizedBox(
                    width: 160,
                    child: ProductCard(
                      product: p,
                      onTap: (_) {
                        HapticFeedback.selectionClick();
                        context.push('/market/product/$id');
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
