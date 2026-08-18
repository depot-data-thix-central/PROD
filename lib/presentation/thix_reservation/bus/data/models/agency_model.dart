// lib/presentation/thix_reservation/bus/data/models/agency_model.dart
import 'package:flutter/foundation.dart';

class AgencyModel {
  final String id;
  final String ownerId; // UID Supabase = lié au THIX ID utilisateur
  final String name;
  final String slug;
  final String? logoUrl;
  final String? description;
  final String countryCode; // CD, CI...
  final bool isVerified;
  final String status; // pending, active, suspended
  final String subscriptionPlan; // free, pro
  final double ratingAvg;
  final int ratingCount;
  final DateTime createdAt;

  const AgencyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    required this.countryCode,
    this.isVerified = false,
    this.status = 'pending',
    this.subscriptionPlan = 'free',
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    required this.createdAt,
  });

  factory AgencyModel.fromJson(Map<String, dynamic> json) {
    return AgencyModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logoUrl: json['logo_url'] as String?,
      description: json['description'] as String?,
      countryCode: json['country_code'] as String? ?? 'CD',
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      subscriptionPlan: json['subscription_plan'] as String? ?? 'free',
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner_id': ownerId,
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'description': description,
      'country_code': countryCode,
      'is_verified': isVerified,
      'status': status,
      'subscription_plan': subscriptionPlan,
    };
  }

  AgencyModel copyWith({bool? isVerified, String? status}) {
    return AgencyModel(
      id: id,
      ownerId: ownerId,
      name: name,
      slug: slug,
      logoUrl: logoUrl,
      description: description,
      countryCode: countryCode,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
      subscriptionPlan: subscriptionPlan,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      createdAt: createdAt,
    );
  }
}
