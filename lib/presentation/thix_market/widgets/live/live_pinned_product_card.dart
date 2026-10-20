// lib/presentation/thix_market/widgets/live/live_pinned_product_card.dart
// ============================================================================
// LIVE PINNED PRODUCT CARD — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Charge les vrais détails produit (image, titre, prix) via Supabase
//  • ✅ Conversion automatique des devises (54 devises africaines)
//  • ✅ Hauteur adaptative (plus de coupe)
//  • ✅ Navigation vers ProductDetailPage au tap
//  • ✅ Badge réduction + indicateur 💱 si conversion
//  • ✅ Placeholder skeleton pendant le chargement
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../core/african_currencies.dart';
import '../../core/currency_service.dart';
import '../../providers/currency_provider.dart';

// ============================================================================
// PROVIDER LOCAL — Charge les détails d'un produit épinglé
// ============================================================================
final _liveProductDetailProvider =
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
    debugPrint('[LivePinnedCard] ❌ Fetch product $productId error: $e');
    return null;
  }
});

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class LivePinnedProductCard extends ConsumerWidget {
  final String productId;
  final bool isFeatured;
  final VoidCallback? onTap;
  final VoidCallback? onSetFeatured;

  const LivePinnedProductCard({
    super.key,
    required this.productId,
    required this.isFeatured,
    this.onTap,
    this.onSetFeatured,
  });

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_liveProductDetailProvider(productId));
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;
    final lang = Localizations.localeOf(context).languageCode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 170,
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFeatured ? _gold : Colors.white24,
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: _gold.withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap ??
            () {
              HapticFeedback.selectionClick();
              context.push('/market/product/$productId');
            },
        borderRadius: BorderRadius.circular(16),
        child: productAsync.when(
          loading: () => _buildSkeleton(isFeatured),
          error: (_, __) => _buildSkeleton(isFeatured),
          data: (product) {
            if (product == null) return _buildSkeleton(isFeatured);
            return _buildContent(product, displayCurrencyCode, currencyService, lang);
          },
        ),
      ),
    );
  }

  // ─── CONTENU AVEC VRAIES DONNÉES PRODUIT ───
  Widget _buildContent(
    Map<String, dynamic> product,
    String displayCurrencyCode,
    CurrencyService currencyService,
    String lang,
  ) {
    // ✅ Extraire l'image
    String? imageUrl = product['image_url']?.toString();
    if ((imageUrl == null || imageUrl.isEmpty) && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) imageUrl = images.first.toString();
    }

    // ✅ Titre
    final title = (product['title']?.toString() ?? 'Produit').trim();

    // ✅ Prix avec conversion
    final sellerCurrency = (product['currency'] ?? 'CDF').toString().toUpperCase();
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final discountPrice = (product['discount_price'] as num?)?.toDouble();
    final hasDiscount = discountPrice != null && discountPrice > 0 && discountPrice < price;
    final displayPrice = hasDiscount ? discountPrice! : price;

    final convertedPrice = currencyService.convert(
      displayPrice,
      from: sellerCurrency,
      to: displayCurrencyCode,
    );
    final formattedPrice = currencyService.formatPrice(
      convertedPrice,
      currencyCode: displayCurrencyCode,
      lang: lang,
    );

    final isConverted = sellerCurrency != displayCurrencyCode;

    // Prix original barré (converti aussi)
    String? formattedOriginalPrice;
    if (hasDiscount) {
      final convertedOriginal = currencyService.convert(
        price,
        from: sellerCurrency,
        to: displayCurrencyCode,
      );
      formattedOriginalPrice = currencyService.formatPrice(
        convertedOriginal,
        currencyCode: displayCurrencyCode,
        lang: lang,
      );
    }

    // Pourcentage de réduction
    final discountPercent = hasDiscount
        ? ((price - discountPrice!) / price * 100).round()
        : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── IMAGE PRODUIT ───
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Stack(
            children: [
              imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => Container(
                        height: 100,
                        color: Colors.white.withOpacity(0.08),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 100,
                        color: Colors.white.withOpacity(0.08),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 32),
                        ),
                      ),
                    )
                  : Container(
                      height: 100,
                      color: Colors.white.withOpacity(0.08),
                      child: const Center(
                        child: Icon(Icons.shopping_bag_rounded, color: Colors.white38, size: 32),
                      ),
                    ),

              // Badge "EN VEDETTE"
              if (isFeatured)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: _navy, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'EN VEDETTE',
                          style: TextStyle(color: _navy, fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),

              // Badge réduction
              if (hasDiscount)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-$discountPercent%',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

              // Bouton définir comme vedette (hôte uniquement)
              if (onSetFeatured != null && !isFeatured)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onSetFeatured,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_border_rounded, color: _gold, size: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ─── INFOS PRODUIT ───
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              Text(
                title.isEmpty ? 'Produit' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),

              // Prix converti
              Row(
                children: [
                  Flexible(
                    child: Text(
                      formattedPrice,
                      style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isConverted) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.currency_exchange_rounded, size: 10, color: _gold),
                  ],
                ],
              ),

              // Prix original barré
              if (hasDiscount && formattedOriginalPrice != null)
                Text(
                  formattedOriginalPrice,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── SKELETON PENDANT LE CHARGEMENT ───
  Widget _buildSkeleton(bool isFeatured) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image placeholder
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
            ),
          ),
        ),

        // Texte placeholder
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
