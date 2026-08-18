class RatingModel {
  final String id;
  final String productId;
  final String userId;
  final String? orderId;
  final double rating;
  final String? comment;
  final String? reply;
  final List<String>? images;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? repliedAt;

  RatingModel({
    required this.id,
    required this.productId,
    required this.userId,
    this.orderId,
    required this.rating,
    this.comment,
    this.reply,
    this.images,
    required this.createdAt,
    this.updatedAt,
    this.repliedAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      orderId: json['order_id'] as String?,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String?,
      reply: json['reply'] as String?,
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      repliedAt: json['replied_at'] != null
          ? DateTime.parse(json['replied_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'order_id': orderId,
      'rating': rating,
      'comment': comment,
      'reply': reply,
      'images': images,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'replied_at': repliedAt?.toIso8601String(),
    };
  }

  bool get hasReply => reply != null && reply!.isNotEmpty;
}

class UserRatingModel {
  final String id;
  final String raterUserId;
  final String ratedUserId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserRatingModel({
    required this.id,
    required this.raterUserId,
    required this.ratedUserId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserRatingModel.fromJson(Map<String, dynamic> json) {
    return UserRatingModel(
      id: json['id'] as String,
      raterUserId: json['rater_user_id'] as String,
      ratedUserId: json['rated_user_id'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rater_user_id': raterUserId,
      'rated_user_id': ratedUserId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
