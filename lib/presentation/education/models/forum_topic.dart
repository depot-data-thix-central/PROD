// models/forum_topic.dart
import 'forum_reply.dart';

class ForumTopic {
  final String id;
  final String formationId;
  final String userId;
  final String title;
  final String content;
  bool isPinned;
  bool isLocked;
  int viewsCount;
  int repliesCount;
  String status; // 'open', 'closed', 'locked'  // ✅ ajout
  final DateTime? createdAt;
  final DateTime? updatedAt;

  List<ForumReply>? replies;
  String? authorName;

  ForumTopic({
    required this.id,
    required this.formationId,
    required this.userId,
    required this.title,
    required this.content,
    this.isPinned = false,
    this.isLocked = false,
    this.viewsCount = 0,
    this.repliesCount = 0,
    this.status = 'open',  // ✅ valeur par défaut
    this.createdAt,
    this.updatedAt,
    this.replies,
    this.authorName,
  });

  factory ForumTopic.fromJson(Map<String, dynamic> json) => ForumTopic(
        id: json['id'],
        formationId: json['formation_id'],
        userId: json['user_id'],
        title: json['title'],
        content: json['content'],
        isPinned: json['is_pinned'] ?? false,
        isLocked: json['is_locked'] ?? false,
        viewsCount: json['views_count'] ?? 0,
        repliesCount: json['replies_count'] ?? 0,
        status: json['status'] ?? 'open',  // ✅
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        replies: json['replies'] != null
            ? (json['replies'] as List).map((r) => ForumReply.fromJson(r)).toList()
            : null,
        authorName: json['author_name'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'formation_id': formationId,
        'user_id': userId,
        'title': title,
        'content': content,
        'is_pinned': isPinned,
        'is_locked': isLocked,
        'views_count': viewsCount,
        'replies_count': repliesCount,
        'status': status,  // ✅
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  ForumTopic copyWith({
    String? title,
    String? content,
    bool? isPinned,
    bool? isLocked,
    int? viewsCount,
    int? repliesCount,
    String? status,
    List<ForumReply>? replies,
    String? authorName,
  }) =>
      ForumTopic(
        id: id,
        formationId: formationId,
        userId: userId,
        title: title ?? this.title,
        content: content ?? this.content,
        isPinned: isPinned ?? this.isPinned,
        isLocked: isLocked ?? this.isLocked,
        viewsCount: viewsCount ?? this.viewsCount,
        repliesCount: repliesCount ?? this.repliesCount,
        status: status ?? this.status,  // ✅
        createdAt: createdAt,
        updatedAt: updatedAt,
        replies: replies ?? this.replies,
        authorName: authorName ?? this.authorName,
      );
}
