import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NetworkStory {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userTitle;
  final String imageUrl;
  final String? textContent;
  final String mediaType;
  final int duration;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isViewed;
  final bool? isCurrentUserOverride;
  final String? bgColor;                          // ✅ AJOUT

  NetworkStory({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.userTitle,
    required this.imageUrl,
    this.textContent,
    this.mediaType = 'image',
    required this.duration,
    required this.createdAt,
    required this.expiresAt,
    this.isViewed = false,
    this.isCurrentUserOverride,
    this.bgColor,                                 // ✅ AJOUT
  });

  factory NetworkStory.fromCreation({
    required String userId,
    required String userName,
    required String imageUrl,
    String? textContent,
    String mediaType = 'image',
    String? userAvatar,
    String? userTitle,
    int durationHours = 24,
    String? bgColor,                              // ✅ AJOUT
  }) {
    final now = DateTime.now().toUtc(); // ✅ UTC
    return NetworkStory(
      id: '',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      userTitle: userTitle ?? 'Membre THIX',
      imageUrl: imageUrl,
      textContent: textContent,
      mediaType: mediaType,
      duration: durationHours,
      createdAt: now,
      expiresAt: now.add(Duration(hours: durationHours)),
      bgColor: bgColor,                           // ✅ AJOUT
    );
  }

  factory NetworkStory.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : null;

    // ✅ CORRIGÉ : Parsing UTC
    DateTime parseDate(dynamic v, {Duration? fallbackAdd}) {
      if (v == null) return DateTime.now().toUtc().add(fallbackAdd ?? Duration.zero);
      try {
        return DateTime.parse(v.toString()).toUtc(); // ✅ UTC
      } catch (_) {
        return DateTime.now().toUtc().add(fallbackAdd ?? Duration.zero);
      }
    }

    // ✅ NOUVEAU : Validation d'URL
    String validateUrl(String? url) {
      if (url == null || url.trim().isEmpty) return '';
      final trimmed = url.trim();
      
      // Seules les URLs HTTP/HTTPS sont autorisées
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        return '';
      }
      
      return trimmed;
    }

    // Extraction de l'image
    String media = '';
    final possibleMediaKeys = ['media_urls', 'image_urls', 'media_url', 'image_url', 'file_url', 'photo_url', 'url'];
    
    for (final key in possibleMediaKeys) {
      final val = json[key];
      if (val != null && val.toString() != 'null' && val.toString().trim().isNotEmpty) {
        if (val is List && val.isNotEmpty) {
          media = validateUrl(val.first.toString());
          if (media.isNotEmpty) break;
        } else if (val is String) {
          if (val.startsWith('{') && val.endsWith('}')) {
            final clean = val.substring(1, val.length - 1);
            if (clean.isNotEmpty) {
              media = validateUrl(clean.split(',').first.replaceAll('"', '').trim());
              if (media.isNotEmpty) break;
            }
          } else {
            media = validateUrl(val.trim());
            if (media.isNotEmpty) break;
          }
        }
      }
    }

    // Extraction du texte
    String text = '';
    final possibleTextKeys = ['text_content', 'content', 'text', 'description', 'caption'];
    for (final key in possibleTextKeys) {
      final val = json[key];
      if (val != null && val.toString() != 'null' && val.toString().trim().isNotEmpty) {
        text = val.toString().trim();
        break;
      }
    }

    final name = (profiles?['display_name'] ?? profiles?['full_name'] ?? json['user_name'] ?? json['author_name'] ?? 'Utilisateur').toString();
    final avatar = validateUrl(profiles?['avatar_url']?.toString() ?? profiles?['photo_url']?.toString() ?? json['user_avatar']?.toString() ?? json['author_avatar']?.toString());
    final title = (profiles?['profession'] ?? json['user_title'] ?? 'Membre THIX').toString();

    return NetworkStory(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      userName: name == 'null' ? 'Utilisateur' : name,
      userAvatar: avatar == 'null' || avatar.isEmpty ? null : avatar,
      userTitle: title == 'null' ? 'Membre THIX' : title,
      imageUrl: media,
      textContent: text.isEmpty ? null : text,
      mediaType: (json['media_type'] ?? 'image').toString(),
      duration: (json['duration'] as num?)?.toInt() ?? 24,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      expiresAt: parseDate(json['expires_at'] ?? json['expiresAt'], fallbackAdd: const Duration(hours: 24)),
      isViewed: json['is_viewed'] == true || json['isViewed'] == true,
      bgColor: json['bg_color'] as String?,                       // ✅ AJOUT
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'media_url': imageUrl,
    'image_url': imageUrl,
    'text': textContent,
    'text_content': textContent,
    'media_type': mediaType,
    'duration': duration,
    'bg_color': bgColor,                                          // ✅ AJOUT
  };

  /// ✅ OPTIMISÉ : Cache le résultat pour éviter les appels répétés
  bool? _isCurrentUserCache;
  bool get isCurrentUser {
    if (isCurrentUserOverride != null) return isCurrentUserOverride!;
    _isCurrentUserCache ??= Supabase.instance.client.auth.currentUser?.id == userId;
    return _isCurrentUserCache ?? false;
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
  bool get isActive => !isExpired;
  String get avatarUrl => userAvatar ?? '';
  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : '?';

  double get remainingPercentage {
    final total = expiresAt.difference(createdAt).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().toUtc().difference(createdAt).inSeconds;
    return (1 - elapsed / total).clamp(0.0, 1.0);
  }

  String get timeRemaining {
    final r = expiresAt.difference(DateTime.now().toUtc());
    if (r.isNegative) return 'expirée';
    if (r.inHours > 0) return '${r.inHours}h';
    if (r.inMinutes > 0) return '${r.inMinutes}min';
    return 'bientôt';
  }

  NetworkStory markAsViewed() => copyWith(isViewed: true);

  NetworkStory copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userTitle,
    String? imageUrl,
    String? textContent,
    String? mediaType,
    int? duration,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isViewed,
    String? bgColor,                              // ✅ AJOUT
  }) {
    return NetworkStory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userTitle: userTitle ?? this.userTitle,
      imageUrl: imageUrl ?? this.imageUrl,
      textContent: textContent ?? this.textContent,
      mediaType: mediaType ?? this.mediaType,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isViewed: isViewed ?? this.isViewed,
      bgColor: bgColor ?? this.bgColor,           // ✅ AJOUT
    );
  }
}

extension NetworkStoryListExtension on List<NetworkStory> {
  List<NetworkStory> get active => where((s) => !s.isExpired).toList();
  List<NetworkStory> get unviewed => where((s) => !s.isViewed).toList();
  List<NetworkStory> get sortedByNewest => toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  Map<String, List<NetworkStory>> groupByUser() {
    final map = <String, List<NetworkStory>>{};
    for (final s in this) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }
}
