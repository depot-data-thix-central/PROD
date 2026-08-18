class ProductModel {
  final String id;
  final String shopId;
  final String title;
  final String description;
  final double price;
  final double? discountPrice;
  final int stock;
  final String? brand;
  final String category;
  final String condition;
  final List<String> images;
  final double rating;
  final int reviewsCount;
  final int views;
  final bool isFlashSale;
  final DateTime? flashSaleEnd;
  final bool freeShipping;
  final String? shippingType;
  final bool isService;
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final double? latitude;
  final double? longitude;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.shopId,
    required this.title,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.stock,
    this.brand,
    required this.category,
    required this.condition,
    required this.images,
    this.rating = 0,
    this.reviewsCount = 0,
    this.views = 0,
    this.isFlashSale = false,
    this.flashSaleEnd,
    this.freeShipping = false,
    this.shippingType,
    this.isService = false,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.latitude,
    this.longitude,
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      stock: json['stock'] as int,
      brand: json['brand'] as String?,
      category: json['category'] as String,
      condition: json['condition'] as String,
      images: List<String>.from(json['images'] ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      isFlashSale: json['is_flash_sale'] as bool? ?? false,
      flashSaleEnd: json['flash_sale_end'] != null
          ? DateTime.parse(json['flash_sale_end'] as String)
          : null,
      freeShipping: json['free_shipping'] as bool? ?? false,
      shippingType: json['shipping_type'] as String?,
      isService: json['is_service'] as bool? ?? false,
      isBoosted: json['is_boosted'] as bool? ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.parse(json['boost_expires_at'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'title': title,
      'description': description,
      'price': price,
      'discount_price': discountPrice,
      'stock': stock,
      'brand': brand,
      'category': category,
      'condition': condition,
      'images': images,
      'rating': rating,
      'reviews_count': reviewsCount,
      'views': views,
      'is_flash_sale': isFlashSale,
      'flash_sale_end': flashSaleEnd?.toIso8601String(),
      'free_shipping': freeShipping,
      'shipping_type': shippingType,
      'is_service': isService,
      'is_boosted': isBoosted,
      'boost_expires_at': boostExpiresAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  double get finalPrice => discountPrice ?? price;
  int get discountPercent => discountPrice != null
      ? ((price - discountPrice!) / price * 100).round()
      : 0;
  bool get inStock => stock > 0;
  bool get isOnSale => discountPrice != null && discountPrice! < price;
}
