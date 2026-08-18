// lib/presentation/education/models/book_chapter.dart

class BookChapter {
  final String id;
  final String bookId;
  final String title;
  final int chapterNumber;
  final int sortOrder;
  final DateTime? createdAt;

  BookChapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.chapterNumber,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      title: json['title'] as String,
      chapterNumber: json['chapter_number'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'book_id': bookId,
      'title': title,
      'chapter_number': chapterNumber,
      'sort_order': sortOrder,
    };
  }
}
