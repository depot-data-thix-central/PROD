import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

// ============================================================================
// CACHE EN MÉMOIRE (max 50 profils pour éviter requêtes répétées)
// ============================================================================
class _ProfileCache {
  static final Map<String, Map<String, dynamic>> _profiles = {};
  static final Map<String, Map<String, int>> _stats = {};
  static const int _maxSize = 50;

  static Map<String, dynamic>? getProfile(String userId) => _profiles[userId];
  static Map<String, int>? getStats(String userId) => _stats[userId];

  static void setProfile(String userId, Map<String, dynamic> profile) {
    if (_profiles.length >= _maxSize) {
      _profiles.remove(_profiles.keys.first);
    }
    _profiles[userId] = profile;
  }

  static void setStats(String userId, Map<String, int> stats) {
    if (_stats.length >= _maxSize) {
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
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
      .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .trim();
}

// ============================================================================
// PROVIDER : DONNÉES DE PROFIL (avec cache)
// ============================================================================
final userProfileDataProvider = FutureProvider.autoDispose.family<UserProfileBundle, String>((ref, userId) async {
  if (userId.trim().isEmpty) {
    return UserProfileBundle.error('ID utilisateur invalide');
  }

  // ✅ Utiliser le cache si disponible
  final cachedProfile = _ProfileCache.getProfile(userId);
  final cachedStats = _ProfileCache.getStats(userId);
  if (cachedProfile != null && cachedStats != null) {
    return UserProfileBundle(
      profile: cachedProfile,
      stats: cachedStats,
      isFollowing: false,
      initialPosts: const [],
    );
  }

  try {
    final service = MediaService();
    final results = await Future.wait([
      service.fetchProfile(userId),
      service.fetchUserStats(userId),
      service.isFollowing(userId),
    ]);

    final profile = results[0] as Map<String, dynamic>?;
    final stats = Map<String, int>.from(results[1] as Map);
    final isFollowing = results[2] as bool;

    if (profile == null) {
      return UserProfileBundle.error('Profil introuvable');
    }

    // ✅ Sanitize les champs texte
    final sanitizedProfile = {
      ...profile,
      'username': _sanitize(profile['username']?.toString()),
      'full_name': _sanitize(profile['full_name']?.toString()),
      'bio': _sanitize(profile['bio']?.toString()),
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
    return UserProfileBundle.error('Erreur de chargement : $e');
  }
});

// ============================================================================
// PROVIDER : LISTE DES POSTS (avec pagination cursor-based)
// ============================================================================
class UserPostsNotifier extends StateNotifier<AsyncValue<UserPostsState>> {
  UserPostsNotifier(this.userId) : super(const AsyncValue.loading()) {
    _load();
  }

  final String userId;
  static const int _limit = 15;
  static const int _maxPosts = 200; // ✅ Limite mémoire
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loading = false;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final posts = await _fetchPage(null);
      if (!mounted) return;
      state = AsyncValue.data(UserPostsState(posts: posts, hasMore: posts.length == _limit));
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null || current.posts.isEmpty) return;

    // ✅ Protection anti-DoS : max 200 posts en mémoire
    if (current.posts.length >= _maxPosts) {
      _hasMore = false;
      state = AsyncValue.data(current.copyWith(hasMore: false));
      return;
    }

    _loading = true;
    try {
      _cursor = current.posts.last.createdAt.toUtc();
      final newPosts = await _fetchPage(_cursor);
      if (!mounted) return;

      // ✅ Dédupliquer
      final existingIds = current.posts.map((p) => p.id).toSet();
      final uniqueNewPosts = newPosts.where((p) => !existingIds.contains(p.id)).toList();

      state = AsyncValue.data(UserPostsState(
        posts: [...current.posts, ...uniqueNewPosts],
        hasMore: newPosts.length == _limit,
      ));
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    } finally {
      _loading = false;
    }
  }

  Future<List<MediaContent>> _fetchPage(DateTime? cursor) async {
    var q = Supabase.instance.client
        .from('media_content')
        .select('*')
        .eq('user_id', userId)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(_limit);

    if (cursor != null) {
      q = q.lt('created_at', cursor.toIso8601String());
    }

    final data = await q;
    return (data as List).map((e) => MediaContent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

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

final userPostsProvider = StateNotifierProvider.autoDispose.family<UserPostsNotifier, AsyncValue<UserPostsState>, String>(
  (ref, userId) => UserPostsNotifier(userId),
);

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

  factory UserProfileBundle.error(String message) =>
      UserProfileBundle(error: message);
}
