// lib/presentation/thix_media/providers/user_profile_providers.dart
/// User Profile Providers (Production Enterprise)
///
/// - Performance : Cache mémoire (Max 50) + Limite anti-DoS (Max 200 posts)
/// - Sécurité : Sanitization agressive (Anti-XSS) + Timeouts stricts (15s)
/// - Robustesse : Logs structurés + gestion d'erreurs Riverpod

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

// ============================================================================
// CONSTANTS & LOGGING
// ============================================================================

const Duration _kQueryTimeout = Duration(seconds: 15);
const int _kLimit = 15;
const int _kMaxPosts = 200; // Limite anti-DoS mémoire
const int _kMaxCacheSize = 50;

class _ProviderLogger {
  static const _tag = 'UserProfileProviders';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// CACHE EN MÉMOIRE
// ============================================================================

class _ProfileCache {
  static final Map<String, Map<String, dynamic>> _profiles = {};
  static final Map<String, Map<String, int>> _stats = {};

  static Map<String, dynamic>? getProfile(String userId) => _profiles[userId];
  static Map<String, int>? getStats(String userId) => _stats[userId];

  static void setProfile(String userId, Map<String, dynamic> profile) {
    if (_profiles.length >= _kMaxCacheSize) {
      _profiles.remove(_profiles.keys.first);
    }
    _profiles[userId] = profile;
  }

  static void setStats(String userId, Map<String, int> stats) {
    if (_stats.length >= _kMaxCacheSize) {
      _stats.remove(_stats.keys.first);
    }
    _stats[userId] = stats;
  }

  static void invalidate(String userId) {
    _profiles.remove(userId);
    _stats.remove(userId);
  }
}

// ============================================================================
// HELPERS DE SANITIZATION
// ============================================================================

String _sanitize(String? input) {
  if (input == null || input.trim().isEmpty) return '';
  return input
      .replaceAll(RegExp(r'<[^>]*>'), '') // Supprime les balises HTML
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '') // Anti XSS
      .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '') // Supprime les events JS
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Supprime les caractères de contrôle invisibles
      .trim();
}

// ============================================================================
// BUNDLE DE DONNÉES
// ============================================================================

class UserProfileBundle {
  final Map<String, dynamic>? profile;
  final Map<String, int> stats;
  final bool isFollowing;
  final List<MediaContent> initialPosts;
  final String? error;

  const UserProfileBundle({
    this.profile,
    this.stats = const {'followers': 0, 'following': 0, 'posts': 0},
    this.isFollowing = false,
    this.initialPosts = const [],
    this.error,
  });

  bool get hasError => error != null;

  factory UserProfileBundle.error(String message) => UserProfileBundle(error: message);
}

// ============================================================================
// PROVIDER : DONNÉES DE PROFIL
// ============================================================================

final userProfileDataProvider = FutureProvider.autoDispose.family<UserProfileBundle, String>((ref, userId) async {
  if (userId.trim().isEmpty) {
    return UserProfileBundle.error('ID utilisateur invalide');
  }

  // ✅ Utilisation du cache si disponible
  final cachedProfile = _ProfileCache.getProfile(userId);
  final cachedStats = _ProfileCache.getStats(userId);
  if (cachedProfile != null && cachedStats != null) {
    _ProviderLogger.info('Loaded profile from cache', {'userId': userId});
    return UserProfileBundle(
      profile: cachedProfile,
      stats: cachedStats,
      isFollowing: false, // Le statut de follow n'est pas caché car très dynamique
      initialPosts: const [],
    );
  }

  _ProviderLogger.info('Fetching profile from network', {'userId': userId});

  try {
    final service = MediaService();
    // ✅ Timeout appliqué sur l'attente globale
    final results = await Future.wait([
      service.fetchProfile(userId),
      service.fetchUserStats(userId),
      service.isFollowing(userId),
    ]).timeout(_kQueryTimeout);

    final profile = results[0] as Map<String, dynamic>?;
    final stats = Map<String, int>.from(results[1] as Map);
    final isFollowing = results[2] as bool;

    if (profile == null) {
      _ProviderLogger.warn('Profile not found', {'userId': userId});
      return UserProfileBundle.error('Profil introuvable');
    }

    // ✅ Sanitization des champs textes exposés à l'UI
    final sanitizedProfile = {
      ...profile,
      'username': _sanitize(profile['username']?.toString()),
      'full_name': _sanitize(profile['full_name']?.toString()),
      'bio': _sanitize(profile['bio']?.toString()),
      'avatar_url': profile['avatar_url'], // L'URL est gérée par MediaSanitizer côté UI
    };

    _ProfileCache.setProfile(userId, sanitizedProfile);
    _ProfileCache.setStats(userId, stats);

    return UserProfileBundle(
      profile: sanitizedProfile,
      stats: stats,
      isFollowing: isFollowing,
      initialPosts: const [],
    );
  } catch (e) {
    _ProviderLogger.error('Profile fetch failed', {'userId': userId, 'error': '$e'});
    return UserProfileBundle.error('Erreur de chargement, veuillez vérifier votre connexion.');
  }
});

