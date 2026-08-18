class Announcement {
  final String id;
  final String instructorId;
  final String? formationId;
  final String title;
  final String content;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  Announcement({required this.id, required this.instructorId, this.formationId, required this.title, required this.content, this.isPublished = false, required this.createdAt, required this.updatedAt});

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'],
    instructorId: json['instructor_id'],
    formationId: json['formation_id'],
    title: json['title'],
    content: json['content'],
    isPublished: json['is_published'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
