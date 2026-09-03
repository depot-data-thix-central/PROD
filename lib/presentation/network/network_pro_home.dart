/// NetworkProHome — "Community Glass" Design
///
/// Inspiré des apps communautaires modernes (chaleureux, éditorial)
/// mais supérieur : sections data-driven, glassmorphism maîtrisé,
/// a11y/i18n/perf complets.
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/network_story.dart';

import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kRefreshCooldown = Duration(seconds: 60);
const Duration _kScrollDebounce = Duration(milliseconds: 200);
const Duration _kTapThrottle = Duration(milliseconds: 300);
const Duration _kSuggestionRefreshInterval = Duration(minutes: 1);
const Duration _kNetworkTimeout = Duration(seconds: 15);
const double _kGlassBlur = kIsWeb ? 8 : 14;

const int _kMaxSuggestions = 100;
const int _kMaxSuggestionRefreshes = 10;
const int _kScrollLoadMoreThreshold = 700;

// ============================================================================
// LOGGING
// ============================================================================

class _NetworkLogger {
  static const _tag = 'NetworkPro';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// PROVIDERS (inchangés)
// ============================================================================

final _storiesProvider = StateProvider<List<NetworkStory>>((ref) => []);
final _loadingStoriesProvider = StateProvider<bool>((ref) => true);
final _feedTypeProvider = StateProvider<String>((ref) => 'foryou');
final _suggestionsProvider = StateProvider<List<dynamic>>((ref) => []);
final _navVisibleProvider = StateProvider<bool>((ref) => true);

final activeLiveSessionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  try {
    await for (final data in Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(10)) {
      yield data;
    }
  } catch (e) {
    _NetworkLogger.error('Live stream error', {'error': '$e'});
    yield const <Map<String, dynamic>>[];
  }
});

// ============================================================================
// GLASS SURFACE (réutilisable, maîtrisé)
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
    this.alpha = 0.65,
    this.blur = _kGlassBlur,
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
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.7), width: 1),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.inkDeep.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
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
// PAGE
// ============================================================================

