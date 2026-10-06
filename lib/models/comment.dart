class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  String content; 
  final String? audioUrl; // 🌟 Note vocale
  final String? imageUrl; // 🌟 Photo
  final DateTime createdAt;
  int likesCount; 
  bool isLiked; 
  bool isPinned; // 📌 Épinglé
  final String? parentId;
  List<Comment> replies; 

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.audioUrl,
    this.imageUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.isPinned = false, // 📌 Par défaut false
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
      audioUrl: json['audio_url'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isPinned: json['is_pinned'] ?? false, // 📌 Récupération depuis Supabase
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
    'audio_url': audioUrl,
    'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(),
    'likes_count': likesCount,
    'is_liked': isLiked,
    'is_pinned': isPinned, // 📌 Envoi vers Supabase
    'parent_id': parentId,
    'replies': replies.map((e) => e.toJson()).toList(),
  };

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    String? audioUrl,
    String? imageUrl,
    DateTime? createdAt,
    int? likesCount,
    bool? isLiked,
    bool? isPinned,
    String? parentId,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      isPinned: isPinned ?? this.isPinned,
      parentId: parentId ?? this.parentId,
      replies: replies ?? this.replies,
    );
  }
}
