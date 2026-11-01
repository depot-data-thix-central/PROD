// lib/presentation/thix_weeding/pages/guest/guestbook_repository.dart
// ============================================================================
// LIVRE D'OR — Repository production (Web + Mobile)
// ✅ Même table que le Staff (thix_weeding_guestbook) → synchronisation totale
// ✅ Vidéos ≤ 50 min via Supabase Storage (bucket thix_wedding_assets)
// ✅ Réactions ❤️ (table dédiée) — pas de commentaires
// ✅ Fallbacks défensifs (migration non appliquée / RLS) + erreurs explicites
// ✅ Aucun dart:io → 100% Web-safe (upload via bytes)
// ============================================================================
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final guestbookRepositoryProvider =
    Provider<GuestbookRepository>((ref) => GuestbookRepository());

// ============================================================
// MODÈLE
// ============================================================
class GuestbookPost {
  final String id;
  final String authorName;
  final String message;
  final DateTime createdAt;
  final String? mediaUrl;
  final String? mediaType; // 'video' | null
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

  GuestbookPost copyWith({int? likesCount, bool? likedByMe, bool? isApproved}) =>
      GuestbookPost(
        id: id,
        authorName: authorName,
        message: message,
        createdAt: createdAt,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        guestThixId: guestThixId,
        isApproved: isApproved ?? this.isApproved,
        likesCount: likesCount ?? this.likesCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );

  factory GuestbookPost.fromJson(Map<String, dynamic> j,
          {bool likedByMe = false}) =>
      GuestbookPost(
        id: j['id'] as String,
        authorName:
            (j['author_name'] as String?) ?? (j['guest_name'] as String?) ?? 'Invité',
        message: (j['message'] as String?) ?? '',
        createdAt:
            DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now(),
        mediaUrl: j['media_url'] as String?,
        mediaType: j['media_type'] as String?,
        guestThixId: j['guest_thix_id'] as String?,
        isApproved: (j['is_approved'] as bool?) ?? true,
        likesCount: (j['likes_count'] as int?) ?? 0,
        likedByMe: likedByMe,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_name': authorName,
        'message': message,
        'created_at': createdAt.toIso8601String(),
        'media_url': mediaUrl,
        'media_type': mediaType,
        'guest_thix_id': guestThixId,
        'is_approved': isApproved,
        'likes_count': likesCount,
      };
}

// ============================================================
// REPOSITORY
// ============================================================
class GuestbookRepository {
  final _c = Supabase.instance.client;
  final _uuid = const Uuid();

  /// ⏱️ Limite entreprise : 50 minutes de souvenir vidéo
  static const Duration maxVideoDuration = Duration(minutes: 50);

  /// 📦 Taille max d'un upload vidéo (200 Mo)
  static const int maxVideoBytes = 200 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // LECTURE DU FEED
  // ---------------------------------------------------------------------------
  Future<List<GuestbookPost>> getPosts(String weddingId, String myThixId) async {
    final rows = await _c
        .from('thix_weeding_guestbook')
        .select()
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false)
        .limit(200);

    final posts = List<Map<String, dynamic>>.from(rows);
    if (posts.isEmpty) return const [];

    // Réactions ❤️ de l'invité courant (tolérant si table/policy absente)
    Set<String> likedIds = {};
    try {
      final myLikes = await _c
          .from('thix_weeding_guestbook_likes')
          .select('post_id')
          .eq('liker_thix_id', myThixId)
          .inFilter('post_id', posts.map((p) => p['id'] as String).toList());
      likedIds = List<Map<String, dynamic>>.from(myLikes)
          .map((e) => e['post_id'] as String)
          .toSet();
    } catch (_) {}

    return posts
        .map((j) => GuestbookPost.fromJson(j, likedByMe: likedIds.contains(j['id'])))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // PUBLICATION (texte ou vidéo)
  // ---------------------------------------------------------------------------
  Future<GuestbookPost> createPost({
    required String weddingId,
    required String authorName,
    required String message,
    Uint8List? videoBytes,
    String? videoFileName,
    String? guestThixId,
  }) async {
    String? mediaUrl;
    String? mediaType;

    if (videoBytes != null && videoBytes.isNotEmpty) {
      if (videoBytes.length > maxVideoBytes) {
        throw Exception('Vidéo trop lourde (max 200 Mo).');
      }
      final ext = (videoFileName?.split('.').last ?? 'mp4').toLowerCase();
      final fileName = '${_uuid.v4()}.$ext';
      final storagePath = 'weddings/$weddingId/guestbook/$fileName';

      await _c.storage.from('thix_wedding_assets').uploadBinary(
            storagePath,
            videoBytes,
            fileOptions: FileOptions(contentType: 'video/$ext', upsert: false),
          );
      mediaUrl = _c.storage.from('thix_wedding_assets').getPublicUrl(storagePath);
      mediaType = 'video';
    }

    final now = DateTime.now().toIso8601String();

    try {
      final res = await _c.from('thix_weeding_guestbook').insert({
        'wedding_id': weddingId,
        'author_name': authorName,
        'message': message,
        'created_at': now,
        'is_approved': true,
        'likes_count': 0,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'media_type': mediaType,
        if (guestThixId != null) 'guest_thix_id': guestThixId,
      }).select().single();
      return GuestbookPost.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      // 42703 = colonne manquante (migration non appliquée) → insert minimal v1
      if (e.code == '42703') {
        final res = await _c.from('thix_weeding_guestbook').insert({
          'wedding_id': weddingId,
          'author_name': authorName,
          'message': message,
          'created_at': now,
        }).select().single();
        return GuestbookPost.fromJson(Map<String, dynamic>.from(res));
      }
      // 42501 = RLS bloque l'insert anonyme (Web)
      if (e.code == '42501') {
        throw Exception(
            'Permission refusée (RLS). Exécutez le script SQL : policies guestbook_insert.');
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // RÉACTIONS ❤️ (optimiste géré côté UI)
  // ---------------------------------------------------------------------------
  Future<void> toggleLike(String postId, String myThixId,
      {required bool currentlyLiked}) async {
    try {
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
    } on PostgrestException catch (e) {
      if (e.code != '42P01') rethrow; // table likes absente → compteur seul
    }

    final row = await _c
        .from('thix_weeding_guestbook')
        .select('likes_count')
        .eq('id', postId)
        .maybeSingle();
    final current = (row?['likes_count'] as int?) ?? 0;
    await _c.from('thix_weeding_guestbook').update({
      'likes_count': currentlyLiked ? (current - 1).clamp(0, 999999) : current + 1,
    }).eq('id', postId);
  }

  // ---------------------------------------------------------------------------
  // VALIDATION VIDÉO (durée) — utilisé par le composer pour la preview
  // ---------------------------------------------------------------------------
  static String formatDuration(Duration d) => d.inHours > 0
      ? '${d.inHours}h ${d.inMinutes % 60}min'
      : '${d.inMinutes}min ${d.inSeconds % 60}s';
}
