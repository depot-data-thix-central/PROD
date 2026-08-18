class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  String content; 
  final String? audioUrl; // 🌟 AJOUT : Pour la note vocale
  final String? imageUrl; // 🌟 AJOUT : Pour la photo
  final DateTime createdAt;
  int likesCount; 
  bool isLiked; 
  final String? parentId;
  List<Comment> replies; 

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.audioUrl, // 🌟
    this.imageUrl, // 🌟
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.parentId,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      userName: json['profiles']?['display_name'] ?? json['user_name'] ?? 'Utilisateur',
      userAvatar: json['profiles']?['avatar_url'] ?? json['user_avatar'],
      content: json['content'] ?? '',
      audioUrl: json['audio_url'], // 🌟 Mapper depuis Supabase
      imageUrl: json['image_url'], // 🌟 Mapper depuis Supabase
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      parentId: json['parent_id'],
      replies: (json['replies'] as List?)
          ?.map((e) => Comment.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_id': postId,
    'user_id': userId,
    'user_name': userName,
    'user_avatar': userAvatar,
    'content': content,
    'audio_url': audioUrl, // 🌟 Envoyer à Supabase
    'image_url': imageUrl, // 🌟 Envoyer à Supabase
    'created_at': createdAt.toIso8601String(),
    'likes_count': likesCount,
    'is_liked': isLiked,
    'parent_id': parentId,
    'replies': replies.map((e) => e.toJson()).toList(),
  };
}
