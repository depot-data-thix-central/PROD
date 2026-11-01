// lib/presentation/thix_weeding/pages/guest/guestbook_repository.dart
// ============================================================================
// LIVRE D'OR — Repository production (lecteur/éditeur du feed invité)
// ✅ Même table que le Staff (thix_weeding_guestbook) → synchronisation totale
// ✅ Médias vidéo via Supabase Storage (bucket thix_wedding_assets)
// ✅ Réactions ❤️ via table dédiée (pas de commentaires)
// ============================================================================
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final guestbookRepositoryProvider = Provider<GuestbookRepository>((ref) => GuestbookRepository());

class GuestbookPost {
  final String id;
  final String authorName;
  final String message;
  final DateTime createdAt;
  final String? mediaUrl;   // URL vidéo si publication média
  final String? mediaType;  // 'video' | null
  final String? guestThixId;
  final bool isApproved;
  final int likesCount;
  final bool likedByMe;

  const GuestbookPost({
    required this.id,
    required this.authorName,
    required this.message,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
    this.guestThixId,
    this.isApproved = true,
    this.likesCount = 0,
    this.likedByMe = false,
  });

  bool get hasVideo => mediaType == 'video' && mediaUrl != null;

  GuestbookPost copyWith({int? likesCount, bool? likedByMe}) => GuestbookPost(
        id: id,
        authorName: authorName,
        message: message,
        createdAt: createdAt,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        guestThixId: guestThixId,
        isApproved: isApproved,
        likesCount: likesCount ?? this.likesCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );

  factory GuestbookPost.fromJson(Map<String, dynamic> j, {bool likedByMe = false}) => GuestbookPost(
        id: j['id'] as String,
        authorName: (j['author_name'] as String?) ?? (j['guest_name'] as String?) ?? 'Invité',
        message: (j['message'] as String?) ?? '',
        createdAt: DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now(),
        mediaUrl: j['media_url'] as String?,
        mediaType: j['media_type'] as String?,
        guestThixId: j['guest_thix_id'] as String?,
        isApproved: (j['is_approved'] as bool?) ?? true,
        likesCount: (j['likes_count'] as int?) ?? 0,
        likedByMe: likedByMe,
      );
}

class GuestbookRepository {
  final _c = Supabase.instance.client;
  final _uuid = const Uuid();

  /// ⏱️ Limite entreprise : 50 minutes de souvenir vidéo
  static const Duration maxVideoDuration = Duration(minutes: 50);

  /// Feed complet (plus récent d'abord) + statut "j'aime" de l'invité courant
  Future<List<GuestbookPost>> getPosts(String weddingId, String myThixId) async {
    final rows = await _c
        .from('thix_weeding_guestbook')
        .select()
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false)
        .limit(200);

    final posts = List<Map<String, dynamic>>.from(rows);
    if (posts.isEmpty) return const [];

    // Mes réactions sur ces publications
    final ids = posts.map((p) => p['id'] as String).toList();
    final myLikes = await _c
        .from('thix_weeding_guestbook_likes')
        .select('post_id')
        .eq('liker_thix_id', myThixId)
        .inFilter('post_id', ids);
    final likedIds = List<Map<String, dynamic>>.from(myLikes).map((e) => e['post_id'] as String).toSet();

    return posts
        .map((j) => GuestbookPost.fromJson(j, likedByMe: likedIds.contains(j['id'])))
        .toList();
  }

  /// Publie un vœu (texte) ou un souvenir vidéo (upload Storage + insert DB)
  Future<GuestbookPost> createPost({
    required String weddingId,
    required String authorName,
    required String message,
    File? video,
    String? guestThixId,
  }) async {
    String? mediaUrl;
    String? mediaType;

    if (video != null) {
      final ext = video.path.split('.').last.toLowerCase();
      final fileName = '${_uuid.v4()}.$ext';
      final storagePath = 'weddings/$weddingId/guestbook/$fileName';

      await _c.storage.from('thix_wedding_assets').uploadBinary(
            storagePath,
            await video.readAsBytes(),
            fileOptions: FileOptions(contentType: 'video/$ext', upsert: false),
          );
      mediaUrl = _c.storage.from('thix_wedding_assets').getPublicUrl(storagePath);
      mediaType = 'video';
    }

    final res = await _c
        .from('thix_weeding_guestbook')
        .insert({
          'wedding_id': weddingId,
          'author_name': authorName,
          'message': message,
          'media_url': mediaUrl,
          'media_type': mediaType,
          'guest_thix_id': guestThixId,
          'is_approved': true, // le staff peut repasser à false pour modérer
          'likes_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return GuestbookPost.fromJson(Map<String, dynamic>.from(res));
  }

  /// Réaction ❤️ (ajout/retrait) + compteur maintenu à jour
  Future<void> toggleLike(String postId, String myThixId, {required bool currentlyLiked}) async {
    if (currentlyLiked) {
      await _c
          .from('thix_weeding_guestbook_likes')
          .delete()
          .eq('post_id', postId)
          .eq('liker_thix_id', myThixId);
    } else {
      await _c.from('thix_weeding_guestbook_likes').insert({
        'post_id': postId,
        'liker_thix_id': myThixId,
      });
    }

    final row = await _c.from('thix_weeding_guestbook').select('likes_count').eq('id', postId).maybeSingle();
    final current = (row?['likes_count'] as int?) ?? 0;
    await _c.from('thix_weeding_guestbook').update({
      'likes_count': currentlyLiked ? (current - 1).clamp(0, 999999) : current + 1,
    }).eq('id', postId);
  }
}
