import 'dart:math'; 
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_ranker.dart';

final feedProvider = AsyncNotifierProvider<Feed, List<NetworkPost>>(Feed.new);

class Feed extends AsyncNotifier<List<NetworkPost>> {
  String _currentType = 'all';
  bool _hasMore = true;
  bool _isFetchingMore = false;
  Set<String> _connectionIds = {};
  DateTime? _lastPostDate;
  
  int _feedSeed = 0; // ✅ AJOUT : seed du mélange pour la DB

  // ✅ Limite mémoire (max 500 posts en mémoire)
  static const int _maxPostsInMemory = 500;

  bool get hasMore => _hasMore;
  String get currentType => _currentType;
  bool get isFetchingMore => _isFetchingMore;

  Future<void> _ensureConnections() async {
    if (_connectionIds.isNotEmpty) return;
    try {
      final service = ref.read(networkServiceProvider);
      _connectionIds = await service.getMyConnectionIds();
    } catch (e) {
      debugPrint('[Feed] connections error: $e');
      _connectionIds = {};
    }
  }

  List<NetworkPost> _rank(List<NetworkPost> posts) {
    return FeedRanker.rank(
      posts: posts,
      connectionIds: _connectionIds,
      feedType: _currentType,
    );
  }

  // ✅ Trim la liste si elle dépasse la limite
  List<NetworkPost> _enforceMemoryLimit(List<NetworkPost> posts) {
    if (posts.length <= _maxPostsInMemory) return posts;
    debugPrint('[Feed] Trimming from ${posts.length} to $_maxPostsInMemory posts');
    return posts.take(_maxPostsInMemory).toList();
  }

  @override
  Future<List<NetworkPost>> build() async {
    _hasMore = true;
    _lastPostDate = null;
    _isFetchingMore = false;
    _feedSeed = Random().nextInt(1000000000); // ✅ Mélange initial
    
    try {
      return await _fetch(offset: 0);
    } catch (e) {
      debugPrint('[Feed] build error: $e');
      return [];
    }
  }

  Future<void> loadFeed({String? feedType, bool force = false}) async {
    if (feedType != null) _currentType = feedType;
    state = const AsyncLoading();

    try {
      if (force) _connectionIds = {};
      
      _lastPostDate = null;
      _feedSeed = Random().nextInt(1000000000); // ✅ NOUVEAU mélange à chaque refresh (pull-to-refresh)

      final posts = await _fetch(offset: 0);
      state = AsyncData(posts);
    } catch (e, stack) {
      debugPrint('[Feed] loadFeed error: $e');
      state = AsyncError(e, stack);
    }
  }

  // ✅ CORRIGÉ : Vérifie les doublons avant d'ajouter un nouveau post publié
  void addPostOnTop(NetworkPost post) {
    final current = state.valueOrNull ?? [];
    
    // Vérifier si le post existe déjà
    if (current.any((p) => p.id == post.id)) {
      debugPrint('[Feed] Post ${post.id} already exists, skipping');
      return;
    }
    
    final updated = [post, ...current];
    state = AsyncData(_enforceMemoryLimit(updated));
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isFetchingMore) return;
    
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    // ✅ Stop si on a atteint la limite mémoire
    if (current.length >= _maxPostsInMemory) {
      debugPrint('[Feed] Memory limit reached, stopping pagination');
      _hasMore = false;
      return;
    }

    _isFetchingMore = true;

    try {
      // ✅ MÊME seed que le refresh initial → pagination cohérente
      final more = await _fetch(offset: current.length);
      
      // ✅ Sécurité anti-doublon lors du fetch
      final ids = current.map((p) => p.id).toSet();
      final unique = more.where((p) => !ids.contains(p.id)).toList();

      final updated = [...current, ...unique];
      state = AsyncData(_enforceMemoryLimit(updated));
    } catch (e) {
      debugPrint('[Feed] loadMore error: $e');
    } finally {
      _isFetchingMore = false;
    }
  }

  // ✅ NOUVEAU : Méthode centralisée pour récupérer et formater les données
  Future<List<NetworkPost>> _fetch({required int offset}) async {
    await _ensureConnections();
    final service = ref.read(networkServiceProvider);
    
    // Limites dynamiques
    final limit = _currentType == 'all' ? (offset == 0 ? 50 : 30) : 20;

    if (_currentType == 'all') {
      // ✅ SMART FEED : La DB s'occupe déjà de calculer et trier.
      final posts = await service.getFeedPosts(
        feedType: 'all',
        limit: limit,
        offset: offset,
        seed: _feedSeed, // Paramètre de mélange
      );
      
      _hasMore = posts.length >= limit;
      return _enforceMemoryLimit(posts); // ❌ Pas de FeedRanker client-side ici pour ne pas écraser l'algorithme DB
    }

    // ── Autres onglets (Abonnements, Tendances) ──
    final posts = await service.getFeedPosts(
      feedType: _currentType,
      limit: limit,
      offset: offset,
      lastCreatedAt: _lastPostDate,
    );
    
    _hasMore = posts.length >= limit;
    if (posts.isNotEmpty) _lastPostDate = posts.last.createdAt;
    
    // On applique le FeedRanker localement pour les onglets classiques
    return _enforceMemoryLimit(_rank(posts)); 
  }

  Future<void> deletePost(String postId) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((p) => p.id != postId).toList());
    
    try {
      await ref.read(networkServiceProvider).deletePost(postId);
    } catch (e) {
      debugPrint('[Feed] deletePost error, rollback: $e');
      state = AsyncData(current); // Rollback
    }
  }

  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final old = current[idx];
    final wasLiked = old.isLiked;
    final oldCount = old.likesCount;

    final optimistic = old.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1,
    );

    final list = [...current];
    list[idx] = optimistic;
    state = AsyncData(list);

    try {
      final service = ref.read(networkServiceProvider);
      if (wasLiked) {
        await service.unlikePost(postId);
      } else {
        await service.likePost(postId);
      }
    } catch (e) {
      debugPrint('[Feed] toggleLike error, rollback: $e');
      state = AsyncData(current);
    }
  }
}
