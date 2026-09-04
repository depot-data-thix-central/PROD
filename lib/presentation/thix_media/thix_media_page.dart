// lib/presentation/thix_media/thix_media_page.dart
//
// ThixMediaPage (TDIA) — "Modern Sleek Light" (Production Enterprise)
//
// - Design 100% refait : Thème BLANC / CLAIR éclatant (Sleek Glassmorphism).
// - Fichier allégé : Le Fil (TikTok) et les Posters sont déportés dans /widgets.
// - Navigation gérée proprement via MediaRoutes (go_router).
// - Complet à 100% : Héros, Recherche, Salons Audio, Séries.

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
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

import 'media_routes.dart';

// ✅ IMPORTS DE TES WIDGETS DÉPORTÉS
import 'widgets/fil_feed_view.dart';
import 'widgets/media_poster_card.dart';

// ============================================================================
// CONFIGURATION GLOBALE (Publique pour être utilisée par les widgets)
// ============================================================================
class MediaConfig {
  MediaConfig._();
  static const double glassBlur = kIsWeb ? 8 : 16;
  static const int maxSearchLength = 120;
  static const int maxTitleLength = 100;
  static const int maxCommentLength = 500;
  static const int maxHeroItems = 6;
  static const Duration scrollThrottle = Duration(milliseconds: 250);
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const Duration heroAutoScroll = Duration(seconds: 5);
  static const Duration analyticsFlushDelay = Duration(seconds: 8);
  static const Duration networkTimeout = Duration(seconds: 10);
  static const Duration heartPopDuration = Duration(milliseconds: 550);
  static const int previewSeconds = 30;
  static const int commentsPageSize = 50;
  static const double likeWeight = 2.0;
  static const double commentWeight = 3.0;
  static const double viewWeight = 0.05;
  static const double explorationMin = 0.65;
  static const double explorationRange = 0.7;
}

class MediaLightPalette {
  MediaLightPalette._();
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color accentAudio = Color(0xFF8B5CF6);
}

class MediaSanitizer {
  MediaSanitizer._();
  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }
  static String? imageUrl(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (!u.startsWith('http://') && !u.startsWith('https://')) return null;
    return u;
  }
  static String searchQuery(String? input) => text(input, maxLength: MediaConfig.maxSearchLength).toLowerCase();
  static bool isValidId(String? id) => id != null && id.trim().isNotEmpty && id.length <= 128;
}

String formatMediaNumber(int count) {
  if (count <= 0) return '0';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}

class AnalyticsBatcher {
  AnalyticsBatcher._();
  static final Set<String> _pending = {};
  static Timer? _timer;

  static void register(String id) {
    if (!MediaSanitizer.isValidId(id)) return;
    _pending.add(id);
    _timer ??= Timer(MediaConfig.analyticsFlushDelay, _flush);
  }

  static Future<void> _flush() async {
    if (_pending.isEmpty) { _timer = null; return; }
    final batch = _pending.toList();
    _pending.clear();
    _timer = null;
    try { await Supabase.instance.client.rpc('batch_register_views', params: {'p_media_ids': batch}).timeout(MediaConfig.networkTimeout); } catch (_) { _pending.addAll(batch); }
  }

  static void dispose() { _timer?.cancel(); _timer = null; }
}

