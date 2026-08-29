// lib/presentation/network/network_pro_home.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/network_story.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/nav.dart'; // ✅ Routes centralisées
import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';

import 'package:thix_id/presentation/network/live/live_prep_screen.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';

// ============================================================================
// PROVIDERS LOCAUX (remplace setState)
// ============================================================================
final _storiesProvider = StateProvider<List<NetworkStory>>((ref) => []);
final _loadingStoriesProvider = StateProvider<bool>((ref) => true);
final _feedTypeProvider = StateProvider<String>((ref) => 'foryou');
final _suggestionsProvider = StateProvider<List<dynamic>>((ref) => []);
final _navVisibleProvider = StateProvider<bool>((ref) => true);

// ============================================================================
// PROVIDER — SESSIONS LIVE ACTIVES
// ============================================================================
final activeLiveSessionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  try {
    return Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(10);
  } catch (e) {
    debugPrint('[LiveSessions] Stream error: $e');
    return Stream.value(const <Map<String, dynamic>>[]);
  }
});

// ============================================================================
// COMPOSANT — AVATAR ROND ÉPURÉ
// ============================================================================
class RoundAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final bool isLive;

  const RoundAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isLive ? ThixPolicy.danger : Colors.white.withValues(alpha: 0.8),
          width: isLive ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        color: ThixPolicy.surfaceSoft,
      ),
      child: ClipOval(
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.5, color: ThixPolicy.textSecondary),
              )
            : Icon(Icons.person, size: size * 0.5, color: ThixPolicy.textSecondary),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE — THIX PRO