// ============================================================================
// PROVIDER : LISTE DES POSTS (Pagination cursor-based)
// ============================================================================

class UserPostsState {
  final List<MediaContent> posts;
  final bool hasMore;

  const UserPostsState({required this.posts, required this.hasMore});

  UserPostsState copyWith({List<MediaContent>? posts, bool? hasMore}) {
    return UserPostsState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class UserPostsNotifier extends StateNotifier<AsyncValue<UserPostsState>> {
  UserPostsNotifier(this.userId) : super(const AsyncValue.loading()) {
    _load();
  }

  final String userId;
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loading = false;

  Future<void> _load() async {
    _ProviderLogger.info('Initial load posts', {'userId': userId});
    state = const AsyncValue.loading();
    try {
      final posts = await _fetchPage(null);
      if (!mounted) return;
      _hasMore = posts.length == _kLimit;
      state = AsyncValue.data(UserPostsState(posts: posts, hasMore: _hasMore));
    } catch (e, st) {
      _ProviderLogger.error('Initial load failed', {'error': '$e'});
      if (!mounted) return;
      state = AsyncValue.error(e, st);
      void removePost(String postId) {
  final current = state.valueOrNull;
  if (current == null) return;
  state = AsyncValue.data(
    current.copyWith(
      posts: current.posts.where((p) => p.id != postId).toList(),
    ),
  );
}
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    await _load();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null || current.posts.isEmpty) return;

    // ✅ Protection anti-DoS : limite mémoire stricte
    if (current.posts.length >= _kMaxPosts) {
      _ProviderLogger.warn('Max posts memory limit reached', {'userId': userId, 'limit': _kMaxPosts});
      _hasMore = false;
      state = AsyncValue.data(current.copyWith(hasMore: false));
      return;
    }

    _loading = true;
    try {
      _cursor = current.posts.last.createdAt.toUtc();
      final newPosts = await _fetchPage(_cursor);
      if (!mounted) return;

      _hasMore = newPosts.length == _kLimit;
      
      // ✅ Déduplication stricte basée sur l'ID
      final existingIds = current.posts.map((p) => p.id).toSet();
      final uniqueNewPosts = newPosts.where((p) => !existingIds.contains(p.id)).toList();

      state = AsyncValue.data(UserPostsState(
        posts: [...current.posts, ...uniqueNewPosts],
        hasMore: _hasMore,
      ));
      
      _ProviderLogger.info('Loaded more posts', {'added': uniqueNewPosts.length, 'total': current.posts.length + uniqueNewPosts.length});
    } catch (e, st) {
      _ProviderLogger.error('Load more failed', {'error': '$e'});
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    } finally {
      _loading = false;
    }
  }

  Future<List<MediaContent>> _fetchPage(DateTime? cursor) async {
    var query = Supabase.instance.client
        .from('media_content')
        .select('*')
        .eq('user_id', userId)
        .eq('is_published', true);

    if (cursor != null) {
      query = query.lt('created_at', cursor.toIso8601String());
    }

    // ✅ Timeout systématique sur les appels Supabase
    final data = await query
        .order('created_at', ascending: false)
        .limit(_kLimit)
        .timeout(_kQueryTimeout);

    return (data as List).map((e) => MediaContent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

final userPostsProvider = StateNotifierProvider.autoDispose.family<UserPostsNotifier, AsyncValue<UserPostsState>, String>(
  (ref, userId) => UserPostsNotifier(userId),
);
