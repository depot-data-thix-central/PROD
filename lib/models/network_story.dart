// lib/models/network_story.dart
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
  }) {
    final now = DateTime.now();
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
    );
  }
  // 🔥 FIX ULTIME : Extraction ultra-robuste + Mode Débogage
  factory NetworkStory.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : null;

    DateTime parseDate(dynamic v, {Duration? fallbackAdd}) {
      if (v == null) return DateTime.now().add(fallbackAdd ?? Duration.zero);
      try { return DateTime.parse(v.toString()); } 
      catch (_) { return DateTime.now().add(fallbackAdd ?? Duration.zero); }
    }

    // 1. Recherche agressive de l'image (Gère les listes, les strings, et les tableaux Postgres)
    String media = '';
    final possibleMediaKeys = ['media_urls', 'image_urls', 'media_url', 'image_url', 'file_url', 'photo_url', 'url'];
    
    for (final key in possibleMediaKeys) {
      final val = json[key];
      if (val != null && val.toString() != 'null' && val.toString().trim().isNotEmpty) {
        if (val is List && val.isNotEmpty) {
          media = val.first.toString();
          break;
        } else if (val is String) {
          // Si Supabase renvoie un tableau au format String Postgres "{lien1, lien2}"
          if (val.startsWith('{') && val.endsWith('}')) {
            final clean = val.substring(1, val.length - 1);
            if (clean.isNotEmpty) {
              media = clean.split(',').first.replaceAll('"', '').trim();
              break;
            }
          } else {
            media = val.trim();
            break;
          }
        }
      }
    }

    // 2. Recherche agressive du texte
    String text = '';
    final possibleTextKeys = ['text_content', 'content', 'text', 'description', 'caption'];
    for (final key in possibleTextKeys) {
      final val = json[key];
      if (val != null && val.toString() != 'null' && val.toString().trim().isNotEmpty) {
        text = val.toString().trim();
        break;
      }
    }

    // 🚨 LE MODE DÉTECTIVE 🚨
    // Si la story est toujours vide, on affiche le JSON brut à l'écran pour comprendre !
    if (media.isEmpty && text.isEmpty) {
      text = "🔧 LIGNE VIDE DANS SUPABASE\n\nVoici ce que la base a renvoyé :\n\n$json";
    }

    // 3. Extraction Profil
    final name = (profiles?['display_name'] ?? profiles?['full_name'] ?? json['user_name'] ?? json['author_name'] ?? 'Utilisateur').toString();
    final avatar = (profiles?['avatar_url'] ?? profiles?['photo_url'] ?? json['user_avatar'] ?? json['author_avatar'])?.toString();
    final title = (profiles?['profession'] ?? json['user_title'] ?? 'Membre THIX').toString();

    return NetworkStory(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      userName: name == 'null' ? 'Utilisateur' : name,
      userAvatar: avatar == 'null' ? null : avatar,
      userTitle: title == 'null' ? 'Membre THIX' : title,
      imageUrl: media,
      textContent: text.isEmpty ? null : text,
      mediaType: (json['media_type'] ?? 'image').toString(),
      duration: (json['duration'] as num?)?.toInt() ?? 24,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      expiresAt: parseDate(json['expires_at'] ?? json['expiresAt'], fallbackAdd: const Duration(hours: 24)),
      isViewed: json['is_viewed'] == true || json['isViewed'] == true,
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
  };


  bool get isCurrentUser {
    if (isCurrentUserOverride != null) return isCurrentUserOverride!;
    try { return Supabase.instance.client.auth.currentUser?.id == userId; } catch (_) { return false; }
  }
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired;
  String get avatarUrl => userAvatar ?? '';
  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : '?';

  double get remainingPercentage {
    final total = expiresAt.difference(createdAt).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (1 - elapsed / total).clamp(0.0, 1.0);
  }

  String get timeRemaining {
    final r = expiresAt.difference(DateTime.now());
    if (r.isNegative) return 'expirée';
    if (r.inHours > 0) return '${r.inHours}h';
    if (r.inMinutes > 0) return '${r.inMinutes}min';
    return 'bientôt';
  }

  NetworkStory markAsViewed() => copyWith(isViewed: true);

  NetworkStory copyWith({String? id, String? userId, String? userName, String? userAvatar, String? userTitle, String? imageUrl, String? textContent, String? mediaType, int? duration, DateTime? createdAt, DateTime? expiresAt, bool? isViewed}) {
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
    );
  }
}

extension NetworkStoryListExtension on List<NetworkStory> {
  List<NetworkStory> get active => where((s) => !s.isExpired).toList();
  List<NetworkStory> get unviewed => where((s) => !s.isViewed).toList();
  List<NetworkStory> get sortedByNewest => toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt));
  Map<String, List<NetworkStory>> groupByUser() {
    final map = <String, List<NetworkStory>>{};
    for (final s in this) { map.putIfAbsent(s.userId, ()=> []).add(s); }
    return map;
  }
}
