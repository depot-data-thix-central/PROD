// lib/features/network/presentation/providers/community_detail_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const int _kPostsLimit = 20;
const int _kMembersLimit = 50;
const int _kMaxPostLength = 2000;

// ============================================================================
// STATE
// ============================================================================
@immutable
class CommunityDetailState {
  final NetworkCommunity community;
  final List<NetworkPost> posts;
  final List<Map<String, dynamic>> members;
  final bool isMember;
  final bool hasMorePosts;
  final Set<String> _postIds; // Pour dedup

  CommunityDetailState({
    required this.community,
    this.posts = const [],
    this.members = const [],
    this.isMember = false,
    this.hasMorePosts = true,
  }) : _postIds = posts.map((p) => p.id).toSet();

  CommunityDetailState copyWith({
    NetworkCommunity? community,
    List<NetworkPost>? posts,
    List<Map<String, dynamic>>? members,
    bool? isMember,
    bool? hasMorePosts,
  }) {
    final newPosts = posts ?? this.posts;
    return CommunityDetailState(
      community: community ?? this.community,
      posts: newPosts,
      members: members ?? this.members,
      isMember: isMember ?? this.isMember,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================
class CommunityDetailNotifier
    extends AutoDisposeFamilyAsyncNotifier<CommunityDetailState, String> {
  int _postsOffset = 0;

  @override
  Future<CommunityDetailState> build(String arg) async {
    _postsOffset = 0;
    return _loadInitialData(arg);
  }

  Future<CommunityDetailState> _loadInitialData(String communityId) async {
    debugPrint('[Community] Loading initial data for $communityId');
    final supabase = ref.read(supabaseClientProvider);
    final currentUserId = supabase.auth.currentUser?.id;

    try {
      final results = await Future.wait([
        // 1. Communauté
        supabase
            .from('communities')
            .select('*')
            .eq('id', communityId)
            .maybeSingle()
            .timeout(_kRequestTimeout),

        // 2. Membres (limit 50)
        supabase
            .from('community_members')
            .select('user_id, role, joined_at, users:profiles!user_id(id, display_name, avatar_url, photo_url, profession)')
            .eq('community_id', communityId)
            .order('joined_at', ascending: true)
            .limit(_kMembersLimit)
            .timeout(_kRequestTimeout),

        // 3. Posts (avec join explicite FK)
        supabase
            .from('posts')
            .select('*, profiles!posts_user_id_fkey(display_name, avatar_url, photo_url, profession)')
            .eq('community_id', communityId)
            .order('created_at', ascending: false)
            .range(0, _kPostsLimit - 1)
            .timeout(_kRequestTimeout),

        // 4. Check is member
        currentUserId != null
            ? supabase
                .from('community_members')
                .select('id, role')
                .eq('community_id', communityId)
                .eq('user_id', currentUserId)
                .maybeSingle()
                .timeout(_kRequestTimeout)
            : Future.value(null),
      ]);

      final communityData = results[0] as Map<String, dynamic>?;
      if (communityData == null) {
        throw Exception('Communauté introuvable');
      }

      final membersData = results[1] as List<dynamic>;
      final postsData = results[2] as List<dynamic>;
      final memberCheck = results[3] as Map<String, dynamic>?;

      final posts = postsData.map((e) => _mapPost(e)).toList();
      _postsOffset = posts.length;

      final members = membersData.map((e) {
        final memberRow = e as Map<String, dynamic>;
        final profile = memberRow['users'] as Map<String, dynamic>?;
        return {
          'id': profile?['id'] ?? memberRow['user_id'],
          'display_name': profile?['display_name'] ?? 'Utilisateur',
          'avatar_url': profile?['avatar_url'] ?? profile?['photo_url'],
          'photo_url': profile?['avatar_url'] ?? profile?['photo_url'],
          'profession': profile?['profession'],
          'role': memberRow['role'] ?? 'member',
          'joined_at': memberRow['joined_at'],
        };
      }).toList();

      debugPrint('[Community] Loaded ${posts.length} posts, ${members.length} members');

      return CommunityDetailState(
        community: NetworkCommunity.fromJson({
          ...communityData,
          'members_count': communityData['members_count'] ?? members.length,
        }),
        members: members,
        posts: posts,
        isMember: memberCheck != null,
        hasMorePosts: posts.length >= _kPostsLimit,
      );
    } catch (e, stack) {
      debugPrint('[Community] Load error: $e\n$stack');
      rethrow;
    }
  }

  NetworkPost _mapPost(dynamic e) {
    final row = Map<String, dynamic>.from(e as Map);
    final userData = row['profiles'] as Map<String, dynamic>?;

    return NetworkPost.fromJson({
      ...row,
      'author_name': userData?['display_name'] ?? 'Utilisateur',
      'author_avatar': userData?['avatar_url'] ?? userData?['photo_url'],
      'author_title': userData?['profession'],
      'media_urls': _extractMediaUrls(row),
    });
  }

  List<String> _extractMediaUrls(Map<String, dynamic> row) {
    if (row['media_urls'] != null) {
      return List<String>.from(row['media_urls'] as List);
    }
    if (row['media_url'] != null && row['media_url'].toString().isNotEmpty) {
      return [row['media_url'].toString()];
    }
    if (row['image_urls'] != null) {
      return List<String>.from(row['image_urls'] as List);
    }
    return [];
  }

  // ─── PAGINATION ───
  Future<void> loadMorePosts() async {
    final currentState = state.valueOrNull;
    if (currentState == null || !currentState.hasMorePosts) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      debugPrint('[Community] Loading more posts from offset $_postsOffset');

      final res = await supabase
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(display_name, avatar_url, photo_url, profession)')
          .eq('community_id', arg)
          .order('created_at', ascending: false)
          .range(_postsOffset, _postsOffset + _kPostsLimit - 1)
          .timeout(_kRequestTimeout);

      if ((res as List).isEmpty) {
        state = AsyncData(currentState.copyWith(hasMorePosts: false));
        return;
      }

      final morePosts = res.map((e) => _mapPost(e)).toList();
      _postsOffset += morePosts.length;

      // Dedup par ID
      final existingIds = currentState._postIds;
      final uniqueNew = morePosts.where((p) => !existingIds.contains(p.id)).toList();

      state = AsyncData(
        currentState.copyWith(
          posts: [...currentState.posts, ...uniqueNew],
          hasMorePosts: morePosts.length >= _kPostsLimit,
        ),
      );

      debugPrint('[Community] Loaded ${uniqueNew.length} new posts');
    } catch (e) {
      debugPrint('[Community] Load more error: $e');
      // Silencieux pour la pagination (évite de bloquer le scroll)
    }
  }

  // ─── JOIN / QUIT ───
  Future<void> toggleJoin() async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final wasMember = currentState.isMember;
    final currentCount = currentState.community.membersCount;

    // Optimistic UI
    state = AsyncData(
      currentState.copyWith(
        isMember: !wasMember,
        community: currentState.community.copyWith(
          membersCount: wasMember ? (currentCount - 1).clamp(0, 1 << 30) : currentCount + 1,
        ),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        throw Exception('Non authentifié');
      }

      if (wasMember) {
        await supabase
            .from('community_members')
            .delete()
            .eq('community_id', arg)
            .eq('user_id', uid)
            .timeout(_kRequestTimeout);
        debugPrint('[Community] Left community $arg');
      } else {
        await supabase
            .from('community_members')
            .insert({
              'community_id': arg,
              'user_id': uid,
              'role': 'member',
              'joined_at': DateTime.now().toUtc().toIso8601String(),
            })
            .timeout(_kRequestTimeout);
        debugPrint('[Community] Joined community $arg');
      }
    } catch (e) {
      debugPrint('[Community] Toggle join error: $e');
      state = AsyncData(currentState); // Rollback
      throw Exception('Erreur de synchronisation réseau');
    }
  }

  // ─── LIKE ───
  Future<void> toggleLike(String postId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final postIndex = currentState.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = currentState.posts[postIndex];
    final newIsLiked = !post.isLiked;

    // Optimistic UI
    final updatedPosts = List<NetworkPost>.from(currentState.posts);
    updatedPosts[postIndex] = post.copyWith(
      isLiked: newIsLiked,
      likesCount: (post.likesCount + (newIsLiked ? 1 : -1)).clamp(0, 1 << 30),
    );

    state = AsyncData(currentState.copyWith(posts: updatedPosts));

    try {
      final ns = ref.read(networkServiceProvider);
      if (newIsLiked) {
        await ns.likePost(postId);
      } else {
        await ns.unlikePost(postId);
      }
    } catch (e) {
      debugPrint('[Community] Toggle like error: $e');
      ref.invalidateSelf(); // Reload from DB
    }
  }

  // ─── CRÉATION DE POST (NOUVEAU) ───
  Future<NetworkPost?> createPost(String content) async {
    final sanitized = content.trim();
    if (sanitized.isEmpty) {
      throw Exception('Le contenu ne peut pas être vide');
    }
    if (sanitized.length > _kMaxPostLength) {
      throw Exception('Contenu trop long (max $_kMaxPostLength caractères)');
    }

    final supabase = ref.read(supabaseClientProvider);
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Vous devez être connecté pour publier');
    }

    // Vérifier que l'user est membre
    final currentState = state.valueOrNull;
    if (currentState != null && !currentState.isMember) {
      throw Exception('Vous devez être membre de cette communauté pour publier');
    }

    try {
      debugPrint('[Community] Creating post in $arg');

      final response = await supabase
          .from('posts')
          .insert({
            'user_id': uid,
            'community_id': arg,
            'content': sanitized,
            'is_public': true,
            'post_type': 'standard',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('*, profiles!posts_user_id_fkey(display_name, avatar_url, photo_url, profession)')
          .single()
          .timeout(_kRequestTimeout);

      final newPost = _mapPost(response);
      debugPrint('[Community] Post created: ${newPost.id}');

      // Ajouter en tête de la liste
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(
          posts: [newPost, ...current.posts],
        ));
      }

      // Rafraîchir les données de la communauté (pour le compteur de posts)
      try {
        await _refreshCommunityData();
      } catch (e) {
        debugPrint('[Community] Refresh after post error: $e');
        // Non bloquant
      }

      return newPost;
    } catch (e, stack) {
      debugPrint('[Community] Create post error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> _refreshCommunityData() async {
    final supabase = ref.read(supabaseClientProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final community = await supabase
        .from('communities')
        .select('*')
        .eq('id', arg)
        .maybeSingle()
        .timeout(_kRequestTimeout);

    if (community != null) {
      state = AsyncData(current.copyWith(
        community: NetworkCommunity.fromJson({
          ...community,
          'members_count': community['members_count'] ?? current.members.length,
        }),
      ));
    }
  }

  // ─── REFRESH ───
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadInitialData(arg));
  }

  // ─── DELETE POST ───
  Future<void> deletePost(String postId) async {
    final supabase = ref.read(supabaseClientProvider);
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');

    try {
      await supabase.from('posts').delete().eq('id', postId).eq('user_id', uid).timeout(_kRequestTimeout);

      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(
          posts: current.posts.where((p) => p.id != postId).toList(),
        ));
      }
      debugPrint('[Community] Post deleted: $postId');
    } catch (e) {
      debugPrint('[Community] Delete post error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final communityDetailProvider = AsyncNotifierProvider.autoDispose
    .family<CommunityDetailNotifier, CommunityDetailState, String>(
  CommunityDetailNotifier.new,
);