class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});

  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  DateTime? _lastRefreshTime;
  bool _isLoadingMore = false;
  Timer? _scrollDebounce;
  Timer? _suggestionTimer;
  int _suggestionRefreshCount = 0;
  DateTime? _lastTap;
  bool _isInitializing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    _NetworkLogger.info('Page initialized');
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      return false;
    }
    _lastTap = now;
    return true;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(_kScrollDebounce, () {
      if (!mounted) return;

      if (pos.pixels >= pos.maxScrollExtent - _kScrollLoadMoreThreshold &&
          !_isLoadingMore) {
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
      if (dir == ScrollDirection.reverse && ref.read(_navVisibleProvider)) {
        navVisible.state = false;
      } else if (dir == ScrollDirection.forward &&
          !ref.read(_navVisibleProvider)) {
        navVisible.state = true;
      }
    });
  }

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      final now = DateTime.now();
      final needsRefresh = _lastRefreshTime == null ||
          now.difference(_lastRefreshTime!) > _kRefreshCooldown;

      final feedType = ref.read(_feedTypeProvider);
      await ref
          .read(feedProvider.notifier)
          .loadFeed(feedType: feedType, force: needsRefresh);
      if (needsRefresh) _lastRefreshTime = now;

      await Future.wait([_loadStories(), _loadSuggestions()]);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadStories() async {
    try {
      final data = await ref
          .read(networkServiceProvider)
          .getActiveStories()
          .timeout(_kNetworkTimeout);
      if (!mounted) return;
      ref.read(_storiesProvider.notifier).state = data;
      ref.read(_loadingStoriesProvider.notifier).state = false;
    } catch (e) {
      _NetworkLogger.error('Stories failed', {'error': '$e'});
      if (mounted) ref.read(_loadingStoriesProvider.notifier).state = false;
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref
          .read(networkServiceProvider)
          .getSuggestedConnections(limit: 30)
          .timeout(_kNetworkTimeout);
      if (!mounted) return;

      final merged = [...ref.read(_suggestionsProvider), ...data]
          .take(_kMaxSuggestions)
          .toList();
      ref.read(_suggestionsProvider.notifier).state = merged;
      _shuffleSuggestions();

      _suggestionTimer?.cancel();
      if (_suggestionRefreshCount < _kMaxSuggestionRefreshes) {
        _suggestionTimer = Timer.periodic(_kSuggestionRefreshInterval, (_) {
          if (!mounted) {
            _suggestionTimer?.cancel();
            return;
          }
          _suggestionRefreshCount++;
          if (_suggestionRefreshCount >= _kMaxSuggestionRefreshes) {
            _suggestionTimer?.cancel();
          } else {
            _shuffleSuggestions();
          }
        });
      }
    } catch (e) {
      _NetworkLogger.error('Suggestions failed', {'error': '$e'});
    }
  }

  void _shuffleSuggestions() {
    final s = ref.read(_suggestionsProvider);
    if (s.isEmpty || !mounted) return;
    final list = List<dynamic>.from(s)..shuffle(Random());
    ref.read(_suggestionsProvider.notifier).state = list.take(10).toList();
  }

  Future<void> _onRefresh() async {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    final feedType = ref.read(_feedTypeProvider);
    await ref.read(feedProvider.notifier).loadFeed(feedType: feedType, force: true);
    _lastRefreshTime = DateTime.now();
    _suggestionRefreshCount = 0;
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
  }

  Future<void> _openCreateStory() async {
    if (!_throttle()) return;
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const CreateStoryDialog());
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
    }
  }

  void _safePush(String path) {
    if (!mounted || !_throttle()) return;
    try {
      context.push(path);
    } catch (e) {
      _NetworkLogger.error('Nav failed', {'path': path, 'error': '$e'});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h < 12) return 'network_greeting_morning';
    if (h < 18) return 'network_greeting_afternoon';
    return 'network_greeting_evening';
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final authAsync = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUser = authAsync.value;

    final liveSessions = ref.watch(activeLiveSessionsProvider).value ?? const [];
    final liveHostIds = liveSessions
        .map((s) => s['host_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final posts = feedAsync.valueOrNull ?? [];

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final firstName = (currentUser.fullName ?? currentUser.username ?? '')
        .split(' ')
        .first;

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
            _backgroundDecor(),
            RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: ThixPolicy.card,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildGreetingHeader(l10n, currentUser, firstName),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCreatorsRow(l10n, currentUser.id, liveHostIds),
                  ),
                  SliverToBoxAdapter(child: _buildSearchBar(l10n)),
                  SliverToBoxAdapter(child: _buildCategoryChips(l10n)),
                  if (posts.isNotEmpty) ...[
                    SliverToBoxAdapter(
                        child: RepaintBoundary(child: _buildFeaturedCard(l10n, posts))),
                    SliverToBoxAdapter(
                        child: RepaintBoundary(child: _buildPopularGrid(l10n, posts))),
                  ],
                  if (ref.watch(_suggestionsProvider).isNotEmpty)
                    SliverToBoxAdapter(
                        child: RepaintBoundary(child: _buildCommunitiesRow(l10n))),
                  SliverToBoxAdapter(
                      child: _buildFeedHeader(l10n)),
                  feedAsync.when(
                    loading: () =>
                        SliverToBoxAdapter(child: RepaintBoundary(child: _buildShimmer())),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            l10n.t('network_error_generic', args: [e.toString()]),
                            style: ThixPolicy.bodyStyle
                                .copyWith(color: ThixPolicy.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    data: (feedPosts) {
                      if (feedPosts.isEmpty) {
                        return SliverToBoxAdapter(child: _buildEmpty(l10n));
                      }
                      return SliverList.builder(
                        itemCount: feedPosts.length,
                        itemBuilder: (c, i) {
                          final post = feedPosts[i];
                          return RepaintBoundary(
                            child: PostCard(
                              key: ValueKey(post.id),
                              post: post,
                              currentProfileId: currentUser.id,
                              onLike: null,
                              onComment: () => _safePush('/network/comments/${post.id}'),
                              onShare: () => _showShareSheet(l10n, post),
                              onDelete: () => ref
                                  .read(feedProvider.notifier)
                                  .deletePost(post.id),
                              onRefresh: null,
                            ),
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
                  child: _buildBottomNav(l10n, visible, currentUser),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SECTIONS
  // ════════════════════════════════════════════════════════════════════

  Widget _backgroundDecor() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ThixPolicy.primary.withValues(alpha: 0.06),
                Colors.transparent,
              ],
              stops: const [0, 0.4],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(l10n, currentUser, String firstName) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _safePush('/network/profile/${currentUser.id}'),
              child: _ringAvatar(
                  url: currentUser.photoUrl, isLive: false, size: 44),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.t(_greetingKey())}, $firstName 👋',
                    style: ThixPolicy.h2Style.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ThixPolicy.textMain,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.t('network_greeting_subtitle'),
                    style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _glassIconButton(
              icon: Icons.notifications_none_rounded,
              label: l10n.t('network_notifications'),
              onTap: () => _safePush('/network/notifications'),
              badge: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorsRow(l10n, String currentUserId, Set<String> liveHostIds) {
    final loading = ref.watch(_loadingStoriesProvider);
    final stories = ref.watch(_storiesProvider);
    final myStories = stories.where((s) => s.userId == currentUserId).toList();
    final others = stories.where((s) => s.userId != currentUserId).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _sectionHeader(
            l10n.t('network_creators_follow'),
            l10n.t('network_see_all'),
            () => _safePush('/network/creators'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: loading
                ? const Center(child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: others.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (c, i) {
                      if (i == 0) {
                        return _creatorItem(
                          name: l10n.t('network_your_story'),
                          url: myStories.isNotEmpty
                              ? myStories.first.userAvatar
                              : null,
                          isMe: true,
                          isLive: liveHostIds.contains(currentUserId),
                          onTap: myStories.isNotEmpty
                              ? () => _safePush('/network/stories/view')
                              : _openCreateStory,
                        );
                      }
                      final s = others[i - 1];
                      return _creatorItem(
                        name: s.userName.split(' ').first,
                        url: s.userAvatar,
                        isLive: liveHostIds.contains(s.userId),
                        onTap: () => _safePush('/network/stories/view'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _creatorItem({
    required String name,
    String? url,
    bool isMe = false,
    bool isLive = false,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _ringAvatar(url: url, isLive: isLive, size: 58),
                  if (isMe)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ThixPolicy.textMain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ringAvatar({String? url, required bool isLive, required double size}) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLive
              ? [ThixPolicy.danger, ThixPolicy.warning]
              : [ThixPolicy.primary, ThixPolicy.gold],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: ThixPolicy.card),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: ThixPolicy.surfaceSoft,
          backgroundImage:
              (url != null && url.isNotEmpty) ? CachedNetworkImageProvider(url) : null,
          child: (url == null || url.isEmpty)
              ? Icon(Icons.person_rounded,
                  size: size * 0.5, color: ThixPolicy.textMuted)
              : null,
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: _Glass(
          radius: 14,
          alpha: 0.6,
          blur: 10,
          padding: const EdgeInsets.all(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: ThixPolicy.textMain),
              if (badge)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _Glass(
        radius: 16,
        alpha: 0.6,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: ThixPolicy.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('network_search_hint'),
                style: ThixPolicy.bodyStyle.copyWith(
                    color: ThixPolicy.textMuted, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    ).addGestureRecognizer?.call ?? GestureDetector(
      onTap: () => _safePush('/network/search'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _Glass(
          radius: 16,
          alpha: 0.6,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: ThixPolicy.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('network_search_hint'),
                  style: ThixPolicy.bodyStyle.copyWith(
                      color: ThixPolicy.textMuted, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(l10n) {
    final feedType = ref.watch(_feedTypeProvider);
    final filters = {
      'foryou': l10n.t('network_filter_foryou'),
      'network': l10n.t('network_filter_network'),
      'recent': l10n.t('network_filter_recent'),
      'popular': l10n.t('network_filter_popular'),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (c, i) {
            final e = filters.entries.elementAt(i);
            final active = feedType == e.key;
            return Semantics(
              button: true,
              selected: active,
              label: e.value,
              child: GestureDetector(
                onTap: () {
                  if (active || !_throttle()) return;
                  HapticFeedback.lightImpact();
                  ref.read(_feedTypeProvider.notifier).state = e.key;
                  ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? ThixPolicy.danger : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? ThixPolicy.danger : Colors.white.withValues(alpha: 0.8)),
                  ),
                  child: Text(
                    e.value,
                    style: ThixPolicy.labelStyle.copyWith(
                      color: active ? Colors.white : ThixPolicy.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(l10n, List posts) {
    final featured = posts.firstWhere(
      (p) => p.hasImages || p.hasVideos,
      orElse: () => posts.first,
    );
    final cover = featured.imageUrls.isNotEmpty ? featured.imageUrls.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: _Glass(
        radius: 24,
        alpha: 0.0,
        blur: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (cover != null)
                CachedNetworkImage(
                  imageUrl: cover,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              else
                Container(height: 240, color: ThixPolicy.primary.withValues(alpha: 0.2)),
              // Overlay gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        ThixPolicy.inkDeep.withValues(alpha: 0.85),
                      ],
                      stops: const [0.4, 1],
                    ),
                  ),
                ),
              ),
              // Badge À LA UNE (glass)
              Positioned(
                top: 14,
                left: 14,
                child: _Glass(
                  radius: 20,
                  alpha: 0.25,
                  blur: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    l10n.t('network_featured'),
                    style: ThixPolicy.captionStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
              // Contenu bas
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featured.content.isNotEmpty
                          ? featured.content.split('\n').first
                          : featured.authorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.titleStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // CTA Explorer (glass)
                        GestureDetector(
                          onTap: () => _safePush('/network/comments/${featured.id}'),
                          child: _Glass(
                            radius: 20,
                            alpha: 0.25,
                            blur: 10,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.t('network_explore_cta'),
                                  style: ThixPolicy.labelStyle.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(featured.viewCount),
                              style: ThixPolicy.captionStyle.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularGrid(l10n, List posts) {
    final popular = [...posts]
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final top = popular.take(4).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          _sectionHeader(
            l10n.t('network_popular_now'),
            l10n.t('network_see_all'),
            () => _safePush('/network/discover'),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: top.length,
            itemBuilder: (c, i) {
              final p = top[i];
              final cover = p.imageUrls.isNotEmpty ? p.imageUrls.first : null;
              return Semantics(
                button: true,
                label: p.authorName,
                child: GestureDetector(
                  onTap: () => _safePush('/network/comments/${p.id}'),
                  child: _Glass(
                    radius: 18,
                    alpha: 0.0,
                    blur: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cover != null)
                            CachedNetworkImage(
                                imageUrl: cover, fit: BoxFit.cover)
                          else
                            Container(color: ThixPolicy.surfaceSoft),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    ThixPolicy.inkDeep.withValues(alpha: 0.8),
                                  ],
                                  stops: const [0.5, 1],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ThixPolicy.captionStyle.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.remove_red_eye_outlined,
                                        size: 12, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_formatCount(p.viewCount)} ${l10n.t("network_views")}',
                                      style: ThixPolicy.captionStyle.copyWith(
                                          color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitiesRow(l10n) {
    final suggestions = ref.watch(_suggestionsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          _sectionHeader(
            l10n.t('network_communities'),
            l10n.t('network_see_all'),
            () => _safePush('/network/communities'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final u = suggestions[i];
                return _Glass(
                  radius: 16,
                  alpha: 0.6,
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 150,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: ThixPolicy.surfaceSoft,
                          backgroundImage: u.avatar != null
                              ? CachedNetworkImageProvider(u.avatar)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                u.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ThixPolicy.captionStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: ThixPolicy.textMain),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  ref.read(_suggestionsProvider.notifier).state =
                                      suggestions.where((s) => s.id != u.id).toList();
                                  try {
                                    await ref
                                        .read(networkServiceProvider)
                                        .sendConnectionRequest(u.id);
                                  } catch (e) {
                                    _NetworkLogger.error('Connect failed',
                                        {'error': '$e'});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.danger,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+ ${l10n.t("network_connect")}',
                                    style: ThixPolicy.captionStyle.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedHeader(l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: _sectionHeader(l10n.t('network_feed_title'), null, null),
    );
  }

  Widget _sectionHeader(String title, String? action, VoidCallback? onAction) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ThixPolicy.textMain),
            ),
          ),
          if (action != null && onAction != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onAction();
              },
              child: Text(
                action,
                style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.danger, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(l10n) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: ThixPolicy.textMuted),
          const SizedBox(height: 16),
          Text(l10n.t('network_empty_feed'),
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _onRefresh,
            child: Text(l10n.t('common_refresh')),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  void _showShareSheet(l10n, dynamic post) {
    if (!_throttle()) return;
    final link = 'https://thix.id/network/post/${post.id}';
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
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.link, color: ThixPolicy.textMain),
                title: Text(l10n.t('network_copy_link')),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: ThixPolicy.textSecondary),
                title: Text(l10n.t('common_close')),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(l10n, bool visible, currentUser) {
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _Glass(
                radius: 32,
                alpha: 0.85,
                blur: _kGlassBlur,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navBtn(Icons.home_rounded, l10n.t('network_nav_home'), true,
                          () => _scrollController.animateTo(0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut)),
                      _navBtn(Icons.explore_outlined,
                          l10n.t('network_nav_discover'), false,
                          () => _safePush('/network/discover')),
                      // FAB central
                      Semantics(
                        button: true,
                        label: l10n.t('network_nav_post'),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            showDialog(
                                context: context,
                                builder: (_) => const CreatePostDialog());
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [ThixPolicy.danger, ThixPolicy.warning],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: ThixPolicy.danger.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                      _navBtn(Icons.mail_outline_rounded,
                          l10n.t('network_nav_messages'), false,
                          () => _safePush('/network/messages')),
                      _navBtn(Icons.person_outline_rounded,
                          l10n.t('network_nav_profile'), false,
                          () => _safePush('/network/profile/${currentUser.id}')),
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
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          tap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ic,
                  size: 22,
                  color: active
                      ? ThixPolicy.primary
                      : ThixPolicy.textSecondary.withValues(alpha: 0.7)),
              const SizedBox(height: 2),
              Text(
                label,
                style: ThixPolicy.microStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? ThixPolicy.primary
                        : ThixPolicy.textSecondary.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
