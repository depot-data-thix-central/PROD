// lib/presentation/thix_market/widgets/search/nearby_products.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NearbyProducts extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProductTap;
  final double? radiusKm;

  const NearbyProducts({
    super.key,
    this.onProductTap,
    this.radiusKm = 10,
  });

  @override
  State<NearbyProducts> createState() => _NearbyProductsState();
}

class _NearbyProductsState extends State<NearbyProducts> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  Position? _currentPosition;
  String? _errorMessage;

  // ============================================================
  // CHARTE ÉLITE
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color softBlue = Color(0xFFEFF5FF);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10192E);
  static const Color mutedText = Color(0xFF7386A8);
  static const Color gold = Color(0xFFE3B23C);
  static const Color danger = Color(0xFFFF5B3D);

  @override
  void initState() {
    super.initState();
    _checkLocationAndLoad();
  }

  // ─── PERMISSIONS ────────────────────────────────────────────────
  Future<void> _checkLocationAndLoad() async {
    await _checkLocationPermission();
    if (_hasLocationPermission) {
      await _getCurrentPosition();
      await _loadNearbyProducts();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Autorisation de localisation refusée';
          _hasLocationPermission = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Localisation désactivée de façon permanente';
        _hasLocationPermission = false;
      });
      return;
    }

    setState(() => _hasLocationPermission = true);
  }

  Future<void> _getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() => _errorMessage = 'Impossible d\'obtenir votre position');
    }
  }

  // ─── CHARGEMENT ──────────────────────────────────────────────────
  Future<void> _loadNearbyProducts() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .rpc('nearby_products', params: {
            'lat': _currentPosition!.latitude,
            'lng': _currentPosition!.longitude,
            'radius_km': widget.radiusKm,
            'limit': 20,
          });

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors du chargement des produits';
        });
      }
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_hasLocationPermission) {
      return _buildPermissionDenied();
    }

    if (_products.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, size: 16, color: primaryBlue),
              ),
              const SizedBox(width: 8),
              Text(
                'À moins de ${widget.radiusKm} km',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadNearbyProducts,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Actualiser'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 290,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(_products[index]);
            },
          ),
        ),
      ],
    );
  }

  // ─── CARTE PRODUIT ──────────────────────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> product) {
    final currency = product['currency'] ?? 'CDF';
    final symbol = currency == 'USD' ? '\$' : 'FC';
    final price = (product['price'] as num).toInt();
    final distance = (product['distance_km'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () => widget.onProductTap?.call(product),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: softBlue, width: 1),
          boxShadow: [
            BoxShadow(
              color: navyDeep.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: CachedNetworkImage(
                  imageUrl: product['image_url'] ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: softBlue,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: softBlue,
                    child: const Icon(Icons.image_rounded, color: mutedText),
                  ),
                ),
              ),
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: softBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 10, color: primaryBlue),
                            const SizedBox(width: 2),
                            Text(
                              distance.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 9,
                                color: primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$price $symbol',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: navyDeep,
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

  // ─── LOADING SHIMMER ─────────────────────────────────────────────
  Widget _buildLoadingShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 120, height: 16, child: ColoredBox(color: Colors.grey)),
            ],
          ),
        ),
        SizedBox(
          height: 290,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ÉTAT ERREUR ─────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded, size: 48, color: danger),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 15, color: darkText, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _checkLocationAndLoad,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: pureWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PERMISSION REFUSÉE ──────────────────────────────────────────
  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_off_rounded, size: 48, color: mutedText),
          ),
          const SizedBox(height: 16),
          const Text(
            'Activez la localisation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText),
          ),
          const SizedBox(height: 6),
          Text(
            'Pour voir les produits près de chez vous',
            style: TextStyle(color: mutedText, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _checkLocationAndLoad,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Autoriser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: pureWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ÉTAT VIDE ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_searching_rounded, size: 48, color: gold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun produit à proximité',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: darkText),
          ),
          const SizedBox(height: 6),
          Text(
            'Essayez d\'élargir votre recherche',
            style: TextStyle(color: mutedText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
