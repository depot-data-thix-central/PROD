class AnnouncementModel {
  final String id;
  final String shopId;
  final String title;
  final String description;
  final double price;
  final double? discountPrice;
  final int stock;
  final List<String> images;
  final String category;
  final String condition;
  final String? brand;
  final bool freeShipping;
  final String? shippingType;
  final bool isService;
  final int views;
  final int likes;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  AnnouncementModel({
    required this.id,
    required this.shopId,
    required this.title,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.stock,
    required this.images,
    required this.category,
    required this.condition,
    this.brand,
    this.freeShipping = false,
    this.shippingType,
    this.isService = false,
    this.views = 0,
    this.likes = 0,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.expiresAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      stock: json['stock'] as int,
      images: List<String>.from(json['images'] ?? []),
      category: json['category'] as String,
      condition: json['condition'] as String,
      brand: json['brand'] as String?,
      freeShipping: json['free_shipping'] as bool? ?? false,
      shippingType: json['shipping_type'] as String?,
      isService: json['is_service'] as bool? ?? false,
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
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
      'images': images,
      'category': category,
      'condition': condition,
      'brand': brand,
      'free_shipping': freeShipping,
      'shipping_type': shippingType,
      'is_service': isService,
      'views': views,
      'likes': likes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  double get finalPrice => discountPrice ?? price;
  bool get isActive => status == 'active';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
}
