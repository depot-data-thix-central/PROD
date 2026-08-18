import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LiveIndicator extends StatefulWidget {
  final Function(Map<String, dynamic>)? onLiveTap;
  
  const LiveIndicator({super.key, this.onLiveTap});

  @override
  State<LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<LiveIndicator> {
  List<Map<String, dynamic>> _liveSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLiveSessions();
  }

  Future<void> _loadLiveSessions() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _liveSessions = _generateMockLives();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _generateMockLives() {
    return [
      {
        'id': 'live_1',
        'title': 'Vente Flash Mode',
        'shop_name': 'Mode Express',
        'shop_avatar': 'https://picsum.photos/id/20/100/100',
        'thumbnail': 'https://picsum.photos/id/20/400/300',
        'viewers': 1247,
        'products_count': 15,
      },
      {
        'id': 'live_2',
        'title': 'Démo Smartphones',
        'shop_name': 'TechZone',
        'shop_avatar': 'https://picsum.photos/id/0/100/100',
        'thumbnail': 'https://picsum.photos/id/0/400/300',
        'viewers': 892,
        'products_count': 8,
      },
      {
        'id': 'live_3',
        'title': 'Enchères Auto',
        'shop_name': 'Auto Prestige',
        'shop_avatar': 'https://picsum.photos/id/111/100/100',
        'thumbnail': 'https://picsum.photos/id/111/400/300',
        'viewers': 2456,
        'products_count': 3,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_liveSessions.isEmpty) {
      return const SizedBox();
    }

    return Container(
      height: 240,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lives en cours',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Naviguer vers tous les lives
                  },
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE5592F)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Liste des lives
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _liveSessions.length,
              itemBuilder: (context, index) {
                return _buildLiveCard(_liveSessions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> live) {
    return GestureDetector(
      onTap: () => widget.onLiveTap?.call(live),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: live['thumbnail'],
                    height: 160,
                    width: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 160,
                      width: 160,
                      color: Colors.grey[200],
                    ),
                  ),
                ),
                // Live badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Viewers count
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(live['viewers']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Products count
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5592F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${live['products_count']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Infos
            Text(
              live['title'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundImage: CachedNetworkImageProvider(live['shop_avatar']),
                  child: live['shop_avatar'] == null
                      ? Icon(Icons.store, size: 10, color: Colors.grey[400])
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    live['shop_name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            // Indicateur d'animation de pulsation
            if (live['viewers'] > 1000)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Très animé',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
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
      height: 240,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 8, height: 8, child: ColoredBox(color: Colors.grey)),
                SizedBox(width: 8),
                SizedBox(width: 120, height: 20, child: ColoredBox(color: Colors.grey)),
                Spacer(),
                SizedBox(width: 60, height: 16, child: ColoredBox(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      height: 160,
                      width: 160,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 10,
                      width: 100,
                      color: Colors.grey[200],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
