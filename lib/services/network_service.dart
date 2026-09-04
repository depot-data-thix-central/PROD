// lib/services/network_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/network_post.dart';
import '../models/network_connection.dart';
import '../models/network_community.dart';
import '../models/network_message.dart';
import '../models/network_notification.dart';
import '../models/network_story.dart';
import '../models/comment.dart';

// ============================================================================
// VALIDATIONS CENTRALISÉES (Anti-XSS + Sécurité)
// ============================================================================
class _NetworkValidators {
  _NetworkValidators._();

  static String sanitizeText(String? input, {int maxLength = 5000}) {
    if (input == null || input.trim().isEmpty) return '';

    final document = html_parser.parse(input);
    var sanitized = document.body?.text ?? input;

    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();

    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '';
    }

    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool validateFileSize(int bytes, {int maxSizeMB = 50}) {
    return bytes <= maxSizeMB * 1024 * 1024;
  }

  static bool validateFileExtension(String filename, Set<String> allowed) {
    final ext = filename.split('.').last.toLowerCase();
    return allowed.contains(ext);
  }
}

// ============================================================================
// CACHE LRU POUR PROFILS
// ============================================================================
class _ProfileCache {
  _ProfileCache._();
  static final _ProfileCache _instance = _ProfileCache._();
  factory _ProfileCache() => _instance;

  static const int _maxCacheSize = 100;
  static const Duration _cacheTTL = Duration(minutes: 5);

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  Map<String, dynamic>? get(String key) {
    if (!_cache.containsKey(key)) return null;

    final entry = _cache[key]!;
    if (DateTime.now().difference(entry.timestamp) > _cacheTTL) {
      _cache.remove(key);
      return null;
    }

    _cache.remove(key);
    _cache[key] = entry;
    return entry.value;
  }

  void set(String key, Map<String, dynamic> value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(value);
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}

class _CacheEntry {
  final Map<String, dynamic> value;
  final DateTime timestamp;

  _CacheEntry(this.value) : timestamp = DateTime.now();
}

// ============================================================================
// NETWORK SERVICE (Production Enterprise)
// ============================================================================
class NetworkService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final _ProfileCache _profileCache = _ProfileCache();

  NetworkService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';
  String? get _uid => _supabase.auth.currentUser?.id;

  // Constantes de validation
  static const int _maxImageSizeMB = 10;
  static const int _maxVideoSizeMB = 500;
  static const int _maxAudioSizeMB = 50;
  static const Set<String> _allowedImageExts = {'.jpg', '.jpeg', '.png', '.webp', 'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> _allowedVideoExts = {'.mp4', '.mov', '.avi', '.mkv', 'mp4', 'mov', 'avi', 'mkv'};
  static const Set<String> _allowedAudioExts = {'.m4a', '.mp3', '.wav', 'm4a', 'mp3', 'wav'};
  static const Duration _requestTimeout = Duration(seconds: 15);
  

  // ════════════════════════════════════════════════════════════════════
// FEED (avec retry, fallback, validation)
// ════════════════════════════════════════════════════════════════════

String _normalizeFeedType(String feedType) {
  final t = feedType.trim().toLowerCase();
  if (t == 'pour vous' || t == 'pourvous' || t == 'smart') return 'all';
  if (t == 'réseau' || t == 'reseau') return 'network';
  if (t == 'tendance' || t == 'trending') return 'popular';
  return t;
}

/// Valide et normalise le seed pour le smart feed
int _validateSeed(int seed) {
  if (seed < 0) return 0;
  if (seed > 2147483647) return 2147483647; // Max int32
  return seed;
}

Future<List<NetworkPost>> getFeedPosts({
  int limit = 20,
  int? offset,
  DateTime? lastCreatedAt,
  String feedType = 'all',
  int seed = 0,
}) async {
  final uid = currentUserId;
  if (uid.isEmpty) {
    _NetworkServiceLogger.warn('getFeedPosts: user not authenticated');
    return [];
  }

  // ── Validation des inputs ──
  limit = limit.clamp(1, 100);
  final safeOffset = (offset ?? 0) < 0 ? 0 : (offset ?? 0);
  final type = _normalizeFeedType(feedType);
  final safeSeed = _validateSeed(seed);

  try {
    if (type == 'all') {
      return await _fetchSmartFeed(
        uid: uid,
        limit: limit,
        offset: safeOffset,
        seed: safeSeed,
      );
    }

    // ── Abonnements ──
    if (type == 'network') {
      return await _fetchNetworkFeed(uid: uid, limit: limit, offset: safeOffset);
    }

    // ── Tendances ──
    if (type == 'popular') {
      return await _fetchPopularFeed(limit: limit, offset: safeOffset);
    }

    // ── Récents ──
    return await _fetchRecentFeed(limit: limit, offset: safeOffset);
  } on TimeoutException {
    _NetworkServiceLogger.error('getFeedPosts timeout',
        {'type': type, 'offset': safeOffset});
    return [];
  } catch (e, stack) {
    _NetworkServiceLogger.error('getFeedPosts failed',
        {'type': type, 'error': '$e', 'stack': stack.toString()});
    return [];
  }
}

/// ✅ SMART FEED avec retry + fallback
Future<List<NetworkPost>> _fetchSmartFeed({
  required String uid,
  required int limit,
  required int offset,
  required int seed,
}) async {
  const maxRetries = 2;
  Object? lastError;

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      if (attempt > 0) {
        final delay = Duration(milliseconds: 500 * attempt);
        _NetworkServiceLogger.info('Smart feed retry',
            {'attempt': attempt, 'delay': '$delay'});
        await Future.delayed(delay);
      }

      final res = await _supabase
          .rpc('get_smart_feed', params: {
            'p_user_id': uid,
            'p_limit': limit,
            'p_offset': offset,
            'p_seed': seed,
          })
          .timeout(_requestTimeout);

      // Validation du résultat
      if (res == null) {
        throw Exception('RPC returned null');
      }
      if (res is! List) {
        throw Exception('RPC returned invalid type: ${res.runtimeType}');
      }

      final posts = _parsePostsSafely(res);
      _NetworkServiceLogger.info('Smart feed loaded',
          {'count': posts.length, 'attempt': attempt, 'seed': seed});

      return posts;
    } catch (e) {
      lastError = e;
      _NetworkServiceLogger.warn('Smart feed attempt failed',
          {'attempt': attempt, 'error': '$e'});

      // Pas de retry sur erreurs client (4xx)
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403')) {
        break;
      }
    }
  }

  // ✅ FALLBACK : si smart feed échoue, retourner feed récent
  _NetworkServiceLogger.warn('Smart feed failed, falling back to recent',
      {'error': '$lastError'});
  return await _fetchRecentFeed(limit: limit, offset: offset);
}

/// Parse les posts avec validation stricte
List<NetworkPost> _parsePostsSafely(List<dynamic> data) {
  final posts = <NetworkPost>[];
  int invalidCount = 0;

  for (final item in data) {
    try {
      if (item is! Map) {
        invalidCount++;
        continue;
      }
      final map = Map<String, dynamic>.from(item);

      // Validation minimale
      if (map['id'] == null || map['user_id'] == null) {
        invalidCount++;
        continue;
      }

      posts.add(NetworkPost.fromJson(map));
    } catch (e) {
      invalidCount++;
      _NetworkServiceLogger.warn('Invalid post skipped', {'error': '$e'});
    }
  }

  if (invalidCount > 0) {
    _NetworkServiceLogger.warn('Invalid posts filtered',
        {'invalid': invalidCount, 'valid': posts.length});
  }

  return posts;
}

