import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class RecommendedFeed extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProductTap;
  final String? category;
  
  const RecommendedFeed({
    super.key,
    this.onProductTap,
    this.category,
  });

  @override
  State<RecommendedFeed> createState() => _RecommendedFeedState();
}

class _RecommendedFeedState extends State<RecommendedFeed> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    // Simuler appel API - À remplacer par votre vrai service
    await Future.delayed(const Duration(milliseconds: 800));
    
    final mockProducts = _generateMockProducts();
    
    setState(() {
      _products = mockProducts;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    final moreProducts = _generateMockProducts();
    
    setState(() {
      _products.addAll(moreProducts);
      _isLoading = false;
      _hasMore = _products.length < 50;
    });
  }

  List<Map<String, dynamic>> _generateMockProducts() {
    final List<Map<String, dynamic>> products = [];
    final categories = [
      'Mode', 'Électronique', 'Maison', 'Sport', 'Beauté', 'Auto'
    ];
    final images = [
      'https://picsum.photos/id/20/400/400',  // Café
      'https://picsum.photos/id/30/400/400',  // Nature
      'https://picsum.photos/id/26/400/400',  // Randonnée
      'https://picsum.photos/id/96/400/400',  // Montagne
      'https://picsum.photos/id/29/400/400',  // Architecture
      'https://picsum.photos/id/39/400/400',  // Verre
    ];
    
    for (int i = 0; i < 10; i++) {
      products.add({
        'id': 'prod_${DateTime.now().millisecondsSinceEpoch}_$i',
        'title': 'Produit ${i + 1} - ${categories[i % categories.length]}',
        'price': (500 + i * 250).toDouble(),
        'original_price': (1000 + i * 300).toDouble(),
        'discount': i % 3 == 0 ? (20 + i).toDouble() : null,
        'image_url': images[i % images.length],
        'shop_name': 'Boutique ${categories[i % categories.length]} Pro',
        'shop_id': 'shop_$i',
        'rating': 3.5 + (i % 3) * 0.5,
        'reviews_count': 50 + i * 10,
        'is_flash_sale': i < 3,
        'stock': 10 + i * 5,
        'sold_count': 20 + i * 8,
      });
    }
    return products;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _products.isEmpty) {
      return _buildLoadingShimmer();
    }

    if (_products.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '✨ Recommandé pour vous',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Naviguer vers la page des recommandations
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(color: Color(0xFFE5592F)),
                ),
              ),
            ],
          ),
        ),
        
        // Grille de produits
        GridView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _products.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _products.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return _buildProductCard(_products[index]);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => widget.onProductTap?.call(product),
      child: Container(
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
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: product['image_url'],
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 160,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 160,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                // Badge promo
                if (product['discount'] != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5592F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${product['discount'].toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Badge flash
                if (product['is_flash_sale'] == true)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FLASH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Infos produit
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.store, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          product['shop_name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product['rating'].toString(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        ' (${product['reviews_count']})',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${product['price'].toInt()} FCFA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE5592F),
                        ),
                      ),
                      if (product['original_price'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '${product['original_price'].toInt()} FCFA',
                            style: TextStyle(
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.shopping_bag, size: 10, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        '${product['sold_count']} vendus',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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
        // En-tête shimmer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 150,
                  height: 24,
                  color: Colors.white,
                ),
                Container(
                  width: 70,
                  height: 24,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        // Grille shimmer
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 12,
                          width: double.infinity,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 10,
                          width: 100,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 14,
                          width: 80,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.recommend, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucune recommandation',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadProducts,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5592F),
            ),
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }
}
