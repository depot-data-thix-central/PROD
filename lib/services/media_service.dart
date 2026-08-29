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

  // ============================================================================
  // CONSTANTES DE SÉCURITÉ
  // ============================================================================
  static const int _maxFileSizeBytes = 500 * 1024 * 1024; // 500 MB
  static const int _maxThumbnailSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxCoverSizeBytes = 5 * 1024 * 1024; // 5 MB
  
  static const Set<String> _allowedVideoExtensions = {
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'
  };
  
  static const Set<String> _allowedImageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp'
  };

  // ============================================================================
  // BATCH ANALYTICS (Optimisé avec threshold)
  // ============================================================================
  static final Set<String> _pendingViews = {};
  static Timer? _viewTimer;
  static const int _batchThreshold = 10;
  static const Duration _flushInterval = Duration(seconds: 15);

  void registerView(String id) {
    if (id.isEmpty) return;
    _pendingViews.add(id);
    
    if (_pendingViews.length >= _batchThreshold) {
      _flush();
    } else {
      _viewTimer ??= Timer(_flushInterval, _flush);
    }
  }

  static Future<void> _flush() async {
    _viewTimer?.cancel();
    _viewTimer = null;
    
    if (_pendingViews.isEmpty) return;
    
    final batch = _pendingViews.toList();
    _pendingViews.clear();
    
    try {
      await Supabase.instance.client.rpc(
        'batch_register_views', 
        params: {'p_media_ids': batch},
      );
    } catch (e) {
      debugPrint('[MediaService] Batch flush failed: $e');
      // Retry unique après 30s
      Timer(const Duration(seconds: 30), () {
        _pendingViews.addAll(batch);
      });
    }
  }

  // ============================================================================
  // VALIDATION DE FICHIERS
  // ============================================================================
  
  /// Détecte le MIME type par magic bytes
  String _detectMimeType(Uint8List bytes) {
    if (bytes.length < 12) return 'application/octet-stream';
    
    // JPEG : FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    
    // PNG : 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    
    // MP4/MOV : 00 00 00 XX 66 74 79 70
    if (bytes.length >= 8 && 
        bytes[4] == 0x66 && bytes[5] == 0x74 && 
        bytes[6] == 0x79 && bytes[7] == 0x70) {
      return 'video/mp4';
    }
    
    // WebM : 1A 45 DF A3
    if (bytes[0] == 0x1A && bytes[1] == 0x45 && 
        bytes[2] == 0xDF && bytes[3] == 0xA3) {
      return 'video/webm';
    }
    
    // WebP : 52 49 46 46 XX XX XX XX 57 45 42 50
    if (bytes.length >= 12 && 
        bytes[0] == 0x52 && bytes[1] == 0x49 && 
        bytes[2] == 0x46 && bytes[3] == 0x46) {
      return 'image/webp';
    }
    
    return 'application/octet-stream';
  }

  /// Valide un fichier vidéo avant upload
  void _validateVideoFile(PlatformFile file) {
    // Validation taille
    if (file.size > _maxFileSizeBytes) {
      final maxMB = (_maxFileSizeBytes / 1024 / 1024).toInt();
      throw Exception('Vidéo trop volumineuse (max $maxMB MB)');
    }

    // Validation extension
    final ext = p.extension(file.name).toLowerCase();
    if (!_allowedVideoExtensions.contains(ext)) {
      throw Exception('Format vidéo non supporté : $ext');
    }

    // Validation bytes disponibles
    if (file.bytes == null) {
      throw Exception('Impossible de lire le fichier vidéo (bytes manquants)');
    }

    // Validation MIME type (détection de fichiers déguisés)
    final mimeType = _detectMimeType(file.bytes!);
    if (!mimeType.startsWith('video/')) {
      throw Exception('Type de fichier non autorisé : $mimeType (attendu: video/*)');
    }
  }

  /// Valide un fichier image avant upload
  void _validateImageFile(PlatformFile file) {
    // Validation taille
    if (file.size > _maxCoverSizeBytes) {
      final maxMB = (_maxCoverSizeBytes / 1024 / 1024).toInt();
      throw Exception('Image trop volumineuse (max $maxMB MB)');
    }

    // Validation extension
    final ext = p.extension(file.name).toLowerCase();
    if (!_allowedImageExtensions.contains(ext)) {
      throw Exception('Format image non supporté : $ext');
    }

    // Validation bytes disponibles
    if (file.bytes == null) {
      throw Exception('Impossible de lire le fichier image (bytes manquants)');
    }

    // Validation MIME type
    final mimeType = _detectMimeType(file.bytes!);
    if (!mimeType.startsWith('image/')) {
      throw Exception('Type de fichier non autorisé : $mimeType (attendu: image/*)');
    }
  }

  /// Valide des bytes bruts (pour thumbnail)
  void _validateBytes(Uint8List bytes, String ext, int maxSize) {
    if (bytes.length > maxSize) {
      final maxMB = (maxSize / 1024 / 1024).toInt();
      throw Exception('Fichier trop volumineux (max $maxMB MB)');
    }
    
    final allowedExts = ext.toLowerCase().startsWith('.') 
        ? {ext.toLowerCase()} 
        : {'.${ext.toLowerCase()}'};
    
    if (ext.toLowerCase().endsWith('.jpg') || ext.toLowerCase().endsWith('.jpeg')) {
      // Validation JPEG
      if (bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
        throw Exception('Format JPEG invalide');
      }
    }
  }

  // ============================================================================
  // VÉRIFICATION D'OWNERSHIP
  // ============================================================================
  
  /// Vérifie si l'utilisateur courant est propriétaire du média
  Future<bool> _isMediaOwner(String mediaId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    
    try {
      final media = await supabase
          .from('media_content')
          .select('user_id')
          .eq('id', mediaId)
          .maybeSingle();
      
      return media?['user_id'] == user.id;
    } catch (e) {
      debugPrint('[MediaService] Ownership check failed: $e');
      return false;
    }
  }

  /// Vérifie si l'utilisateur courant est admin
  Future<bool> _isCurrentUserAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    
    try {
      final role = user.userMetadata?['role'] ?? user.appMetadata['role'];
      return role == 'admin' || role == 'superadmin';
    } catch (_) {
      return false;
    }
  }

  /// Vérifie les permissions pour modifier/supprimer un média
  Future<void> _checkMediaPermissions(String mediaId) async {
    final isOwner = await _isMediaOwner(mediaId);
    if (isOwner) return;
    
    final isAdmin = await _isCurrentUserAdmin();
    if (isAdmin) return;
    
    throw Exception('Permission refusée : vous n\'êtes pas autorisé à modifier ce média');
  }

  // ============================================================================
  // NETTOYAGE DES FICHIERS ORPHELINS
  // ============================================================================
  
  /// Extrait le nom de fichier depuis une URL
  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      return p.basename(uri.path);
    } catch (_) {
      return '';
    }
  }

  /// Supprime les fichiers uploadés en cas d'échec (rollback)
  Future<void> _cleanupUploadedFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    
    try {
      await supabase.storage.from('media').remove(paths);
      debugPrint('[Cleanup] Supprimé ${paths.length} fichiers orphelins');
    } catch (e) {
      debugPrint('[Cleanup] Erreur lors du nettoyage : $e');
    }
  }

  // ============================================================================
  // FEED ENRICHI
  // ============================================================================
  
  Future<FeedPage> fetchEnrichedFeed({required List<String> seenIds, int limit = 12}) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      final data = await supabase.rpc(
        'get_feed_with_creator', 
        params: {'p_seen_ids': seenIds, 'p_limit': limit, 'p_uid': uid},
      ) as List;
      
      final items = data.map((e) => MediaContent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final raw = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return FeedPage(items: items, raw: raw);
    } catch (e) {
      debugPrint('[MediaService] fetchEnrichedFeed error: $e');
      return FeedPage(items: [], raw: []);
    }
  }

  Future<FeedPage> fetchShuffledFeed({required List<String> seenIds, int limit = 12}) async {
    try {
      final data = await supabase.rpc(
        'get_shuffled_feed', 
        params: {'p_seen_ids': seenIds, 'p_limit': limit},
      ) as List;
      
      return FeedPage(
        items: data.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList(), 
        raw: [],
      );
    } catch (e) {
      debugPrint('[MediaService] fetchShuffledFeed error: $e');
      return FeedPage(items: [], raw: []);
    }
  }

  // ============================================================================
  // LIKES / FOLLOW (Optimisé avec RPC atomique)
  // ============================================================================
  
  Future<bool> toggleLike(String id) async {
    try {
      final r = await supabase.rpc('toggle_media_like', params: {'p_media_id': id});
      if (r is bool) return r;
      return true;
    } catch (e) {
      debugPrint('[MediaService] toggleLike error: $e');
      return false;
    }
  }

  Future<bool> toggleFollow(String targetId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || targetId.isEmpty || uid == targetId) return false;

    try {
      // ✅ RPC atomique côté serveur (évite race condition)
      final result = await supabase.rpc(
        'toggle_follow', 
        params: {'p_follower_id': uid, 'p_following_id': targetId},
      );
      return result as bool;
    } catch (e) {
      debugPrint('[MediaService] toggleFollow error: $e');
      
      // Fallback client-side si la RPC n'existe pas encore
      try {
        final ex = await supabase
            .from('follows')
            .select()
            .eq('follower_id', uid)
            .eq('following_id', targetId)
            .maybeSingle();
        
        if (ex != null) {
          await supabase.from('follows').delete().eq('follower_id', uid).eq('following_id', targetId);
          return false;
        } else {
          await supabase.from('follows').insert({'follower_id': uid, 'following_id': targetId});
          return true;
        }
      } catch (fallbackError) {
        debugPrint('[MediaService] toggleFollow fallback error: $fallbackError');
        return false;
      }
    }
  }

  Future<bool> isFollowing(String targetId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || targetId.isEmpty || uid == targetId) return false;
    
    try {
      final ex = await supabase
          .from('follows')
          .select()
          .eq('follower_id', uid)
          .eq('following_id', targetId)
          .maybeSingle();
      return ex != null;
    } catch (e) {
      debugPrint('[MediaService] isFollowing error: $e');
      return false;
    }
  }

  Future<Set<String>> getLikedMediaIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    
    try {
      final r = await supabase.rpc('get_liked_media_ids', params: {'p_media_ids': ids});
      return (r as List).map((e) => e.toString()).toSet();
    } catch (e) {
      debugPrint('[MediaService] getLikedMediaIds RPC failed, using fallback: $e');
      
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return {};
      
      try {
        final r = await supabase
            .from('media_likes')
            .select('media_id')
            .eq('user_id', uid)
            .inFilter('media_id', ids);
        return (r as List).map((e) => e['media_id'].toString()).toSet();
      } catch (fallbackError) {
        debugPrint('[MediaService] getLikedMediaIds fallback error: $fallbackError');
        return {};
      }
    }
  }

  // ============================================================================
  // PROFILE
  // ============================================================================
  
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      return await supabase.from('profiles').select().eq('id', userId).maybeSingle();
    } catch (e) {
      debugPrint('[MediaService] fetchProfile error: $e');
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
    } catch (e) {
      debugPrint('[MediaService] fetchUserStats error: $e');
      return {'followers': 0, 'following': 0, 'posts': 0};
    }
  }

  // ============================================================================
  // ADMIN
  // ============================================================================
  
  Future<List<MediaContent>> fetchAllMedia({int page = 0, int limit = 50}) async {
    try {
      final s = page * limit;
      final data = await supabase
          .from('media_content')
          .select()
          .order('created_at', ascending: false)
          .range(s, s + limit - 1) as List;
      
      return data.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[MediaService] fetchAllMedia error: $e');
      return [];
    }
  }

  Future<List<MediaContent>> fetchAllMediaPaginated({int limit = 30, int offset = 0}) async {
    try {
      final data = await supabase
          .from('media_content')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1) as List;
      
      return data.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[MediaService] fetchAllMediaPaginated error: $e');
      return [];
    }
  }

  // ============================================================================
  // UPLOAD HELPERS (avec validation complète)
  // ============================================================================

  Future<String> _upload(PlatformFile f, String base, {String? expectedType}) async {
    // ✅ Validation complète avant upload
    if (expectedType == 'video') {
      _validateVideoFile(f);
    } else if (expectedType == 'image') {
      _validateImageFile(f);
    }
    
    if (f.bytes == null) throw Exception('withData:true requis');
    
    final name = '${_uuid.v4()}${p.extension(f.name)}';
    final path = '$base/$name';
    final mimeType = _detectMimeType(f.bytes!);
    
    try {
      await supabase.storage.from('media').uploadBinary(
        path, 
        f.bytes!, 
        fileOptions: FileOptions(
          cacheControl: '31536000', 
          upsert: true,
          contentType: mimeType, // ✅ Spécifier le content-type
        ),
      );
    } catch (e) {
      throw Exception('Échec de l\'upload : $e');
    }
    
    return supabase.storage.from('media').getPublicUrl(path);
  }

  Future<String> _uploadBytes(Uint8List bytes, String base, String ext) async {
    // ✅ Validation des bytes
    _validateBytes(bytes, ext, _maxThumbnailSizeBytes);
    
    final name = '${_uuid.v4()}$ext';
    final path = '$base/$name';
    final mimeType = _detectMimeType(bytes);
    
    try {
      await supabase.storage.from('media').uploadBinary(
        path, 
        bytes, 
        fileOptions: FileOptions(
          cacheControl: '31536000', 
          upsert: true,
          contentType: mimeType,
        ),
      );
    } catch (e) {
      throw Exception('Échec de l\'upload des bytes : $e');
    }
    
    return supabase.storage.from('media').getPublicUrl(path);
  }

  Future<Uint8List?> _generateThumbnailFromVideo(PlatformFile videoFile) async {
    if (kIsWeb) return null;
    final path = videoFile.path;
    if (path == null) return null;
    
    try {
      return await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxWidth: 720,
      ).timeout(
        const Duration(seconds: 10), // ✅ Timeout 10s
        onTimeout: () {
          debugPrint('[Thumbnail] Timeout dépassé');
          return null;
        },
      );
    } catch (e) {
      debugPrint('[Thumbnail] Error: $e');
      return null;
    }
  }

  // ============================================================================
  // CRÉATION (avec rollback en cas d'échec)
  // ============================================================================

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
    String? c, v;
    List<String> episodeUrls = [];
    final uploadedPaths = <String>[]; // ✅ Tracker les fichiers uploadés pour rollback

    final totalSteps = 1 + (episodeFiles?.length ?? 0) + 1;
    var doneSteps = 0;
    void bump() {
      doneSteps++;
      onProgress?.call((doneSteps / totalSteps).clamp(0.0, 1.0));
    }

    try {
      // Upload vidéo principale
      if (videoFile != null) {
        v = await _upload(videoFile, 'thix_media/$nid/videos', expectedType: 'video');
        uploadedPaths.add('thix_media/$nid/videos/${_extractFileName(v)}');
      }
      bump();

      // Upload épisodes
      if (episodeFiles != null && episodeFiles.isNotEmpty) {
        for (final ep in episodeFiles) {
          final url = await _upload(ep, 'thix_media/$nid/episodes', expectedType: 'video');
          episodeUrls.add(url);
          uploadedPaths.add('thix_media/$nid/episodes/${_extractFileName(url)}');
          bump();
        }
      }

      // Upload couverture (fichier ou thumbnail)
      if (coverFile != null) {
        c = await _upload(coverFile, 'thix_media/$nid/covers', expectedType: 'image');
        uploadedPaths.add('thix_media/$nid/covers/${_extractFileName(c)}');
      } else if (videoFile != null) {
        final thumbBytes = await _generateThumbnailFromVideo(videoFile);
        if (thumbBytes != null) {
          c = await _uploadBytes(thumbBytes, 'thix_media/$nid/covers', '.jpg');
          uploadedPaths.add('thix_media/$nid/covers/${_extractFileName(c)}');
        }
      }
      bump();

      // Insertion DB
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
      
    } catch (e) {
      // ✅ ROLLBACK : Supprimer tous les fichiers uploadés
      await _cleanupUploadedFiles(uploadedPaths);
      debugPrint('[MediaService] insertWithFiles failed, cleaned up ${uploadedPaths.length} files: $e');
      throw Exception('Échec de la publication : $e');
    }
  }

  // ============================================================================
  // MISE À JOUR (avec vérification d'ownership)
  // ============================================================================

  Future<MediaContent> updateWithFiles(
    MediaContent ex, {
    PlatformFile? newCoverFile,
    PlatformFile? newVideoFile,
    List<PlatformFile>? newEpisodeFiles,
    ProgressCallback? onProgress,
  }) async {
    // ✅ Vérification d'ownership
    await _checkMediaPermissions(ex.id);

    String? c = ex.coverUrl, v = ex.videoUrl;
    List<String> episodeUrls = List<String>.from(ex.episodesUrls);
    final uploadedPaths = <String>[];

    final totalSteps = 1 + (newEpisodeFiles?.length ?? 0) + 1;
    var doneSteps = 0;
    void bump() {
      doneSteps++;
      onProgress?.call((doneSteps / totalSteps).clamp(0.0, 1.0));
    }

    try {
      if (newVideoFile != null) {
        v = await _upload(newVideoFile, 'thix_media/${ex.id}/videos', expectedType: 'video');
        uploadedPaths.add('thix_media/${ex.id}/videos/${_extractFileName(v)}');
      }
      bump();

      if (newEpisodeFiles != null && newEpisodeFiles.isNotEmpty) {
        for (final ep in newEpisodeFiles) {
          final url = await _upload(ep, 'thix_media/${ex.id}/episodes', expectedType: 'video');
          episodeUrls.add(url);
          uploadedPaths.add('thix_media/${ex.id}/episodes/${_extractFileName(url)}');
          bump();
        }
      }

      if (newCoverFile != null) {
        c = await _upload(newCoverFile, 'thix_media/${ex.id}/covers', expectedType: 'image');
        uploadedPaths.add('thix_media/${ex.id}/covers/${_extractFileName(c)}');
      } else if (newVideoFile != null && (c == null || c!.isEmpty)) {
        final thumbBytes = await _generateThumbnailFromVideo(newVideoFile);
        if (thumbBytes != null) {
          c = await _uploadBytes(thumbBytes, 'thix_media/${ex.id}/covers', '.jpg');
          uploadedPaths.add('thix_media/${ex.id}/covers/${_extractFileName(c)}');
        }
      }
      bump();

      final up = ex.copyWith(
        coverUrl: c, 
        videoUrl: v, 
        episodesUrls: episodeUrls, 
        updatedAt: DateTime.now(),
      ).toJson();
      
      await supabase.from('media_content').update(up).eq('id', ex.id);
      return ex.copyWith(coverUrl: c, videoUrl: v, episodesUrls: episodeUrls);
      
    } catch (e) {
      await _cleanupUploadedFiles(uploadedPaths);
      debugPrint('[MediaService] updateWithFiles failed, cleaned up ${uploadedPaths.length} files: $e');
      throw Exception('Échec de la mise à jour : $e');
    }
  }

  // ============================================================================
  // SUPPRESSION (avec vérification d'ownership + nettoyage storage)
  // ============================================================================

  Future<void> deleteMedia(MediaContent item) async {
    // ✅ Vérification d'ownership
    await _checkMediaPermissions(item.id);

    try {
      // Supprimer les fichiers du storage
      final filesToDelete = <String>[];
      
      if (item.videoUrl.isNotEmpty) {
        filesToDelete.add('thix_media/${item.id}/videos/${_extractFileName(item.videoUrl)}');
      }
      
      if (item.coverUrl.isNotEmpty) {
        filesToDelete.add('thix_media/${item.id}/covers/${_extractFileName(item.coverUrl)}');
      }
      
      for (var epUrl in item.episodesUrls) {
        if (epUrl.isNotEmpty) {
          filesToDelete.add('thix_media/${item.id}/episodes/${_extractFileName(epUrl)}');
        }
      }
      
      // Supprimer les fichiers (ignore les erreurs si déjà supprimés)
      if (filesToDelete.isNotEmpty) {
        try {
          await supabase.storage.from('media').remove(filesToDelete);
          debugPrint('[Cleanup] Supprimé ${filesToDelete.length} fichiers pour média ${item.id}');
        } catch (e) {
          debugPrint('[Cleanup] Erreur suppression fichiers (ignorée) : $e');
        }
      }
      
      // Supprimer de la DB
      await supabase.from('media_content').delete().eq('id', item.id);
      
    } catch (e) {
      debugPrint('[MediaService] deleteMedia error: $e');
      throw Exception('Échec de la suppression : $e');
    }
  }
}
