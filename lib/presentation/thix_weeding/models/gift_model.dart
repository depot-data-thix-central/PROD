// lib/presentation/thix_weeding/models/gift_model.dart
import 'package:flutter/foundation.dart';

@immutable
class GiftItem {
  final String id;
  final String weddingId;
  final String name;
  final String imageUrl;
  final double price;
  final double contributed;
  final bool isReserved;

  const GiftItem({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.contributed = 0,
    this.isReserved = false,
  });

  double get remaining => (price - contributed).clamp(0, price);
  double get percent => price == 0 ? 0 : contributed / price;

  factory GiftItem.fromJson(Map<String, dynamic> json) {
    return GiftItem(
      id: json['id'] as String,
      weddingId: json['wedding_id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      contributed: (json['contributed'] as num?)?.toDouble() ?? 0,
      isReserved: json['is_reserved'] as bool? ?? false,
    );
  }
}
