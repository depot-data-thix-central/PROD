// lib/presentation/mon_pays/models/article.dart

enum ArticleType {
  constitution,
  codePenal,
  codeCivil,
  codeTravail,
  codeFiscal,
  codeMinier,
  codeForestier,
  codeElectoral,
  loiOrganique,
  ordonnance,
  decret,
  autre;

  String get label {
    switch (this) {
      case ArticleType.constitution:
        return 'Constitution';
      case ArticleType.codePenal:
        return 'Code Pénal';
      case ArticleType.codeCivil:
        return 'Code Civil';
      case ArticleType.codeTravail:
        return 'Code du Travail';
      case ArticleType.codeFiscal:
        return 'Code Fiscal';
      case ArticleType.codeMinier:
        return 'Code Minier';
      case ArticleType.codeForestier:
        return 'Code Forestier';
      case ArticleType.codeElectoral:
        return 'Code Electoral';
      case ArticleType.loiOrganique:
        return 'Loi Organique';
      case ArticleType.ordonnance:
        return 'Ordonnance';
      case ArticleType.decret:
        return 'Décret';
      case ArticleType.autre:
        return 'Autre';
    }
  }

  static ArticleType fromString(String value) {
    return ArticleType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => ArticleType.autre,
    );
  }

  static List<ArticleType> get allTypes => ArticleType.values;
}

class Article {
  final String id;
  final ArticleType type;
  final String title;
  final String? chapter;
  final String? articleNumber;
  final String content;
  final String? explanation;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  Article({
    required this.id,
    required this.type,
    required this.title,
    this.chapter,
    this.articleNumber,
    required this.content,
    this.explanation,
    this.isPublished = false,
    this.publishedAt,
    this.updatedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      type: ArticleType.fromString(json['type'] as String),
      title: json['title'] as String,
      chapter: json['chapter'] as String?,
      articleNumber: json['article_number'] as String?,
      content: json['content'] as String,
      explanation: json['explanation'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type.toString().split('.').last,
      'title': title,
      'chapter': chapter,
      'article_number': articleNumber,
      'content': content,
      'explanation': explanation,
      'is_published': isPublished,
      'published_at': publishedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    // On n'ajoute l'ID au JSON que s'il n'est pas vide (pour la création)
    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  Article copyWith({
    String? id,
    ArticleType? type,
    String? title,
    String? chapter,
    String? articleNumber,
    String? content,
    String? explanation,
    bool? isPublished,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return Article(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      chapter: chapter ?? this.chapter,
      articleNumber: articleNumber ?? this.articleNumber,
      content: content ?? this.content,
      explanation: explanation ?? this.explanation,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
