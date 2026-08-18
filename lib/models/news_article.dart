// lib/models/news_article.dart
class NewsArticle {
  final String id;
  final String title;
  final String? summary;
  final String content;
  final String category;
  final String? imageUrl;
  final String? videoUrl;
  final int viewsCount;
  final bool isFeatured;
  final bool isBreaking;
  final String status;
  final DateTime publishedAt;
  final DateTime createdAt;
  final String? createdBy;
  bool isLiked;
  bool isSaved;

  NewsArticle({
    required this.id,
    required this.title,
    this.summary,
    required this.content,
    required this.category,
    this.imageUrl,
    this.videoUrl,
    this.viewsCount = 0,
    this.isFeatured = false,
    this.isBreaking = false,
    this.status = 'published',
    required this.publishedAt,
    required this.createdAt,
    this.createdBy,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      content: json['content'],
      category: json['category'],
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      viewsCount: json['views_count'] ?? 0,
      isFeatured: json['is_featured'] ?? false,
      isBreaking: json['is_breaking'] ?? false,
      status: json['status'] ?? 'published',
      publishedAt: DateTime.parse(json['published_at']),
      createdAt: DateTime.parse(json['created_at']),
      createdBy: json['created_by'],
      isLiked: json['is_liked'] ?? false,
      isSaved: json['is_saved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'views_count': viewsCount,
      'is_featured': isFeatured,
      'is_breaking': isBreaking,
      'status': status,
      'published_at': publishedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  NewsArticle copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    String? category,
    String? imageUrl,
    String? videoUrl,
    int? viewsCount,
    bool? isFeatured,
    bool? isBreaking,
    String? status,
    DateTime? publishedAt,
    DateTime? createdAt,
    String? createdBy,
    bool? isLiked,
    bool? isSaved,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      viewsCount: viewsCount ?? this.viewsCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isBreaking: isBreaking ?? this.isBreaking,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

// Extension pour les listes d'articles
extension NewsArticleListExtension on List<NewsArticle> {
  List<NewsArticle> get featured => where((a) => a.isFeatured).toList();
  List<NewsArticle> get breaking => where((a) => a.isBreaking).toList();
  List<NewsArticle> get published => where((a) => a.status == 'published').toList();
  
  List<NewsArticle> byCategory(String category) {
    return where((a) => a.category == category).toList();
  }
  
  List<NewsArticle> mostViewed({int limit = 10}) {
    final sorted = [...this]..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
    return sorted.take(limit).toList();
  }
  
  List<NewsArticle> mostRecent({int limit = 10}) {
    final sorted = [...this]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted.take(limit).toList();
  }
}
