// lib/presentation/thix_market/widgets/live/live_pinned_product_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LivePinnedProductCard extends ConsumerWidget {
  final String productId;
  final bool isFeatured;
  final VoidCallback onTap;
  final VoidCallback? onSetFeatured;

  const LivePinnedProductCard({
    super.key,
    required this.productId,
    required this.isFeatured,
    required this.onTap,
    this.onSetFeatured,
  });

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Future: remplacer par productProvider(productId) pour charger image + prix
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 160,
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.85),
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.shopping_bag_rounded,
                        color: Colors.white38, size: 32),
                  ),
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
                            Text('EN VEDETTE',
                                style: TextStyle(
                                    color: _navy,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
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
                          child: const Icon(Icons.star_border_rounded,
                              color: _gold, size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Produit ${productId.substring(0, productId.length.clamp(0, 8))}...',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  const Text('— FCFA',
                      style: TextStyle(
                          color: _gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