// ============================================================================
// PAGE PRINCIPALE THIX MEDIA
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
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _heroController.dispose();
    _searchDebounce?.cancel();
    _scrollThrottle?.cancel();
    _heroAutoScroll?.cancel();
    AnalyticsBatcher.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollThrottle?.isActive ?? false) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      _scrollThrottle = Timer(MediaConfig.scrollThrottle, () {});
      ref.read(thixMediaListProvider.notifier).loadMore();
    }
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() => _showSearchOverlay = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty);
  }

  void _onSearchChanged(String v) {
    final sanitized = MediaSanitizer.searchQuery(v);
    if (sanitized == _lowerQuery) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(MediaConfig.searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _lowerQuery = sanitized;
        _searchQuery = MediaSanitizer.text(v, maxLength: MediaConfig.maxSearchLength);
        _showSearchOverlay = _searchFocusNode.hasFocus && sanitized.isNotEmpty;
      });
      ref.read(searchQueryProvider.notifier).state = sanitized;
    });
  }

  void _clearSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = ''; _lowerQuery = ''; _showSearchOverlay = false;
    });
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _startHeroAutoScroll() {
    _heroAutoScroll = Timer.periodic(MediaConfig.heroAutoScroll, (_) {
      if (!mounted || !_heroController.hasClients) return;
      final page = (_heroController.page ?? 0).round();
      final catalog = ref.read(thixMediaListProvider).valueOrNull ?? [];
      final count = catalog.length.clamp(0, MediaConfig.maxHeroItems);
      if (count == 0) return;
      final next = (page + 1) % count;
      _heroController.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    });
  }

  void _openDetail(MediaContent item) {
    if (!mounted || !MediaSanitizer.isValidId(item.id)) return;
    AnalyticsBatcher.register(item.id);
    final catalog = ref.read(thixMediaListProvider).valueOrNull ?? const [];
    MediaRoutes.goToMediaDetail(context, item, catalog);
  }

  void _openAdmin() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    context.push(MediaRoutes.admin);
  }

  void _openCreatePost() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    context.push(MediaRoutes.createPost);
  }

  void _openProfile() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || !mounted) return;
    HapticFeedback.selectionClick();
    MediaRoutes.goToUserProfile(context, uid);
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.trim().isEmpty) {
      return Container(
        color: MediaLightPalette.border,
        child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: MediaLightPalette.textMuted, size: 40)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url, fit: fit,
      placeholder: (c, url) => Container(color: MediaLightPalette.border),
      errorWidget: (c, e, s) => Container(
        color: MediaLightPalette.border,
        child: const Center(child: Icon(Icons.broken_image_rounded, color: MediaLightPalette.textMuted, size: 30)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;

    // Fallbacks sécurisés si la traduction manque
    final strFil = l10n.t('category_feed').isNotEmpty ? l10n.t('category_feed') : 'Fil';
    final strTous = l10n.t('category_all').isNotEmpty ? l10n.t('category_all') : 'Tous';

    return Scaffold(
      backgroundColor: MediaLightPalette.background,
      body: asyncMedia.when(
        loading: () => const _MediaSkeleton(),
        error: (e, st) => _buildErrorState(l10n, e),
        data: (catalog) => Stack(
          children: [
            _buildMainContent(context, l10n, catalog, isAdmin, selectedCategory, strFil, strTous),
            if (_showSearchOverlay) _buildSearchOverlay(l10n, catalog),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, AppLocalizations l10n, List<MediaContent> catalog, bool isAdmin, String selectedCategory, String strFil, String strTous) {
    final categories = _computeCategories(catalog, strTous, strFil);

    // ── MODE FIL (TIKTOK) ────────────────────────────────────────────────
    if (selectedCategory == strFil || selectedCategory == 'Fil') {
      return Container(
        color: Colors.black, // Fond noir pour faire ressortir la vidéo
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: FilFeedView(
                  catalog: catalog,
                  onOpenDetail: _openDetail,
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTransparentHeader(l10n, isAdmin),
                    _buildCategoryChips(categories, selectedCategory, isDarkBg: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── MODE GRILLE (CATALOGUE) ──────────────────────────────────────────
    final filtered = (selectedCategory == strTous || selectedCategory == 'Tous')
        ? catalog
        : catalog.where((e) => e.type == selectedCategory).toList();

    final series = catalog.where((e) => e.episodesUrls.isNotEmpty).toList();

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: MediaLightPalette.surface,
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
            SliverToBoxAdapter(child: _buildAudioRoomsRail()), 
            SliverToBoxAdapter(child: _buildCategoryChips(categories, selectedCategory, isDarkBg: false)),
            if (series.isNotEmpty) SliverToBoxAdapter(child: _buildSeriesRail(l10n, series)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  (selectedCategory == strTous || selectedCategory == 'Tous') ? (l10n.t('media_catalog').isNotEmpty ? l10n.t('media_catalog') : 'Catalogue TDIA') : selectedCategory,
                  style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.70,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => RepaintBoundary(
                    child: MediaPosterCard(
                      item: filtered[i],
                     //formatNumber: formatMediaNumber,
                      //buildImage: _buildImage,
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
  // CATEGORY CHIPS
  // ========================================================================

  List<String> _computeCategories(List<MediaContent> catalog, String strTous, String strFil) {
    final types = catalog.map((e) => e.type).where((t) => t.isNotEmpty).toSet().toList()..sort();
    return [strTous, strFil, 'Opportunités', ...types]; 
  }

  Widget _buildCategoryChips(List<String> categories, String selected, {bool isDarkBg = false}) {
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

            final unselectedBg = isDarkBg ? Colors.black.withValues(alpha: 0.4) : MediaLightPalette.surface;
            final unselectedBorder = isDarkBg ? Colors.white.withValues(alpha: 0.2) : MediaLightPalette.border;
            final unselectedText = isDarkBg ? Colors.white70 : MediaLightPalette.textSecondary;
            final selectedBg = isDarkBg ? Colors.white : MediaLightPalette.textPrimary;
            final selectedText = isDarkBg ? Colors.black : Colors.white;

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
                    color: sel ? selectedBg : unselectedBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sel ? selectedBg : unselectedBorder, width: 1.2),
                    boxShadow: sel ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(cat, style: TextStyle(color: sel ? selectedText : unselectedText, fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ========================================================================
  // HEADERS (SliverAppBar & Transparent)
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
          filter: ImageFilter.blur(sigmaX: MediaConfig.glassBlur, sigmaY: MediaConfig.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: MediaLightPalette.surface.withValues(alpha: 0.8),
              border: const Border(bottom: BorderSide(color: MediaLightPalette.border)),
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: ThixPolicy.primary, size: 28),
          const SizedBox(width: 8),
          const Text('TDIA', style: TextStyle(color: MediaLightPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        ],
      ),
      actions: [
        if (isAdmin) _headerIconButton(l10n.t('media_admin'), Icons.admin_panel_settings_rounded, _openAdmin),
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
          if (isAdmin) _headerIconButton(l10n.t('media_admin'), Icons.admin_panel_settings_rounded, _openAdmin, isLight: false),
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
            color: isLight ? MediaLightPalette.border.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isLight ? MediaLightPalette.textPrimary : Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MediaLightPalette.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MediaLightPalette.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: MediaLightPalette.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              textField: true,
              label: l10n.t('media_search'),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                maxLength: MediaConfig.maxSearchLength,
                style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                cursorColor: ThixPolicy.primary,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.t('media_search_hint').isNotEmpty ? l10n.t('media_search_hint') : 'Rechercher...',
                  hintStyle: const TextStyle(color: MediaLightPalette.textMuted, fontSize: 13.5, fontWeight: FontWeight.w500),
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
                  decoration: const BoxDecoration(color: MediaLightPalette.textMuted, shape: BoxShape.circle),
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
    final featured = catalog.take(MediaConfig.maxHeroItems).toList();
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
    final safeTitle = MediaSanitizer.text(item.title, maxLength: MediaConfig.maxTitleLength);
    final coverUrl = MediaSanitizer.imageUrl(item.coverUrl);

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
                  _buildImage(coverUrl ?? ''),
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
                        _heroBadge(ThixPolicy.primary, l10n.t('media_featured').isNotEmpty ? l10n.t('media_featured') : 'À LA UNE'),
                        if (item.isPaid) ...[
                          const SizedBox(width: 8),
                          _heroBadge(ThixPolicy.warning, l10n.t('media_premium').isNotEmpty ? l10n.t('media_premium') : 'Premium', icon: Icons.lock_rounded),
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

  // ========================================================================
  // AUDIO ROOMS RAIL
  // ========================================================================

  Widget _buildAudioRoomsRail() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: MediaLightPalette.accentAudio.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.mic_rounded, size: 16, color: MediaLightPalette.accentAudio),
                ),
                const SizedBox(width: 8),
                const Text('Salons Audio en direct', style: TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (c, i) => Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MediaLightPalette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MediaLightPalette.accentAudio.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: MediaLightPalette.accentAudio.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, color: MediaLightPalette.accentAudio, size: 14),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('L\'entrepreneuriat en RDC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: MediaLightPalette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        SizedBox(
                          width: 50, height: 24,
                          child: Stack(
                            children: const [
                              Positioned(left: 0, child: CircleAvatar(radius: 12, backgroundColor: MediaLightPalette.border, child: Icon(Icons.person, size: 12))),
                              Positioned(left: 14, child: CircleAvatar(radius: 12, backgroundColor: MediaLightPalette.border, child: Icon(Icons.person, size: 12))),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: MediaLightPalette.accentAudio, borderRadius: BorderRadius.circular(10)),
                          child: const Text('Rejoindre', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
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
                Text(l10n.t('media_series').isNotEmpty ? l10n.t('media_series') : 'Séries', style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
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
                  child: MediaPosterCard(
                    item: series[i],
                    //formatNumber: formatMediaNumber,
                    //buildImage: _buildImage,
                    onTap: () => _openDetail(series[i]),
                    compact: true,
                  ),
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

  Widget _buildSearchOverlay(AppLocalizations l10n, List<MediaContent> catalog) {
    final results = _lowerQuery.isEmpty ? const <MediaContent>[] : catalog.where((e) => e.title.toLowerCase().contains(_lowerQuery)).toList();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _clearSearch,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: MediaLightPalette.surface.withValues(alpha: 0.85),
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 140, left: 20, right: 20),
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: MediaLightPalette.border, shape: BoxShape.circle),
                            child: const Icon(Icons.search_off_rounded, size: 40, color: MediaLightPalette.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.t('media_no_results').isNotEmpty ? l10n.t('media_no_results') : 'Aucun résultat.', style: const TextStyle(color: MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
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
                                _buildImage(MediaSanitizer.imageUrl(item.coverUrl) ?? ''),
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
                                    MediaSanitizer.text(item.title, maxLength: MediaConfig.maxTitleLength),
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

  Widget _buildErrorState(AppLocalizations l10n, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: ThixPolicy.danger, size: 48),
            const SizedBox(height: 16),
            Text(l10n.t('media_load_error').isNotEmpty ? l10n.t('media_load_error') : 'Erreur de chargement', textAlign: TextAlign.center, style: const TextStyle(color: MediaLightPalette.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(thixMediaListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.t('common_retry').isNotEmpty ? l10n.t('common_retry') : 'Réessayer'),
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
              decoration: const BoxDecoration(color: MediaLightPalette.border, shape: BoxShape.circle),
              child: const Icon(Icons.video_library_outlined, size: 40, color: MediaLightPalette.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('media_empty').isNotEmpty ? l10n.t('media_empty') : 'Aucun contenu.', style: const TextStyle(color: MediaLightPalette.textMuted, fontWeight: FontWeight.w600)),
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
          Text('Chargement du catalogue…', style: TextStyle(color: MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
