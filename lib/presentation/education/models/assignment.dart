class Assignment {
  final String id;
  final String lessonId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final double maxScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({required this.id, required this.lessonId, required this.title, this.description, this.dueDate, this.maxScore = 100, required this.createdAt, required this.updatedAt});

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
    id: json['id'],
    lessonId: json['lesson_id'],
    title: json['title'],
    description: json['description'],
    dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
    maxScore: (json['max_score'] as num?)?.toDouble() ?? 100,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
