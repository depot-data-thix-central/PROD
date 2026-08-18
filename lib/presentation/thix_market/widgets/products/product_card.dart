// lib/presentation/thix_market/widgets/products/product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/market_colors.dart';
import '../../l10n/market_strings.dart';
import 'wishlist_button.dart';

enum ProductCardVariant { grid, horizontal }

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

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String? _extractImage(Map<String, dynamic> p) {
    if (p['image_url'] != null && p['image_url'].toString().isNotEmpty) {
      return p['image_url'].toString();
    }
    if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      return (p['images'] as List).first.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mkt;
    final rawPrice = product['price'];
    final rawDiscount = product['discount_price'];

    final originalPrice = _toDouble(rawPrice);
    final discountPrice = rawDiscount != null ? _toDouble(rawDiscount) : null;
    final hasDiscount =
        discountPrice != null && discountPrice > 0 && discountPrice < originalPrice;
    final price = hasDiscount ? discountPrice : originalPrice;

    final discountPercent = originalPrice > 0 && hasDiscount
        ? ((originalPrice - price) / originalPrice * 100).round()
        : 0;

    final currency = (product['currency'] ?? 'CDF').toString().toUpperCase();
    final symbol = currency == 'USD' ? '\$' : 'FC';

    final stock = int.tryParse(product['stock']?.toString() ?? '1') ?? 1;
    final isOut = stock <= 0;

    final img = _extractImage(product);
    final title = (product['title'] ?? product['name'] ?? '').toString();
    final city = (product['city'] ?? product['location'] ?? t.cityFallback).toString();
    final id = product['id']?.toString() ?? '';

    final isHorizontal = variant == ProductCardVariant.horizontal;
    final borderRadius = isHorizontal ? 12.0 : 10.0;

    final card = Container(
      width: isHorizontal ? (width ?? 138) : null,
      decoration: BoxDecoration(
        color: MarketColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isOut ? const Color(0xFFEDEDED) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: MarketColors.lightBg,
                    child: img == null || img.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: MarketColors.mutedText,
                              size: 28,
                            ),
                          )
                        : Image.network(
                            img,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MarketColors.red,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: MarketColors.mutedText,
                                size: 28,
                              ),
                            ),
                          ),
                  ),
                  if (isOut)
                    Container(
                      decoration: const BoxDecoration(color: Color(0x66000000)),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: MarketColors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.outOfStock,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!isOut && (isFlashSale || isFeatured || hasDiscount))
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isFlashSale
                                ? [MarketColors.redDark, MarketColors.red]
                                : isFeatured
                                    ? [const Color(0xFFC9862B), MarketColors.gold]
                                    : [MarketColors.red, MarketColors.redDark],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          isFlashSale
                              ? t.flashBadge
                              : isFeatured
                                  ? t.featuredBadge.toUpperCase()
                                  : '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  if (showFavoriteButton)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: WishlistButton(productId: id, size: 15),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Color(0xFF1A1D29),
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 9.5,
                      color: MarketColors.mutedText,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: MarketColors.mutedText,
                        ),
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
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 9,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        isOut ? t.unavailable : '${price.toInt()} $symbol',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isOut ? Colors.grey : MarketColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isOut) ...[
                  const SizedBox(height: 3),
                  Text(
                    '$stock ${t.inStock}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00B074),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: isOut
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.outOfStock),
                    backgroundColor: MarketColors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : () {
                if (onTap != null) {
                  onTap!(product);
                } else {
                  context.push('/market/product/$id');
                }
              },
        child: Opacity(
          opacity: isOut ? 0.72 : 1.0,
          child: card,
        ),
      ),
    );
  }
}
