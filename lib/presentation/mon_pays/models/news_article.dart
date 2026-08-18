// lib/models/news_article.dart

class NewsArticle {
  final String id;
  final String title;
  final String? summary;
  final String content;
  final String category;
  final String? coverImageUrl;
  final String? author;
  final DateTime? publishedAt;

  NewsArticle({
    required this.id,
    required this.title,
    this.summary,
    required this.content,
    this.category = 'Général',
    this.coverImageUrl,
    this.author,
    this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sans titre',
      summary: json['summary']?.toString(),
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Général',
      coverImageUrl: json['cover_image_url']?.toString(),
      author: json['author']?.toString(),
      publishedAt: json['published_at'] != null 
          ? DateTime.tryParse(json['published_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'cover_image_url': coverImageUrl,
      'author': author,
      'published_at': publishedAt?.toIso8601String(),
    };
  }
}
