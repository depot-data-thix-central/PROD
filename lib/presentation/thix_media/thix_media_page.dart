
// lib/presentation/thix_media/thix_media_page.dart

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

import 'widgets/fil_feed_view.dart';
import 'widgets/media_detail_page.dart';
import 'admin/thix_media_admin_page.dart';
import 'create_post_page.dart';
import 'user_profile_page.dart';

class MediaConfig {
  MediaConfig._();
  static const double glassBlur = kIsWeb ? 8 : 16;
  static const int maxSearchLength = 120;
  static const int maxTitleLength = 100;
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
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7F8FA);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF0F0F0F);
  static const Color textSecondary = Color(0xFF606060);
  static const Color textMuted = Color(0xFF909090);
  static const Color chipBg = Color(0xFFF2F2F2);
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

// ── Raccourcis "Films" : mapping icône / label par catégorie ─────────────
class MediaShortcut {
  final String label;
  final IconData icon;
  const MediaShortcut(this.label, this.icon);
}

IconData _iconForCategory(String cat) {
  final c = cat.toLowerCase();
  if (c.contains('tous')) return Icons.apps_rounded;
  if (c.contains('fil')) return Icons.play_circle_outline_rounded;
  if (c.contains('film')) return Icons.local_movies_rounded;
  if (c.contains('série') || c.contains('serie')) return Icons.video_library_rounded;
  if (c.contains('clip')) return Icons.bolt_rounded;
  if (c.contains('live') || c.contains('direct')) return Icons.sensors_rounded;
  if (c.contains('musique') || c.contains('music')) return Icons.music_note_rounded;
  if (c.contains('formation')) return Icons.school_rounded;
  if (c.contains('opportunit')) return Icons.work_outline_rounded;
  return Icons.category_rounded;
}

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

  bool _showFilUI = true;
  Timer? _filUITimer;
  DateTime _lastTimerReset = DateTime.now();

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
    _filUITimer?.cancel();
    AnalyticsBatcher.dispose();
    super.dispose();
  }

  void _wakeUpFilUI() {
    if (!mounted) return;
    if (!_showFilUI) {
      setState(() => _showFilUI = true);
    }
    final now = DateTime.now();
    if (_filUITimer == null || !_filUITimer!.isActive || now.difference(_lastTimerReset).inMilliseconds > 500) {
      _lastTimerReset = now;
      _filUITimer?.cancel();
      _filUITimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showFilUI) setState(() => _showFilUI = false);
      });
    }
  }

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key) return fallback;
    return val;
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
    setState(() => _showSearchOverlay = _searchFocusNode.hasFocus && _lowerQuery.isNotEmpty);
  }

  // ✅ CORRECTION RECHERCHE : plus de "cassure" à la 1ère lettre.
  // L'affichage (overlay + filtrage local) est instantané à chaque frappe ;
  // seul l'écriture vers le provider global est débouncée (évite le spam réseau).
  void _onSearchChanged(String v) {
    final sanitizedLower = MediaSanitizer.searchQuery(v);

    setState(() {
      _searchQuery = MediaSanitizer.text(v, maxLength: MediaConfig.maxSearchLength);
      _lowerQuery = sanitizedLower;
      _showSearchOverlay = _searchFocusNode.hasFocus && sanitizedLower.isNotEmpty;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(MediaConfig.searchDebounce, () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = sanitizedLower;
    });
  }

  void _clearSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    _searchDebounce?.cancel();
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailPage(item: item, catalog: catalog)));
  }

  void _openAdmin() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ThixMediaAdminPage()));
  }

  void _openCreatePost() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage()));
  }

  void _openProfile() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || !mounted) return;
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: uid)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;

    final strFil = _safeTr(l10n, 'category_feed', 'Fil');
    final strTous = _safeTr(l10n, 'category_all', 'Tous');

    ref.listen<String>(selectedCategoryProvider, (prev, next) {
      if (next == 'Fil' || next == strFil) {
        _wakeUpFilUI();
      } else {
        _filUITimer?.cancel();
        _showFilUI = true;
      }
    });

    return Scaffold(
      backgroundColor: MediaLightPalette.background,
      body: asyncMedia.when(
        loading: () => _MediaSkeleton(l10n: l10n),
        error: (e, st) => _buildErrorState(l10n, e),
        data: (catalog) => Stack(
          children: [
            _buildMainContent(context, l10n, catalog, isAdmin, selectedCategory, strFil, strTous),
            if (_showSearchOverlay) _buildSearchOverlay(context, l10n, catalog),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, AppLocalizations l10n, List<MediaContent> catalog, bool isAdmin, String selectedCategory, String strFil, String strTous) {
    final categories = _computeCategories(catalog, strTous, strFil);

    // ── MODE FIL (TIKTOK FULL SCREEN + AUTO-HIDE) ─────────────────────────
    if (selectedCategory == strFil || selectedCategory == 'Fil') {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => _wakeUpFilUI(),
                onPointerMove: (_) => _wakeUpFilUI(),
                behavior: HitTestBehavior.translucent,
                child: RepaintBoundary(
                  child: FilFeedView(catalog: catalog, onOpenDetail: _openDetail),
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showFilUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showFilUI,
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
            SliverToBoxAdapter(child: _buildShortcutsRow(categories, selectedCategory)),
            SliverToBoxAdapter(child: _buildHero(l10n, catalog)),
            SliverToBoxAdapter(child: _buildCategoryChips(categories, selectedCategory, isDarkBg: false)),
            if (series.isNotEmpty) SliverToBoxAdapter(child: _buildSeriesRail(l10n, series)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  (selectedCategory == strTous || selectedCategory == 'Tous') ? _safeTr(l10n, 'media_catalog', 'Catalogue TDIA') : selectedCategory,
                  style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 20, childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => RepaintBoundary(
                    child: MediaPosterCard(item: filtered[i], onTap: () => _openDetail(filtered[i])),
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

  List<String> _computeCategories(List<MediaContent> catalog, String strTous, String strFil) {
    final types = catalog.map((e) => e.type)
        .where((t) => t.isNotEmpty && t != 'Fil' && t != strFil && t != 'Opportunités')
        .toSet().toList()..sort();
    return [strTous, strFil, 'Opportunités', ...types];
  }

  // ── NOUVEAU : rail de raccourcis type "Films / Séries / Live / ..." ────
  Widget _buildShortcutsRow(List<String> categories, String selected) {
    // On garde une sélection courte et pertinente (max 8) pour rester épuré.
    final shortcuts = categories.take(8).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: shortcuts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (c, i) {
            final cat = shortcuts[i];
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
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: sel ? ThixPolicy.primary : MediaLightPalette.chipBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForCategory(cat),
                          color: sel ? Colors.white : MediaLightPalette.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                          color: sel ? MediaLightPalette.textPrimary : MediaLightPalette.textMuted,
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
    );
  }

  Widget _buildCategoryChips(List<String> categories, String selected, {bool isDarkBg = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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

            final unselectedBg = isDarkBg ? Colors.black.withValues(alpha: 0.4) : MediaLightPalette.chipBg;
            final unselectedBorder = isDarkBg ? Colors.white.withValues(alpha: 0.2) : Colors.transparent;
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
                    border: Border.all(color: sel ? selectedBg : unselectedBorder, width: 1),
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

  Widget _buildSliverHeader(AppLocalizations l10n, bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MediaLightPalette.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MediaLightPalette.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: MediaLightPalette.surface,
          border: Border(bottom: BorderSide(color: MediaLightPalette.border)),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: ThixPolicy.primary, size: 26),
          const SizedBox(width: 8),
          const Text('TDIA', style: TextStyle(color: MediaLightPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3)),
        ],
      ),
      actions: [
        if (isAdmin) _headerIconButton('Admin', Icons.admin_panel_settings_rounded, _openAdmin),
        _headerIconButton('Créer', Icons.add_rounded, _openCreatePost),
        _headerIconButton('Profil', Icons.person_rounded, _openProfile),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          const Text('TDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
          const Spacer(),
          if (isAdmin) _headerIconButton('Admin', Icons.admin_panel_settings_rounded, _openAdmin, isLight: false),
          _headerIconButton('Créer', Icons.add_rounded, _openCreatePost, isLight: false),
          _headerIconButton('Profil', Icons.person_rounded, _openProfile, isLight: false),
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
            color: isLight ? MediaLightPalette.chipBg : Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isLight ? MediaLightPalette.textPrimary : Colors.white, size: 20),
        ),
      ),
    );
  }

  // ── Recherche : champ stable, filtrage instantané (voir _onSearchChanged) ──
  Widget _buildSearchBar(AppLocalizations l10n) {
    final hint = _safeTr(l10n, 'media_search_hint', 'Rechercher des vidéos...');
    return Container(
      key: const ValueKey('media_search_bar'),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MediaLightPalette.chipBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: MediaLightPalette.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              textField: true,
              label: hint,
              child: TextField(
                key: const ValueKey('media_search_field'),
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
                  hintText: hint,
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
              label: _safeTr(l10n, 'common_clear', 'Effacer'),
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

  Widget _buildHero(AppLocalizations l10n, List<MediaContent> catalog) {
    final featured = catalog.take(MediaConfig.maxHeroItems).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: SizedBox(
        height: 210,
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
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover) : Container(color: MediaLightPalette.chipBg),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Row(
                      children: [
                        _heroBadge(ThixPolicy.primary, _safeTr(l10n, 'media_featured', 'À LA UNE')),
                        if (item.isPaid) ...[
                          const SizedBox(width: 8),
                          _heroBadge(Colors.black.withValues(alpha: 0.55), _safeTr(l10n, 'media_premium', 'Premium'), icon: Icons.lock_rounded),
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
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              '${formatMediaNumber(item.viewCount)} vues',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        ],
      ),
    );
  }

  Widget _buildSeriesRail(AppLocalizations l10n, List<MediaContent> series) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.video_library_rounded, size: 18, color: MediaLightPalette.textPrimary),
                const SizedBox(width: 8),
                Text(_safeTr(l10n, 'media_series', 'Séries'), style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 195,
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

  Widget _buildSearchOverlay(BuildContext context, AppLocalizations l10n, List<MediaContent> catalog) {
    final results = _lowerQuery.isEmpty ? const <MediaContent>[] : catalog.where((e) => e.title.toLowerCase().contains(_lowerQuery)).toList();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _searchFocusNode.unfocus(),
        child: Container(
          color: MediaLightPalette.surface,
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 140, left: 20, right: 20),
          child: results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: MediaLightPalette.chipBg, shape: BoxShape.circle),
                        child: const Icon(Icons.search_off_rounded, size: 36, color: MediaLightPalette.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Text(_safeTr(l10n, 'media_no_results', 'Aucun résultat.'), style: const TextStyle(color: MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final item = results[i];
                    return MediaPosterCard(
                      item: item,
                      compact: true,
                      onTap: () {
                        _clearSearch();
                        _openDetail(item);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: ThixPolicy.danger, size: 48),
            const SizedBox(height: 16),
            Text(_safeTr(l10n, 'media_load_error', 'Erreur de chargement'), textAlign: TextAlign.center, style: const TextStyle(color: MediaLightPalette.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(thixMediaListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_safeTr(l10n, 'common_retry', 'Réessayer')),
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
              decoration: const BoxDecoration(color: MediaLightPalette.chipBg, shape: BoxShape.circle),
              child: const Icon(Icons.video_library_outlined, size: 40, color: MediaLightPalette.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(_safeTr(l10n, 'media_empty', 'Aucun contenu disponible.'), style: const TextStyle(color: MediaLightPalette.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MediaSkeleton extends StatelessWidget {
  final AppLocalizations l10n;
  const _MediaSkeleton({required this.l10n});

  String _safeTr(String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key) return fallback;
    return val;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: ThixPolicy.primary),
          const SizedBox(height: 16),
          Text(_safeTr('media_loading', 'Chargement du catalogue…'), style: const TextStyle(color: MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── CARTE VIDÉO — refonte épurée façon YouTube ─────────────────────────
// Miniature propre (pas de gradient plein cadre), badges discrets,
// titre + vues en dessous sur fond blanc, légende sur 2 lignes max.
class MediaPosterCard extends StatelessWidget {
  final MediaContent item;
  final VoidCallback onTap;
  final bool compact;

  const MediaPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  bool get _isSeries => item.episodesUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final title = MediaSanitizer.text(item.title, maxLength: MediaConfig.maxTitleLength);
    final cover = MediaSanitizer.imageUrl(item.coverUrl);

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: MediaLightPalette.chipBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover != null
                        ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                        : Container(
                            color: MediaLightPalette.chipBg,
                            child: const Icon(Icons.movie_creation_outlined, color: MediaLightPalette.textMuted, size: 28),
                          ),

                    // Badge série (haut-gauche, discret)
                    if (_isSeries)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _miniBadge('${item.episodesUrls.length + 1} parties'),
                      ),

                    // Badge premium (haut-droit, discret)
                    if (item.isPaid)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                          child: const Icon(Icons.lock_rounded, size: 11, color: Colors.white),
                        ),
                      ),

                    // Vues (bas-droit, mini chip sombre — style durée YouTube)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              formatMediaNumber(item.viewCount),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MediaLightPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text(
                item.type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MediaLightPalette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ThixPolicy.primary,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}
