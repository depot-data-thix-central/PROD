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
import 'package:thix_id/l10n/app_localizations.dart';

import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';

import 'package:thix_id/presentation/network/live/live_prep_screen.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';

// ============================================================================
// PROVIDERS LOCAUX
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
// GLASS SURFACE (Design "Community Glass" Premium)
// ============================================================================
class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double alpha;
  final double blur;
  final EdgeInsetsGeometry? padding;

  const _Glass({
    required this.child,
    this.radius = 20,
    this.alpha = 0.7,
    this.blur = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.inkDeep.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

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
          color: isLive ? ThixPolicy.danger : Colors.white.withValues(alpha: 0.9),
          width: isLive ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
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

  DateTime? _lastRefreshTime;
  static const _refreshCooldown = Duration(seconds: 60);

  bool _isLoadingMore = false;
  Timer? _scrollDebounce;
  Timer? _navStopTimer;
  Timer? _suggestionTimer;
  int _suggestionRefreshCount = 0;

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

    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 150), () {
      if (pos.pixels >= pos.maxScrollExtent - 700 && !_isLoadingMore) {
        final notifier = ref.read(feedProvider.notifier);
        if (!ref.read(feedProvider).isLoading && notifier.hasMore) {
          _isLoadingMore = true;
          notifier.loadMore().whenComplete(() {
            if (mounted) _isLoadingMore = false;
          });
        }
      }

      final dir = pos.userScrollDirection;
      final navVisible = ref.read(_navVisibleProvider.notifier);

      if (dir == ScrollDirection.reverse) {
        if (navVisible.state) navVisible.state = false;
      } else if (dir == ScrollDirection.forward) {
        if (!navVisible.state) navVisible.state = true;
      }
    });

    // Réapparition automatique de la navbar dès que le scroll s'arrête
    _navStopTimer?.cancel();
    _navStopTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        final navVisible = ref.read(_navVisibleProvider.notifier);
        if (!navVisible.state) navVisible.state = true;
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

      final currentSuggestions = ref.read(_suggestionsProvider);
      final merged = [...currentSuggestions, ...data].take(_maxSuggestions).toList();
      ref.read(_suggestionsProvider.notifier).state = merged;

      _shuffleSuggestions();

      _suggestionTimer?.cancel();
      if (_suggestionRefreshCount < _maxSuggestionRefreshes) {
        _suggestionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          _suggestionRefreshCount++;
          if (_suggestionRefreshCount >= _maxSuggestionRefreshes) {
            _suggestionTimer?.cancel();
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
    _safePush('/network/comments/$postId');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _navStopTimer?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  Widget _buildGradientOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
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
    final l10n = AppLocalizations.of(context);
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
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Stack(
          children: [
            // Orbes de fond subtiles
            Positioned(top: -80, right: -40, child: _buildGradientOrb(ThixPolicy.primary, 240)),
            Positioned(bottom: 180, left: -80, child: _buildGradientOrb(ThixPolicy.primaryDeep, 280)),

            RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: ThixPolicy.card,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(l10n, avatarUrl: currentUser.photoUrl, currentUserId: currentUser.id),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: _QuickPostEntryCard(
                        l10n: l10n,
                        avatarUrl: currentUser.photoUrl,
                        onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: _buildStories(l10n, currentUser.id, liveHostIds)),
                  SliverToBoxAdapter(child: _buildFilters(l10n)),

                  if (ref.watch(_suggestionsProvider).isNotEmpty || liveSessions.isNotEmpty)
                    SliverToBoxAdapter(child: _buildUnifiedDiscoveryBand(l10n, liveSessions)),

                  feedAsync.when(
                    loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            l10n.t('network_error_generic', args: [e.toString()]),
                            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger),
                          ),
                        ),
                      ),
                    ),
                    data: (posts) {
                      if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty(l10n));
                      // ✅ ESPACEMENT : le Divider doré qui suivait chaque
                      // PostCard a été retiré — PostCard dessine désormais
                      // lui-même sa bordure or de séparation en bas (voir
                      // post_card.dart). Le garder ici aurait doublé la
                      // ligne et rajouté de l'espace vertical entre cartes.
                      // `isFirst: i == 0` marque la coupure avec le haut du feed.
                      return SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (c, i) {
                          final post = posts[i];
                          return PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            currentProfileId: currentUser.id,
                            isFirst: i == 0,
                            onLike: null,
                            onComment: () => _openComments(post.id),
                            onShare: () => _showShareSheet(l10n, post),
                            onDelete: () => ref.read(feedProvider.notifier).deletePost(post.id),
                            onRefresh: null,
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
                  child: _buildBottomNav(l10n, visible),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(AppLocalizations l10n, {required String? avatarUrl, required String currentUserId}) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      toolbarHeight: 58,
      titleSpacing: 16,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.white.withValues(alpha: 0.75),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1)),
            ),
          ),
        ),
      ),
      title: Text(
        'THIX PRO',
        style: ThixPolicy.h2Style.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: ThixPolicy.textMain, fontSize: 18),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePrepScreen())),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThixPolicy.danger.withValues(alpha: 0.1),
              border: Border.all(color: ThixPolicy.danger.withValues(alpha: 0.3), width: 1),
            ),
            child: const Icon(Icons.sensors_rounded, size: 18, color: ThixPolicy.danger),
          ),
        ),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.search_rounded, onTap: () => _safePush('/network/search')),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.notifications_none_rounded, onTap: () => _safePush('/network/notifications')),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => _safePush('/network/profile/$currentUserId'),
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 17, color: ThixPolicy.textMain),
      ),
    );
  }

  Widget _buildStories(AppLocalizations l10n, String currentUserId, Set<String> liveHostIds) {
    final loadingStories = ref.watch(_loadingStoriesProvider);
    final stories = ref.watch(_storiesProvider);

    if (loadingStories) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        height: 120,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
        ),
      );
    }

    final myStories = stories.where((s) => s.userId == currentUserId).toList();
    final Map<String, List<NetworkStory>> groupedOtherStories = {};
    for (final s in stories) {
      if (s.userId != currentUserId) {
        groupedOtherStories.putIfAbsent(s.userId, () => []).add(s);
      }
    }
    final otherUsersList = groupedOtherStories.keys.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 120,
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
                name: myStories.isNotEmpty ? l10n.t('network_your_story') : l10n.t('network_create'),
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

  Widget _buildFilters(AppLocalizations l10n) {
    final feedType = ref.watch(_feedTypeProvider);
    final filters = {
      'foryou': l10n.t('network_filter_foryou'),
      'network': l10n.t('network_filter_network'),
      'recent': l10n.t('network_filter_recent'),
      'popular': l10n.t('network_filter_popular'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? ThixPolicy.textMain : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: active ? ThixPolicy.textMain : Colors.white.withValues(alpha: 0.9), width: 1),
                  boxShadow: active
                      ? []
                      : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                ),
                child: Text(
                  e.value,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? Colors.white : ThixPolicy.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUnifiedDiscoveryBand(AppLocalizations l10n, List<Map<String, dynamic>> liveSessions) {
    final suggestions = ref.watch(_suggestionsProvider);
    final int totalCount = suggestions.length + liveSessions.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.explore_rounded, size: 14, color: ThixPolicy.primary),
                ),
                const SizedBox(width: 8),
                Text(l10n.t('network_discover_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 13.5, color: ThixPolicy.textMain)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: totalCount,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (c, i) {
                if (i < suggestions.length) {
                  final u = suggestions[i];
                  return GestureDetector(
                    onTap: () => context.push('/network/profile/${u.id}'),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              RoundAvatar(size: 52, imageUrl: u.avatar),
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
                                    decoration: BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.add, size: 10, color: Colors.white),
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
                            style: ThixPolicy.microStyle.copyWith(fontWeight: FontWeight.w700, color: ThixPolicy.textMain, fontSize: 11),
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
                        hostName: s['host_name']?.toString() ?? 'Hôte',
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
                      width: 60,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              RoundAvatar(size: 52, imageUrl: s['host_avatar']?.toString(), isLive: true),
                              Positioned(
                                bottom: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1.2)),
                                  child: Text('LIVE', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (s['host_name']?.toString() ?? 'Hôte').split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.microStyle.copyWith(fontWeight: FontWeight.w700, color: ThixPolicy.textMain, fontSize: 11),
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
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          height: 180,
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(50),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.textMuted.withValues(alpha: 0.3))),
            child: const Icon(Icons.feed_outlined, size: 28, color: ThixPolicy.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(l10n.t('network_empty_feed'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.textMain,
              side: const BorderSide(color: ThixPolicy.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white.withValues(alpha: 0.5),
            ),
            child: Text(l10n.t('common_refresh')),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(AppLocalizations l10n, dynamic post) {
    final id = '${post.id}';
    final link = 'https://thix.id/network/post/$id';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _Glass(
        radius: 24,
        alpha: 0.95,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.link_rounded, color: ThixPolicy.primary, size: 20),
                ),
                title: Text(l10n.t('network_copy_link'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  try {
                    await ref.read(networkServiceProvider).sharePost(id);
                  } catch (e) {
                    debugPrint('[Share] Error: $e');
                  }
                  if (mounted) Navigator.pop(context);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('network_link_copied')), behavior: SnackBarBehavior.floating));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ThixPolicy.textMuted.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary, size: 20),
                ),
                title: Text(l10n.t('common_close'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontSize: 14)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // Barre de navigation basse amincie et réactive au scroll stop
  Widget _buildBottomNav(AppLocalizations l10n, bool visible) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: _Glass(
                radius: 28,
                alpha: 0.88,
                blur: 14,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: SizedBox(
                  height: 50, // Hauteur réduite et optimisée
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navBtn(Icons.home_rounded, l10n.t('network_nav_home'), true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                      _navBtn(Icons.explore_outlined, l10n.t('network_nav_discover'), false, () => _safePush('/network/discover')),

                      // FAB Central compact et élégant
                      Semantics(
                        button: true,
                        label: l10n.t('network_nav_post'),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            showDialog(context: context, builder: (_) => const CreatePostDialog());
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [ThixPolicy.primary, ThixPolicy.primaryDeep]),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: ThixPolicy.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),

                      _navBtn(Icons.mail_outline_rounded, l10n.t('network_nav_messages'), false, () => _safePush('/network/messages')),
                      _navBtn(Icons.diversity_3_outlined, l10n.t('network_nav_communities'), false, () => _safePush('/network/communities')),
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
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          tap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? ThixPolicy.primary.withValues(alpha: 0.1) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            ic,
            size: 21,
            color: active ? ThixPolicy.primary : ThixPolicy.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _QuickPostEntryCard extends StatelessWidget {
  final AppLocalizations l10n;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _QuickPostEntryCard({required this.l10n, required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          RoundAvatar(size: 38, imageUrl: avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: Text(
                  l10n.t('network_quick_post_hint'),
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThixPolicy.primary.withValues(alpha: 0.1),
            ),
            child: IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.image_rounded, color: ThixPolicy.primary, size: 20),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
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
        width: 82,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLive ? ThixPolicy.danger : Colors.white.withValues(alpha: 0.85),
            width: isLive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: RoundAvatar(size: 26, imageUrl: avatarUrl, isLive: isLive),
            ),
            if (isMe)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 6,
              right: 6,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
