import 'package:flutter/material.dart';

class CartItemTile extends StatelessWidget {
  final Map<String, dynamic> cartItem;
  final double realPrice;
  final double oldPrice;
  final int discountPercent;
  final String currency;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key, 
    required this.cartItem, 
    required this.realPrice, 
    required this.oldPrice, 
    required this.discountPercent, 
    required this.currency, 
    required this.onQuantityChanged, 
    required this.onRemove
  });

  @override
  Widget build(BuildContext context) {
    final product = (cartItem['product'] as Map<String, dynamic>?) ?? {};
    final shop = (product['shop'] as Map<String, dynamic>?) ?? {};
    final qty = (cartItem['quantity'] as int?) ?? 1;
    
    final hasDiscount = discountPercent > 0 && realPrice < oldPrice;
    final shopName = shop['name'] ?? product['shop_name'] ?? 'ZANDO GLOBAL';
    final city = shop['city'] ?? shop['ville'] ?? product['city'] ?? 'Kinshasa';
    
    final stock = (product['stock'] as num?)?.toInt() ?? 999;
    
    final warranty = product['warranty'] ?? product['garantie'] ?? '12 mois';
    final lowStock = stock <= 5 && stock > 0;
    String fmt(double v) => v.toInt().toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: const Color(0xFFF0F0F0))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14), 
                // CORRECTION : Remplacement de CachedNetworkImage par Image.network
                child: Image.network(
                  product['image_url'] ?? '', 
                  width: 88, 
                  height: 88, 
                  fit: BoxFit.cover, 
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 88, 
                      height: 88, 
                      color: const Color(0xFFF7F7FA), 
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD81E2C))
                      )
                    );
                  },
                  errorBuilder: (_,__,___) => Container(
                    width: 88, 
                    height: 88, 
                    color: const Color(0xFFF7F7FA), 
                    child: const Icon(Icons.image_outlined, color: Colors.grey)
                  )
                )
              ),
              if(hasDiscount) Positioned(
                top: 6, 
                left: 6, 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), 
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0A93B), 
                    borderRadius: BorderRadius.circular(8)
                  ), 
                  child: Text(
                    '-$discountPercent%', 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF5C0E12))
                  )
                )
              ),
            ]
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  product['title'] ?? product['name'] ?? 'Produit', 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis, 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.2, color: Color(0xFF10192E), height: 1.2)
                ),
                const SizedBox(height: 5),
                Row(
                  children: [ 
                    const Icon(Icons.storefront_rounded, size: 11, color: Color(0xFFD81E2C)), 
                    const SizedBox(width: 4), 
                    Flexible(
                      child: Text(
                        shopName, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)
                      )
                    ), 
                    const SizedBox(width: 5), 
                    const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF8A8A8F))), 
                    const SizedBox(width: 5), 
                    const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF8A8A8F)), 
                    const SizedBox(width: 2), 
                    Expanded(
                      child: Text(
                        city, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8F))
                      )
                    )
                  ]
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), 
                      decoration: BoxDecoration(
                        color: lowStock ? const Color(0xFFFFF4CC) : const Color(0xFFE8FFF1), 
                        borderRadius: BorderRadius.circular(6)
                      ), 
                      child: Row(
                        mainAxisSize: MainAxisSize.min, 
                        children: [ 
                          Icon(
                            lowStock ? Icons.warning_amber_rounded : Icons.check_circle_rounded, 
                            size: 11, 
                            color: lowStock ? const Color(0xFFB7791F) : const Color(0xFF00B074)
                          ), 
                          const SizedBox(width: 3), 
                          Text(
                            lowStock ? 'Stock: $stock' : 'En stock', 
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w700, 
                              color: lowStock ? const Color(0xFFB7791F) : const Color(0xFF00B074)
                            )
                          )
                        ]
                      )
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), 
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF), 
                        borderRadius: BorderRadius.circular(6), 
                        border: Border.all(color: const Color(0xFFE0E7FF))
                      ), 
                      child: Row(
                        mainAxisSize: MainAxisSize.min, 
                        children: [ 
                          const Icon(Icons.verified_user_outlined, size: 11, color: Color(0xFF2D6CDF)), 
                          const SizedBox(width: 3), 
                          Text(
                            'Garantie $warranty', 
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2D6CDF))
                          )
                        ]
                      )
                    ),
                  ]
                ),
                const SizedBox(height: 8),
                Row(
                  children: [ 
                    Text(
                      '${fmt(realPrice)} $currency', 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF5C0E12))
                    ), 
                    if(hasDiscount) ...[ 
                      const SizedBox(width: 6), 
                      Text(
                        '${fmt(oldPrice)} $currency', 
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8A8F), decoration: TextDecoration.lineThrough)
                      )
                    ]
                  ]
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1931), 
                        borderRadius: BorderRadius.circular(20)
                      ), 
                      child: Row(
                        children: [ 
                          InkWell(
                            onTap: () => onQuantityChanged(qty - 1), 
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                              child: Icon(Icons.remove, size: 16, color: Color(0xFFF0A93B))
                            )
                          ), 
                          Text(
                            '$qty', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                          ), 
                          InkWell(
                            onTap: () => onQuantityChanged(qty + 1), 
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                              child: Icon(Icons.add, size: 16, color: Color(0xFFF0A93B))
                            )
                          )
                        ]
                      )
                    ),
                    InkWell(
                      onTap: onRemove, 
                      child: Container(
                        padding: const EdgeInsets.all(7), 
                        decoration: const BoxDecoration(color: Color(0xFFFFF0F0), shape: BoxShape.circle), 
                        child: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFD81E2C))
                      )
                    ),
                  ]
                )
              ]
            )
          )
        ]
      ),
    );
  }
}
