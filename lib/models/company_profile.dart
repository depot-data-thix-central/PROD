import 'dart:convert';

class CompanyProfile {
  final String id;
  final String name;
  final String? logoUrl;
  final String? bannerUrl;
  final String? about;
  final String? country;
  final String? city;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyProfile({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.bannerUrl,
    required this.about,
    required this.country,
    required this.city,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  CompanyProfile copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? bannerUrl,
    String? about,
    String? country,
    String? city,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      about: about ?? this.about,
      country: country ?? this.country,
      city: city ?? this.city,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'about': about,
      'country': country,
      'city': city,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static CompanyProfile fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    bool parseBool(Object? v) {
      if (v is bool) return v;
      final s = (v ?? '').toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    return CompanyProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: (json['logo_url'] ?? json['logoUrl'])?.toString(),
      bannerUrl: (json['banner_url'] ?? json['bannerUrl'])?.toString(),
      about: (json['about'] ?? '').toString().trim().isEmpty ? null : (json['about'] ?? '').toString(),
      country: (json['country'] ?? '').toString().trim().isEmpty ? null : (json['country'] ?? '').toString(),
      city: (json['city'] ?? '').toString().trim().isEmpty ? null : (json['city'] ?? '').toString(),
      isVerified: parseBool(json['is_verified'] ?? json['isVerified'] ?? false),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<CompanyProfile> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));
  static List<CompanyProfile> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => CompanyProfile.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
