// lib/presentation/thix_media/thix_media_page.dart
//
// ThixMediaPage (TDIA) — "Modern Sleek Light" (Production Enterprise)
//
// - Design 100% refait : Thème BLANC / CLAIR éclatant (Sleek Glassmorphism).
// - i18n complet (Correction des filtres "Fil" et "Tous").
// - Riverpod pur, go_router, throttling et sanitization anti-XSS conservés.
// - Ombres ultra-douces, bordures subtiles et lisibilité maximale.

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
import 'media_routes.dart';

// ============================================================================
// PALETTE CLAIRE (Light Mode Premium)
// ============================================================================

class _MediaLightPalette {
  _MediaLightPalette._();

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
}

// ============================================================================
// CONSTANTES & CONFIGURATION
// ============================================================================

const double _kGlassBlur = kIsWeb ? 8 : 16;
const int _kMaxSearchLength = 120;
const int _kMaxTitleLength = 100;
const int _kMaxHeroItems = 6;
const Duration _kScrollThrottle = Duration(milliseconds: 250);
const Duration _kSearchDebounce = Duration(milliseconds: 400);
const Duration _kHeroAutoScroll = Duration(seconds: 5);

// ============================================================================
// SANITIZER (Sécurité anti-XSS préservée)
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
// PAGE PRINCIPALE
// ============================================================================

class ThixMediaPage extends ConsumerStatefulWidget {
  const ThixMediaPage({super.key});
  @override
  ConsumerState<ThixMediaPage> createState() => _ThixMediaPageState();
}

class _ThixMediaPageState extends ConsumerState<ThixMediaPage> with AutomaticKeepAliveClientMixin<ThixMediaPage> {
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
    setState(() => _showSearchOverlay = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty);
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
        _showSearchOverlay = _searchFocusNode.hasFocus && sanitized.isNotEmpty;
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
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  // ── Navigation ──────────────────────────────────────────────

