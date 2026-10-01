import 'package:flutter/foundation.dart';

/// 🏛️ Figure historique de la RDC (miroir de historical_figures)
@immutable
class HistoricalFigure {
  final String id;
  final String fullName;
  final String role;
  final String category;
  final String era;
  final String? quote;
  final String biography;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  const HistoricalFigure({
    required this.id,
    required this.fullName,
    required this.role,
    required this.category,
    required this.era,
    this.quote,
    required this.biography,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
  });

  factory HistoricalFigure.fromJson(Map<String, dynamic> json) {
    return HistoricalFigure(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      category: (json['category'] ?? 'Politique').toString(),
      era: (json['era'] ?? '').toString(),
      quote: json['quote']?.toString(),
      biography: (json['biography'] ?? '').toString(),
      photoUrl: json['photo_url']?.toString(),
      isActive: json['is_active'] != false,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
