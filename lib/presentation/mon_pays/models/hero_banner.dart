import 'package:flutter/foundation.dart';

@immutable
class HeroBanner {
  final String id;
  final String tag;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final int position;
  final bool isActive;

  const HeroBanner({
    required this.id,
    required this.tag,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.position,
    this.isActive = true,
  });

  factory HeroBanner.fromJson(Map<String, dynamic> json) => HeroBanner(
        id: (json['id'] ?? '').toString(),
        tag: (json['tag'] ?? 'PATRIOTISME').toString(),
        title: (json['title'] ?? '').toString(),
        subtitle: (json['subtitle'] ?? '').toString(),
        imageUrl: json['image_url']?.toString(),
        position: (json['position'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] != false,
      );
}
