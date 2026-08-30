// lib/presentation/thix_market/widgets/products/product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// Compatibilité avec l'ancien design system (fallback)
import '../../core/market_colors.dart';
import '../../l10n/market_strings.dart';
import 'wishlist_button.dart';

enum ProductCardVariant { grid, horizontal }

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ProductCardValidators {
  _ProductCardValidators._();

  static const int _kMaxTitleLength = 120;
  static const int _kMaxCityLength = 60;

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    try {
      final doc = html_parser.parse(input);
      var sanitized = doc.body?.text ?? input;
      sanitized = sanitized
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
          .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .trim();
      return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
    } catch (_) {
      return '';
    }
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Parse un prix avec protection contre NaN / Infinity / négatif
  static double parsePrice(dynamic v) {
    if (v == null) return 0;
    double parsed;
    if (v is num) {
      parsed = v.toDouble();
    } else {
      parsed = double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.,-]'), '')) ?? 0;
    }
    if (parsed.isNaN || parsed.isInfinite || parsed < 0) return 0;
    return parsed;
  }

  static int parseStock(dynamic v) {
    if (v == null) return 1;
    final parsed = int.tryParse(v.toString());
    return (parsed != null && parsed >= 0) ? parsed : 0;
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class ProductCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final ProductCardVariant variant;
  final bool isFlashSale;
  final bool isFeatured;
  final bool showFavoriteButton;
  final bool isFavorite;
  final double? width;
  final Function(Map<String, dynamic>)? onTap;
  final Function(String)? onFavoriteTap;

  const ProductCard({
    super.key,
    required this.product,
    this.variant = ProductCardVariant.grid,
    this.isFlashSale = false,
    this.isFeatured = false,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.width,
    this.onTap,
    this.onFavoriteTap,
  });

  String? _extractImage(Map<String, dynamic> p) {
    final url1 = p['image_url']?.toString();
    if (url1 != null && url1.isNotEmpty) return _ProductCardValidators.sanitizeUrl(url1);
    if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      return _ProductCardValidators.sanitizeUrl((p['images'] as List).first.toString());
    }
    if (p['media_url'] != null) return _ProductCardValidators.sanitizeUrl(p['media_url'].toString());
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mkt;

    // ─── Parsing sécurisé ───
    final originalPrice = _ProductCardValidators.parsePrice(product['price']);
    final rawDiscount = product['discount_price'];
    final discountPrice = rawDiscount != null ? _ProductCardValidators.parsePrice(rawDiscount) : null;
    final hasDiscount = discountPrice != null && discountPrice > 0 && discountPrice < originalPrice;
    final price = hasDiscount ? discountPrice! : originalPrice;

    final discountPercent = originalPrice > 0 && hasDiscount
        ? ((originalPrice - price) / originalPrice * 100).round()
        : 0;

    final currency = (product['currency'] ?? 'CDF').toString().toUpperCase();
    final symbol = currency == 'USD' ? '\$' : 'FC';

    final stock = _ProductCardValidators.parseStock(product['stock']);
    final isOut = stock <= 0;
    final isLowStock = !isOut && stock <= 5;

    final img = _extractImage(product);
    final title = _ProductCardValidators.sanitize(
      product['title']?.toString() ?? product['name']?.toString(),
      maxLength: _ProductCardValidators._kMaxTitleLength,
    );
    final city = _ProductCardValidators.sanitize(
      product['city']?.toString() ?? product['location']?.toString() ?? t.cityFallback,
      maxLength: _ProductCardValidators._kMaxCityLength,
    );
    final id = product['id']?.toString() ?? '';

    final isHorizontal = variant == ProductCardVariant.horizontal;
    final borderRadius = isHorizontal ? 12.0 : 10.0;
    final aspectRatio = isHorizontal ? 4 / 3 : 1.0;

    final card = Container(
      width: isHorizontal ? (width ?? 138) : null,
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isOut ? ThixPolicy.border : ThixPolicy.border.withOpacity(0.7),
        ),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image avec placeholder premium + cache
                  Container(
                    color: ThixPolicy.surfaceSoft,
                    child: img == null || img.isEmpty
                        ? const _ImagePlaceholder()
                        : CachedNetworkImage(
                            imageUrl: img,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 150),
                            placeholder: (context, url) => const _ImageLoading(),
                            errorWidget: (context, url, error) => const _ImagePlaceholder(),
                          ),
                  ),

                  // Overlay "Rupture"
                  if (isOut)
                    Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45)),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.outOfStock,
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),

                  // Badge (flash / featured / discount)
                  if (!isOut && (isFlashSale || isFeatured || hasDiscount))
                    Positioned(
                      top: 5,
                      left: 5,
                      child: _buildBadge(
                        isFlashSale: isFlashSale,
                        isFeatured: isFeatured,
                        discountPercent: discountPercent,
                        t: t,
                      ),
                    ),

                  // Bouton favori
                  if (showFavoriteButton && id.isNotEmpty)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: WishlistButton(productId: id, size: 15),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Infos produit ───
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.isEmpty ? '—' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 11,
                    color: ThixPolicy.textMain,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 9.5, color: ThixPolicy.textMuted),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hasDiscount && !isOut)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${originalPrice.toInt()}',
                          style: TextStyle(decoration: TextDecoration.lineThrough, fontSize: 9, color: ThixPolicy.textMuted),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _buildPriceLabel(isOut: isOut, price: price, symbol: symbol, t: t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13,
                          color: isOut ? ThixPolicy.textMuted : ThixPolicy.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isOut) ...[
                  const SizedBox(height: 3),
                  _buildStockLabel(stock: stock, isLowStock: isLowStock, t: t),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${title.isEmpty ? "Produit" : title}, ${isOut ? "indisponible" : "${price.toInt()} $symbol"}',
        enabled: !isOut,
        child: GestureDetector(
          onTap: () => _handleTap(context: context, id: id, isOut: isOut, t: t),
          child: Opacity(opacity: isOut ? 0.72 : 1.0, child: card),
        ),
      ),
    );
  }

  void _handleTap({
    required BuildContext context,
    required String id,
    required bool isOut,
    required MarketStrings t,
  }) {
    if (isOut) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.outOfStock),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();

    if (onTap != null) {
      onTap!(product);
      return;
    }

    if (id.isEmpty) {
      debugPrint('[ProductCard] ⚠️ Tap on product with empty ID');
      return;
    }

    debugPrint('[ProductCard] 🛍️ Tap product $id');
    context.push('/market/product/$id');
  }

  Widget _buildBadge({
    required bool isFlashSale,
    required bool isFeatured,
    required int discountPercent,
    required MarketStrings t,
  }) {
    final gradient = isFlashSale
        ? const LinearGradient(colors: [ThixPolicy.danger, Color(0xFFFF5252)])
        : isFeatured
            ? const LinearGradient(colors: [Color(0xFFC9862B), ThixPolicy.gold])
            : const LinearGradient(colors: [ThixPolicy.danger, Color(0xFFB71C1C)]);

    final label = isFlashSale
        ? t.flashBadge
        : isFeatured
            ? t.featuredBadge.toUpperCase()
            : '-$discountPercent%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: (isFeatured ? ThixPolicy.gold : ThixPolicy.danger).withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }

  String _buildPriceLabel({
    required bool isOut,
    required double price,
    required String symbol,
    required MarketStrings t,
  }) {
    if (isOut) return t.unavailable;
    if (price <= 0) return t.priceOnRequest ?? 'Sur demande';
    return '${price.toInt()} $symbol';
  }

  Widget _buildStockLabel({
    required int stock,
    required bool isLowStock,
    required MarketStrings t,
  }) {
    final color = isLowStock ? ThixPolicy.warning : ThixPolicy.success;
    final label = isLowStock
        ? 'Plus que $stock !'
        : '$stock ${t.inStock}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: ThixPolicy.microStyle.copyWith(
            fontSize: 8.5,
            fontWeight: ThixPolicy.semiBold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS D'IMAGE
// ============================================================================
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.shopping_bag_outlined, color: ThixPolicy.textMuted, size: 28),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
      ),
    );
  }
}
