/// ThixMediaPage (TDIA) — Production Enterprise
/// - Glass monochrome cohérent avec ThixPolicy
/// - i18n complet FR/EN/SW/LN, sanitization, Semantics
/// - Riverpod pur (plus de double state), go_router
/// - BackdropFilter réduit (perf), RepaintBoundary, throttling
import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/nav.dart' show AppRoutes;
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'utils/media_constants.dart';
import 'widgets/media_poster_card.dart';
import 'widgets/media_detail_page.dart';
import 'widgets/fil_feed_view.dart';
import 'admin/thix_media_admin_page.dart';
import 'create_post_page.dart';
import 'user_profile_page.dart';
import 'package:thix_id/nav.dart' show AppRoutes;
import 'media_routes.dart';
// ============================================================================
// DESIGN TOKENS (cohérents avec le reste de l'app)
// ============================================================================

const double _kGlassBlur = kIsWeb ? 6 : 12;      // réduit sur Web
const double _kGlassAlpha = 0.08;
const double _kGlassBorderAlpha = 0.12;
const double _kSurfaceAlpha = 0.85;

const int _kMaxSearchLength = 120;
const int _kMaxTitleLength = 100;
const int _kMaxHeroItems = 6;
const Duration _kScrollThrottle = Duration(milliseconds: 250);
const Duration _kSearchDebounce = Duration(milliseconds: 400);
const Duration _kHeroAutoScroll = Duration(seconds: 5);

// ============================================================================
// SANITIZER
// ============================================================================

class _MediaSanitizer {
  _MediaSanitizer._();

  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static String? imageUrl(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (!u.startsWith('http://') && !u.startsWith('https://')) return null;
    return u;
  }

  static String searchQuery(String? input) {
    return text(input, maxLength: _kMaxSearchLength).toLowerCase();
  }
}

// ============================================================================
// PAGE
// ============================================================================

class ThixMediaPage extends ConsumerStatefulWidget {
  const ThixMediaPage({super.key});
  @override
  ConsumerState<ThixMediaPage> createState() => _ThixMediaPageState();
}

