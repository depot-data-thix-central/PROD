import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FlashOffers extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProductTap;
  
  const FlashOffers({super.key, this.onProductTap});

  @override
  State<FlashOffers> createState() => _FlashOffersState();
}

class _FlashOffersState extends State<FlashOffers> {
  List<Map<String, dynamic>> _flashProducts = [];
  bool _isLoading = true;
  Duration _timeLeft = const Duration(hours: 3, minutes: 45, seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadFlashProducts();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_timeLeft.inSeconds > 0) {
            _timeLeft = Duration(seconds: _timeLeft.inSeconds - 1);
            _startCountdown();
          }
        });
      }
    });
  }

  Future<void> _loadFlashProducts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _flashProducts = _generateMockFlashProducts();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _generateMockFlashProducts() {
    return [
      {
        'id': 'flash_1',
        'title': 'Smartphone XYZ Pro',
        'price': 249990,
        'original_price': 499990,
        'discount': 50,
        'image_url': 'https://picsum.photos/id/0/400/400',
        'sold_percentage': 78,
        'stock': 45,
      },
      {
        'id': 'flash_2',
        'title': 'Casque Audio Bluetooth',
        'price': 24990,
        'original_price': 59990,
        'discount': 58,
        'image_url': 'https://picsum.photos/id/1/400/400',
        'sold_percentage': 92,
        'stock': 12,
      },
      {
        'id': 'flash_3',
        'title': 'Montre Connectée Sport',
        'price': 39990,
        'original_price': 89990,
        'discount': 55,
        'image_url': 'https://picsum.photos/id/2/400/400',
        'sold_percentage': 65,
        'stock': 89,
      },
      {
        'id': 'flash_4',
        'title': 'Enceinte Portable',
        'price': 19990,
        'original_price': 49990,
        'discount': 60,
        'image_url': 'https://picsum.photos/id/3/400/400',
        'sold_percentage': 85,
        'stock': 34,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_flashProducts.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5592F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FLASH SALE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Jusqu\'à -70%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: Color(0xFFE5592F)),
                    const SizedBox(width: 4),
                    _buildCountdownTimer(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Produits flash
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _flashProducts.length,
              itemBuilder: (context, index) {
                return _buildFlashCard(_flashProducts[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_timeLeft.inHours.remainder(24));
    final minutes = twoDigits(_timeLeft.inMinutes.remainder(60));
    final seconds = twoDigits(_timeLeft.inSeconds.remainder(60));
    
    return Row(
      children: [
        _buildTimeUnit(hours),
        const Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildTimeUnit(minutes),
        const Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildTimeUnit(seconds),
      ],
    );
  }

  Widget _buildTimeUnit(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFlashCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => widget.onProductTap?.call(product),
      child: Container(
        width: 180,
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
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: product['image_url'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Badge discount
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${product['discount']}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                // Stock indicator
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: (product['sold_percentage'] / 100),
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE5592F)),
                    ),
                  ),
                ),
              ],
            ),
            
            // Infos
            Padding(
              padding: const EdgeInsets.all(10),
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
                      const SizedBox(width: 6),
                      Text(
                        '${product['original_price'].toInt()} FCFA',
                        style: TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.inventory, size: 10, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        'Stock: ${product['stock']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      const Spacer(),
                      Text(
                        '${product['sold_percentage']}% vendu',
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 24,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 100,
                      height: 20,
                      color: Colors.grey[200],
                    ),
                  ],
                ),
                Container(
                  width: 100,
                  height: 24,
                  color: Colors.grey[200],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 4,
              itemBuilder: (context, index) => Container(
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                color: Colors.grey[200],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
