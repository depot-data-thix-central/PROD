// models/video.dart
class Video {
  final String id;
  final String lessonId;
  final String title;
  final String url;
  final int duration; // en secondes
  final DateTime? createdAt;

  Video({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.url,
    this.duration = 0,
    this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        id: json['id'],
        lessonId: json['lesson_id'],
        title: json['title'],
        url: json['url'],
        duration: json['duration'] ?? 0,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'title': title,
        'url': url,
        'duration': duration,
        'created_at': createdAt?.toIso8601String(),
      };

  Video copyWith({
    String? title,
    String? url,
    int? duration,
  }) =>
      Video(
        id: id,
        lessonId: lessonId,
        title: title ?? this.title,
        url: url ?? this.url,
        duration: duration ?? this.duration,
        createdAt: createdAt,
      );
}
