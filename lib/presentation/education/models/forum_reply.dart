// models/forum_reply.dart
class ForumReply {
  final String id;
  final String topicId;
  final String userId;
  final String content;
  bool isSolution;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relation (nom d'auteur)
  String? authorName;

  ForumReply({
    required this.id,
    required this.topicId,
    required this.userId,
    required this.content,
    this.isSolution = false,
    this.createdAt,
    this.updatedAt,
    this.authorName,
  });

  factory ForumReply.fromJson(Map<String, dynamic> json) => ForumReply(
        id: json['id'],
        topicId: json['topic_id'],
        userId: json['user_id'],
        content: json['content'],
        isSolution: json['is_solution'] ?? false,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        authorName: json['author_name'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic_id': topicId,
        'user_id': userId,
        'content': content,
        'is_solution': isSolution,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  ForumReply copyWith({
    String? content,
    bool? isSolution,
    String? authorName,
  }) =>
      ForumReply(
        id: id,
        topicId: topicId,
        userId: userId,
        content: content ?? this.content,
        isSolution: isSolution ?? this.isSolution,
        createdAt: createdAt,
        updatedAt: updatedAt,
        authorName: authorName ?? this.authorName,
      );
}
