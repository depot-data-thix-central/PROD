// lib/presentation/network/network_pro_home.dart
// ─────────────────────────────────────────────────────────────────────────────
// THIX PRO — Home « Enterprise »
// Refonte design : design tokens centralisés, thème clair/sombre, navigation
// flottante avec labels, segmented control, stories premium, shimmer animé.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'widgets/audio_spaces_strip.dart';

import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';
import 'package:thix_id/presentation/network/live/create_audio_space_sheet.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — Source unique de vérité visuelle
// ════════════════════════════════════════════════════════════════════════════
class Ent {
  Ent._();

  /// Palette « Monochrome + Or » — sobriété enterprise, rappel de la marque THIX
  static const Color ink        = Color(0xFF09090B); // zinc-950
  static const Color inkSoft    = Color(0xFF27272A); // zinc-800
  static const Color zinc       = Color(0xFF52525B); // zinc-600
  static const Color zincLight  = Color(0xFFA1A1AA); // zinc-400
  static const Color mist       = Color(0xFFE4E4E7); // zinc-200
  static const Color gold       = Color(0xFFEAB308); // accent marque
  static const Color goldDeep   = Color(0xFFA16207);
  static const Color live       = Color(0xFFEF4444);

  /// Échelle de rayons
  static const double rSm = 10, rMd = 14, rLg = 20, rPill = 28;

  /// Échelle d'espacements (base 4)
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 24, s6 = 32;

  /// Cible tactile minimale accessible
  static const double hitMin = 40;

  /// Ombre douce standard
  static List<BoxShadow> shadow(Color base, {double a = 0.05, double blur = 14, double y = 4}) => [
        BoxShadow(color: base.withValues(alpha: a), blurRadius: blur, offset: Offset(0, y)),
      ];

  /// Surfaces adaptatives clair / sombre
  static Color surface(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF101012) : const Color(0xFFF4F4F5);
  static Color card(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF18181B) : Colors.white;
  static Color textMain(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFFFAFAFA) : ink;
  static Color textSecondary(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? zincLight : zinc;

  /// Anneau dégradé « story non vue » (signature visuelle)
  static const Gradient storyRing = LinearGradient(
    colors: [gold, Color(0xFFFACC15), goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS (inchangés)
// ════════════════════════════════════════════════════════════════════════════
final _storiesProvider = StateProvider<List<NetworkStory>>((ref) => []);
final _loadingStoriesProvider = StateProvider<bool>((ref) => true);
final _feedTypeProvider = StateProvider<String>((ref) => 'foryou');
final _suggestionsProvider = StateProvider<List<dynamic>>((ref) => []);
final _navVisibleProvider = StateProvider<bool>((ref) => true);

final activeLiveSessionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
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

// ════════════════════════════════════════════════════════════════════════════
// VERRE DÉPOLI — Composant glassmorphism standardisé
// ════════════════════════════════════════════════════════════════════════════
class EntGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double alpha;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;

  const EntGlass({
    super.key,
    required this.child,
    this.radius = Ent.rLg,
    this.alpha = 0.72,
    this.blur = 14,
    this.padding,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? (isDark ? Ent.inkSoft : Colors.white))
                .withValues(alpha: isDark ? min(alpha, 0.82) : alpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: Ent.shadow(Ent.ink, a: isDark ? 0.25 : 0.04),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AVATAR CIRCULAIRE — Bordure LIVE / story / neutre
// ════════════════════════════════════════════════════════════════════════════
class EntAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final bool isLive;
  final bool showRing;
  final bool ringSeen;

  const EntAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.isLive = false,
    this.showRing = false,
    this.ringSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isDark ? Colors.white.withValues(alpha: 0.14) : Ent.mist;

    Widget avatar = Container(
      width: size,
      height: size,
      padding: showRing ? const EdgeInsets.all(2.5) : EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (showRing && !ringSeen && !isLive) ? Ent.storyRing : null,
        color: (showRing && !ringSeen && !isLive) ? null : ringColor,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isLive
                ? Ent.live
                : (isDark ? Ent.inkSoft : Colors.white),
            width: isLive ? 2 : 2,
          ),
        ),
        child: ClipOval(
          child: (imageUrl != null && imageUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Ent.surface(context)),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    size: size * 0.45,
                    color: Ent.zincLight,
                  ),
                )
              : Container(
                  color: Ent.surface(context),
                  child: Icon(Icons.person_rounded,
                      size: size * 0.45, color: Ent.zincLight),
                ),
        ),
      ),
    );

