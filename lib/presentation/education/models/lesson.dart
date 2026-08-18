// models/lesson.dart
import 'video.dart';
import 'evaluation.dart';

class Lesson {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final String type; // 'video', 'text', 'quiz', 'assignment', 'evaluation', 'document'
  final int durationMinutes;
  final int order;
  final String? content;
  final DateTime? createdAt;

  // Relations
  Video? video;
  Evaluation? evaluation;

  Lesson({
    required this.id,
    required this.moduleId,
    required this.title,
    this.description,
    required this.type,
    this.durationMinutes = 0,
    this.order = 0,
    this.content,
    this.createdAt,
    this.video,
    this.evaluation,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String? ?? '',
        moduleId: json['module_id'] as String? ?? '',
        title: json['title'] as String? ?? 'Leçon sans titre',
        description: json['description'] as String?,
        type: json['type'] as String? ?? 'text',
        durationMinutes: json['duration_minutes'] as int? ?? 0,
        order: json['order'] as int? ?? 0,
        content: json['content'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        video: json['video'] != null
            ? Video.fromJson(json['video'] as Map<String, dynamic>)
            : null,
        evaluation: json['evaluation'] != null
            ? Evaluation.fromJson(json['evaluation'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_id': moduleId,
        'title': title,
        'description': description,
        'type': type,
        'duration_minutes': durationMinutes,
        'order': order,
        'content': content,
        'created_at': createdAt?.toIso8601String(),
      };

  Lesson copyWith({
    String? id,
    String? moduleId,
    String? title,
    String? description,
    String? type,
    int? durationMinutes,
    int? order,
    String? content,
    DateTime? createdAt,
    Video? video,
    Evaluation? evaluation,
  }) =>
      Lesson(
        id: id ?? this.id,
        moduleId: moduleId ?? this.moduleId,
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        order: order ?? this.order,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        video: video ?? this.video,
        evaluation: evaluation ?? this.evaluation,
      );
}
