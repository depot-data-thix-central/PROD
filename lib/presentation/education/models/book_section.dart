// lib/presentation/education/models/book_section.dart

class BookSection {
  final String id;
  final String chapterId;
  final String bookId;
  final String? title;
  final String? sectionNumber;
  final String contentFr;
  final String? contentLn;
  final String? contentSw;
  final String? contentEn;
  final String? explanationFr;
  final String? explanationLn;
  final String? explanationSw;
  final int sortOrder;
  final bool isPublished;
  final DateTime? createdAt;

  BookSection({
    required this.id,
    required this.chapterId,
    required this.bookId,
    this.title,
    this.sectionNumber,
    required this.contentFr,
    this.contentLn,
    this.contentSw,
    this.contentEn,
    this.explanationFr,
    this.explanationLn,
    this.explanationSw,
    this.sortOrder = 0,
    this.isPublished = true,
    this.createdAt,
  });

  factory BookSection.fromJson(Map<String, dynamic> json) {
    return BookSection(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      bookId: json['book_id'] as String,
      title: json['title'] as String?,
      sectionNumber: json['section_number'] as String?,
      contentFr: json['content_fr'] as String? ?? '',
      contentLn: json['content_ln'] as String?,
      contentSw: json['content_sw'] as String?,
      contentEn: json['content_en'] as String?,
      explanationFr: json['explanation_fr'] as String?,
      explanationLn: json['explanation_ln'] as String?,
      explanationSw: json['explanation_sw'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'chapter_id': chapterId,
      'book_id': bookId,
      'title': title,
      'section_number': sectionNumber,
      'content_fr': contentFr,
      'content_ln': contentLn,
      'content_sw': contentSw,
      'content_en': contentEn,
      'explanation_fr': explanationFr,
      'explanation_ln': explanationLn,
      'explanation_sw': explanationSw,
      'sort_order': sortOrder,
      'is_published': isPublished,
    };
  }

  /// Retourne le contenu selon la langue choisie
  String getContent(String lang) {
    switch (lang.toUpperCase()) {
      case 'LN':
        return (contentLn != null && contentLn!.isNotEmpty)
            ? contentLn!
            : 'Traduction en Lingala en cours de préparation…';
      case 'SW':
        return (contentSw != null && contentSw!.isNotEmpty)
            ? contentSw!
            : 'Traduction en Swahili en cours de préparation…';
      case 'EN':
        return (contentEn != null && contentEn!.isNotEmpty)
            ? contentEn!
            : 'English translation coming soon…';
      default:
        return contentFr;
    }
  }

  /// Retourne l’explication selon la langue
  String? getExplanation(String lang) {
    switch (lang.toUpperCase()) {
      case 'LN':
        return explanationLn;
      case 'SW':
        return explanationSw;
      default:
        return explanationFr;
    }
  }
}
