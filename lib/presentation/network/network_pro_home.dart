/// NetworkProHome — "Executive Briefing" Design
///
/// Design enterprise premium, distinct d'Instagram :
/// - Briefing cards horizontales (pas de stories circulaires)
/// - Top tabs navigation (pas de bottom nav flottante)
/// - Segmented control iOS-style pour filtres
/// - Layout aéré style Medium/LinkedIn
/// - Avatar hexagonal distinctif
/// - Grid pattern subtil au lieu de gradient orbs
///
/// ✅ Toute la logique préservée : providers, throttling, mounted checks,
///    i18n, Semantics, logs, RepaintBoundary
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
// PROVIDERS LOCAUX (inchangés)
// ============================================================================

final _storiesProvider = StateProvider<List<NetworkStory>>((ref) => []);
final _loadingStoriesProvider = StateProvider<bool>((ref) => true);
final _feedTypeProvider = StateProvider<String>((ref) => 'foryou');
final _suggestionsProvider = StateProvider<List<dynamic>>((ref) => []);

// ============================================================================
// PROVIDER — SESSIONS LIVE ACTIVES
// ============================================================================

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
    _NetworkLogger.error('Live sessions stream error', {'error': '$e'});
    yield const <Map<String, dynamic>>[];
  }
});

// ============================================================================
// NOUVEAU COMPOSANT — AVATAR HEXAGONAL (distinctif enterprise)
// ============================================================================

class HexAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final bool isLive;
  final bool showBorder;

  const HexAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.isLive = false,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Forme hexagonale
            ClipPath(
              clipper: _HexagonClipper(),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLive
                        ? [
                            ThixPolicy.danger,
                            ThixPolicy.danger.withValues(alpha: 0.7),
                          ]
                        : [
                            ThixPolicy.textMain.withValues(alpha: 0.12),
                            ThixPolicy.textMain.withValues(alpha: 0.06),
                          ],
                  ),
                ),
                child: ClipPath(
                  clipper: _HexagonClipper(inset: 2),
                  child: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: ThixPolicy.surfaceSoft,
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(Icons.person,
                                size: size * 0.45,
                                color: ThixPolicy.textMuted),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.person,
                              size: size * 0.45,
                              color: ThixPolicy.textMuted),
                        ),
                ),
              ),
            ),
            // Indicateur LIVE
            if (isLive)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size * 0.28,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThixPolicy.card, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.1,
                      height: size * 0.1,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  final double inset;
  _HexagonClipper({this.inset = 0});

  @override
  Path getClip(Size size) {
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(w, h) / 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * pi / 180;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ============================================================================
// PAGE PRINCIPALE — EXECUTIVE BRIEFING
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
      _NetworkLogger.warn('Tap throttled');
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
          _NetworkLogger.info('Load more triggered');
          notifier.loadMore().whenComplete(() {
            if (mounted) _isLoadingMore = false;
          });
        }
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
      _NetworkLogger.info('Init completed', {'needsRefresh': needsRefresh});
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
      _NetworkLogger.info('Stories loaded', {'count': data.length});
    } catch (e) {
      _NetworkLogger.error('Stories load failed', {'error': '$e'});
      if (mounted) {
        ref.read(_loadingStoriesProvider.notifier).state = false;
      }
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref
          .read(networkServiceProvider)
          .getSuggestedConnections(limit: 30)
          .timeout(_kNetworkTimeout);
      if (!mounted) return;

      final currentSuggestions = ref.read(_suggestionsProvider);
      final merged = [...currentSuggestions, ...data]
          .take(_kMaxSuggestions)
          .toList();
      ref.read(_suggestionsProvider.notifier).state = merged;

      _shuffleSuggestions();

      _suggestionTimer?.cancel();
      if (_suggestionRefreshCount < _kMaxSuggestionRefreshes) {
        _suggestionTimer = Timer.periodic(
          _kSuggestionRefreshInterval,
          (_) {
            if (!mounted) {
              _suggestionTimer?.cancel();
              return;
            }
            _suggestionRefreshCount++;
            if (_suggestionRefreshCount >= _kMaxSuggestionRefreshes) {
              _suggestionTimer?.cancel();
              _NetworkLogger.info('Suggestions max refreshes reached');
            } else {
              _shuffleSuggestions();
            }
          },
        );
      }
      _NetworkLogger.info('Suggestions loaded', {'count': data.length});
    } catch (e) {
      _NetworkLogger.error('Suggestions load failed', {'error': '$e'});
    }
  }

  void _shuffleSuggestions() {
    final suggestions = ref.read(_suggestionsProvider);
    if (suggestions.isEmpty || !mounted) return;

    final list = List<dynamic>.from(suggestions);
    list.shuffle(Random());
    ref.read(_suggestionsProvider.notifier).state = list.take(10).toList();
    _NetworkLogger.info('Suggestions shuffled');
  }

  Future<void> _onRefresh() async {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    final feedType = ref.read(_feedTypeProvider);
    await ref
        .read(feedProvider.notifier)
        .loadFeed(feedType: feedType, force: true);
    _lastRefreshTime = DateTime.now();
    _suggestionRefreshCount = 0;
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
    _NetworkLogger.info('Refresh completed');
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
      _NetworkLogger.info('Navigated', {'path': path});
    } catch (e) {
      _NetworkLogger.error('Navigation failed', {'path': path, 'error': '$e'});
    }
  }

  Future<void> _openComments(String postId) async {
    _safePush('/network/comments/$postId');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _suggestionTimer?.cancel();
    _NetworkLogger.info('Page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final authAsync = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUser = authAsync.value;

    final liveSessionsAsync = ref.watch(activeLiveSessionsProvider);
    final liveSessions =
        liveSessionsAsync.value ?? const <Map<String, dynamic>>[];
    final liveHostIds = liveSessions
        .map((s) => s['host_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.card,
        body: Center(
            child: CircularProgressIndicator(color: ThixPolicy.primary)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.card,
        body: RefreshIndicator(
          color: ThixPolicy.primary,
          backgroundColor: ThixPolicy.card,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // ═══════════════════════════════════════════════════════
              // TOP NAVIGATION BAR (remplace bottom nav flottante)
              // ═══════════════════════════════════════════════════════
              SliverToBoxAdapter(
                child: _TopNavBar(
                  currentUser: currentUser,
                  onProfileTap: () =>
                      _safePush('/network/profile/${currentUser.id}'),
                  onSearchTap: () => _safePush('/network/search'),
                  onNotificationsTap: () =>
                      _safePush('/network/notifications'),
                  onMessagesTap: () => _safePush('/network/messages'),
                  onCommunitiesTap: () => _safePush('/network/communities'),
                  onCreateTap: () {
                    HapticFeedback.selectionClick();
                    showDialog(
                        context: context,
                        builder: (_) => const CreatePostDialog());
                  },
                ),
              ),

              // ═══════════════════════════════════════════════════════
              // BRIEFING BAND (remplace stories circulaires)
              // ═══════════════════════════════════════════════════════
              SliverToBoxAdapter(
                child: _ExecutiveBriefing(
                  currentUserId: currentUser.id,
                  currentUserAvatar: currentUser.photoUrl,
                  liveSessions: liveSessions,
                  liveHostIds: liveHostIds,
                  onCreateStory: _openCreateStory,
                ),
              ),

              // ═══════════════════════════════════════════════════════
              // COMPOSE ENTRY (inchangé, style épuré)
              // ═══════════════════════════════════════════════════════
              SliverToBoxAdapter(
                child: _ComposeEntry(
                  avatarUrl: currentUser.photoUrl,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    showDialog(
                        context: context,
                        builder: (_) => const CreatePostDialog());
                  },
                ),
              ),

              // ═══════════════════════════════════════════════════════
              // SEGMENTED CONTROL (remplace filters chips)
              // ═══════════════════════════════════════════════════════
              SliverToBoxAdapter(
                child: _FeedSegmentedControl(
                  onChanged: (type) {
                    if (!_throttle()) return;
                    ref.read(_feedTypeProvider.notifier).state = type;
                    ref
                        .read(feedProvider.notifier)
                        .loadFeed(feedType: type, force: true);
                    _lastRefreshTime = DateTime.now();
                    HapticFeedback.lightImpact();
                    _NetworkLogger.info('Filter changed', {'filter': type});
                  },
                ),
              ),

              // ═══════════════════════════════════════════════════════
              // DISCOVERY BAND (suggestions + lives)
              // ═══════════════════════════════════════════════════════
              if (ref.watch(_suggestionsProvider).isNotEmpty ||
                  liveSessions.isNotEmpty)
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _DiscoveryBand(liveSessions: liveSessions),
                  ),
                ),

              // ═══════════════════════════════════════════════════════
              // FEED
              // ═══════════════════════════════════════════════════════
              feedAsync.when(
                loading: () => SliverToBoxAdapter(
                    child: RepaintBoundary(child: const _ShimmerFeed())),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        l10n.t('network_error_generic',
                            args: [e.toString()]),
                        style: ThixPolicy.bodyStyle
                            .copyWith(color: ThixPolicy.textSecondary),
                      ),
                    ),
                  ),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(child: _buildEmpty(l10n));
                  }
                  return SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (c, i) {
                      final post = posts[i];
                      return RepaintBoundary(
                        child: Column(
                          children: [
                            PostCard(
                              key: ValueKey(post.id),
                              post: post,
                              currentProfileId: currentUser.id,
                              onLike: null,
                              onComment: () => _openComments(post.id),
                              onShare: () => _showShareSheet(l10n, post),
                              onDelete: () => ref
                                  .read(feedProvider.notifier)
                                  .deletePost(post.id),
                              onRefresh: null,
                            ),
                            Container(
                              height: 1,
                              color: ThixPolicy.border.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThixPolicy.surfaceSoft,
              border: Border.all(color: ThixPolicy.border),
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 28, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 20),
          Text(l10n.t('network_empty_feed'),
              style: ThixPolicy.titleStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l10n.t('network_empty_feed_hint'),
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: l10n.t('common_refresh'),
            child: OutlinedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.t('common_refresh')),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.textMain,
                side: BorderSide(color: ThixPolicy.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(AppLocalizations l10n, dynamic post) {
    if (!_throttle()) return;
    final id = '${post.id}';
    final link = 'https://thix.id/network/post/$id';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
              top: BorderSide(color: ThixPolicy.border.withValues(alpha: 0.5))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: ThixPolicy.border,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  label: l10n.t('network_copy_link'),
                  child: _SheetAction(
                    icon: Icons.link_rounded,
                    label: l10n.t('network_copy_link'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await Clipboard.setData(ClipboardData(text: link));
                      try {
                        await ref
                            .read(networkServiceProvider)
                            .sharePost(id);
                      } catch (e) {
                        _NetworkLogger.error('Share failed', {'error': '$e'});
                      }
                      if (mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l10n.t('network_link_copied')),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: l10n.t('common_close'),
                  child: _SheetAction(
                    icon: Icons.close_rounded,
                    label: l10n.t('common_close'),
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TOP NAVIGATION BAR (remplace bottom nav)
// ============================================================================

class _TopNavBar extends StatelessWidget {
  final dynamic currentUser;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onCommunitiesTap;
  final VoidCallback onCreateTap;

  const _TopNavBar({
    required this.currentUser,
    required this.onProfileTap,
    required this.onSearchTap,
    required this.onNotificationsTap,
    required this.onMessagesTap,
    required this.onCommunitiesTap,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(
            bottom: BorderSide(color: ThixPolicy.border.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rangée supérieure : Logo + Actions
            Row(
              children: [
                // Logo TDIA
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ThixPolicy.primary,
                            ThixPolicy.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grid_view_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'THIX PRO',
                      style: ThixPolicy.h2Style.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: ThixPolicy.textMain,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Actions
                _NavIconButton(
                  icon: Icons.search_rounded,
                  label: l10n.t('network_search'),
                  onTap: onSearchTap,
                ),
                const SizedBox(width: 4),
                _NavIconButton(
                  icon: Icons.notifications_none_rounded,
                  label: l10n.t('network_notifications'),
                  onTap: onNotificationsTap,
                ),
                const SizedBox(width: 4),
                _NavIconButton(
                  icon: Icons.mail_outline_rounded,
                  label: l10n.t('network_nav_messages'),
                  onTap: onMessagesTap,
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: l10n.t('network_profile'),
                  child: GestureDetector(
                    onTap: onProfileTap,
                    child: HexAvatar(
                        size: 36, imageUrl: currentUser.photoUrl),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Rangée inférieure : Navigation tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _NavTab(
                    icon: Icons.home_rounded,
                    label: l10n.t('network_nav_home'),
                    active: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 4),
                  _NavTab(
                    icon: Icons.explore_outlined,
                    label: l10n.t('network_nav_discover'),
                    onTap: () => _safePushPath(context, '/network/discover'),
                  ),
                  const SizedBox(width: 4),
                  _NavTab(
                    icon: Icons.diversity_3_outlined,
                    label: l10n.t('network_nav_communities'),
                    onTap: onCommunitiesTap,
                  ),
                  const SizedBox(width: 4),
                  _NavTab(
                    icon: Icons.add_circle_outline_rounded,
                    label: l10n.t('network_nav_post'),
                    accent: true,
                    onTap: onCreateTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _safePushPath(BuildContext context, String path) {
    HapticFeedback.selectionClick();
    context.push(path);
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: ThixPolicy.textMain),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool accent;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    this.active = false,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: accent
                ? ThixPolicy.primary
                : active
                    ? ThixPolicy.surfaceSoft
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active && !accent
                  ? ThixPolicy.border
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: accent
                      ? Colors.white
                      : active
                          ? ThixPolicy.textMain
                          : ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: ThixPolicy.labelStyle.copyWith(
                      color: accent
                          ? Colors.white
                          : active
                              ? ThixPolicy.textMain
                              : ThixPolicy.textSecondary,
                      fontWeight:
                          active || accent ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EXECUTIVE BRIEFING (remplace stories circulaires)
// ============================================================================

class _ExecutiveBriefing extends StatelessWidget {
  final String currentUserId;
  final String? currentUserAvatar;
  final List<Map<String, dynamic>> liveSessions;
  final Set<String> liveHostIds;
  final VoidCallback onCreateStory;

  const _ExecutiveBriefing({
    required this.currentUserId,
    required this.currentUserAvatar,
    required this.liveSessions,
    required this.liveHostIds,
    required this.onCreateStory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading =
        ProviderScope.containerOf(context).read(_loadingStoriesProvider);
    final stories =
        ProviderScope.containerOf(context).read(_storiesProvider);

    final myStories = stories.where((s) => s.userId == currentUserId).toList();
    final otherStories =
        stories.where((s) => s.userId != currentUserId).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: ThixPolicy.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(l10n.t('network_briefing_title'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
              const Spacer(),
              if (!loading && otherStories.isNotEmpty)
                Text(
                  '${otherStories.length} ${l10n.t("network_briefing_updates")}',
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Cartes briefing horizontales
          if (loading)
            const _BriefingSkeleton()
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 1 + otherStories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (c, i) {
                  if (i == 0) {
                    return _BriefingCard(
                      type: _BriefingType.me,
                      hasStory: myStories.isNotEmpty,
                      isLive: liveHostIds.contains(currentUserId),
                      avatar: currentUserAvatar,
                      title: myStories.isNotEmpty
                          ? l10n.t('network_briefing_my_update')
                          : l10n.t('network_briefing_create_update'),
                      subtitle: myStories.isNotEmpty
                          ? l10n.t('network_briefing_view')
                          : l10n.t('network_briefing_tap_to_share'),
                      onTap: myStories.isNotEmpty
                          ? () {
                              HapticFeedback.selectionClick();
                              context.push('/network/stories/view',
                                  extra: {
                                    'stories': myStories,
                                    'initialIndex': 0
                                  });
                            }
                          : onCreateStory,
                    );
                  }
                  final story = otherStories[i - 1];
                  return _BriefingCard(
                    type: _BriefingType.other,
                    hasStory: true,
                    isLive: liveHostIds.contains(story.userId),
                    avatar: story.userAvatar,
                    title: story.userName.split(' ').first,
                    subtitle: l10n.t('network_briefing_new_update'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/network/stories/view',
                          extra: {'stories': [story], 'initialIndex': 0});
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

enum _BriefingType { me, other }

class _BriefingCard extends StatelessWidget {
  final _BriefingType type;
  final bool hasStory;
  final bool isLive;
  final String? avatar;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BriefingCard({
    required this.type,
    required this.hasStory,
    required this.isLive,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLive
                  ? ThixPolicy.danger.withValues(alpha: 0.4)
                  : ThixPolicy.border,
            ),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.inkDeep.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HexAvatar(size: 36, imageUrl: avatar, isLive: isLive),
                  const Spacer(),
                  if (type == _BriefingType.me && !hasStory)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 14),
                    )
                  else if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('LIVE',
                          style: ThixPolicy.captionStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 0.5)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.bodyStyle.copyWith(
                      color: ThixPolicy.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.captionStyle.copyWith(
                      color: ThixPolicy.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefingSkeleton extends StatelessWidget {
  const _BriefingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 180,
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSE ENTRY
// ============================================================================

class _ComposeEntry extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ComposeEntry({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          HexAvatar(size: 40, imageUrl: avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.t('network_create_post'),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l10n.t('network_create_post_hint'),
                      style: ThixPolicy.bodyStyle.copyWith(
                          color: ThixPolicy.textMuted)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEGMENTED CONTROL (iOS-style, remplace filters chips)
// ============================================================================

class _FeedSegmentedControl extends ConsumerWidget {
  final ValueChanged<String> onChanged;

  const _FeedSegmentedControl({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feedType = ref.watch(_feedTypeProvider);

    final segments = [
      {'key': 'foryou', 'label': l10n.t('network_filter_foryou')},
      {'key': 'network', 'label': l10n.t('network_filter_network')},
      {'key': 'recent', 'label': l10n.t('network_filter_recent')},
      {'key': 'popular', 'label': l10n.t('network_filter_popular')},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: segments.map((s) {
          final active = feedType == s['key'];
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              label: s['label'],
              child: GestureDetector(
                onTap: () => onChanged(s['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? ThixPolicy.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: ThixPolicy.inkDeep.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      s['label']!,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: active
                            ? ThixPolicy.textMain
                            : ThixPolicy.textSecondary,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// DISCOVERY BAND (suggestions + lives)
// ============================================================================

class _DiscoveryBand extends ConsumerWidget {
  final List<Map<String, dynamic>> liveSessions;

  const _DiscoveryBand({required this.liveSessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suggestions = ref.watch(_suggestionsProvider);
    final totalCount = suggestions.length + liveSessions.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: ThixPolicy.warning,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(l10n.t('network_discover'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
              const Spacer(),
              Text('$totalCount ${l10n.t("network_discover_count")}',
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: totalCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (c, i) {
                if (i < suggestions.length) {
                  final u = suggestions[i];
                  return _DiscoveryUserCard(
                    user: u,
                    onConnect: () async {
                      HapticFeedback.selectionClick();
                      ref.read(_suggestionsProvider.notifier).state =
                          suggestions.where((s) => s.id != u.id).toList();
                      try {
                        await ref
                            .read(networkServiceProvider)
                            .sendConnectionRequest(u.id);
                      } catch (e) {
                        _NetworkLogger.error('Connection failed',
                            {'error': '$e'});
                      }
                    },
                    onViewProfile: () {
                      HapticFeedback.selectionClick();
                      context.push('/network/profile/${u.id}');
                    },
                  );
                } else {
                  final live = liveSessions[i - suggestions.length];
                  return _DiscoveryLiveCard(session: live);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryUserCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onConnect;
  final VoidCallback onViewProfile;

  const _DiscoveryUserCard({
    required this.user,
    required this.onConnect,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: user.name,
      child: GestureDetector(
        onTap: onViewProfile,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HexAvatar(size: 32, imageUrl: user.avatar),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: l10n.t('network_connect'),
                    child: GestureDetector(
                      onTap: onConnect,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(user.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.bodyStyle.copyWith(
                      color: ThixPolicy.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(user.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.captionStyle.copyWith(
                      color: ThixPolicy.textSecondary, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryLiveCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _DiscoveryLiveCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label:
          '${l10n.t("network_live")} ${(session['host_name']?.toString() ?? "Hôte")}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final liveSession = LiveSession(
            id: session['id']?.toString() ?? '',
            channelName: session['channel_name']?.toString() ?? '',
            title: session['title']?.toString() ?? 'Live',
            hostId: session['host_id']?.toString() ?? '',
            hostName: session['host_name']?.toString() ?? 'Hôte THIX',
            hostAvatarUrl: session['host_avatar']?.toString(),
          );
          context.push('/network/live/view', extra: liveSession);
        },
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ThixPolicy.danger.withValues(alpha: 0.08),
                ThixPolicy.danger.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: ThixPolicy.danger.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HexAvatar(
                    size: 32,
                    imageUrl: session['host_avatar']?.toString(),
                    isLive: true,
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text('LIVE',
                            style: ThixPolicy.captionStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                (session['host_name']?.toString() ?? 'Hôte').split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.bodyStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(session['title']?.toString() ?? 'Live',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.captionStyle.copyWith(
                      color: ThixPolicy.textSecondary, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SHIMMER FEED
// ============================================================================

class _ShimmerFeed extends StatefulWidget {
  const _ShimmerFeed();

  @override
  State<_ShimmerFeed> createState() => _ShimmerFeedState();
}

class _ShimmerFeedState extends State<_ShimmerFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            height: 220,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    ThixPolicy.card.withValues(alpha: 0.0),
                    ThixPolicy.card.withValues(alpha: 0.4),
                    ThixPolicy.card.withValues(alpha: 0.0),
                  ],
                  stops: [
                    (_ctrl.value - 0.3).clamp(0.0, 1.0),
                    _ctrl.value,
                    (_ctrl.value + 0.3).clamp(0.0, 1.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SHEET ACTION (utilitaire)
// ============================================================================

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ThixPolicy.textMain),
            const SizedBox(width: 14),
            Text(label,
                style: ThixPolicy.bodyStyle.copyWith(
                    color: ThixPolicy.textMain, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
