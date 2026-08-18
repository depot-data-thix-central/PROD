import 'dart:convert';

/// Represents a news / info item published from Admin and visible in the app.
///
/// Designed to map flexibly to Supabase rows (best-effort) while still
/// supporting local JSON encode/decode for caching.
class NewsItem {
  final String id;
  final String title;
  final String subtitle;
  final String source;
  final String category;
  final String severity;
  final bool featured;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NewsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.category,
    required this.severity,
    required this.featured,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  NewsItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? source,
    String? category,
    String? severity,
    bool? featured,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NewsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      source: source ?? this.source,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      featured: featured ?? this.featured,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'source': source,
        'category': category,
        'severity': severity,
        'featured': featured,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static NewsItem fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      final s = v.toString();
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return NewsItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      featured: (json['featured'] == true) || (json['featured']?.toString().toLowerCase() == 'true'),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static String encodeList(List<NewsItem> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<NewsItem> decodeList(String raw) {
    final v = jsonDecode(raw);
    if (v is! List) return const <NewsItem>[];
    return v.whereType<Map>().map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
  }
}
