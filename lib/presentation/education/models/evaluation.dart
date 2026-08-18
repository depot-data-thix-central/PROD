// models/evaluation.dart
import 'question.dart';

class Evaluation {
  final String id;
  final String lessonId;
  final String title;
  final int passingScore;
  final DateTime? createdAt;

  // Relations
  List<Question>? questions;

  Evaluation({
    required this.id,
    required this.lessonId,
    required this.title,
    this.passingScore = 0,
    this.createdAt,
    this.questions,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) => Evaluation(
        id: json['id'],
        lessonId: json['lesson_id'],
        title: json['title'],
        passingScore: json['passing_score'] ?? 0,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        questions: json['questions'] != null
            ? (json['questions'] as List).map((q) => Question.fromJson(q)).toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'title': title,
        'passing_score': passingScore,
        'created_at': createdAt?.toIso8601String(),
      };

  Evaluation copyWith({
    String? title,
    int? passingScore,
    List<Question>? questions,
  }) =>
      Evaluation(
        id: id,
        lessonId: lessonId,
        title: title ?? this.title,
        passingScore: passingScore ?? this.passingScore,
        createdAt: createdAt,
        questions: questions ?? this.questions,
      );
}
