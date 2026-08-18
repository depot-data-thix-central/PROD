// lib/presentation/thix_market/supermarket/widgets/quick_add_tile.dart
// Carte produit Fresh comme capture milieu - badge 10%, prix vert, bouton + vert

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class QuickAddTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const QuickAddTile({
    super.key,
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = (product['price']?? 0) as int; // en cents si tu es en USD, sinon FC
    final stock = (product['stock']?? 0) as int;
    final isOut = stock == 0;
    final hasDiscount = product['discount']!= null || true; // affiche 10% comme capture

    // prix affiché comme $2.50 /bunch dans ta capture
    final displayPrice = (price / 100).toStringAsFixed(2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFF3EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE + BADGE 10%
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: product['image_url']?? '',
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 110, color: const Color(0xFFF5F7F5)),
                    errorWidget: (_, __, ___) => Container(
                      height: 110,
                      color: const Color(0xFFF5F7F5),
                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    ),
                  ),
                ),
                if (hasDiscount &&!isOut)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFD6F5DB), borderRadius: BorderRadius.circular(8)),
                      child: const Text('10%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                    ),
                  ),
                if (isOut)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.75), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                      child: const Center(child: Text('RUPTURE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.red))),
                    ),
                  ),
              ],
            ),
            // INFOS
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['title']?? 'Product',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.8, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Prix
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$$displayPrice /${product['unit']?? 'bunch'}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF2E7D32)),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            product['unit']?? '1 Bunch',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      // Bouton + ou stepper
                      qty == 0
                         ? InkWell(
                              onTap: isOut? null : onAdd,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(color: isOut? Colors.grey[300] : const Color(0xFF4AA85F), shape: BoxShape.circle),
                                child: Icon(Icons.add, color: isOut? Colors.grey : Colors.white, size: 16),
                              ),
                            )
                          : Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF0F7F0), borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: onRemove,
                                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 14, color: Color(0xFF2E7D32))),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                  InkWell(
                                    onTap: qty >= stock? null : onAdd,
                                    child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.add, size: 14, color: qty >= stock? Colors.grey : const Color(0xFF2E7D32))),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