    if (isLive) {
      return Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Ent.live, Color(0xFFB91C1C)]),
        ),
        child: avatar,
      );
    }
    return avatar;
  }
}

class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});

  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome>
    with AutomaticKeepAliveClientMixin {
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

  // ── Infinite scroll + nav auto-hide (inchangé) ──
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
    final needsRefresh = _lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _refreshCooldown;

    final feedType = ref.read(_feedTypeProvider);
    await ref
        .read(feedProvider.notifier)
        .loadFeed(feedType: feedType, force: needsRefresh);
    if (needsRefresh) _lastRefreshTime = now;

    await Future.wait([_loadStories(), _loadSuggestions()]);
  }

  Future<void> _loadStories() async {
    try {
      final data =
          await ref.read(networkServiceProvider).getActiveStories();
      ref.read(_storiesProvider.notifier).state = data;
      ref.read(_loadingStoriesProvider.notifier).state = false;
    } catch (e) {
      debugPrint('[Stories] Load error: $e');
      ref.read(_loadingStoriesProvider.notifier).state = false;
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref
          .read(networkServiceProvider)
          .getSuggestedConnections(limit: 30);

      final current = ref.read(_suggestionsProvider);
      final merged = [...current, ...data].take(_maxSuggestions).toList();
      ref.read(_suggestionsProvider.notifier).state = merged;

      _shuffleSuggestions();

      _suggestionTimer?.cancel();
      if (_suggestionRefreshCount < _maxSuggestionRefreshes) {
        _suggestionTimer =
            Timer.periodic(const Duration(minutes: 1), (_) {
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
    final list = List<dynamic>.from(suggestions)..shuffle(Random());
    ref.read(_suggestionsProvider.notifier).state = list.take(10).toList();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    final feedType = ref.read(_feedTypeProvider);
    await ref
        .read(feedProvider.notifier)
        .loadFeed(feedType: feedType, force: true);
    _lastRefreshTime = DateTime.now();
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
  }

  Future<void> _openCreateStory() async {
    final ok = await CreateStoryDialog.show(context);
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
    }
  }

  void _openCreateAudioSpace() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateAudioSpaceSheet(),
    );
  }

  void _safePush(String path) {
    if (!mounted) return;
    try {
      context.push(path);
    } catch (e) {
      debugPrint('[Nav] Push error: $e');
    }
  }

  Future<void> _openComments(String postId) async =>
      _safePush('/network/comments/$postId');

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _navStopTimer?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }

  // ── Orbes décoratifs d'arrière-plan ──
  Widget _orb(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.03),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      );

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
        backgroundColor: Ent.surface(context),
        body: const Center(
            child: CircularProgressIndicator(color: Ent.ink)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: Ent.surface(context),
        body: Stack(
          children: [
            Positioned(
                top: -90, right: -50, child: _orb(Ent.gold, 260)),
            Positioned(
                bottom: 200, left: -90, child: _orb(Ent.ink, 300)),

            RefreshIndicator(
              color: Ent.goldDeep,
              backgroundColor: Ent.card(context),
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  _buildAppBar(currentUser.photoUrl, currentUser.id),
                  const SliverToBoxAdapter(child: SizedBox(height: Ent.s3)),

                  // ── Stories ──
                  SliverToBoxAdapter(
                      child: _buildStories(
                          l10n, currentUser.id, liveHostIds, currentUser.photoUrl)),
                  const SliverToBoxAdapter(child: AudioSpacesStrip()),

                  // ── Filtres : segmented control enterprise ──
                  SliverToBoxAdapter(child: _buildSegmentedFilters(l10n)),

                  if (ref.watch(_suggestionsProvider).isNotEmpty ||
                      liveSessions.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildDiscoveryBand(l10n, liveSessions)),

                  feedAsync.when(
                    loading: () =>
                        SliverToBoxAdapter(child: _buildShimmerFeed(context)),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(Ent.s6),
                        child: Center(
                          child: Text(
                            l10n.t('network_error_generic', args: [e.toString()]),
                            style: ThixPolicy.bodyStyle
                                .copyWith(color: Ent.live),
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
                          return Column(
                            children: [
                              if (i > 0)
                                Container(
                                  height: Ent.s2,
                                  color: Ent.textSecondary(context)
                                      .withValues(alpha: 0.08),
                                ),
                              PostCard(
                                key: ValueKey(post.id),
                                post: post,
                                currentProfileId: currentUser.id,
                                isFirst: i == 0,
                                onLike: null,
                                onComment: () => _openComments(post.id),
                                onShare: () => _showShareSheet(l10n, post),
                                onDelete: () => ref
                                    .read(feedProvider.notifier)
                                    .deletePost(post.id),
                                onRefresh: null,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),

            // ── Navigation flottante ──
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

  // ══════════════════════════════════════════════════════════════════════
  // APP BAR — Verre, icônes 40px cohérentes, wordmark typographié
  // ══════════════════════════════════════════════════════════════════════
   Widget _buildAppBar(String? avatarUrl, String currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      centerTitle: false,
      toolbarHeight: 60,
      titleSpacing: Ent.s4,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Ent.ink : Colors.white).withValues(alpha: 0.78),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      // Titre seul (plus de logo ⚡), se réduit si l'écran est étroit
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'THIX',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Ent.textMain(context),
                ),
              ),
              TextSpan(
                text: ' PRO',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                  color: Ent.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Bloc « Space » (ancien micro) → Audio Spaces
        _SpaceButton(onTap: _openCreateAudioSpace),
        const SizedBox(width: 6),
        _AppBarAction(
          icon: Icons.search_rounded,
          onTap: () => _safePush('/network/search'),
        ),
        const SizedBox(width: 6),
        _AppBarAction(
          icon: Icons.notifications_none_rounded,
          badge: true,
          onTap: () => _safePush('/network/notifications'),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(right: Ent.s4),
          child: GestureDetector(
            onTap: () => _safePush('/network/profile/$currentUserId'),
            child: EntAvatar(size: 38, imageUrl: avatarUrl),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // STORIES — Rectangle haut, anneau or pour les non vues, LIVE en surimpression
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildStories(AppLocalizations l10n, String currentUserId,
      Set<String> liveHostIds, String? avatarUrl) {
    final loading = ref.watch(_loadingStoriesProvider);
    final stories = ref.watch(_storiesProvider);

    if (loading) {
      return Container(
        color: Ent.card(context),
        height: 216,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Ent.ink),
        ),
      );
    }

    final myStories = stories.where((s) => s.userId == currentUserId).toList();
    final Map<String, List<NetworkStory>> grouped = {};
    for (final s in stories) {
      if (s.userId != currentUserId) {
        grouped.putIfAbsent(s.userId, () => []).add(s);
      }
    }
    final others = grouped.keys.toList();

    return Container(
      color: Ent.card(context),
      padding: const EdgeInsets.symmetric(vertical: Ent.s3),
      child: SizedBox(
        height: 192,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Ent.s4),
          itemCount: others.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: Ent.s2),
          itemBuilder: (c, i) {
            if (i == 0) {
              final myAvatar =
                  myStories.isNotEmpty ? myStories.first.userAvatar : avatarUrl;
              return EntStoryCard(
                isMe: true,
                hasStory: myStories.isNotEmpty,
                isLive: liveHostIds.contains(currentUserId),
                name: myStories.isNotEmpty
                    ? l10n.t('network_your_story')
                    : l10n.t('network_create'),
                coverUrl: myStories.isNotEmpty
                    ? (myStories.first.imageUrl.isNotEmpty
                        ? myStories.first.imageUrl
                        : myStories.first.userAvatar)
                    : avatarUrl,
                avatarUrl: myAvatar,
                onTap: myStories.isNotEmpty
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StoryViewer(
                            stories: myStories, initialIndex: 0)))
                    : _openCreateStory,
                onAdd: _openCreateStory,
              );
            }
            final userId = others[i - 1];
            final userStories = grouped[userId]!;
            final first = userStories.first;
            return EntStoryCard(
              isMe: false,
              hasStory: true,
              isLive: liveHostIds.contains(userId),
              name: first.userName.split(' ').first,
              coverUrl: first.imageUrl.isNotEmpty
                  ? first.imageUrl
                  : first.userAvatar,
              avatarUrl: first.userAvatar,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      StoryViewer(stories: userStories, initialIndex: 0))),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // FILTRES — Segmented control (référence : iOS / LinkedIn)
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildSegmentedFilters(AppLocalizations l10n) {
    final feedType = ref.watch(_feedTypeProvider);
    final filters = {
      'foryou': l10n.t('network_filter_foryou'),
      'network': l10n.t('network_filter_network'),
      'recent': l10n.t('network_filter_recent'),
      'popular': l10n.t('network_filter_popular'),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Ent.s4, Ent.s2, Ent.s4, Ent.s2),
      child: EntGlass(
        radius: Ent.rPill,
        alpha: isDark ? 0.6 : 0.75,
        padding: const EdgeInsets.all(3),
        child: Row(
          children: filters.entries.map((e) {
            final active = feedType == e.key;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (active) return;
                  ref.read(_feedTypeProvider.notifier).state = e.key;
                  ref
                      .read(feedProvider.notifier)
                      .loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                  HapticFeedback.lightImpact();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: Ent.s2 + 1),
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark ? Colors.white : Ent.ink)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Ent.rPill),
                    boxShadow: active
                        ? Ent.shadow(Ent.ink, a: isDark ? 0.3 : 0.15,
                            blur: 8, y: 2)
                        : null,
                  ),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12.5,
                      letterSpacing: 0.1,
                      color: active
                          ? (isDark ? Ent.ink : Colors.white)
                          : Ent.textSecondary(context),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // BANDE DÉCOUVERTE — Suggestions + LIVE unifiés
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildDiscoveryBand(
      AppLocalizations l10n, List<Map<String, dynamic>> liveSessions) {
    final suggestions = ref.watch(_suggestionsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Ent.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Ent.s4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Ent.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.explore_rounded,
                      size: 14, color: Ent.goldDeep),
                ),
                const SizedBox(width: Ent.s2),
                Text(
                  l10n.t('network_discover_title'),
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: 0.2,
                    color: Ent.textMain(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Ent.s3),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Ent.s4),
              itemCount: suggestions.length + liveSessions.length,
              separatorBuilder: (_, __) => const SizedBox(width: Ent.s4),
              itemBuilder: (c, i) {
                if (i < suggestions.length) {
                  final u = suggestions[i];
                  return _DiscoveryPerson(
                    name: u.name,
                    avatarUrl: u.avatar,
                    onOpen: () => context.push('/network/profile/${u.id}'),
                    onConnect: () async {
                      HapticFeedback.selectionClick();
                      ref.read(_suggestionsProvider.notifier).state =
                          suggestions.where((s) => s.id != u.id).toList();
                      try {
                        await ref
                            .read(networkServiceProvider)
                            .sendConnectionRequest(u.id);
                      } catch (e) {
                        debugPrint('[Follow] Error: $e');
                      }
                    },
                  );
                }
                final s = liveSessions[i - suggestions.length];
                return _DiscoveryLive(
                  hostName: s['host_name']?.toString() ?? 'Hôte',
                  hostAvatar: s['host_avatar']?.toString(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveViewerScreen(
                          session: LiveSession(
                            id: s['id']?.toString() ?? '',
                            channelName: s['channel_name']?.toString() ?? '',
                            title: s['title']?.toString() ?? 'Live',
                            hostId: s['host_id']?.toString() ?? '',
                            hostName: s['host_name']?.toString() ?? 'Hôte',
                            hostAvatarUrl: s['host_avatar']?.toString(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SHIMMER — Squelettes animés (niveau LinkedIn)
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildShimmerFeed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Ent.inkSoft : Colors.white;
    return _Shimmer(
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.symmetric(
                vertical: Ent.s2, horizontal: Ent.s4),
            padding: const EdgeInsets.all(Ent.s4),
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(Ent.rLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                        color: Ent.mist, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: Ent.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: 140,
                          decoration: BoxDecoration(
                              color: Ent.mist,
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 9,
                          width: 90,
                          decoration: BoxDecoration(
                              color: Ent.mist,
                              borderRadius: BorderRadius.circular(5)),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: Ent.s4),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                      color: Ent.mist,
                      borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 220,
                  decoration: BoxDecoration(
                      color: Ent.mist,
                      borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(height: Ent.s4),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                      color: Ent.mist,
                      borderRadius: BorderRadius.circular(Ent.rMd)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Ent.s6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Ent.s5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Ent.gold.withValues(alpha: 0.08),
            ),
            child: const Icon(Icons.feed_outlined,
                size: 30, color: Ent.goldDeep),
          ),
          const SizedBox(height: Ent.s3),
          Text(
            l10n.t('network_empty_feed'),
            style: ThixPolicy.bodyStyle.copyWith(
              color: Ent.textSecondary(context),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: Ent.s4),
          OutlinedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            style: OutlinedButton.styleFrom(
              foregroundColor: Ent.textMain(context),
              side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Ent.mist),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Ent.rPill)),
              padding: const EdgeInsets.symmetric(
                  horizontal: Ent.s4, vertical: Ent.s2),
            ),
            label: Text(l10n.t('common_refresh')),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SHARE SHEET — Verre + actions claires
  // ══════════════════════════════════════════════════════════════════════
  void _showShareSheet(AppLocalizations l10n, dynamic post) {
    final link = 'https://thix.id/network/post/${post.id}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EntGlass(
        radius: 24,
        alpha: 0.95,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Ent.s3),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Ent.zincLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: Ent.s2),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(Ent.s2),
                  decoration: BoxDecoration(
                    color: Ent.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded,
                      color: Ent.goldDeep, size: 20),
                ),
                title: Text(
                  l10n.t('network_copy_link'),
                  style: ThixPolicy.bodyStyle.copyWith(
                    color: Ent.textMain(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  try {
                    await ref
                        .read(networkServiceProvider)
                        .sharePost('${post.id}');
                  } catch (e) {
                    debugPrint('[Share] Error: $e');
                  }
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Ent.rPill)),
                        content: Text(l10n.t('network_link_copied')),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(Ent.s2),
                  decoration: BoxDecoration(
                    color: Ent.zincLight.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Ent.zinc, size: 20),
                ),
                title: Text(
                  l10n.t('common_close'),
                  style: ThixPolicy.bodyStyle
                      .copyWith(color: Ent.textMain(context), fontSize: 14),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: Ent.s3),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // BOTTOM NAV — Verre flottant, LABELS visibles (l'élément manquant
  // du design actuel), indicateur actif en pilule
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav(AppLocalizations l10n, bool visible) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
              child: EntGlass(
                radius: 30,
                alpha: 0.9,
                blur: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: Ent.s2, vertical: 6),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: l10n.t('network_nav_home'),
                        active: true,
                        onTap: () => _scrollController.animateTo(0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut),
                      ),
                      _NavItem(
                        icon: Icons.explore_outlined,
                        label: l10n.t('network_nav_discover'),
                        active: false,
                        onTap: () => _safePush('/network/discover'),
                      ),
                      // Bouton central — action primaire
                      Semantics(
                        button: true,
                        label: l10n.t('network_nav_post'),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            CreatePostDialog.show(context);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Ent.ink, Color(0xFF2A2A2E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Ent.gold.withValues(alpha: 0.5),
                                  width: 1.2),
                              boxShadow: Ent.shadow(Ent.ink,
                                  a: 0.35, blur: 10, y: 3),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Ent.gold, size: 22),
                          ),
                        ),
                      ),
                      _NavItem(
                        icon: Icons.mail_outline_rounded,
                        label: l10n.t('network_nav_messages'),
                        active: false,
                        onTap: () => _safePush('/network/messages'),
                      ),
                      _NavItem(
                        icon: Icons.diversity_3_outlined,
                        label: l10n.t('network_nav_communities'),
                        active: false,
                        onTap: () => _safePush('/network/communities'),
                      ),
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
}

// ════════════════════════════════════════════════════════════════════════════
// COMPOSANTS PRIVÉS
// ════════════════════════════════════════════════════════════════════════════
/// Bloc « Space » : micro + texte, ouvre la création d'un Audio Space.
class _SpaceButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SpaceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Space',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Ent.ink, Color(0xFF2A2A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Ent.rPill),
            border: Border.all(color: Ent.gold.withValues(alpha: 0.45), width: 1),
            boxShadow: Ent.shadow(Ent.ink, a: 0.25, blur: 8, y: 2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, size: 16, color: Ent.gold),
              SizedBox(width: 6),
              Text(
                'Space',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Bouton d'app bar : 40px de cible tactile, style cohérent, option badge
/// notification et variant « filled » pour l'action primaire.
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool badge;

  const _AppBarAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: Ent.hitMin,
        height: Ent.hitMin,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled
              ? const LinearGradient(
                  colors: [Ent.ink, Color(0xFF2A2A2E)])
              : null,
          color: filled
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.85)),
          border: Border.all(
            color: filled
                ? Ent.gold.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white),
            width: 1,
          ),
          boxShadow: filled
              ? Ent.shadow(Ent.ink, a: 0.25, blur: 8, y: 2)
              : Ent.shadow(Ent.ink, a: 0.03, blur: 6, y: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 17, color: filled ? Ent.gold : Ent.textMain(context)),
            if (badge)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Ent.live,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDark ? Ent.ink : Colors.white, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Élément de navigation basse : icône + LABEL (lisibilité), pilule active.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Ent.textMain(context) : Ent.textSecondary(context);
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: Ent.s3, vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? Ent.gold.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Ent.rPill),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.2,
                  color: color,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte story premium : rectangle haut, anneau or, gradient de lecture,
/// bouton « + » création sur la story personnelle.
class EntStoryCard extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? coverUrl;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const EntStoryCard({
    super.key,
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
    final bg = (coverUrl != null && coverUrl!.isNotEmpty)
        ? coverUrl
        : (avatarUrl != null && avatarUrl!.isNotEmpty ? avatarUrl : null);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Ent.rMd),
          boxShadow: Ent.shadow(Ent.ink, a: isDark ? 0.3 : 0.08, blur: 10, y: 3),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Ent.rMd),
                child: bg != null
                    ? CachedNetworkImage(
                        imageUrl: bg,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Ent.surface(context)),
                        errorWidget: (_, __, ___) =>
                            Container(color: Ent.surface(context)),
                      )
                    : Container(color: Ent.surface(context)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Ent.rMd),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Ent.ink.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: Ent.s2,
              left: Ent.s2,
              child: EntAvatar(
                size: 34,
                imageUrl: avatarUrl,
                isLive: isLive,
                showRing: !isMe && !isLive,
              ),
            ),
            if (isMe)
              Positioned(
                top: 26,
                left: 26,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Ent.gold,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 14, color: Ent.ink),
                  ),
                ),
              ),
            if (isLive)
              Positioned(
                top: Ent.s2,
                right: Ent.s2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Ent.live,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: Ent.s3,
              left: Ent.s3,
              right: Ent.s3,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Personne suggérée dans la bande découverte.
class _DiscoveryPerson extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final VoidCallback onOpen;
  final VoidCallback onConnect;

  const _DiscoveryPerson({
    required this.name,
    required this.avatarUrl,
    required this.onOpen,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                EntAvatar(size: 54, imageUrl: avatarUrl, showRing: true),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: onConnect,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Ent.ink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 11, color: Ent.gold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Ent.s2),
            Text(
              name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.microStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: Ent.textMain(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Session LIVE dans la bande découverte.
class _DiscoveryLive extends StatelessWidget {
  final String hostName;
  final String? hostAvatar;
  final VoidCallback onTap;

  const _DiscoveryLive({
    required this.hostName,
    required this.hostAvatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                EntAvatar(size: 54, imageUrl: hostAvatar, isLive: true),
                Positioned(
                  bottom: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Ent.live,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Ent.s2),
            Text(
              hostName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.microStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: Ent.textMain(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Effet shimmer animé pour les états de chargement.
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = Tween<double>(begin: -1.2, end: 2.2)
                .transform(_c.value);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? const [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF18181B)]
                  : const [Color(0xFFF4F4F5), Colors.white, Color(0xFFF4F4F5)],
              stops: [slide - 0.25, slide, slide + 0.25],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
