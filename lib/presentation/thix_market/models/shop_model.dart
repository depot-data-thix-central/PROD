class ShopModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? category;
  final String? logoUrl;
  final String? coverUrl;
  final String? address;
  final String? phone;
  final String? email;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int productsCount;
  final int followersCount;
  final bool isVerified;
  final bool isFeatured;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShopModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.category,
    this.logoUrl,
    this.coverUrl,
    this.address,
    this.phone,
    this.email,
    this.latitude,
    this.longitude,
    this.rating = 0,
    this.productsCount = 0,
    this.followersCount = 0,
    this.isVerified = false,
    this.isFeatured = false,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      productsCount: json['products_count'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'category': category,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      'address': address,
      'phone': phone,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'products_count': productsCount,
      'followers_count': followersCount,
      'is_verified': isVerified,
      'is_featured': isFeatured,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ShopModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? category,
    String? logoUrl,
    String? coverUrl,
    String? address,
    String? phone,
    String? email,
    double? latitude,
    double? longitude,
    double? rating,
    int? productsCount,
    int? followersCount,
    bool? isVerified,
    bool? isFeatured,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      productsCount: productsCount ?? this.productsCount,
      followersCount: followersCount ?? this.followersCount,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
