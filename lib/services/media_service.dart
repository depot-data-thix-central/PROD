import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

typedef ProgressCallback = void Function(double progress);

class FeedPage {
  final List<MediaContent> items;
  final List<Map<String, dynamic>> raw;
  FeedPage({required this.items, required this.raw});
}

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService({SupabaseClient? client, String? bucket}) => _instance;
  MediaService._internal();

  SupabaseClient get supabase => Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // ---- BATCH VUES ----
  static final Set<String> _pendingViews = {};
  static Timer? _viewTimer;

  void registerView(String id) {
    _pendingViews.add(id);
    _viewTimer ??= Timer(const Duration(seconds: 8), _flush);
  }

  static Future<void> _flush() async {
    if (_pendingViews.isEmpty) {
      _viewTimer = null;
      return;
    }
    final b = _pendingViews.toList();
    _pendingViews.clear();
    _viewTimer = null;
    try {
      await Supabase.instance.client.rpc('batch_register_views', params: {'p_media_ids': b});
    } catch (_) {
      _pendingViews.addAll(b);
    }
  }

  // ---- FEED ENRICHI ----
  Future<FeedPage> fetchEnrichedFeed({required List<String> seenIds, int limit = 12}) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      final data = await supabase.rpc('get_feed_with_creator', params: {'p_seen_ids': seenIds, 'p_limit': limit, 'p_uid': uid}) as List;
      final items = data.map((e) => MediaContent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final raw = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return FeedPage(items: items, raw: raw);
    } catch (_) {
      return FeedPage(items: [], raw: []);
    }
  }

  Future<FeedPage> fetchShuffledFeed({required List<String> seenIds, int limit = 12}) async {
    try {
      final data = await supabase.rpc('get_shuffled_feed', params: {'p_seen_ids': seenIds, 'p_limit': limit}) as List;
      return FeedPage(items: data.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList(), raw: []);
    } catch (_) {
      return FeedPage(items: [], raw: []);
    }
  }

  // ---- LIKES / FOLLOW ----
  Future<bool> toggleLike(String id) async {
    try {
      final r = await supabase.rpc('toggle_media_like', params: {'p_media_id': id});
      if (r is bool) return r;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleFollow(String targetId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || targetId.isEmpty || uid == targetId) return false;

    try {
      final ex = await supabase.from('follows').select().eq('follower_id', uid).eq('following_id', targetId).maybeSingle();
      if (ex != null) {
        await supabase.from('follows').delete().eq('follower_id', uid).eq('following_id', targetId);
        return false;
      } else {
        await supabase.from('follows').insert({'follower_id': uid, 'following_id': targetId});
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFollowing(String targetId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || targetId.isEmpty || uid == targetId) return false;
    try {
      final ex = await supabase.from('follows').select().eq('follower_id', uid).eq('following_id', targetId).maybeSingle();
      return ex != null;
    } catch (_) {
      return false;
    }
  }

  Future<Set<String>> getLikedMediaIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final r = await supabase.rpc('get_liked_media_ids', params: {'p_media_ids': ids});
      return (r as List).map((e) => e.toString()).toSet();
    } catch (_) {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return {};
      final r = await supabase.from('media_likes').select('media_id').eq('user_id', uid).inFilter('media_id', ids);
      return (r as List).map((e) => e['media_id'].toString()).toSet();
    }
  }

  // ---- PROFILE ----
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      return await supabase.from('profiles').select().eq('id', userId).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchUserStats(String userId) async {
    try {
      final followersCount = await supabase.from('follows').count(CountOption.exact).eq('following_id', userId);
      final followingCount = await supabase.from('follows').count(CountOption.exact).eq('follower_id', userId);
      final postsCount = await supabase.from('media_content').count(CountOption.exact).eq('user_id', userId);

      return {
        'followers': followersCount,
        'following': followingCount,
        'posts': postsCount,
      };
    } catch (_) {
      return {'followers': 0, 'following': 0, 'posts': 0};
    }
  }

  // ---- ADMIN ----
  Future<List<MediaContent>> fetchAllMedia({int page = 0, int limit = 50}) async {
    try {
      final s = page * limit;
      final data = await supabase.from('media_content').select().order('created_at', ascending: false).range(s, s + limit - 1) as List;
      return data.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MediaContent>> fetchAllMediaPaginated({int limit = 30, int offset = 0}) async {
    try {
      final data = await supabase.from('media_content').select().order('created_at', ascending: false).range(offset, offset + limit - 1) as List;
      return data.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---- UPLOAD HELPERS ----

  Future<String> _upload(PlatformFile f, String base) async {
    if (f.bytes == null) throw Exception('withData:true requis');
    final name = '${_uuid.v4()}${p.extension(f.name)}';
    final path = '$base/$name';
    await supabase.storage.from('media').uploadBinary(path, f.bytes!, fileOptions: const FileOptions(cacheControl: '31536000', upsert: true));
    return supabase.storage.from('media').getPublicUrl(path);
  }

  /// Upload direct depuis des bytes bruts — utilisé notamment pour la
  /// miniature générée automatiquement à partir de la vidéo.
  Future<String> _uploadBytes(Uint8List bytes, String base, String ext) async {
    final name = '${_uuid.v4()}$ext';
    final path = '$base/$name';
    await supabase.storage.from('media').uploadBinary(path, bytes, fileOptions: const FileOptions(cacheControl: '31536000', upsert: true));
    return supabase.storage.from('media').getPublicUrl(path);
  }

  /// Génère une miniature (JPEG) à partir de la première frame de la vidéo.
  /// Retourne `null` sur le web ou en cas d'échec — jamais d'exception,
  /// pour ne jamais bloquer la publication faute de couverture.
  Future<Uint8List?> _generateThumbnailFromVideo(PlatformFile videoFile) async {
    if (kIsWeb) return null; // video_thumbnail non supporté sur le web
    final path = videoFile.path;
    if (path == null) return null;
    try {
      return await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxWidth: 720,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- CRÉATION / MISE À JOUR ----

  /// [episodeFiles] : pour une série — liste de fichiers vidéo additionnels
  /// (au-delà de la vidéo principale [videoFile]) qui seront uploadés et
  /// stockés dans `episodesUrls`.
  Future<MediaContent> insertWithFiles(
    MediaContent item, {
    PlatformFile? coverFile,
    PlatformFile? videoFile,
    List<PlatformFile>? episodeFiles,
    ProgressCallback? onProgress,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception("Utilisateur non connecté. Impossible de publier.");
    }

    final nid = _uuid.v4();
    String? c = item.coverUrl, v = item.videoUrl;
    List<String> episodeUrls = List<String>.from(item.episodesUrls);

    // Poids de progression réparti entre vidéo principale, couverture et épisodes
    final totalSteps = 1 + (episodeFiles?.length ?? 0) + 1; // vidéo + épisodes + couverture
    var doneSteps = 0;
    void bump() {
      doneSteps++;
      onProgress?.call((doneSteps / totalSteps).clamp(0.0, 1.0));
    }

    if (videoFile != null) {
      v = await _upload(videoFile, 'thix_media/$nid/videos');
    }
    bump();

    if (episodeFiles != null && episodeFiles.isNotEmpty) {
      for (final ep in episodeFiles) {
        final url = await _upload(ep, 'thix_media/$nid/episodes');
        episodeUrls.add(url);
        bump();
      }
    }

    // Couverture : priorité au fichier fourni manuellement, sinon
    // génération automatique depuis la première frame de la vidéo.
    if (coverFile != null) {
      c = await _upload(coverFile, 'thix_media/$nid/covers');
    } else if (videoFile != null) {
      final thumbBytes = await _generateThumbnailFromVideo(videoFile);
      if (thumbBytes != null) {
        c = await _uploadBytes(thumbBytes, 'thix_media/$nid/covers', '.jpg');
      }
    }
    bump();

    final ins = item
        .copyWith(
          id: nid,
          userId: user.id,
          coverUrl: c,
          videoUrl: v,
          episodesUrls: episodeUrls,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
        .toJson();

    final res = await supabase.from('media_content').insert(ins).select().single();

    return MediaContent.fromJson(res as Map<String, dynamic>);
  }

  Future<MediaContent> updateWithFiles(
    MediaContent ex, {
    PlatformFile? newCoverFile,
    PlatformFile? newVideoFile,
    List<PlatformFile>? newEpisodeFiles,
    ProgressCallback? onProgress,
  }) async {
    String? c = ex.coverUrl, v = ex.videoUrl;
    List<String> episodeUrls = List<String>.from(ex.episodesUrls);

    final totalSteps = 1 + (newEpisodeFiles?.length ?? 0) + 1;
    var doneSteps = 0;
    void bump() {
      doneSteps++;
      onProgress?.call((doneSteps / totalSteps).clamp(0.0, 1.0));
    }

    if (newVideoFile != null) {
      v = await _upload(newVideoFile, 'thix_media/${ex.id}/videos');
    }
    bump();

    if (newEpisodeFiles != null && newEpisodeFiles.isNotEmpty) {
      for (final ep in newEpisodeFiles) {
        final url = await _upload(ep, 'thix_media/${ex.id}/episodes');
        episodeUrls.add(url);
        bump();
      }
    }

    if (newCoverFile != null) {
      c = await _upload(newCoverFile, 'thix_media/${ex.id}/covers');
    } else if (newVideoFile != null && (c == null || c!.isEmpty)) {
      // Régénère une couverture uniquement si aucune n'existe déjà
      final thumbBytes = await _generateThumbnailFromVideo(newVideoFile);
      if (thumbBytes != null) {
        c = await _uploadBytes(thumbBytes, 'thix_media/${ex.id}/covers', '.jpg');
      }
    }
    bump();

    final up = ex.copyWith(coverUrl: c, videoUrl: v, episodesUrls: episodeUrls, updatedAt: DateTime.now()).toJson();
    await supabase.from('media_content').update(up).eq('id', ex.id);

    return ex.copyWith(coverUrl: c, videoUrl: v, episodesUrls: episodeUrls);
  }

  Future<void> deleteMedia(MediaContent item) async {
    try {
      await supabase.from('media_content').delete().eq('id', item.id);
    } catch (_) {
      // Ignorer l'erreur silencieusement
    }
  }
}
