
// lib/presentation/thix_market/models/supermarket_product.dart
// ============================================================================
// MODÈLE PRODUIT SUPERMARCHÉ — fiche complète enterprise
// ============================================================================

class SupermarketProduct {
  final String id;
  final String title;
  final String? description;
  final List<String> photos; // jusqu'à 5 photos
  final double price;
  final double? discountPrice;
  final String currency; // CDF, USD, EUR...
  final int stock;
  final String? unit; // pcs, kg, L, paquet...
  final String? barcode;
  final bool isPerishable;
  final DateTime? expiryDate;
  final bool isPromo;
  final bool isFeatured;
  final String? departmentId;
  final int aisleNumber;
  final double rating;
  final DateTime? createdAt;

  const SupermarketProduct({
    required this.id,
    required this.title,
    this.description,
    this.photos = const [],
    required this.price,
    this.discountPrice,
    required this.currency,
    required this.stock,
    this.unit,
    this.barcode,
    this.isPerishable = false,
    this.expiryDate,
    this.isPromo = false,
    this.isFeatured = false,
    this.departmentId,
    this.aisleNumber = 0,
    this.rating = 0,
    this.createdAt,
  });

  factory SupermarketProduct.fromJson(Map<String, dynamic> j) {
    // ── Photos : jsonb 'photos' (liste) + fallback image_url ──
    final photos = <String>[];
    final raw = j['photos'];
    if (raw is List) {
      for (final p in raw) {
        final s = p?.toString() ?? '';
        if (s.startsWith('http') && !photos.contains(s)) photos.add(s);
        if (photos.length >= 5) break;
      }
    }
    final main = j['image_url']?.toString();
    if (main != null && main.isNotEmpty && !photos.contains(main)) {
      photos.insert(0, main);
    }
    if (photos.length > 5) photos.removeRange(5, photos.length);

    final price = (j['price'] as num?)?.toDouble() ?? 0;
    final discount = (j['discount_price'] as num?)?.toDouble();
    final promoFlag = (j['is_promo'] as bool?) ?? false;

    return SupermarketProduct(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Produit',
      description: j['description']?.toString(),
      photos: photos,
      price: price,
      discountPrice: (discount != null && discount > 0 && discount < price) ? discount : null,
      currency: j['currency']?.toString() ?? 'CDF',
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      unit: j['unit']?.toString() ?? j['unit_of_measure']?.toString(),
      barcode: j['barcode']?.toString(),
      isPerishable: (j['is_perishable'] as bool?) ?? false,
      expiryDate: DateTime.tryParse(j['expiry_date']?.toString() ?? ''),
      isPromo: promoFlag,
      isFeatured: (j['is_featured'] as bool?) ?? false,
      departmentId: j['department_id']?.toString(),
      aisleNumber: (j['aisle_number'] as num?)?.toInt() ?? 0,
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
    );
  }

  // ── Helpers métier ──
  bool get onPromo => isPromo || discountPrice != null;
  double get effectivePrice => onPromo ? (discountPrice ?? price) : price;

  int get promoPercent {
    if (!onPromo || price <= 0) return 0;
    return (((price - effectivePrice) / price) * 100).round().clamp(0, 99);
  }

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  int get daysToExpiry {
    if (expiryDate == null) return -1;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isFreshSoon =>
      isPerishable && !isExpired && daysToExpiry >= 0 && daysToExpiry <= 3;

  String get mainPhoto => photos.isNotEmpty ? photos.first : '';
  bool get hasPhotos => photos.isNotEmpty;

  String priceLabel([double? value]) {
    final v = value ?? effectivePrice;
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }
}
