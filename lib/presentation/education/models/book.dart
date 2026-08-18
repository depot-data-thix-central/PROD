// lib/presentation/education/models/book.dart

class Book {
  final String id;
  final String title;
  final String author;
  final String? description;
  final double price;
  final String currency;
  final String? imageUrl;
  final String? fileUrl;
  final String? category;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? scheduledDeletionAt;
  final String? shelfCode;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    this.price = 0.0,
    this.currency = 'FC',
    this.imageUrl,
    this.fileUrl,
    this.category,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.scheduledDeletionAt,
    this.shelfCode,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        description: json['description'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'FC',
        imageUrl: json['image_url'] as String? ?? json['cover_url'] as String?,
        fileUrl: json['file_url'] as String?,
        category: json['category'] as String?,
        createdBy: json['created_by'] as String? ?? json['instructor_id'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
        scheduledDeletionAt: json['scheduled_deletion_at'] != null
            ? DateTime.parse(json['scheduled_deletion_at'] as String)
            : null,
        shelfCode: json['shelf_code'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'description': description,
        'price': price,
        'currency': currency,
        'image_url': imageUrl,
        'file_url': fileUrl,
        'category': category,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'scheduled_deletion_at': scheduledDeletionAt?.toIso8601String(),
        'shelf_code': shelfCode,
      };

  bool get isScheduledForDeletion =>
      scheduledDeletionAt != null &&
      scheduledDeletionAt!.isAfter(DateTime.now());
}