class _ThixMediaPageState extends ConsumerState<ThixMediaPage>
    with AutomaticKeepAliveClientMixin<ThixMediaPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final PageController _heroController = PageController(viewportFraction: 0.92);

  Timer? _searchDebounce;
  Timer? _scrollThrottle;
  Timer? _heroAutoScroll;

  bool _showSearchOverlay = false;
  String _searchQuery = '';
  String _lowerQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedCategoryProvider.notifier).state = 'Tous';
      _startHeroAutoScroll();
      debugPrint('[ThixMedia] Page initialized');
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _heroController.dispose();
    _searchDebounce?.cancel();
    _scrollThrottle?.cancel();
    _heroAutoScroll?.cancel();
    AnalyticsBatcher.dispose();
    super.dispose();
  }

  // ── Listeners ───────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollThrottle?.isActive ?? false) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      _scrollThrottle = Timer(_kScrollThrottle, () {});
      ref.read(thixMediaListProvider.notifier).loadMore();
    }
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() => _showSearchOverlay =
        _searchFocusNode.hasFocus && _searchQuery.isNotEmpty);
  }

  void _onSearchChanged(String v) {
    final sanitized = _MediaSanitizer.searchQuery(v);
    if (sanitized == _lowerQuery) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      setState(() {
        _lowerQuery = sanitized;
        _searchQuery = _MediaSanitizer.text(v, maxLength: _kMaxSearchLength);
        _showSearchOverlay =
            _searchFocusNode.hasFocus && sanitized.isNotEmpty;
      });
      ref.read(searchQueryProvider.notifier).state = sanitized;
    });
  }

  void _clearSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _lowerQuery = '';
      _showSearchOverlay = false;
    });
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _startHeroAutoScroll() {
    _heroAutoScroll = Timer.periodic(_kHeroAutoScroll, (_) {
      if (!mounted || !_heroController.hasClients) return;
      final page = (_heroController.page ?? 0).round();
      final catalog = ref.read(thixMediaListProvider).valueOrNull ?? [];
      final count = catalog.length.clamp(0, _kMaxHeroItems);
      if (count == 0) return;
      final next = (page + 1) % count;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  // ── Navigation (go_router) ──────────────────────────────────

  void _openDetail(MediaContent item) {
    if (!mounted) return;
    final safeId = _MediaSanitizer.text(item.id, maxLength: 64);
    if (safeId.isEmpty) {
      debugPrint('[ThixMedia] Invalid item id, aborting detail nav');
      return;
    }
    AnalyticsBatcher.register(safeId);
    debugPrint('[ThixMedia] Detail: ${item.title.substring(0, item.title.length.clamp(0, 30))}');
    MediaRoutes.goToMediaDetail(
      context,
      item,
      ref.read(thixMediaListProvider).valueOrNull ?? const [],
    );
    );
    );
  }

  void _openAdmin() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    context.push('/media/admin');
  }

  void _openCreatePost() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    context.push('/media/create');
  }

  void _openProfile() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || !mounted) return;
    HapticFeedback.selectionClick();
    context.pushNamed(AppRoutes.profile, extra: uid);
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: asyncMedia.when(
        loading: () => const _MediaSkeleton(),
        error: (e, st) => _buildErrorState(context, l10n, e),
        data: (catalog) => Stack(
          children: [
            _buildMainContent(context, l10n, catalog, isAdmin, selectedCategory),
            if (_showSearchOverlay) _buildSearchOverlay(context, l10n, catalog),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // MAIN CONTENT
  // ========================================================================

  Widget _buildMainContent(
    BuildContext context,
    AppLocalizations l10n,
    List<MediaContent> catalog,
    bool isAdmin,
    String selectedCategory,
  ) {
    if (selectedCategory == 'Fil') {
      return Stack(
        children: [
          RepaintBoundary(
            child: FilFeedView(catalog: catalog, onOpenDetail: _openDetail),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTransparentHeader(l10n, isAdmin)),
          ),
        ],
      );
    }

    final filtered = selectedCategory == 'Tous'
        ? catalog
        : catalog.where((e) => e.type == selectedCategory).toList();
    final series = catalog.where((e) => e.episodesUrls.isNotEmpty).toList();
    final categories = _computeCategories(catalog);

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: ThixPolicy.card,
      onRefresh: () {
        HapticFeedback.mediumImpact();
        return ref.read(thixMediaListProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildSliverHeader(l10n, isAdmin),
          if (catalog.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(l10n),
            )
          else ...[
            SliverToBoxAdapter(child: _buildHero(catalog)),
            SliverToBoxAdapter(
                child: _buildCategoryChips(l10n, categories, selectedCategory)),
            if (series.isNotEmpty)
              SliverToBoxAdapter(child: _buildSeriesRail(l10n, series)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  selectedCategory == 'Tous'
                      ? l10n.t('media_catalog')
                      : selectedCategory,
                  style: ThixPolicy.h3Style.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => RepaintBoundary(
                    child: MediaPosterCard(
                      item: filtered[i],
                      onTap: () => _openDetail(filtered[i]),
                    ),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========================================================================
  // ERROR / EMPTY
  // ========================================================================

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    debugPrint('[ThixMedia] Error: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: ThixPolicy.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.t('media_load_error'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(thixMediaListProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.t('common_retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 56, color: ThixPolicy.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              l10n.t('media_empty'),
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // HEADER (SliverAppBar)
  // ========================================================================

  Widget _buildSliverHeader(AppLocalizations l10n, bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 70,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep.withValues(alpha: _kSurfaceAlpha),
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: _kGlassBorderAlpha)),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_filled_rounded,
              color: ThixPolicy.primary, size: 26),
          const SizedBox(width: 8),
          Text(
            'TDIA',
            style: ThixPolicy.h2Style.copyWith(
              color: ThixPolicy.textMain,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        if (isAdmin)
          Semantics(
            button: true,
            label: l10n.t('media_admin'),
            child: IconButton(
              onPressed: _openAdmin,
              icon: Icon(Icons.admin_panel_settings_rounded,
                  color: ThixPolicy.textMuted, size: 20),
            ),
          ),
        Semantics(
          button: true,
          label: l10n.t('media_create'),
          child: IconButton(
            onPressed: _openCreatePost,
            icon: Icon(Icons.add_box_outlined,
                color: ThixPolicy.textMain, size: 22),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('nav_profile'),
          child: IconButton(
            onPressed: _openProfile,
            icon: Icon(Icons.person_outline_rounded,
                color: ThixPolicy.textMain, size: 22),
          ),
        ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildSearchBar(l10n),
        ),
      ),
    );
  }

  Widget _buildTransparentHeader(AppLocalizations l10n, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.play_circle_filled_rounded,
              color: ThixPolicy.primary, size: 26),
          const SizedBox(width: 8),
          Text('TDIA',
              style: ThixPolicy.h2Style.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
          const Spacer(),
          if (isAdmin)
            Semantics(
              button: true,
              label: l10n.t('media_admin'),
              child: IconButton(
                onPressed: _openAdmin,
                icon: Icon(Icons.admin_panel_settings_rounded,
                    color: ThixPolicy.textMain, size: 22),
              ),
            ),
          Semantics(
            button: true,
            label: l10n.t('media_create'),
            child: IconButton(
              onPressed: _openCreatePost,
              icon: Icon(Icons.add_box_outlined,
                  color: ThixPolicy.textMain, size: 24),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('nav_profile'),
            child: IconButton(
              onPressed: _openProfile,
              icon: Icon(Icons.person_outline_rounded,
                  color: ThixPolicy.textMain, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _kGlassAlpha),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Colors.white.withValues(alpha: _kGlassBorderAlpha)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: ThixPolicy.textMuted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  textField: true,
                  label: l10n.t('media_search'),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    maxLength: _kMaxSearchLength,
                    style: TextStyle(
                        color: ThixPolicy.textMain, fontSize: 14),
                    cursorColor: ThixPolicy.primary,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.t('media_search_hint'),
                      hintStyle: TextStyle(
                          color: ThixPolicy.textMuted, fontSize: 13.5),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                Semantics(
                  button: true,
                  label: l10n.t('common_clear'),
                  child: GestureDetector(
                    onTap: _clearSearch,
                    child: Icon(Icons.close_rounded,
                        color: ThixPolicy.textMuted, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // HERO CAROUSEL
  // ========================================================================

  Widget _buildHero(List<MediaContent> catalog) {
    final featured = catalog.take(_kMaxHeroItems).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: SizedBox(
        height: 200,
        child: PageView.builder(
          controller: _heroController,
          itemCount: featured.length,
          itemBuilder: (c, i) => _buildHeroCard(featured[i]),
        ),
      ),
    );
  }

  Widget _buildHeroCard(MediaContent item) {
    final safeTitle =
        _MediaSanitizer.text(item.title, maxLength: _kMaxTitleLength);
    final coverUrl = _MediaSanitizer.imageUrl(item.coverUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: safeTitle,
        child: GestureDetector(
          onTap: () => _openDetail(item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCoverImage(coverUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 14,
                  child: Row(
                    children: [
                      _heroBadge(ThixPolicy.primary, 'À LA UNE'),
                      if (item.isPaid) ...[
                        const SizedBox(width: 8),
                        _heroBadge(ThixPolicy.warning, 'Premium',
                            icon: Icons.lock_rounded),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Color(0x99000000),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            formatMediaNumber(item.viewCount),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
  }

  Widget _heroBadge(Color color, String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(String? url) {
    if (url == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThixPolicy.primary.withValues(alpha: 0.4),
              ThixPolicy.inkDeep,
            ],
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheHeight: 400,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: ThixPolicy.inkDeep),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.inkDeep,
        child: Icon(Icons.broken_image_rounded,
            color: ThixPolicy.textMuted, size: 32),
      ),
    );
  }

  // ========================================================================
  // CATEGORY CHIPS
  // ========================================================================

  List<String> _computeCategories(List<MediaContent> catalog) {
    final types = catalog
        .map((e) => e.type)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Tous', 'Fil', ...types];
  }

  Widget _buildCategoryChips(
    AppLocalizations l10n,
    List<String> categories,
    String selected,
  ) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final cat = categories[i];
          final sel = selected == cat;
          return Semantics(
            button: true,
            selected: sel,
            label: cat,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(selectedCategoryProvider.notifier).state = cat;
                debugPrint('[ThixMedia] Category: $cat');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? ThixPolicy.primary
                      : Colors.white.withValues(alpha: _kGlassAlpha),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: sel
                        ? ThixPolicy.primary
                        : Colors.white.withValues(alpha: _kGlassBorderAlpha),
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: sel ? Colors.white : ThixPolicy.textMain,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ========================================================================
  // SERIES RAIL
  // ========================================================================

  Widget _buildSeriesRail(AppLocalizations l10n, List<MediaContent> series) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.video_library_rounded,
                      size: 16, color: ThixPolicy.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('media_series'),
                    style: ThixPolicy.h3Style.copyWith(
                      color: ThixPolicy.textMain,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: series.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) => RepaintBoundary(
                  child: SizedBox(
                    width: 128,
                    child: MediaPosterCard(
                      item: series[i],
                      onTap: () => _openDetail(series[i]),
                      compact: true,
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

  // ========================================================================
  // SEARCH OVERLAY
  // ========================================================================

  Widget _buildSearchOverlay(
    BuildContext context,
    AppLocalizations l10n,
    List<MediaContent> catalog,
  ) {
    final results = _lowerQuery.isEmpty
        ? const <MediaContent>[]
        : catalog
            .where((e) => e.title.toLowerCase().contains(_lowerQuery))
            .toList();

    return Positioned.fill(
      child: GestureDetector(
        onTap: _clearSearch,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
            child: Container(
              color: ThixPolicy.inkDeep.withValues(alpha: _kSurfaceAlpha),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 130,
                left: 16,
                right: 16,
              ),
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: ThixPolicy.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            l10n.t('media_no_results'),
                            style: ThixPolicy.bodyStyle
                                .copyWith(color: ThixPolicy.textMuted),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final item = results[i];
                        final safeTitle = _MediaSanitizer.text(
                            item.title,
                            maxLength: _kMaxTitleLength);
                        final coverUrl =
                            _MediaSanitizer.imageUrl(item.coverUrl);
                        return Semantics(
                          button: true,
                          label: safeTitle,
                          child: GestureDetector(
                            onTap: () {
                              _clearSearch();
                              _openDetail(item);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildCoverImage(coverUrl),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Color(0xCC000000),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 6,
                                    right: 6,
                                    bottom: 6,
                                    child: Text(
                                      safeTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON
// ============================================================================

class _MediaSkeleton extends StatelessWidget {
  const _MediaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: ThixPolicy.primary),
          SizedBox(height: 16),
          Text(
            'Chargement du catalogue…',
            style: TextStyle(color: ThixPolicy.textMuted),
          ),
        ],
      ),
    );
  }
}