// ============================================================================
class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});

  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  // ✅ CORRIGÉ : Variables d'instance au lieu de static
  DateTime? _lastRefreshTime;
  static const _refreshCooldown = Duration(seconds: 60);

  bool _isLoadingMore = false;
  Timer? _scrollDebounce; // ✅ Debounce scroll
  Timer? _suggestionTimer;
  int _suggestionRefreshCount = 0; // ✅ Limite refreshes

  // ✅ CORRIGÉ : Limites mémoire
  static const int _maxSuggestions = 100;
  static const int _maxSuggestionRefreshes = 10;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // ✅ DEBOUNCE : Évite appels multiples
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
      if (pos.pixels >= pos.maxScrollExtent - 700 && !_isLoadingMore) {
        final notifier = ref.read(feedProvider.notifier);
        if (!ref.read(feedProvider).isLoading && notifier.hasMore) {
          _isLoadingMore = true;
          notifier.loadMore().whenComplete(() {
            if (mounted) _isLoadingMore = false;
          });
        }
      }

      // Hide/show nav
      final dir = pos.userScrollDirection;
      final navVisible = ref.read(_navVisibleProvider.notifier);
      if (dir == ScrollDirection.reverse && ref.read(_navVisibleProvider)) {
        navVisible.state = false;
      } else if (dir == ScrollDirection.forward && !ref.read(_navVisibleProvider)) {
        navVisible.state = true;
      }
    });
  }

  Future<void> _init() async {
    final now = DateTime.now();
    final needsRefresh = _lastRefreshTime == null || now.difference(_lastRefreshTime!) > _refreshCooldown;

    final feedType = ref.read(_feedTypeProvider);
    await ref.read(feedProvider.notifier).loadFeed(feedType: feedType, force: needsRefresh);
    if (needsRefresh) _lastRefreshTime = now;

    await Future.wait([_loadStories(), _loadSuggestions()]);
  }

  Future<void> _loadStories() async {
    try {
      final data = await ref.read(networkServiceProvider).getActiveStories();
      ref.read(_storiesProvider.notifier).state = data;
      ref.read(_loadingStoriesProvider.notifier).state = false;
    } catch (e) {
      debugPrint('[Stories] Load error: $e');
      ref.read(_loadingStoriesProvider.notifier).state = false;
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref.read(networkServiceProvider).getSuggestedConnections(limit: 30);

      // ✅ LIMITE MÉMOIRE : Max 100 suggestions
      final currentSuggestions = ref.read(_suggestionsProvider);
      final merged = [...currentSuggestions, ...data].take(_maxSuggestions).toList();
      ref.read(_suggestionsProvider.notifier).state = merged;

      _shuffleSuggestions();

      // ✅ LIMITE REFRESHES : Max 10 fois
      _suggestionTimer?.cancel();
      if (_suggestionRefreshCount < _maxSuggestionRefreshes) {
        _suggestionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          _suggestionRefreshCount++;
          if (_suggestionRefreshCount >= _maxSuggestionRefreshes) {
            _suggestionTimer?.cancel();
            debugPrint('[Suggestions] Max refreshes reached, stopping timer');
          } else {
            _shuffleSuggestions();
          }
        });
      }
    } catch (e) {
      debugPrint('[Suggestions] Load error: $e');
    }
  }

  void _shuffleSuggestions() {
    final suggestions = ref.read(_suggestionsProvider);
    if (suggestions.isEmpty || !mounted) return;

    final list = List<dynamic>.from(suggestions);
    list.shuffle(Random());
    ref.read(_suggestionsProvider.notifier).state = list.take(10).toList();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    final feedType = ref.read(_feedTypeProvider);
    await ref.read(feedProvider.notifier).loadFeed(feedType: feedType, force: true);
    _lastRefreshTime = DateTime.now();
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
  }

  Future<void> _openCreateStory() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const CreateStoryDialog());
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
    }
  }

  void _safePush(String path) {
    if (!mounted) return;
    try {
      context.push(path);
    } catch (e) {
      debugPrint('[Nav] Push error: $e');
    }
  }

  Future<void> _openComments(String postId) async {
    _safePush(AppRoutes.networkComments.replaceFirst(':postId', postId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  // ✅ OPTIMISÉ : Gradient au lieu de BackdropFilter
  Widget _buildGradientOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authAsync = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUser = authAsync.value;

    final liveSessionsAsync = ref.watch(activeLiveSessionsProvider);
    final liveSessions = liveSessionsAsync.value ?? const <Map<String, dynamic>>[];
    final liveHostIds = liveSessions.map((s) => s['host_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Stack(
          children: [
            // ✅ OPTIMISÉ : Gradients au lieu de BackdropFilter
            Positioned(top: -100, right: -50, child: _buildGradientOrb(ThixPolicy.primary, 250)),
            Positioned(bottom: 200, left: -100, child: _buildGradientOrb(ThixPolicy.primaryDeep, 300)),

            RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: ThixPolicy.card,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(avatarUrl: currentUser.photoUrl),
                  SliverToBoxAdapter(
                    child: _QuickPostEntryCard(
                      avatarUrl: currentUser.photoUrl,
                      onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildStories(currentUser.id, liveHostIds)),
                  SliverToBoxAdapter(child: _buildFilters()),

                  if (ref.watch(_suggestionsProvider).isNotEmpty || liveSessions.isNotEmpty)
                    SliverToBoxAdapter(child: _buildUnifiedDiscoveryBand(liveSessions)),

                  feedAsync.when(
                    loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text('Erreur: $e', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
                        ),
                      ),
                    ),
                    data: (posts) {
                      if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty());
                      return SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (c, i) {
                          final post = posts[i];
                          return Column(
                            children: [
                              PostCard(
                                key: ValueKey(post.id),
                                post: post,
                                currentProfileId: currentUser.id,
                                onLike: null,
                                onComment: () => _openComments(post.id),
                                onShare: () => _showShareSheet(post),
                                onDelete: () => ref.read(feedProvider.notifier).deletePost(post.id),
                                onRefresh: null,
                              ),
                              Divider(height: 1, thickness: 0.5, color: ThixPolicy.gold.withValues(alpha: 0.8)),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),

            Consumer(
              builder: (context, ref, _) {
                final visible = ref.watch(_navVisibleProvider);
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomNav(visible),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar({required String? avatarUrl}) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      toolbarHeight: 60,
      titleSpacing: 16,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: Colors.white.withValues(alpha: 0.7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1)),
            ),
          ),
        ),
      ),
      title: Text(
        'THIX PRO',
        style: ThixPolicy.h2Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.3, color: ThixPolicy.textMain),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePrepScreen())),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThixPolicy.danger.withValues(alpha: 0.1),
              border: Border.all(color: ThixPolicy.danger.withValues(alpha: 0.3), width: 1),
            ),
            child: const Icon(Icons.sensors_rounded, size: 20, color: ThixPolicy.danger),
          ),
        ),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.search_rounded, onTap: () => _safePush(AppRoutes.networkSearch)),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.notifications_none_rounded, onTap: () => _safePush(AppRoutes.networkNotifications)),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => _safePush(AppRoutes.networkProfile),
            child: RoundAvatar(size: 34, imageUrl: avatarUrl),
          ),
        ),
      ],
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 19, color: ThixPolicy.textMain),
      ),
    );
  }

  Widget _buildStories(String currentUserId, Set<String> liveHostIds) {
    final loadingStories = ref.watch(_loadingStoriesProvider);
    final stories = ref.watch(_storiesProvider);

    if (loadingStories) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
        ),
        height: 150,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
        ),
      );
    }

    // ✅ OPTIMISÉ : Calcul en dehors de build
    final myStories = stories.where((s) => s.userId == currentUserId).toList();
    final Map<String, List<NetworkStory>> groupedOtherStories = {};
    for (final s in stories) {
      if (s.userId != currentUserId) {
        groupedOtherStories.putIfAbsent(s.userId, () => []).add(s);
      }
    }
    final otherUsersList = groupedOtherStories.keys.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 134,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: otherUsersList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (c, i) {
            if (i == 0) {
              return _StoryCard(
                isMe: true,
                hasStory: myStories.isNotEmpty,
                isLive: liveHostIds.contains(currentUserId),
                name: myStories.isNotEmpty ? 'Votre story' : 'Créer',
                coverUrl: myStories.isNotEmpty
                    ? (myStories.first.imageUrl.isNotEmpty ? myStories.first.imageUrl : myStories.first.userAvatar)
                    : null,
                avatarUrl: myStories.isNotEmpty ? myStories.first.userAvatar : null,
                onTap: myStories.isNotEmpty
                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: myStories, initialIndex: 0)))
                    : _openCreateStory,
                onAdd: _openCreateStory,
              );
            }
            final userId = otherUsersList[i - 1];
            final userStories = groupedOtherStories[userId]!;
            final firstStory = userStories.first;

            return _StoryCard(
              isMe: false,
              hasStory: true,
              isLive: liveHostIds.contains(userId),
              name: firstStory.userName.split(' ').first,
              coverUrl: firstStory.imageUrl.isNotEmpty ? firstStory.imageUrl : null,
              avatarUrl: firstStory.userAvatar,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: userStories, initialIndex: 0))),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final feedType = ref.watch(_feedTypeProvider);
    final filters = {
      'foryou': 'Pour vous',
      'network': 'Abonnements',
      'recent': 'Récents',
      'popular': 'Tendances',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final active = feedType == e.key;
            return GestureDetector(
              onTap: () {
                if (active) return;
                ref.read(_feedTypeProvider.notifier).state = e.key;
                ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                _lastRefreshTime = DateTime.now();
                HapticFeedback.lightImpact();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? ThixPolicy.textMain : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ThixPolicy.textMain : Colors.white.withValues(alpha: 0.8), width: 1.2),
                  boxShadow: active
                      ? []
                      : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                ),
                child: Text(
                  e.value,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: active ? ThixPolicy.bold : ThixPolicy.semiBold,
                    color: active ? Colors.white : ThixPolicy.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUnifiedDiscoveryBand(List<Map<String, dynamic>> liveSessions) {
    final suggestions = ref.watch(_suggestionsProvider);
    final int totalCount = suggestions.length + liveSessions.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.explore_rounded, size: 16, color: ThixPolicy.textMain),
                const SizedBox(width: 8),
                Text('À découvrir', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14.5, color: ThixPolicy.textMain)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: totalCount,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (c, i) {
                if (i < suggestions.length) {
                  final u = suggestions[i];
                  return GestureDetector(
                    onTap: () => context.push(AppRoutes.networkProfileUser.replaceFirst(':userId', u.id.toString())),
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              RoundAvatar(size: 56, imageUrl: u.avatar),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    ref.read(_suggestionsProvider.notifier).state = suggestions.where((s) => s.id != u.id).toList();
                                    try {
                                      await ref.read(networkServiceProvider).sendConnectionRequest(u.id);
                                    } catch (e) {
                                      debugPrint('[Follow] Error: $e');
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            u.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final liveIndex = i - suggestions.length;
                  final s = liveSessions[liveIndex];
                  return GestureDetector(
                    onTap: () {
                      final liveSession = LiveSession(
                        id: s['id']?.toString() ?? '',
                        channelName: s['channel_name']?.toString() ?? '',
                        title: s['title']?.toString() ?? 'Live',
                        hostId: s['host_id']?.toString() ?? '',
                        hostName: s['host_name']?.toString() ?? 'Hôte THIX',
                        hostAvatarUrl: s['host_avatar']?.toString(),
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LiveViewerScreen(session: liveSession),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              RoundAvatar(size: 56, imageUrl: s['host_avatar']?.toString(), isLive: true),
                              Positioned(
                                bottom: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1.5)),
                                  child: Text('LIVE', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontSize: 8, fontWeight: ThixPolicy.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (s['host_name']?.toString() ?? 'Hôte').split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          ),
          height: 200,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
            child: const Icon(Icons.feed_outlined, size: 32, color: ThixPolicy.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('Aucune publication pour ce filtre', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.textMain,
              side: const BorderSide(color: ThixPolicy.border),
              backgroundColor: Colors.white.withValues(alpha: 0.5),
            ),
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(dynamic post) {
    final id = '${post.id}';
    final link = 'https://thix.id/network/post/$id';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
              ListTile(
                leading: const Icon(Icons.link, color: ThixPolicy.textMain),
                title: Text('Copier le lien', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.semiBold)),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  try {
                    await ref.read(networkServiceProvider).sharePost(id);
                  } catch (e) {
                    debugPrint('[Share] Error: $e');
                  }
                  if (mounted) Navigator.pop(context);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: ThixPolicy.textSecondary),
                title: Text('Fermer', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool visible) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navBtn(Icons.home_rounded, 'Accueil', true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                      _navBtn(Icons.explore_outlined, 'Découvrir', false, () => _safePush(AppRoutes.networkDiscover)),
                      _navBtn(Icons.add_circle_outline_rounded, 'Publier', false, () => showDialog(context: context, builder: (_) => const CreatePostDialog())),
                      _navBtn(Icons.mail_outline_rounded, 'Messages', false, () => _safePush(AppRoutes.networkMessages)),
                      _navBtn(Icons.diversity_3_outlined, 'Communauté', false, () => _safePush(AppRoutes.networkCommunities)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData ic, String label, bool active, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 22, color: active ? ThixPolicy.primary : ThixPolicy.textSecondary.withValues(alpha: 0.8)),
            const SizedBox(height: 2),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: active ? ThixPolicy.primary : ThixPolicy.textSecondary.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPostEntryCard extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _QuickPostEntryCard({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          RoundAvatar(size: 44, imageUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: Text('Commencer un post...', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.image_outlined, color: ThixPolicy.primary, size: 26),
            tooltip: 'Ajouter un média',
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? coverUrl;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StoryCard({
    required this.isMe,
    required this.hasStory,
    this.isLive = false,
    required this.name,
    this.coverUrl,
    this.avatarUrl,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLive ? ThixPolicy.danger : Colors.white.withValues(alpha: 0.8),
            width: isLive ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (coverUrl != null && coverUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.transparent),
                        errorWidget: (_, __, ___) => Container(color: Colors.transparent),
                      )
                    : Container(color: Colors.transparent),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: RoundAvatar(size: 28, imageUrl: avatarUrl, isLive: isLive),
            ),
            if (isMe)
              Positioned(
                top: 22,
                left: 22,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 1.8)),
                    child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