/// ✅ FALLBACK : Feed récent (chronologique)
Future<List<NetworkPost>> _fetchRecentFeed({
  required int limit,
  required int offset,
}) async {
  try {
    final res = await _supabase
        .from('posts_view')
        .select()
        .eq('is_public', true)
        .isFilter('community_id', null)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1)
        .timeout(_requestTimeout);

    return _parsePostsSafely(res as List);
  } catch (e) {
    _NetworkServiceLogger.error('Recent feed fallback failed', {'error': '$e'});
    return [];
  }
}

/// Feed abonnements
Future<List<NetworkPost>> _fetchNetworkFeed({
  required String uid,
  required int limit,
  required int offset,
}) async {
  final connIds = await getMyConnectionIds();
  connIds.add(uid);
  if (connIds.isEmpty) return [];

  final res = await _supabase
      .from('posts_view')
      .select()
      .inFilter('user_id', connIds.toList())
      .isFilter('community_id', null)
      .order('created_at', ascending: false)
      .range(offset, offset + limit - 1)
      .timeout(_requestTimeout);

  return _parsePostsSafely(res as List);
}

/// Feed populaire
Future<List<NetworkPost>> _fetchPopularFeed({
  required int limit,
  required int offset,
}) async {
  final res = await _supabase
      .from('posts_view')
      .select()
      .eq('is_public', true)
      .isFilter('community_id', null)
      .order('likes_count', ascending: false)
      .range(offset, offset + limit - 1)
      .timeout(_requestTimeout);

  return _parsePostsSafely(res as List);
}

  // ─────────────────────────────────────────────────────────────
  // COMMUNITIES
  // ─────────────────────────────────────────────────────────────

  Future<NetworkCommunity> createCommunity({
    required String name,
    String? description,
    String? bannerUrl,
    String? logoUrl,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Non authentifié');

    final sanitizedName = _NetworkValidators.sanitizeText(name, maxLength: 200);
    if (sanitizedName.isEmpty) throw Exception('Nom de communauté requis');

    try {
      final existing = await _supabase
          .from('communities')
          .select('id')
          .ilike('name', sanitizedName)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (existing != null) {
        throw Exception('Une communauté avec ce nom existe déjà.');
      }

      final sanitizedDesc = description != null
          ? _NetworkValidators.sanitizeText(description, maxLength: 2000)
          : null;

      final res = await _supabase.from('communities').insert({
        'name': sanitizedName,
        'description': sanitizedDesc,
        'logo_url': _NetworkValidators.sanitizeUrl(logoUrl ?? bannerUrl),
        'banner_url': _NetworkValidators.sanitizeUrl(bannerUrl),
        'created_by': uid,
        'privacy': 'public',
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'members_count': 1,
        'posts_count': 0,
      }).select().single().timeout(_requestTimeout);

      final communityId = res['id'];

      await _supabase.from('community_members').upsert({
        'community_id': communityId,
        'user_id': uid,
        'role': 'owner',
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'community_id,user_id');

      notifyListeners();
      return NetworkCommunity.fromJson(res);
    } catch (e) {
      debugPrint('[NetworkService] Create community error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // POSTS CRUD
  // ─────────────────────────────────────────────────────────────

  Future<NetworkPost?> getPostById(String postId) async {
    try {
      final response = await _supabase
          .from('posts_view')
          .select()
          .eq('id', postId)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (response == null) return null;
      return NetworkPost.fromJson(response);
    } catch (e) {
      debugPrint('[NetworkService] Erreur getPostById: $e');
      return null;
    }
  }

  Future<String> createPost(String content, List<String> images, {String postType = 'standard'}) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    final sanitizedContent = _NetworkValidators.sanitizeText(content);
    if (sanitizedContent.isEmpty) throw Exception('Contenu invalide');

    final sanitizedImages = images
        .map((url) => _NetworkValidators.sanitizeUrl(url))
        .where((url) => url.isNotEmpty)
        .toList();

    final res = await _supabase.from('posts').insert({
      'user_id': currentUserId,
      'content': sanitizedContent,
      'image_urls': sanitizedImages,
      'media_urls': sanitizedImages,
      'media_url': sanitizedImages.isNotEmpty ? sanitizedImages.first : null,
      'post_type': postType,
      'is_public': true,
    }).select('id').single().timeout(_requestTimeout);

    notifyListeners();
    return res['id'] as String;
  }

  Future<String> createCommunityPost({
    required String communityId,
    required String content,
    List<String> images = const [],
  }) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    final sanitizedContent = _NetworkValidators.sanitizeText(content);
    if (sanitizedContent.isEmpty) throw Exception('Contenu invalide');

    final sanitizedImages = images
        .map((url) => _NetworkValidators.sanitizeUrl(url))
        .where((url) => url.isNotEmpty)
        .toList();

    final res = await _supabase.from('posts').insert({
      'user_id': currentUserId,
      'community_id': communityId,
      'content': sanitizedContent,
      'image_urls': sanitizedImages,
      'media_urls': sanitizedImages,
      'media_url': sanitizedImages.isNotEmpty ? sanitizedImages.first : null,
      'is_public': true,
    }).select('id').single().timeout(_requestTimeout);

    notifyListeners();
    return res['id'] as String;
  }

  Future<void> updatePost(String id, String content) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    await _verifyPostOwnership(id);

    final sanitizedContent = _NetworkValidators.sanitizeText(content);
    if (sanitizedContent.isEmpty) throw Exception('Contenu invalide');

    await _supabase.from('posts').update({
      'content': sanitizedContent,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).timeout(_requestTimeout);

    notifyListeners();
  }

  Future<void> deletePost(String id) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    await _verifyPostOwnership(id);

    await _supabase.from('posts').delete().eq('id', id).timeout(_requestTimeout);
    notifyListeners();
  }

  Future<void> _verifyPostOwnership(String postId) async {
    try {
      final post = await _supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (post == null) throw Exception('Post introuvable');

      final ownerId = post['user_id']?.toString() ?? '';
      if (ownerId != currentUserId) {
        throw Exception('Permission refusée : vous n\'êtes pas le propriétaire');
      }
    } on TimeoutException {
      throw Exception('Timeout vérification ownership');
    }
  }

  Future<void> hidePost(String id) async {
    await _supabase.from('hidden_posts').upsert({
      'post_id': id,
      'user_id': currentUserId,
      'hidden_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'post_id,user_id').timeout(_requestTimeout);
    notifyListeners();
  }

  Future<void> reportPost(String postId, String reason) async {
    final sanitizedReason = _NetworkValidators.sanitizeText(reason, maxLength: 500);
    await _supabase.from('reported_posts').insert({
      'post_id': postId,
      'user_id': currentUserId,
      'reason': sanitizedReason,
      'reported_at': DateTime.now().toUtc().toIso8601String(),
    }).timeout(_requestTimeout);
  }

  Future<void> pinPost(String postId) async {
    await _verifyPostOwnership(postId);

    await _supabase
        .from('posts')
        .update({'is_pinned': false})
        .eq('user_id', currentUserId)
        .eq('is_pinned', true)
        .timeout(_requestTimeout);
    await _supabase.from('posts').update({'is_pinned': true}).eq('id', postId).timeout(_requestTimeout);
    notifyListeners();
  }

  Future<void> unpinPost(String postId) async {
    await _verifyPostOwnership(postId);
    await _supabase.from('posts').update({'is_pinned': false}).eq('id', postId).timeout(_requestTimeout);
    notifyListeners();
  }

  Future<NetworkPost?> getPinnedPost(String userId) async {
    try {
      final res = await _supabase
          .from('posts_view')
          .select()
          .eq('user_id', userId)
          .eq('is_pinned', true)
          .maybeSingle()
          .timeout(_requestTimeout);
      return res == null ? null : NetworkPost.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[PostService] Error getPinnedPost: $e');
      return null;
    }
  }

  Future<List<NetworkPost>> getPinnedPosts(String userId) async {
    try {
      final res = await _supabase
          .from('posts_view')
          .select()
          .eq('user_id', userId)
          .eq('is_pinned', true)
          .order('created_at', ascending: false)
          .timeout(_requestTimeout);
      return (res as List)
          .map((e) => NetworkPost.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[PostService] Error getPinnedPosts: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LIKE / SHARE / REPOST
  // ─────────────────────────────────────────────────────────────

  Future<({bool liked, int likesCount})> togglePostLike(String postId) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    try {
      final res = await _supabase.rpc(
        'rpc_toggle_post_like',
        params: {'p_post_id': postId},
      ).timeout(_requestTimeout);

      Map<String, dynamic> row;
      if (res is List && res.isNotEmpty) {
        row = Map<String, dynamic>.from(res.first as Map);
      } else if (res is Map) {
        row = Map<String, dynamic>.from(res);
      } else {
        throw Exception('Réponse RPC invalide');
      }

      final liked = row['liked'] == true;
      final count = (row['likes_count'] as num?)?.toInt() ?? 0;

      if (liked) {
        final owner = await _getPostOwnerId(postId);
        if (owner.isNotEmpty && owner != currentUserId) {
          unawaited(_createNotification(userId: owner, type: 'like', postId: postId));
        }
      }

      notifyListeners();
      return (liked: liked, likesCount: count);
    } on TimeoutException {
      debugPrint('[PostService] Timeout togglePostLike');
      rethrow;
    } catch (e) {
      debugPrint('[PostService] Fallback togglePostLike: $e');
      final existing = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (existing != null) {
        await unlikePost(postId);
        final c = await _countLikes(postId);
        return (liked: false, likesCount: c);
      } else {
        await likePost(postId);
        final c = await _countLikes(postId);
        return (liked: true, likesCount: c);
      }
    }
  }

  Future<int> _countLikes(String postId) async {
    try {
      final res = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .timeout(_requestTimeout);
      return (res as List).length;
    } catch (e) {
      debugPrint('[PostService] Error _countLikes: $e');
      return 0;
    }
  }

  Future<void> likePost(String id) async {
    if (currentUserId.isEmpty) return;
    try {
      await _supabase.from('post_likes').upsert(
        {'post_id': id, 'user_id': currentUserId},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      ).timeout(_requestTimeout);

      final owner = await _getPostOwnerId(id);
      if (owner.isNotEmpty && owner != currentUserId) {
        unawaited(_createNotification(userId: owner, type: 'like', postId: id));
      }
    } on TimeoutException {
      debugPrint('[PostService] Timeout likePost');
      rethrow;
    } catch (e) {
      debugPrint('[PostService] Error likePost: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> unlikePost(String id) async {
    if (currentUserId.isEmpty) return;
    try {
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', id)
          .eq('user_id', currentUserId)
          .timeout(_requestTimeout);
    } on TimeoutException {
      debugPrint('[PostService] Timeout unlikePost');
      rethrow;
    } catch (e) {
      debugPrint('[PostService] Error unlikePost: $e');
      rethrow;
// ─────────────────────────────────────────────────────────────
  // LIKE / SHARE / REPOST (Production Enterprise)
  // ─────────────────────────────────────────────────────────────

  // ══════════════════════════════════════════════════════════════
  // LIKE (avec protection race condition)
  // ══════════════════════════════════════════════════════════════

  /// Cache des opérations like en cours pour éviter les double-like
  final Set<String> _pendingLikes = {};

  Future<({bool liked, int likesCount})> togglePostLike(String postId) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');
    if (postId.trim().isEmpty) throw Exception('PostId invalide');

    // Protection contre les appels concurrents
    if (_pendingLikes.contains(postId)) {
      _NetworkServiceLogger.warn('Like already pending', {'postId': postId});
      throw Exception('Opération déjà en cours');
    }

    _pendingLikes.add(postId);

    try {
      final res = await _supabase
          .rpc(
            'rpc_toggle_post_like',
            params: {'p_post_id': postId},
          )
          .timeout(_requestTimeout);

      Map<String, dynamic> row;
      if (res is List && res.isNotEmpty) {
        row = Map<String, dynamic>.from(res.first as Map);
      } else if (res is Map) {
        row = Map<String, dynamic>.from(res);
      } else {
        throw Exception('Réponse RPC invalide');
      }

      final liked = row['liked'] == true;
      final count = (row['likes_count'] as num?)?.toInt() ?? 0;

      if (liked) {
        final owner = await _getPostOwnerId(postId);
        if (owner.isNotEmpty && owner != currentUserId) {
          unawaited(_createNotification(userId: owner, type: 'like', postId: postId));
        }
      }

      notifyListeners();
      _NetworkServiceLogger.info('Like toggled',
          {'postId': postId, 'liked': liked, 'count': count});

      return (liked: liked, likesCount: count);
    } on TimeoutException {
      _NetworkServiceLogger.error('Like timeout', {'postId': postId});
      rethrow;
    } catch (e) {
      _NetworkServiceLogger.warn('Like RPC failed, using fallback',
          {'postId': postId, 'error': '$e'});

      // Fallback manuel : vérifier état actuel puis basculer
      try {
        final existing = await _supabase
            .from('post_likes')
            .select('post_id')
            .eq('post_id', postId)
            .eq('user_id', currentUserId)
            .maybeSingle();

        if (existing != null) {
          await unlikePost(postId);
          final c = await _countLikes(postId);
          return (liked: false, likesCount: c);
        } else {
          await likePost(postId);
          final c = await _countLikes(postId);
          return (liked: true, likesCount: c);
        }
      } catch (fallbackError) {
        _NetworkServiceLogger.error('Like fallback failed',
            {'postId': postId, 'error': '$fallbackError'});
        rethrow;
      }
    } finally {
      _pendingLikes.remove(postId);
    }
  }

  Future<int> _countLikes(String postId) async {
    try {
      final res = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .timeout(_requestTimeout);
      return (res as List).length;
    } catch (e) {
      _NetworkServiceLogger.error('_countLikes failed',
          {'postId': postId, 'error': '$e'});
      return 0;
    }
  }

  Future<void> likePost(String id) async {
    if (currentUserId.isEmpty) return;
    if (id.trim().isEmpty) {
      _NetworkServiceLogger.warn('likePost: empty id');
      return;
    }
    try {
      await _supabase.from('post_likes').upsert(
        {'post_id': id, 'user_id': currentUserId},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      ).timeout(_requestTimeout);

      final owner = await _getPostOwnerId(id);
      if (owner.isNotEmpty && owner != currentUserId) {
        unawaited(_createNotification(userId: owner, type: 'like', postId: id));
      }

      notifyListeners();
      _NetworkServiceLogger.info('Post liked', {'postId': id});
    } on TimeoutException {
      _NetworkServiceLogger.error('likePost timeout', {'postId': id});
      rethrow;
    } catch (e) {
      _NetworkServiceLogger.error('likePost failed',
          {'postId': id, 'error': '$e'});
      rethrow;
    }
  }

  Future<void> unlikePost(String id) async {
    if (currentUserId.isEmpty) return;
    if (id.trim().isEmpty) {
      _NetworkServiceLogger.warn('unlikePost: empty id');
      return;
    }
    try {
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', id)
          .eq('user_id', currentUserId)
          .timeout(_requestTimeout);

      notifyListeners();
      _NetworkServiceLogger.info('Post unliked', {'postId': id});
    } on TimeoutException {
      _NetworkServiceLogger.error('unlikePost timeout', {'postId': id});
      rethrow;
    } catch (e) {
      _NetworkServiceLogger.error('unlikePost failed',
          {'postId': id, 'error': '$e'});
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SHARE (avec retry et validation)
  // ══════════════════════════════════════════════════════════════

  Future<void> sharePost(String id) async {
    if (id.trim().isEmpty) {
      _NetworkServiceLogger.warn('sharePost: empty id');
      return;
    }

    // Tentative 1 : RPC increment_share
    try {
      await _supabase
          .rpc('increment_share', params: {'p_post_id': id})
          .timeout(_requestTimeout);
      _NetworkServiceLogger.info('Share incremented', {'postId': id});
      return;
    } catch (e) {
      _NetworkServiceLogger.warn('increment_share failed, trying fallback',
          {'postId': id, 'error': '$e'});
    }

    // Tentative 2 : RPC rpc_increment_share (nom alternatif)
    try {
      await _supabase
          .rpc('rpc_increment_share', params: {'p_post_id': id})
          .timeout(_requestTimeout);
      _NetworkServiceLogger.info('Share incremented (fallback)',
          {'postId': id});
      return;
    } catch (e2) {
      _NetworkServiceLogger.error('sharePost failed (all attempts)',
          {'postId': id, 'error': '$e2'});
      // Ne pas rethrow : le partage n'est pas critique, silencieux
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SAVE / UNSAVE (avec validation)
  // ══════════════════════════════════════════════════════════════

  Future<void> savePost(String postId) async {
    if (currentUserId.isEmpty) {
      throw Exception('Non authentifié');
    }
    if (postId.trim().isEmpty) {
      throw Exception('PostId invalide');
    }

    try {
      await _supabase.from('saved_posts').upsert({
        'post_id': postId,
        'user_id': currentUserId,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'post_id,user_id').timeout(_requestTimeout);

      notifyListeners();
      _NetworkServiceLogger.info('Post saved', {'postId': postId});
    } on TimeoutException {
      _NetworkServiceLogger.error('savePost timeout', {'postId': postId});
      rethrow;
    } catch (e) {
      _NetworkServiceLogger.error('savePost failed',
          {'postId': postId, 'error': '$e'});
      rethrow;
    }
  }

  Future<void> unsavePost(String postId) async {
    if (currentUserId.isEmpty) {
      throw Exception('Non authentifié');
    }
    if (postId.trim().isEmpty) {
      throw Exception('PostId invalide');
    }

    try {
      await _supabase
          .from('saved_posts')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUserId)
          .timeout(_requestTimeout);

      notifyListeners();
      _NetworkServiceLogger.info('Post unsaved', {'postId': postId});
    } on TimeoutException {
      _NetworkServiceLogger.error('unsavePost timeout', {'postId': postId});
      rethrow;
    } catch (e) {
      _NetworkServiceLogger.error('unsavePost failed',
          {'postId': postId, 'error': '$e'});
      rethrow;
    }
  }

  Future<List<NetworkPost>> getSavedPosts() async {
    if (currentUserId.isEmpty) {
      _NetworkServiceLogger.warn('getSavedPosts: user not authenticated');
      return [];
    }

    try {
      final res = await _supabase
          .from('saved_posts')
          .select('post:post_id(*, profiles:user_id(display_name, avatar_url, profession))')
          .eq('user_id', currentUserId)
          .order('saved_at', ascending: false)
          .timeout(_requestTimeout);

      if (res == null || res is! List) {
        _NetworkServiceLogger.warn('getSavedPosts: invalid response type',
            {'type': res.runtimeType.toString()});
        return [];
      }

      final posts = <NetworkPost>[];
      int invalidCount = 0;

      for (final item in res) {
        try {
          if (item is! Map) {
            invalidCount++;
            continue;
          }
          final postMap = item['post'];
          if (postMap == null || postMap is! Map) {
            invalidCount++;
            continue;
          }
          posts.add(NetworkPost.fromJson(
              Map<String, dynamic>.from(postMap as Map)));
        } catch (e) {
          invalidCount++;
          _NetworkServiceLogger.warn('Invalid saved post skipped',
              {'error': '$e'});
        }
      }

      if (invalidCount > 0) {
        _NetworkServiceLogger.warn('Saved posts: invalid items filtered',
            {'invalid': invalidCount, 'valid': posts.length});
      }

      _NetworkServiceLogger.info('Saved posts loaded',
          {'count': posts.length});
      return posts;
    } on TimeoutException {
      _NetworkServiceLogger.error('getSavedPosts timeout');
      return [];
    } catch (e) {
      _NetworkServiceLogger.error('getSavedPosts failed', {'error': '$e'});
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════
  // REPOST (avec retry + fallback manuel)
  // ══════════════════════════════════════════════════════════════

  Future<NetworkPost?> repostPost(String originalPostId, {String? quote}) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');
    if (originalPostId.trim().isEmpty) throw Exception('PostId invalide');

    final sanitizedQuote = quote != null
        ? _NetworkValidators.sanitizeText(quote, maxLength: 1000)
        : null;

    // Tentative 1 : RPC centralisé (préféré car atomique + notifications)
    try {
      final res = await _supabase.rpc(
        'rpc_repost',
        params: {
          'p_original_post_id': originalPostId,
          'p_quote': sanitizedQuote,
        },
      ).timeout(_requestTimeout);

      Map<String, dynamic> row;
      if (res is List && res.isNotEmpty) {
        row = Map<String, dynamic>.from(res.first as Map);
      } else if (res is Map) {
        row = Map<String, dynamic>.from(res);
      } else {
        throw Exception('Réponse RPC invalide: ${res.runtimeType}');
      }

      notifyListeners();

      final feedPostId = row['feed_post_id']?.toString();
      if (feedPostId == null || feedPostId.isEmpty) {
        _NetworkServiceLogger.warn('Repost RPC returned no feed_post_id',
            {'originalPostId': originalPostId});
        return null;
      }

      final repost = await getPostById(feedPostId);
      _NetworkServiceLogger.info('Repost created (RPC)',
          {'originalId': originalPostId, 'repostId': feedPostId});
      return repost;
    } catch (e) {
      _NetworkServiceLogger.warn('Repost RPC failed, using fallback',
          {'originalPostId': originalPostId, 'error': '$e'});
    }

    // Tentative 2 : Insertion manuelle dans la table reposts
    try {
      await _supabase.from('reposts').insert({
        'original_post_id': originalPostId,
        'user_id': currentUserId,
        'quote': sanitizedQuote,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_requestTimeout);

      notifyListeners();
      _NetworkServiceLogger.info('Repost created (fallback)',
          {'originalId': originalPostId});
      return null; // Pas de post complet disponible via fallback
    } on TimeoutException {
      _NetworkServiceLogger.error('Repost fallback timeout',
          {'originalPostId': originalPostId});
      rethrow;
    } catch (e2) {
      _NetworkServiceLogger.error('Repost failed (all attempts)',
          {'originalPostId': originalPostId, 'error': '$e2'});
      rethrow;
    }
  }

  /// Alias pour compatibilité ascendante
  Future<void> repost(String originalPostId, String? quote) async {
    await repostPost(originalPostId, quote: quote);
  }

  Future<List<NetworkPost>> getUserReposts(String userId) async {
    if (userId.trim().isEmpty) {
      _NetworkServiceLogger.warn('getUserReposts: empty userId');
      return [];
    }

    try {
      final res = await _supabase
          .from('reposts')
          .select('post:original_post_id(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(_requestTimeout);

      if (res == null || res is! List) {
        _NetworkServiceLogger.warn('getUserReposts: invalid response type',
            {'type': res.runtimeType.toString()});
        return [];
      }

      final posts = <NetworkPost>[];
      int invalidCount = 0;

      for (final item in res) {
        try {
          if (item is! Map) {
            invalidCount++;
            continue;
          }
          final postMap = item['post'];
          if (postMap == null || postMap is! Map) {
            invalidCount++;
            continue;
          }
          posts.add(NetworkPost.fromJson(
              Map<String, dynamic>.from(postMap as Map)));
        } catch (e) {
          invalidCount++;
          _NetworkServiceLogger.warn('Invalid repost skipped',
              {'error': '$e'});
        }
      }

      if (invalidCount > 0) {
        _NetworkServiceLogger.warn('User reposts: invalid items filtered',
            {'userId': userId, 'invalid': invalidCount, 'valid': posts.length});
      }

      _NetworkServiceLogger.info('User reposts loaded',
          {'userId': userId, 'count': posts.length});
      return posts;
    } on TimeoutException {
      _NetworkServiceLogger.error('getUserReposts timeout',
          {'userId': userId});
      return [];
    } catch (e) {
      _NetworkServiceLogger.error('getUserReposts failed',
          {'userId': userId, 'error': '$e'});
      return [];
    }
  }
  // ─────────────────────────────────────────────────────────────
  // COMMENTS
  // ─────────────────────────────────────────────────────────────

  Future<List<Comment>> getCommentsWithReplies(String postId) async {
    try {
      final res = await _supabase
          .from('comments')
          .select('*, profiles!user_id(display_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .timeout(_requestTimeout);

      final map = <String, Comment>{
        for (final j in res as List) '${j['id']}': Comment.fromJson(j),
      };

      final roots = <Comment>[];
      for (final c in map.values) {
        if (c.parentId == null || c.parentId!.isEmpty || !map.containsKey(c.parentId)) {
          roots.add(c);
        } else {
          map[c.parentId]?.replies.add(c);
        }
      }
      return roots;
    } catch (e) {
      debugPrint('[CommentService] Error getCommentsWithReplies: $e');
      return [];
    }
  }

  Future<Comment> addComment(
    String postId,
    String content, {
    String? parentId,
    String? audioUrl,
    String? imageUrl,
  }) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    final sanitizedContent = _NetworkValidators.sanitizeText(content);
    if (sanitizedContent.isEmpty) throw Exception('Contenu invalide');

    final res = await _supabase
        .from('comments')
        .insert({
          'post_id': postId,
          'user_id': currentUserId,
          'content': sanitizedContent,
          'parent_id': parentId,
          'audio_url': _NetworkValidators.sanitizeUrl(audioUrl),
          'image_url': _NetworkValidators.sanitizeUrl(imageUrl),
        })
        .select('*, profiles!user_id(display_name, avatar_url)')
        .single()
        .timeout(_requestTimeout);

    notifyListeners();
    return Comment.fromJson(res);
  }

  Future<bool> addCommentToPost(String postId, String comment) async {
    try {
      await addComment(postId, comment);
      return true;
    } catch (e) {
      debugPrint('[CommentService] Error addCommentToPost: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final res = await _supabase
          .from('comments')
          .select('*, profiles!user_id(display_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .timeout(_requestTimeout);
      return (res as List)
          .map((e) => {
                'id': e['id'],
                'user_id': e['user_id'],
                'user_name': e['profiles']?['display_name'],
                'user_avatar': e['profiles']?['avatar_url'],
                'content': e['content'],
                'created_at': e['created_at'],
              })
          .toList();
    } catch (e) {
      debugPrint('[CommentService] Error getComments: $e');
      return [];
    }
  }

  Future<bool> updateComment(String commentId, String newContent) async {
    try {
      final comment = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', commentId)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (comment == null || comment['user_id'] != currentUserId) {
        throw Exception('Permission refusée');
      }

      final sanitizedContent = _NetworkValidators.sanitizeText(newContent);
      if (sanitizedContent.isEmpty) throw Exception('Contenu invalide');

      await _supabase.from('comments').update({
        'content': sanitizedContent,
        'is_edited': true,
      }).eq('id', commentId).timeout(_requestTimeout);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CommentService] Error updateComment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      final comment = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', commentId)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (comment == null || comment['user_id'] != currentUserId) {
        throw Exception('Permission refusée');
      }

      await _supabase.from('comments').delete().eq('id', commentId).timeout(_requestTimeout);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CommentService] Error deleteComment: $e');
      return false;
    }
  }

  /// ✅ AJOUT : Signaler un commentaire
  Future<void> reportComment(String commentId, String reason, String? details) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Non authentifié');

    final sanitizedReason = _NetworkValidators.sanitizeText(reason, maxLength: 100);
    if (sanitizedReason.isEmpty) throw Exception('Motif requis');

    final sanitizedDetails = details != null
        ? _NetworkValidators.sanitizeText(details, maxLength: 500)
        : null;

    try {
      await _supabase.from('comment_reports').insert({
        'comment_id': commentId,
        'reporter_id': uid,
        'reason': sanitizedReason,
        'details': sanitizedDetails,
        'status': 'pending',
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_requestTimeout);

      debugPrint('[CommentService] ✓ Reported comment $commentId');
    } catch (e) {
      debugPrint('[CommentService] Error reportComment: $e');
      rethrow;
    }
  }

  Future<bool> likeComment(String commentId) async {
    if (_uid == null) return false;
    try {
      await _supabase.from('comment_likes').upsert(
        {'comment_id': commentId, 'user_id': _uid},
        onConflict: 'comment_id,user_id',
        ignoreDuplicates: true,
      ).timeout(_requestTimeout);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CommentService] Error likeComment: $e');
      return false;
    }
  }

  Future<bool> unlikeComment(String commentId) async {
    try {
      await _supabase
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', _uid!)
          .timeout(_requestTimeout);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CommentService] Error unlikeComment: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // POLL / CHALLENGE
  // ─────────────────────────────────────────────────────────────

  Future<String> createPollPost({
    required String content,
    required List<String> options,
    List<String> images = const [],
  }) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    final sanitizedContent = _NetworkValidators.sanitizeText(content);
    if (sanitizedContent.isEmpty) throw Exception('Contenu invalide');

    final sanitizedOptions = options.map((opt) => _NetworkValidators.sanitizeText(opt, maxLength: 200)).where((opt) => opt.isNotEmpty).toList();
    if (sanitizedOptions.isEmpty) throw Exception('Options invalides');

    final formattedOptions = sanitizedOptions.map((opt) => {'text': opt, 'votes': <String>[]}).toList();
    final sanitizedImages = images.map((url) => _NetworkValidators.sanitizeUrl(url)).where((url) => url.isNotEmpty).toList();

    final res = await _supabase.from('posts').insert({
      'user_id': currentUserId,
      'content': sanitizedContent,
      'media_urls': sanitizedImages,
      'image_urls': sanitizedImages,
      'post_type': 'poll',
      'poll_data': {'options': formattedOptions},
      'is_public': true,
    }).select('id').single().timeout(_requestTimeout);

    notifyListeners();
    return res['id'] as String;
  }

  Future<String> createChallengePost({
    required String title,
    required String description,
    required DateTime endDate,
    List<String> images = const [],
  }) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    final sanitizedTitle = _NetworkValidators.sanitizeText(title, maxLength: 200);
    if (sanitizedTitle.isEmpty) throw Exception('Titre invalide');

    final sanitizedDesc = _NetworkValidators.sanitizeText(description, maxLength: 2000);
    if (sanitizedDesc.isEmpty) throw Exception('Description invalide');

    final sanitizedImages = images.map((url) => _NetworkValidators.sanitizeUrl(url)).where((url) => url.isNotEmpty).toList();

    final res = await _supabase.from('posts').insert({
      'user_id': currentUserId,
      'content': sanitizedTitle,
      'media_urls': sanitizedImages,
      'image_urls': sanitizedImages,
      'post_type': 'challenge',
      'challenge_data': {
        'description': sanitizedDesc,
        'end_date': endDate.toUtc().toIso8601String(),
        'participants_count': 0,
      },
      'is_public': true,
    }).select('id').single().timeout(_requestTimeout);

    notifyListeners();
    return res['id'] as String;
  }

  Future<void> votePoll(String postId, int optionIndex) async {
    try {
      final postRes = await _supabase.from('posts').select('poll_data').eq('id', postId).single().timeout(_requestTimeout);
      final pollData = postRes['poll_data'] as Map<String, dynamic>?;
      if (pollData == null) return;

      final options = List<Map<String, dynamic>>.from(pollData['options'] ?? []);
      for (final opt in options) {
        final votes = List<String>.from(opt['votes'] ?? []);
        votes.remove(currentUserId);
        opt['votes'] = votes;
      }
      if (optionIndex >= 0 && optionIndex < options.length) {
        final targetVotes = List<String>.from(options[optionIndex]['votes'] ?? []);
        if (!targetVotes.contains(currentUserId)) {
          targetVotes.add(currentUserId);
        }
        options[optionIndex]['votes'] = targetVotes;
      }
      await _supabase.from('posts').update({'poll_data': {'options': options}}).eq('id', postId).timeout(_requestTimeout);
      notifyListeners();
    } catch (e) {
      debugPrint('[PostService] Error votePoll: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STORIES
  // ─────────────────────────────────────────────────────────────

  Future<List<NetworkStory>> getActiveStories() async {
    try {
      final res = await _supabase
          .from('active_stories')
          .select('*')
          .order('created_at', ascending: false)
          .limit(30)
          .timeout(_requestTimeout);
      return (res as List).map((e) => NetworkStory.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[StoryService] Error getActiveStories: $e');
      return [];
    }
  }

  Future<void> createStory(
    String? mediaUrl, {
    String? text,
    String mediaType = 'image',
    int duration = 24,
    String? bgColor,
  }) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    await _supabase.from('stories').insert({
      'user_id': currentUserId,
      'media_url': mediaUrl,
      'image_url': mediaUrl,
      'text_content': text,
      'content': text,
      'text': text,
      'media_type': mediaType,
      'bg_color': bgColor,
      'is_active': true,
      'expires_at': DateTime.now().toUtc()
          .add(Duration(hours: duration.clamp(6, 48))).toIso8601String(),
    }).timeout(_requestTimeout);

    notifyListeners();
  }

  Future<void> deleteStory(String storyId) async {
    if (currentUserId.isEmpty) return;
    await _supabase.from('stories').delete().eq('id', storyId).eq('user_id', currentUserId).timeout(_requestTimeout);
    notifyListeners();
  }

  Future<void> markStoryAsViewed(String storyId) async {
    await _supabase.from('story_views').upsert(
      {'story_id': storyId, 'user_id': currentUserId},
      onConflict: 'story_id,user_id',
      ignoreDuplicates: true,
    ).timeout(_requestTimeout);
  }

  Future<List<Highlight>> getUserHighlights(String userId) async {
    try {
      final res = await _supabase
          .from('story_highlights')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(_requestTimeout);
      return (res as List)
          .map((e) => Highlight(
                id: e['id'],
                name: e['name'],
                coverImage: e['cover_image'],
                storyIds: List<String>.from(e['story_ids'] ?? []),
                createdAt: DateTime.parse(e['created_at']),
              ))
          .toList();
    } catch (e) {
      debugPrint('[StoryService] Error getUserHighlights: $e');
      return [];
    }
  }

  Future<void> createHighlight(String name, List<String> storyIds, String? coverImage) async {
    final sanitizedName = _NetworkValidators.sanitizeText(name, maxLength: 100);
    if (sanitizedName.isEmpty) throw Exception('Nom invalide');

    await _supabase.from('story_highlights').insert({
      'user_id': currentUserId,
      'name': sanitizedName,
      'cover_image': _NetworkValidators.sanitizeUrl(coverImage),
      'story_ids': storyIds,
    }).timeout(_requestTimeout);
  }

  // ─────────────────────────────────────────────────────────────
  // CONNECTIONS / FOLLOW
  // ─────────────────────────────────────────────────────────────

  Future<Set<String>> getMyConnectionIds() async {
    final uid = currentUserId;
    if (uid.isEmpty) return {};

    try {
      final res = await _supabase.from('follows').select('following_id').eq('follower_id', uid).timeout(_requestTimeout);
      return (res as List).map((e) => '${e['following_id']}').toSet();
    } catch (e) {
      debugPrint('[ConnectionService] Fallback getMyConnectionIds: $e');
      try {
        final res = await _supabase.from('connections').select('user1_id, user2_id').or('user1_id.eq.$uid,user2_id.eq.$uid').timeout(_requestTimeout);
        return (res as List).map((e) {
          final user1 = '${e['user1_id']}';
          final user2 = '${e['user2_id']}';
          return user1 == uid ? user2 : user1;
        }).toSet();
      } catch (e2) {
        debugPrint('[ConnectionService] Error getMyConnectionIds: $e2');
        return {};
      }
    }
  }

  Future<Set<String>> _getConnectionIds() => getMyConnectionIds();

  Future<List<NetworkConnection>> getMyConnections() async {
    final uid = currentUserId;
    if (uid.isEmpty) return [];

    try {
      final res = await _supabase
          .from('follows')
          .select('''
            created_at,
            following:profiles!follows_following_id_fkey(
              id, display_name, avatar_url, profession
            )
          ''')
          .eq('follower_id', uid)
          .order('created_at', ascending: false)
          .timeout(_requestTimeout);

      return (res as List).map((row) {
        final other = row['following'];
        return NetworkConnection(
          id: other?['id']?.toString() ?? '',
          name: other?['display_name']?.toString() ?? 'Utilisateur',
          avatar: other?['avatar_url']?.toString(),
          title: other?['profession']?.toString() ?? 'Membre THIX',
          mutualConnections: 0,
          status: 'accepted',
          connectedAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[ConnectionService] Fallback getMyConnections: $e');
      try {
        final ids = await getMyConnectionIds();
        if (ids.isEmpty) return [];

        final profiles = await _supabase.from('profiles').select('id, display_name, avatar_url, profession').inFilter('id', ids.toList()).timeout(_requestTimeout);

        return (profiles as List).map((p) {
          return NetworkConnection(
            id: p['id']?.toString() ?? '',
            name: p['display_name']?.toString() ?? 'Utilisateur',
            avatar: p['avatar_url']?.toString(),
            title: p['profession']?.toString() ?? 'Membre THIX',
            mutualConnections: 0,
            status: 'accepted',
          );
        }).toList();
      } catch (e2) {
        debugPrint('[ConnectionService] Error getMyConnections: $e2');
        return [];
      }
    }
  }

  Future<List<NetworkConnection>> getSuggestedConnections({int limit = 10}) async {
    try {
      final res = await _supabase
          .rpc('get_suggested_connections', params: {'p_user_id': currentUserId, 'p_limit': limit})
          .timeout(_requestTimeout);
      return (res as List)
          .map((e) => NetworkConnection(
                id: e['id'],
                name: e['display_name'] ?? 'Utilisateur',
                avatar: e['avatar_url'],
                title: e['profession'] ?? 'Membre',
                mutualConnections: (e['mutual_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (e) {
      debugPrint('[ConnectionService] Error getSuggestedConnections: $e');
      return [];
    }
  }

  Future<void> followUser(String targetId) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');
    if (targetId.isEmpty || targetId == currentUserId) throw Exception('Cible invalide');

    await _supabase.from('follows').upsert({
      'follower_id': currentUserId,
      'following_id': targetId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'follower_id,following_id').timeout(_requestTimeout);

    try {
      unawaited(_createNotification(userId: targetId, type: 'follow'));
    } catch (e) {
      debugPrint('[ConnectionService] Error notification follow: $e');
    }

    notifyListeners();
  }

  Future<void> unfollowUser(String targetId) async {
    if (currentUserId.isEmpty) return;

    try {
      await _supabase.from('follows').delete().eq('follower_id', currentUserId).eq('following_id', targetId).timeout(_requestTimeout);
      notifyListeners();
    } catch (e) {
      debugPrint('[ConnectionService] Fallback unfollowUser: $e');
      try {
        await _supabase.from('connections').delete().or('and(user1_id.eq.$currentUserId,user2_id.eq.$targetId),and(user1_id.eq.$targetId,user2_id.eq.$currentUserId)').timeout(_requestTimeout);
        notifyListeners();
      } catch (e2) {
        debugPrint('[ConnectionService] Error unfollowUser: $e2');
      }
    }
  }

  Future<bool> isFollowing(String targetId) async {
    if (currentUserId.isEmpty) return false;

    try {
      final res = await _supabase.from('follows').select('follower_id').eq('follower_id', currentUserId).eq('following_id', targetId).maybeSingle().timeout(_requestTimeout);
      return res != null;
    } catch (e) {
      debugPrint('[ConnectionService] Fallback isFollowing: $e');
      final ids = await getMyConnectionIds();
      return ids.contains(targetId);
    }
  }

  Future<void> sendConnectionRequest(String targetId) => followUser(targetId);

  Future<void> acceptConnectionRequest(String requestId) async {
    debugPrint('[ConnectionService] acceptConnectionRequest: plus nécessaire (follow direct)');
  }

  // ─────────────────────────────────────────────────────────────
  // COMMUNITIES LIST
  // ─────────────────────────────────────────────────────────────

  Future<List<NetworkCommunity>> getAllCommunities({
    int limit = 20,
    int offset = 0,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;

    try {
      final res = await _supabase
          .from('communities')
          .select('*')
          .eq('is_active', true)
          .order('members_count', ascending: false)
          .range(safeOffset, safeOffset + safeLimit - 1)
          .timeout(_requestTimeout);

      return (res as List).map((e) => NetworkCommunity.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[NetworkService] getAllCommunities error: $e');
      return [];
    }
  }

  Future<List<NetworkCommunity>> getSuggestedCommunities({int limit = 10}) async {
    try {
      final res = await _supabase.from('communities').select().order('members_count', ascending: false).limit(limit).timeout(_requestTimeout);
      return (res as List).map((e) => NetworkCommunity.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[CommunityService] Error getSuggestedCommunities: $e');
      return [];
    }
  }

  Future<List<NetworkCommunity>> getMyCommunities() async {
    try {
      final res = await _supabase.from('community_members').select('communities(*)').eq('user_id', currentUserId).timeout(_requestTimeout);
      return (res as List).map((e) => NetworkCommunity.fromJson({...e['communities'], 'is_member': true})).toList();
    } catch (e) {
      debugPrint('[CommunityService] Error getMyCommunities: $e');
      return [];
    }
  }

  Future<NetworkCommunity?> getCommunityById(String id) async {
    try {
      final res = await _supabase.from('communities').select().eq('id', id).maybeSingle().timeout(_requestTimeout);
      return res == null ? null : NetworkCommunity.fromJson(res);
    } catch (e) {
      debugPrint('[CommunityService] Error getCommunityById: $e');
      return null;
    }
  }

  Future<void> joinCommunity(String id) async {
    await _supabase.from('community_members').upsert({
      'community_id': id,
      'user_id': currentUserId,
      'role': 'member',
    }, onConflict: 'community_id,user_id', ignoreDuplicates: true).timeout(_requestTimeout);
  }

  Future<void> leaveCommunity(String id) async {
    await _supabase.from('community_members').delete().eq('community_id', id).eq('user_id', currentUserId).timeout(_requestTimeout);
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final sanitizedQuery = _NetworkValidators.sanitizeText(q, maxLength: 100);
    if (sanitizedQuery.isEmpty) return [];

    try {
      final r = await _supabase.from('profiles').select('id, display_name, avatar_url, profession').ilike('display_name', '%$sanitizedQuery%').limit(20).timeout(_requestTimeout);
      return List<Map<String, dynamic>>.from(r as List);
    } catch (e) {
      debugPrint('[SearchService] Error searchUsers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchPosts(String q) async {
    final sanitizedQuery = _NetworkValidators.sanitizeText(q, maxLength: 100);
    if (sanitizedQuery.isEmpty) return [];

    try {
      final r = await _supabase.from('posts_view').select('id, content, created_at, author_name, author_avatar').ilike('content', '%$sanitizedQuery%').limit(20).timeout(_requestTimeout);
      return List<Map<String, dynamic>>.from(r as List);
    } catch (e) {
      debugPrint('[SearchService] Error searchPosts: $e');
      return [];
    }
  }

  Future<List<NetworkCommunity>> searchCommunities(String q) async {
    final sanitizedQuery = _NetworkValidators.sanitizeText(q, maxLength: 100);
    if (sanitizedQuery.isEmpty) return [];

    try {
      final r = await _supabase.from('communities').select().ilike('name', '%$sanitizedQuery%').limit(20).timeout(_requestTimeout);
      return (r as List).map((e) => NetworkCommunity.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[SearchService] Error searchCommunities: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations() async {
    try {
      final uid = currentUserId;
      final res = await _supabase
          .from('messages')
          .select(
            'sender_id, receiver_id, content, created_at, is_read, sender:profiles!messages_sender_id_fkey(display_name, avatar_url), receiver:profiles!messages_receiver_id_fkey(display_name, avatar_url)',
          )
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(_requestTimeout);

      final map = <String, Conversation>{};
      for (final m in res as List) {
        final otherId = m['sender_id'] == uid ? m['receiver_id'] : m['sender_id'];
        if (!map.containsKey(otherId)) {
          final other = m['sender_id'] == uid ? m['receiver'] : m['sender'];
          map[otherId] = Conversation(
            id: otherId,
            otherUserId: otherId,
            otherUserName: other?['display_name'] ?? 'Utilisateur',
            otherUserAvatar: other?['avatar_url'],
            lastMessage: m['content'],
            lastMessageAt: DateTime.parse(m['created_at']),
            lastMessageIsFromMe: m['sender_id'] == uid,
            unreadCount: (m['is_read'] == false && m['receiver_id'] == uid) ? 1 : 0,
          );
        }
      }
      return map.values.toList();
    } catch (e) {
      debugPrint('[MessageService] Error getConversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String otherId) async {
    final uid = currentUserId;
    try {
      final res = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$uid,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$uid)')
          .order('created_at', ascending: true)
          .limit(100)
          .timeout(_requestTimeout);
      return (res as List)
          .map((e) => {
                'id': e['id'],
                'content': e['content'],
                'is_sent_by_me': e['sender_id'] == uid,
                'created_at': DateTime.parse(e['created_at']),
              })
          .toList();
    } catch (e) {
      debugPrint('[MessageService] Error getMessages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> sendMessage(String receiverId, String content) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    final sanitizedContent = _NetworkValidators.sanitizeText(content);
    if (sanitizedContent.isEmpty) throw Exception('Message vide');

    final res = await _supabase.from('messages').insert({
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'content': sanitizedContent,
      'is_read': false,
    }).select().single().timeout(_requestTimeout);

    return {
      'id': res['id'],
      'content': res['content'],
      'is_sent_by_me': true,
      'created_at': DateTime.parse(res['created_at']),
    };
  }

  Future<void> markMessagesAsRead(String otherId) async {
    await _supabase.from('messages').update({'is_read': true}).eq('receiver_id', currentUserId).eq('sender_id', otherId).timeout(_requestTimeout);
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────

  Future<List<NetworkNotification>> getNotifications() async {
    try {
      final res = await _supabase
          .from('notifications')
          .select('*, profiles!sender_id(display_name, avatar_url)')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(_requestTimeout);
      return (res as List).map((e) => NetworkNotification.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[NotificationService] Error getNotifications: $e');
      return [];
    }
  }

  Future<int> getUnreadNotificationsCount() async {
    try {
      final res = await _supabase.from('notifications').select('id').eq('user_id', currentUserId).eq('is_read', false).timeout(_requestTimeout);
      return (res as List).length;
    } catch (e) {
      debugPrint('[NotificationService] Error getUnreadNotificationsCount: $e');
      return 0;
    }
  }

  Future<int> getUnreadMessagesCount() async {
    try {
      final res = await _supabase.from('messages').select('id').eq('receiver_id', currentUserId).eq('is_read', false).timeout(_requestTimeout);
      return (res as List).length;
    } catch (e) {
      debugPrint('[MessageService] Error getUnreadMessagesCount: $e');
      return 0;
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    await _supabase.from('notifications').update({'is_read': true}).eq('user_id', currentUserId).eq('is_read', false).timeout(_requestTimeout);
  }

  /// ✅ AJOUT : Marque UNE notification spécifique comme lue
  /// (utilisé par notifications_page.dart au tap sur une notification)
  Future<void> markNotificationAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', uid)  // Sécurité : seul le propriétaire peut marquer comme lu
          .timeout(_requestTimeout);

      debugPrint('[NotificationService] ✓ Marked $notificationId as read');
    } on TimeoutException {
      debugPrint('[NotificationService] ⏱️ Timeout markNotificationAsRead');
      rethrow;
    } catch (e) {
      debugPrint('[NotificationService] ❌ Error markNotificationAsRead: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PROFILE / POSTS USER
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final cached = _profileCache.get(userId);
    if (cached != null) return cached;

    try {
      final res = await _supabase
          .from('profiles')
          .select(
            'id, display_name, avatar_url, cover_url, profession, bio, '
            'certification_tier, certification_status, is_verified',
          )
          .eq('id', userId)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (res == null) return null;

      final results = await Future.wait([
        _supabase.from('posts').count(CountOption.exact).eq('user_id', userId).timeout(_requestTimeout),
        _supabase.from('follows').count(CountOption.exact).eq('following_id', userId).timeout(_requestTimeout),
        _supabase.from('follows').count(CountOption.exact).eq('follower_id', userId).timeout(_requestTimeout),
      ]);

      final profile = {
        ...res,
        'posts_count': results[0],
        'followers_count': results[1],
        'following_count': results[2],
      };

      _profileCache.set(userId, profile);

      return profile;
    } catch (e) {
      debugPrint('[ProfileService] Error getUserProfile: $e');
      return null;
    }
  }

  Future<List<NetworkPost>> getUserPosts(String userId, {int offset = 0, int limit = 15}) async {
    try {
      final res = await _supabase
          .from('posts_view')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(_requestTimeout);
      return (res as List).map((e) => NetworkPost.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('[PostService] Error getUserPosts: $e');
      return [];
    }
  }

  Future<void> markEventInterest(String id) async {
    await _supabase.from('event_interests').upsert(
      {'event_id': id, 'user_id': currentUserId},
      onConflict: 'event_id,user_id',
      ignoreDuplicates: true,
    ).timeout(_requestTimeout);
  }

  Future<bool> hasEventInterest(String id) async {
    try {
      final r = await _supabase.from('event_interests').select('id').eq('event_id', id).eq('user_id', currentUserId).maybeSingle().timeout(_requestTimeout);
      return r != null;
    } catch (e) {
      debugPrint('[EventService] Error hasEventInterest: $e');
      return false;
    }
  }

  Future<Map<String, int>> getRecommendationsCount() async {
    return {'people': 5, 'opportunities': 0, 'communities': 5};
  }

  // ─────────────────────────────────────────────────────────────
  // UPLOAD
  // ─────────────────────────────────────────────────────────────

  Future<String?> uploadImageBytes(
    Uint8List bytes, {
    required String fileExtension,
    String bucket = 'post_images',
  }) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    if (!_NetworkValidators.validateFileSize(bytes.length, maxSizeMB: _maxImageSizeMB)) {
      throw Exception('Image trop volumineuse (max ${_maxImageSizeMB}MB)');
    }

    if (!_NetworkValidators.validateFileExtension(fileExtension, _allowedImageExts)) {
      throw Exception('Format image non supporté : $fileExtension');
    }

    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final path = '$currentUserId/$name';

      Uint8List finalBytes = bytes;

      if (!kIsWeb) {
        try {
          finalBytes = await _compressImageAsync(bytes, fileExtension);
        } catch (e) {
          debugPrint('[UploadService] Compression failed, using original: $e');
        }
      }

      final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(fileExtension.toLowerCase());
      final mimeType = isVideo ? 'video/$fileExtension' : 'image/$fileExtension';

      await _supabase.storage.from(bucket).uploadBinary(
        path,
        finalBytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      ).timeout(const Duration(seconds: 30));

      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('[UploadService] Error uploadImageBytes: $e');
      throw Exception(e.toString());
    }
  }

  Future<Uint8List> _compressImageAsync(Uint8List bytes, String ext) async {
    final compressFormat = ext.toLowerCase() == 'png' ? CompressFormat.png : CompressFormat.jpeg;

    if (!kIsWeb) {
      return await compute(_compressImageInIsolate, {'bytes': bytes, 'format': compressFormat});
    }

    return await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1080,
      minHeight: 1080,
      quality: 80,
      format: compressFormat,
    );
  }

  static Future<Uint8List> _compressImageInIsolate(Map<String, dynamic> params) async {
    final bytes = params['bytes'] as Uint8List;
    final format = params['format'] as CompressFormat;

    return await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1080,
      minHeight: 1080,
      quality: 80,
      format: format,
    );
  }

  Future<String?> uploadAudioBytes(Uint8List bytes, {String bucket = 'audio_uploads'}) async {
    if (currentUserId.isEmpty) throw Exception('Non authentifié');

    if (!_NetworkValidators.validateFileSize(bytes.length, maxSizeMB: _maxAudioSizeMB)) {
      throw Exception('Audio trop volumineux (max ${_maxAudioSizeMB}MB)');
    }

    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '$currentUserId/$name';

      await _supabase.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'audio/x-m4a', upsert: true),
      ).timeout(const Duration(seconds: 30));

      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('[UploadService] Error uploadAudioBytes: $e');
      throw Exception(e.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  Future<String> _getPostOwnerId(String postId) async {
    try {
      final r = await _supabase.from('posts').select('user_id').eq('id', postId).maybeSingle().timeout(_requestTimeout);
      return r?['user_id'] ?? '';
    } catch (e) {
      debugPrint('[PostService] Error _getPostOwnerId: $e');
      return '';
    }
  }

  Future<void> _createNotification({
    required String userId,
    required String type,
    String? postId,
  }) async {
    if (userId.isEmpty || userId == currentUserId) return;
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'sender_id': currentUserId,
        'post_id': postId,
        'is_read': false,
      }).timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[NotificationService] Error _createNotification: $e');
    }
  }
}

// ============================================================================
// MODÈLES LOCAUX
// ============================================================================

class Highlight {
  final String id, name;
  final String? coverImage;
  final List<String> storyIds;
  final DateTime createdAt;
  Highlight({
    required this.id,
    required this.name,
    this.coverImage,
    required this.storyIds,
    required this.createdAt,
  });
}

class Conversation {
  final String id, otherUserId, otherUserName, lastMessage;
  final String? otherUserAvatar;
  final DateTime lastMessageAt;
  final bool lastMessageIsFromMe;
  final int unreadCount;
  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsFromMe,
    required this.unreadCount,
  });
}
