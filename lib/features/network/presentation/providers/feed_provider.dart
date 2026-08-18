// lib/features/network/presentation/providers/feed_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_ranker.dart';

final feedProvider = AsyncNotifierProvider<Feed, List<NetworkPost>>(Feed.new);

class Feed extends AsyncNotifier<List<NetworkPost>> {
  String _currentType = 'all';
  bool _hasMore = true;
  bool _isFetchingMore = false; // Verrou anti-spam pour le scroll
  Set<String> _connectionIds = {};
  
  // Le Curseur ! Il remplacera l'offset.
  DateTime? _lastPostDate;

  bool get hasMore => _hasMore;
  String get currentType => _currentType;
  bool get isFetchingMore => _isFetchingMore;

  Future<void> _ensureConnections() async {
    if (_connectionIds.isNotEmpty) return;
    try {
      final service = ref.read(networkServiceProvider);
      _connectionIds = await service.getMyConnectionIds();
    } catch (e) {
      debugPrint('🔥 connections for rank: $e');
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

  @override
  Future<List<NetworkPost>> build() async {
    _hasMore = true;
    _lastPostDate = null;
    _isFetchingMore = false;
    
    try {
      await _ensureConnections();
      final service = ref.read(networkServiceProvider);
      final limit = _currentType == 'all' ? 50 : 20;
      
      // Appel avec le curseur (initialement null)
      final posts = await service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        lastCreatedAt: _lastPostDate, 
      );
      
      _hasMore = posts.length >= limit;
      if (posts.isNotEmpty) {
        _lastPostDate = posts.last.createdAt; // Mise à jour du curseur
      }
      
      return _rank(posts);
    } catch (e) {
      debugPrint('🔥 Erreur dans Feed.build: $e');
      return [];
    }
  }

  Future<void> loadFeed({String? feedType, bool force = false}) async {
    if (feedType != null) _currentType = feedType;
    state = const AsyncLoading();

    try {
      if (force) {
        _connectionIds = {};
      }
      await _ensureConnections();

      _lastPostDate = null; // Réinitialisation du curseur

      final service = ref.read(networkServiceProvider);
      final limit = _currentType == 'all' ? 50 : 30;
      
      final posts = await service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        lastCreatedAt: _lastPostDate,
      );
      
      _hasMore = posts.length >= limit;
      if (posts.isNotEmpty) {
        _lastPostDate = posts.last.createdAt;
      }
      
      state = AsyncData(_rank(posts));
    } catch (e, stack) {
      debugPrint('🔥 Erreur dans Feed.loadFeed: $e');
      state = AsyncError(e, stack);
    }
  }

  void addPostOnTop(NetworkPost post) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([post, ...current]);
  }

  Future<void> loadMore() async {
    // Bloque si on est déjà en train de charger, ou s'il n'y a plus rien
    if (!_hasMore || _isFetchingMore) return;
    
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    _isFetchingMore = true;

    try {
      await _ensureConnections();
      final service = ref.read(networkServiceProvider);
      final limit = _currentType == 'all' ? 30 : 20;
      
      // On s'assure d'avoir le curseur du dernier post actuellement affiché
      _lastPostDate = current.last.createdAt;
      
      final more = await service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        lastCreatedAt: _lastPostDate,
      );
      
      _hasMore = more.length >= limit;
      if (more.isNotEmpty) {
        _lastPostDate = more.last.createdAt;
      }

      final rankedMore = _rank(more);
      state = AsyncData([...current, ...rankedMore]);
    } catch (e) {
      debugPrint('🔥 Erreur dans Feed.loadMore: $e');
    } finally {
      _isFetchingMore = false; // Libère le verrou
    }
  }

  Future<void> deletePost(String postId) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((p) => p.id != postId).toList());
    try {
      await ref.read(networkServiceProvider).deletePost(postId);
    } catch (_) {
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
    state = AsyncData(list); // Mise à jour optimiste instantanée

    try {
      final service = ref.read(networkServiceProvider);
      if (wasLiked) {
        await service.unlikePost(postId);
      } else {
        await service.likePost(postId);
      }
    } catch (e) {
      debugPrint('🔥 toggleLike rollback: $e');
      state = AsyncData(current); // Rollback en cas d'erreur réseau
    }
  }
}
