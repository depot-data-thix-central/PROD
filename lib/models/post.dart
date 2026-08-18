// lib/models/post.dart

import 'package:thix_id/models/post_media.dart';

class Post {
  final String id;
  final String authorId;
  final String content;
  final String privacy;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? author; // author profile payload when joined
  final List<PostMedia> media;

  Post({
    required this.id,
    required this.authorId,
    required this.content,
    required this.privacy,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    this.updatedAt,
    this.author,
    List<PostMedia>? media,
  }) : media = media ?? [];

  factory Post.fromMap(Map<String, dynamic> map) {
    final mediaList = <PostMedia>[];
    if (map['post_media'] is List) {
      for (final m in (map['post_media'] as List)) {
        if (m is Map<String, dynamic>) mediaList.add(PostMedia.fromMap(m));
      }
    }

    return Post(
      id: map['id'] as String,
      authorId: (map['author'] is String) ? (map['author'] as String) : ((map['author'] as Map?)?['id'] as String? ?? ''),
      content: map['content'] as String? ?? '',
      privacy: map['privacy'] as String? ?? 'public',
      likeCount: (map['like_count'] as int?) ?? 0,
      commentCount: (map['comment_count'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null ? null : DateTime.tryParse(map['updated_at'] as String),
      author: (map['profiles'] is Map) ? Map<String, dynamic>.from(map['profiles'] as Map) : null,
      media: mediaList,
    );
  }
}
