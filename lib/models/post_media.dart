// lib/models/post_media.dart

class PostMedia {
  final String id;
  final String postId;
  final String storagePath;
  final String url;
  final String mime;
  final int size;
  final int ordering;

  PostMedia({
    required this.id,
    required this.postId,
    required this.storagePath,
    required this.url,
    required this.mime,
    required this.size,
    required this.ordering,
  });

  factory PostMedia.fromMap(Map<String, dynamic> map) => PostMedia(
        id: map['id'] as String? ?? '',
        postId: map['post_id'] as String? ?? '',
        storagePath: map['storage_path'] as String? ?? '',
        url: map['url'] as String? ?? '',
        mime: map['mime'] as String? ?? '',
        size: (map['size'] as int?) ?? 0,
        ordering: (map['ordering'] as int?) ?? 0,
      );
}
