// models/user_progress.dart
import 'lesson.dart';

class UserProgress {
  final String id;
  final String userId;
  final String lessonId;
  String status; // 'not_started', 'in_progress', 'completed'
  double progress; // 0.0 à 1.0
  DateTime? lastAccessedAt;
  DateTime? completedAt;
  final DateTime? createdAt;

  // Relation
  Lesson? lesson;

  UserProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    this.status = 'not_started',
    this.progress = 0.0,
    this.lastAccessedAt,
    this.completedAt,
    this.createdAt,
    this.lesson,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
        id: json['id'],
        userId: json['user_id'],
        lessonId: json['lesson_id'],
        status: json['status'] ?? 'not_started',
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        lastAccessedAt: json['last_accessed_at'] != null ? DateTime.parse(json['last_accessed_at']) : null,
        completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        lesson: json['lesson'] != null ? Lesson.fromJson(json['lesson']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'lesson_id': lessonId,
        'status': status,
        'progress': progress,
        'last_accessed_at': lastAccessedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };

  UserProgress copyWith({
    String? status,
    double? progress,
    DateTime? lastAccessedAt,
    DateTime? completedAt,
    Lesson? lesson,
  }) =>
      UserProgress(
        id: id,
        userId: userId,
        lessonId: lessonId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        lesson: lesson ?? this.lesson,
      );
}