  void _openDetail(MediaContent item) {
    if (!mounted) return;
    final safeId = _MediaSanitizer.text(item.id, maxLength: 64);
    if (safeId.isEmpty) return;
    
    AnalyticsBatcher.register(safeId);
    MediaRoutes.goToMediaDetail(
      context,
      item,
      ref.read(thixMediaListProvider).valueOrNull ?? const [],
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

  // ── Build Principal ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: _MediaLightPalette.background,
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
  // MAIN CONTENT (Grille & Fil)
  // ========================================================================

  Widget _buildMainContent(
    BuildContext context,
    AppLocalizations l10n,
    List<MediaContent> catalog,
    bool isAdmin,
    String selectedCategory,
  ) {
    // Gestion intelligente des traductions pour le filtrage
    final strFil = l10n.t('category_feed');
    final strTous = l10n.t('category_all');

    if (selectedCategory == 'Fil' || selectedCategory == strFil) {
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

    final filtered = (selectedCategory == 'Tous' || selectedCategory == strTous)
        ? catalog
        : catalog.where((e) => e.type == selectedCategory).toList();
        
    final series = catalog.where((e) => e.episodesUrls.isNotEmpty).toList();
    final categories = _computeCategories(catalog, l10n);

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: _MediaLightPalette.surface,
      onRefresh: () {
        HapticFeedback.mediumImpact();
        return ref.read(thixMediaListProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildSliverHeader(l10n, isAdmin),
          if (catalog.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(l10n))
          else ...[
            SliverToBoxAdapter(child: _buildHero(l10n, catalog)),
            SliverToBoxAdapter(child: _buildCategoryChips(l10n, categories, selectedCategory)),
            if (series.isNotEmpty) SliverToBoxAdapter(child: _buildSeriesRail(l10n, series)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  (selectedCategory == 'Tous' || selectedCategory == strTous) ? l10n.t('media_catalog') : selectedCategory,
                  style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.70,
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
  // HEADERS (Sliver & Transparent)
  // ========================================================================

  Widget _buildSliverHeader(AppLocalizations l10n, bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: _MediaLightPalette.surface.withValues(alpha: 0.8),
              border: const Border(bottom: BorderSide(color: _MediaLightPalette.border)),
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: ThixPolicy.primary, size: 28),
          const SizedBox(width: 8),
          Text(
            'TDIA',
            style: const TextStyle(color: _MediaLightPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
          ),
        ],
      ),
      actions: [
        if (isAdmin)
          _headerIconButton(l10n.t('media_admin'), Icons.admin_panel_settings_rounded, _openAdmin),
        _headerIconButton(l10n.t('media_create'), Icons.add_rounded, _openCreatePost),
        _headerIconButton(l10n.t('nav_profile'), Icons.person_rounded, _openProfile),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _buildSearchBar(l10n),
        ),
      ),
    );
  }

  Widget _buildTransparentHeader(AppLocalizations l10n, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          const Text('TDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
          const Spacer(),
          if (isAdmin)
            _headerIconButton(l10n.t('media_admin'), Icons.admin_panel_settings_rounded, _openAdmin, isLight: false),
          _headerIconButton(l10n.t('media_create'), Icons.add_rounded, _openCreatePost, isLight: false),
          _headerIconButton(l10n.t('nav_profile'), Icons.person_rounded, _openProfile, isLight: false),
        ],
      ),
    );
  }

  Widget _headerIconButton(String label, IconData icon, VoidCallback onTap, {bool isLight = true}) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isLight ? _MediaLightPalette.border.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isLight ? _MediaLightPalette.textPrimary : Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _MediaLightPalette.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _MediaLightPalette.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _MediaLightPalette.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              textField: true,
              label: l10n.t('media_search'),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                maxLength: _kMaxSearchLength,
                style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                cursorColor: ThixPolicy.primary,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.t('media_search_hint'),
                  hintStyle: const TextStyle(color: _MediaLightPalette.textMuted, fontSize: 13.5, fontWeight: FontWeight.w500),
                  border: InputBorder.none,
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
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: _MediaLightPalette.textMuted, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // HERO CAROUSEL
  // ========================================================================

  Widget _buildHero(AppLocalizations l10n, List<MediaContent> catalog) {
    final featured = catalog.take(_kMaxHeroItems).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: SizedBox(
        height: 220,
        child: PageView.builder(
          controller: _heroController,
          itemCount: featured.length,
          itemBuilder: (c, i) => _buildHeroCard(l10n, featured[i]),
        ),
      ),
    );
  }

  Widget _buildHeroCard(AppLocalizations l10n, MediaContent item) {
    final safeTitle = _MediaSanitizer.text(item.title, maxLength: _kMaxTitleLength);
    final coverUrl = _MediaSanitizer.imageUrl(item.coverUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Semantics(
        button: true,
        label: safeTitle,
        child: GestureDetector(
          onTap: () => _openDetail(item),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCoverImage(coverUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                        stops: [0.4, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: Row(
                      children: [
                        _heroBadge(ThixPolicy.primary, l10n.t('media_featured')),
                        if (item.isPaid) ...[
                          const SizedBox(width: 8),
                          _heroBadge(ThixPolicy.warning, l10n.t('media_premium'), icon: Icons.lock_rounded),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          safeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              formatMediaNumber(item.viewCount),
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _heroBadge(Color color, String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildCoverImage(String? url) {
    if (url == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ThixPolicy.primary.withValues(alpha: 0.6), ThixPolicy.primaryDeep],
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheHeight: 400,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: _MediaLightPalette.border),
      errorWidget: (_, __, ___) => Container(
        color: _MediaLightPalette.border,
        child: const Icon(Icons.broken_image_rounded, color: _MediaLightPalette.textMuted, size: 32),
      ),
    );
  }

  // ========================================================================
  // CATEGORY CHIPS
  // ========================================================================

  List<String> _computeCategories(List<MediaContent> catalog, AppLocalizations l10n) {
    final types = catalog.map((e) => e.type).where((t) => t.isNotEmpty).toSet().toList()..sort();
    return [l10n.t('category_all'), l10n.t('category_feed'), ...types];
  }

  Widget _buildCategoryChips(AppLocalizations l10n, List<String> categories, String selected) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _MediaLightPalette.textPrimary : _MediaLightPalette.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sel ? _MediaLightPalette.textPrimary : _MediaLightPalette.border, width: 1.2),
                    boxShadow: sel ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: sel ? Colors.white : _MediaLightPalette.textSecondary,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
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

  // ========================================================================
  // SERIES RAIL
  // ========================================================================

  Widget _buildSeriesRail(AppLocalizations l10n, List<MediaContent> series) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.video_library_rounded, size: 16, color: ThixPolicy.primary),
                ),
                const SizedBox(width: 8),
                Text(l10n.t('media_series'), style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: series.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (c, i) => RepaintBoundary(
                child: SizedBox(
                  width: 130,
                  child: MediaPosterCard(item: series[i], onTap: () => _openDetail(series[i]), compact: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // SEARCH OVERLAY
  // ========================================================================

  Widget _buildSearchOverlay(BuildContext context, AppLocalizations l10n, List<MediaContent> catalog) {
    final results = _lowerQuery.isEmpty ? const <MediaContent>[] : catalog.where((e) => e.title.toLowerCase().contains(_lowerQuery)).toList();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _clearSearch,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: _MediaLightPalette.surface.withValues(alpha: 0.85),
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 140, left: 20, right: 20),
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: _MediaLightPalette.border, shape: BoxShape.circle),
                            child: const Icon(Icons.search_off_rounded, size: 40, color: _MediaLightPalette.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.t('media_no_results'), style: const TextStyle(color: _MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final item = results[i];
                        return GestureDetector(
                          onTap: () {
                            _clearSearch();
                            _openDetail(item);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildCoverImage(_MediaSanitizer.imageUrl(item.coverUrl)),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black87, Colors.transparent],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 8,
                                  child: Text(
                                    _MediaSanitizer.text(item.title, maxLength: _kMaxTitleLength),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
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

  // ========================================================================
  // ERROR / EMPTY STATES
  // ========================================================================

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: ThixPolicy.danger, size: 48),
            const SizedBox(height: 16),
            Text(l10n.t('media_load_error'), textAlign: TextAlign.center, style: const TextStyle(color: _MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(thixMediaListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, elevation: 0),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: _MediaLightPalette.border, shape: BoxShape.circle),
              child: const Icon(Icons.video_library_rounded, size: 40, color: _MediaLightPalette.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('media_empty'), style: const TextStyle(color: _MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
          ],
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
          Text('Chargement du catalogue…', style: TextStyle(color: _MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
