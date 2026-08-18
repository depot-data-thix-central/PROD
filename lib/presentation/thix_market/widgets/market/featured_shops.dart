import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class FeaturedShops extends StatefulWidget {
  final Function(Map<String, dynamic>)? onShopTap;
  final String title;
  final String actionText;
  final String productsLabel;
  
  const FeaturedShops({
    super.key, 
    this.onShopTap,
    this.title = '🏪 Boutiques mises en avant', // Valeur par défaut
    this.actionText = 'Voir tout >', // Valeur par défaut
    this.productsLabel = 'produits', // Valeur par défaut
  });

  @override
  State<FeaturedShops> createState() => _FeaturedShopsState();
}

class _FeaturedShopsState extends State<FeaturedShops> {
  List<Map<String, dynamic>> _shops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _shops = _generateMockShops();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _generateMockShops() {
    return [
      {
        'id': 'shop_1',
        'name': 'Mode Express',
        'logo': 'https://picsum.photos/id/20/200/200',
        'cover': 'https://picsum.photos/id/20/600/200',
        'rating': 4.8,
        'products_count': 245,
        'followers': 12500,
        'is_verified': true,
        'description': 'La référence de la mode en Côte d\'Ivoire',
      },
      {
        'id': 'shop_2',
        'name': 'TechZone',
        'logo': 'https://picsum.photos/id/0/200/200',
        'cover': 'https://picsum.photos/id/0/600/200',
        'rating': 4.9,
        'products_count': 189,
        'followers': 8900,
        'is_verified': true,
        'description': 'Electronique haut de gamme',
      },
      {
        'id': 'shop_3',
        'name': 'Maison Chic',
        'logo': 'https://picsum.photos/id/26/200/200',
        'cover': 'https://picsum.photos/id/26/600/200',
        'rating': 4.7,
        'products_count': 567,
        'followers': 15600,
        'is_verified': false,
        'description': 'Décoration et ameublement',
      },
      {
        'id': 'shop_4',
        'name': 'Auto Prestige',
        'logo': 'https://picsum.photos/id/111/200/200',
        'cover': 'https://picsum.photos/id/111/600/200',
        'rating': 4.9,
        'products_count': 89,
        'followers': 6700,
        'is_verified': true,
        'description': 'Véhicules de luxe',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_shops.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.actionText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE5592F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _shops.length,
              itemBuilder: (context, index) {
                return _buildShopCard(_shops[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    return GestureDetector(
      onTap: () => widget.onShopTap?.call(shop),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image (Remplacement de CachedNetworkImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                shop['cover'] ?? '',
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 90,
                    color: Colors.grey[200],
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 90,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            
            // Logo et infos
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Remplacement de CachedNetworkImageProvider
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: shop['logo'] != null 
                            ? NetworkImage(shop['logo']) 
                            : null,
                        child: shop['logo'] == null
                            ? Icon(Icons.store, color: Colors.grey[400])
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    shop['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (shop['is_verified'] == true)
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.blue,
                                    size: 14,
                                  ),
                              ],
                            ),
                            RatingBar.builder(
                              initialRating: (shop['rating'] ?? 0).toDouble(),
                              minRating: 1,
                              direction: Axis.horizontal,
                              allowHalfRating: true,
                              itemCount: 5,
                              itemSize: 10,
                              ignoreGestures: true,
                              itemBuilder: (_, __) => const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              onRatingUpdate: (_) {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shop['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.shopping_bag, size: 10, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        '${shop['products_count'] ?? 0} ${widget.productsLabel}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.favorite, size: 10, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        _formatNumber(shop['followers'] ?? 0),
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
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

  Widget _buildLoadingShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.actionText, 
                style: const TextStyle(fontSize: 13, color: Color(0xFFE5592F))
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    height: 90, 
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    )
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(radius: 20, backgroundColor: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  const SizedBox(
                                    height: 12,
                                    width: double.infinity,
                                    child: ColoredBox(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 10,
                                    width: 60,
                                    alignment: Alignment.centerLeft,
                                    child: const ColoredBox(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(height: 20, width: double.infinity, child: ColoredBox(color: Colors.grey)),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            SizedBox(width: 40, height: 10, child: ColoredBox(color: Colors.grey)),
                            SizedBox(width: 8),
                            SizedBox(width: 30, height: 10, child: ColoredBox(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    }
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}k';
    }
    return num.toString();
  }
}
