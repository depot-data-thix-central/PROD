// lib/presentation/thix_media/thix_media_page.dart
//
// ThixMediaPage (TDIA) — "Modern Sleek Light" (Production Enterprise)
//
// - Design 100% refait : Thème BLANC / CLAIR éclatant (Sleek Glassmorphism).
// - i18n, Riverpod, Navigator direct, throttling et sanitization anti-XSS conservés.
// - Ombres ultra-douces, bordures subtiles.

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

import 'admin/thix_media_admin_page.dart';
import 'create_post_page.dart';
import 'user_profile_page.dart';
import 'widgets/media_detail_page.dart';
import '../../services/media_service.dart';

// ============================================================================
// CONFIGURATION
// ============================================================================

class _MediaConfig {
  _MediaConfig._();

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
// SANITIZER (Sécurité anti-XSS)
// ============================================================================

class _MediaSanitizer {
  _MediaSanitizer._();

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

  static String searchQuery(String? input) => text(input, maxLength: _MediaConfig.maxSearchLength).toLowerCase();
  static bool isValidId(String? id) => id != null && id.trim().isNotEmpty && id.length <= 128;
}

String formatMediaNumber(int count) {
  if (count <= 0) return '0';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}

// ============================================================================
// ANALYTICS BATCHER
// ============================================================================

class AnalyticsBatcher {
  AnalyticsBatcher._();
  static final Set<String> _pending = {};
  static Timer? _timer;

  static void register(String id) {
    if (!_MediaSanitizer.isValidId(id)) return;
    _pending.add(id);
    _timer ??= Timer(_MediaConfig.analyticsFlushDelay, _flush);
  }

  static Future<void> _flush() async {
    if (_pending.isEmpty) {
      _timer = null;
      return;
    }
    final batch = _pending.toList();
    _pending.clear();
    _timer = null;
    try {
      await Supabase.instance.client.rpc('batch_register_views', params: {'p_media_ids': batch}).timeout(_MediaConfig.networkTimeout);
    } catch (_) {
      _pending.addAll(batch);
    }
  }

  static void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

final isMediaAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final u = Supabase.instance.client.auth.currentUser;
  if (u == null) return false;
  final role = u.appMetadata['role'] ?? u.userMetadata?['role'];
  return role == 'admin' || role == 'superadmin';
});

final mediaUserProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (!_MediaSanitizer.isValidId(userId)) return null;
  try {
    return await Supabase.instance.client.from('profiles').select('username, full_name, avatar_url, role').eq('id', userId).maybeSingle().timeout(_MediaConfig.networkTimeout);
  } catch (_) {
    return null;
  }
});

final mediaIsFollowingProvider = FutureProvider.autoDispose.family<bool, String>((ref, targetId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || uid == targetId) return true;
  try {
    final res = await Supabase.instance.client.from('follows').select().eq('follower_id', uid).eq('following_id', targetId).maybeSingle().timeout(_MediaConfig.networkTimeout);
    return res != null;
  } catch (_) {
    return true;
  }
});

final mediaCommentCountProvider = FutureProvider.autoDispose.family<int, String>((ref, mediaId) async {
  if (!_MediaSanitizer.isValidId(mediaId)) return 0;
  try {
    final r = await Supabase.instance.client.from('media_stats').select('comment_count').eq('media_id', mediaId).maybeSingle().timeout(_MediaConfig.networkTimeout);
    return (r?['comment_count'] as int?) ?? 0;
  } catch (_) {
    return 0;
  }
});

class MediaCounts {
  final int likeCount, viewCount, commentCount;
  const MediaCounts({required this.likeCount, required this.viewCount, required this.commentCount});
}

final mediaCountsStreamProvider = StreamProvider.autoDispose.family<MediaCounts, String>((ref, mediaId) {
  if (!_MediaSanitizer.isValidId(mediaId)) {
    return Stream.value(const MediaCounts(likeCount: 0, viewCount: 0, commentCount: 0));
  }
  try {
    return Supabase.instance.client.from('media_stats').stream(primaryKey: ['media_id']).eq('media_id', mediaId).map((rows) {
      if (rows.isEmpty) return const MediaCounts(likeCount: 0, viewCount: 0, commentCount: 0);
      final r = rows.first;
      return MediaCounts(
        likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
        viewCount: (r['view_count'] as num?)?.toInt() ?? 0,
        commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
      );
    });
  } catch (_) {
    return Stream.value(const MediaCounts(likeCount: 0, viewCount: 0, commentCount: 0));
  }
});

// ============================================================================
// MIX INTELLIGENT DU FIL
// ============================================================================

class _SmartFeedMixer {
  _SmartFeedMixer._();

  static double _score(MediaContent item, Random rng) {
    final base = (item.likeCount * _MediaConfig.likeWeight) + (item.commentCount * _MediaConfig.commentWeight) + (item.viewCount * _MediaConfig.viewWeight);
    final jitter = _MediaConfig.explorationMin + rng.nextDouble() * _MediaConfig.explorationRange;
    return (base <= 0 ? 1.0 : base) * jitter;
  }

  static List<MediaContent> mix(List<MediaContent> catalog, {int? seed}) {
    if (catalog.length <= 2) return List.of(catalog);
    final rng = Random(seed);

    final buckets = <String, List<MediaContent>>{};
    for (final item in catalog) {
      final key = (item.userId?.isNotEmpty ?? false) ? item.userId! : 'solo_${item.id}';
      buckets.putIfAbsent(key, () => []).add(item);
    }
    for (final bucket in buckets.values) {
      bucket.sort((a, b) => _score(b, rng).compareTo(_score(a, rng)));
    }

    final result = <MediaContent>[];
    final keys = buckets.keys.toList();
    while (keys.any((k) => buckets[k]!.isNotEmpty)) {
      final available = keys.where((k) => buckets[k]!.isNotEmpty).toList();
      final weights = available.map((k) => _score(buckets[k]!.first, rng)).toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      var pick = total <= 0 ? 0.0 : rng.nextDouble() * total;
      var chosen = 0;
      for (var i = 0; i < weights.length; i++) {
        pick -= weights[i];
        chosen = i;
        if (pick <= 0) break;
      }
      result.add(buckets[available[chosen]]!.removeAt(0));
    }
    return result;
  }
}

// ============================================================================
// COMMENTAIRES
// ============================================================================

class CommentItem {
  final String id, userId, userName, content;
  final String? avatarUrl, parentId;
  final DateTime createdAt;
  final int likeCount, replyCount;

  CommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.avatarUrl,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
  });

  factory CommentItem.fromMap(Map<String, dynamic> m) {
    DateTime parsedDate;
    try {
      parsedDate = m['created_at'] != null ? DateTime.parse(m['created_at'].toString()).toLocal() : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return CommentItem(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      userName: (m['user_name'] as String?)?.trim().isNotEmpty == true ? m['user_name'] as String : 'Utilisateur',
      avatarUrl: _MediaSanitizer.imageUrl(m['avatar_url'] as String?),
      content: _MediaSanitizer.text(m['content']?.toString(), maxLength: _MediaConfig.maxCommentLength),
      createdAt: parsedDate,
      parentId: m['parent_id'] as String?,
      likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
      replyCount: (m['reply_count'] as num?)?.toInt() ?? 0,
    );
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollThrottle?.isActive ?? false) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      _scrollThrottle = Timer(_MediaConfig.scrollThrottle, () {});
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
    _searchDebounce = Timer(_MediaConfig.searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _lowerQuery = sanitized;
        _searchQuery = _MediaSanitizer.text(v, maxLength: _MediaConfig.maxSearchLength);
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
    _heroAutoScroll = Timer.periodic(_MediaConfig.heroAutoScroll, (_) {
      if (!mounted || !_heroController.hasClients) return;
      final page = (_heroController.page ?? 0).round();
      final catalog = ref.read(thixMediaListProvider).valueOrNull ?? [];
      final count = catalog.length.clamp(0, _MediaConfig.maxHeroItems);
      if (count == 0) return;
      final next = (page + 1) % count;
      _heroController.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    });
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.trim().isEmpty) {
      return Container(
        color: _MediaLightPalette.border,
        child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: _MediaLightPalette.textMuted, size: 40)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (c, url) => Container(color: _MediaLightPalette.border),
      errorWidget: (c, e, s) => Container(
        color: _MediaLightPalette.border,
        child: const Center(child: Icon(Icons.broken_image_rounded, color: _MediaLightPalette.textMuted, size: 30)),
      ),
    );
  }

  // ── Navigation (Restaurée) ───────────────────────────────────

  void _openDetail(MediaContent item) {
    if (!mounted || !_MediaSanitizer.isValidId(item.id)) return;
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

  // ── Build Principal ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;

    final strFil = l10n.t('category_feed').isNotEmpty ? l10n.t('category_feed') : 'Fil';
    final strTous = l10n.t('category_all').isNotEmpty ? l10n.t('category_all') : 'Tous';

    return Scaffold(
      backgroundColor: _MediaLightPalette.background,
      body: asyncMedia.when(
        loading: () => _MediaSkeleton(l10n: l10n),
        error: (e, st) => _buildErrorState(l10n, e),
        data: (catalog) => Stack(
          children: [
            _buildMainContent(l10n, catalog, isAdmin, selectedCategory, strFil, strTous),
            if (_showSearchOverlay) _buildSearchOverlay(l10n, catalog),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // MAIN CONTENT (Grille & Fil)
  // ========================================================================

  Widget _buildMainContent(AppLocalizations l10n, List<MediaContent> catalog, bool isAdmin, String selectedCategory, String strFil, String strTous) {
    if (selectedCategory == strFil || selectedCategory == 'Fil') {
      return Stack(
        children: [
          RepaintBoundary(
            child: FilFeedView(
              catalog: catalog,
              onOpenDetail: _openDetail,
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(child: _buildTransparentHeader(l10n, isAdmin)),
          ),
        ],
      );
    }

    final filtered = (selectedCategory == strTous || selectedCategory == 'Tous')
        ? catalog
        : catalog.where((e) => e.type == selectedCategory).toList();

    final series = catalog.where((e) => e.episodesUrls.isNotEmpty).toList();
    final categories = _computeCategories(catalog, strTous, strFil);

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
            SliverToBoxAdapter(child: _buildCategoryChips(categories, selectedCategory)),
            if (series.isNotEmpty) SliverToBoxAdapter(child: _buildSeriesRail(l10n, series)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  (selectedCategory == strTous || selectedCategory == 'Tous') ? (l10n.t('media_catalog').isNotEmpty ? l10n.t('media_catalog') : 'Catalogue TDIA') : selectedCategory,
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
                      formatNumber: formatMediaNumber,
                      buildImage: _buildImage,
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

  Widget _buildErrorState(AppLocalizations l10n, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: ThixPolicy.danger, size: 48),
            const SizedBox(height: 16),
            Text(l10n.t('media_load_error').isNotEmpty ? l10n.t('media_load_error') : 'Erreur de chargement', textAlign: TextAlign.center, style: const TextStyle(color: _MediaLightPalette.textMuted, fontWeight: FontWeight.w600)),
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
              decoration: const BoxDecoration(color: _MediaLightPalette.border, shape: BoxShape.circle),
              child: const Icon(Icons.video_library_outlined, size: 40, color: _MediaLightPalette.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('media_empty').isNotEmpty ? l10n.t('media_empty') : 'Aucun contenu.', style: const TextStyle(color: _MediaLightPalette.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // HEADERS (SliverAppBar)
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
          filter: ImageFilter.blur(sigmaX: _MediaConfig.glassBlur, sigmaY: _MediaConfig.glassBlur),
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
          const Text('TDIA', style: TextStyle(color: _MediaLightPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
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
                maxLength: _MediaConfig.maxSearchLength,
                style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                cursorColor: ThixPolicy.primary,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.t('media_search_hint').isNotEmpty ? l10n.t('media_search_hint') : 'Rechercher',
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
    final featured = catalog.take(_MediaConfig.maxHeroItems).toList();
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
    final safeTitle = _MediaSanitizer.text(item.title, maxLength: _MediaConfig.maxTitleLength);
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
  // CATEGORY CHIPS
  // ========================================================================

  List<String> _computeCategories(List<MediaContent> catalog, String strTous, String strFil) {
    final types = catalog.map((e) => e.type).where((t) => t.isNotEmpty).toSet().toList()..sort();
    return [strTous, strFil, ...types];
  }

  Widget _buildCategoryChips(List<String> categories, String selected) {
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
                Text(l10n.t('media_series').isNotEmpty ? l10n.t('media_series') : 'Séries', style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
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
                    formatNumber: formatMediaNumber,
                    buildImage: _buildImage,
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
                          Text(l10n.t('media_no_results').isNotEmpty ? l10n.t('media_no_results') : 'Aucun résultat.', style: const TextStyle(color: _MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
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
                                _buildImage(_MediaSanitizer.imageUrl(item.coverUrl) ?? ''),
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
                                    _MediaSanitizer.text(item.title, maxLength: _MediaConfig.maxTitleLength),
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
}

// ============================================================================
// SKELETON
// ============================================================================

class _MediaSkeleton extends StatelessWidget {
  final AppLocalizations l10n;
  const _MediaSkeleton({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: ThixPolicy.primary),
          const SizedBox(height: 16),
          Text(l10n.t('media_loading').isNotEmpty ? l10n.t('media_loading') : 'Chargement du catalogue…', style: const TextStyle(color: _MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================================
// POSTER CARD
// ============================================================================

class MediaPosterCard extends StatelessWidget {
  final MediaContent item;
  final String Function(int) formatNumber;
  final Widget Function(String, {BoxFit fit}) buildImage;
  final VoidCallback onTap;
  final bool compact;

  const MediaPosterCard({
    super.key,
    required this.item,
    required this.formatNumber,
    required this.buildImage,
    required this.onTap,
    this.compact = false,
  });

  bool get _isSeries => item.episodesUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final title = _MediaSanitizer.text(item.title, maxLength: _MediaConfig.maxTitleLength);
    final cover = _MediaSanitizer.imageUrl(item.coverUrl);

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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildImage(cover ?? ''),
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
                      if (item.isPaid)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                            child: const Icon(Icons.lock_rounded, size: 12, color: ThixPolicy.warning),
                          ),
                        ),
                      if (_isSeries)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                            child: Text('${item.episodesUrls.length + 1} pts', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Row(children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(formatNumber(item.viewCount), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FIL — VUE TYPE TIKTOK
// ============================================================================

class FilFeedView extends ConsumerStatefulWidget {
  final List<MediaContent> catalog;
  final void Function(MediaContent) onOpenDetail;

  const FilFeedView({super.key, required this.catalog, required this.onOpenDetail});

  @override
  ConsumerState<FilFeedView> createState() => _FilFeedViewState();
}

class _FilFeedViewState extends ConsumerState<FilFeedView> {
  int _currentIndex = 0;
  final Map<String, bool> _localLikes = {};
  final Map<String, int> _localLikeCounts = {};
  late List<MediaContent> _mixedFeed;
  final Set<String> _seenIds = {};

  @override
  void initState() {
    super.initState();
    _mixedFeed = _SmartFeedMixer.mix(widget.catalog);
    _seenIds.addAll(_mixedFeed.map((e) => e.id));
    _initLikes();
  }

  @override
  void didUpdateWidget(covariant FilFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newItems = widget.catalog.where((e) => !_seenIds.contains(e.id)).toList();
    if (newItems.isNotEmpty) {
      final mixedNew = _SmartFeedMixer.mix(newItems);
      setState(() {
        _mixedFeed.addAll(mixedNew);
        _seenIds.addAll(mixedNew.map((e) => e.id));
      });
      for (final item in mixedNew) {
        _localLikeCounts[item.id] = item.likeCount;
      }
      _syncLikedStatus(mixedNew.map((e) => e.id).toList());
    }
  }

  void _initLikes() {
    for (final item in _mixedFeed) {
      _localLikeCounts[item.id] = item.likeCount;
    }
    _syncLikedStatus(_mixedFeed.map((e) => e.id).toList());
  }

  Future<void> _syncLikedStatus(List<String> ids) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || ids.isEmpty) return;
    try {
      final res = await Supabase.instance.client.rpc('get_liked_media_ids', params: {'p_media_ids': ids}).timeout(_MediaConfig.networkTimeout);
      if (mounted && res is List) {
        setState(() {
          for (final id in res) {
            _localLikes[id.toString()] = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(MediaContent item, AppLocalizations l10n) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('media_login_to_like').isNotEmpty ? l10n.t('media_login_to_like') : 'Veuillez vous connecter')));
      return;
    }
    HapticFeedback.selectionClick();
    final wasLiked = _localLikes[item.id] ?? false;
    final currentCount = _localLikeCounts[item.id] ?? item.likeCount;

    setState(() {
      _localLikes[item.id] = !wasLiked;
      _localLikeCounts[item.id] = wasLiked ? (currentCount - 1).clamp(0, 999999999) : currentCount + 1;
    });

    try {
      await Supabase.instance.client.rpc('toggle_media_like', params: {'p_media_id': item.id}).timeout(_MediaConfig.networkTimeout);
    } catch (_) {
      if (mounted) {
        setState(() {
          _localLikes[item.id] = wasLiked;
          _localLikeCounts[item.id] = currentCount;
        });
      }
    }
  }

  void _openProfile(String userId) {
    if (!_MediaSanitizer.isValidId(userId) || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));
  }

  void _openComments(MediaContent item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(mediaId: item.id, mediaTitle: item.title),
    ).then((_) => ref.invalidate(mediaCommentCountProvider(item.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_mixedFeed.isEmpty) {
      return Center(child: Text(l10n.t('media_feed_empty').isNotEmpty ? l10n.t('media_feed_empty') : 'Aucun contenu', style: const TextStyle(color: Colors.white54)));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemCount: _mixedFeed.length,
      itemBuilder: (context, index) {
        final item = _mixedFeed[index];
        final isCurrent = index == _currentIndex;
        final isLiked = _localLikes[item.id] ?? false;
        final likeCount = _localLikeCounts[item.id] ?? item.likeCount;
        final live = ref.watch(mediaCountsStreamProvider(item.id)).valueOrNull;
        final commentCount = live?.commentCount ?? item.commentCount;
        final viewCount = live?.viewCount ?? item.viewCount;
        final creatorId = item.userId ?? '';
        final creatorProfile = creatorId.isNotEmpty ? ref.watch(mediaUserProfileProvider(creatorId)).valueOrNull : null;
        final currentUid = Supabase.instance.client.auth.currentUser?.id;
        final isFollowing = creatorId.isEmpty ? true : (ref.watch(mediaIsFollowingProvider(creatorId)).valueOrNull ?? true);
        final displayName = creatorId.isEmpty ? 'TDIA' : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? 'Créateur');
        final showFollow = creatorId.isNotEmpty && creatorId != currentUid && !isFollowing;

        return _FilVideoCard(
          key: ValueKey(item.id),
          item: item,
          isCurrent: isCurrent,
          isLiked: isLiked,
          likeCount: likeCount,
          commentCount: commentCount,
          viewCount: viewCount,
          displayName: '$displayName',
          creatorAvatar: creatorProfile?['avatar_url'] as String?,
          showFollow: showFollow,
          onLike: () => _toggleLike(item, l10n),
          onDoubleTapLike: () {
            if (!(_localLikes[item.id] ?? false)) _toggleLike(item, l10n);
          },
          onComment: () => _openComments(item),
          onOpenDetail: () => widget.onOpenDetail(item),
          onOpenProfile: () => _openProfile(creatorId),
          onFollow: () async {
            HapticFeedback.selectionClick();
            try {
              await MediaService().toggleFollow(creatorId);
              ref.invalidate(mediaIsFollowingProvider(creatorId));
            } catch (_) {}
          },
        );
      },
    );
  }
}

class _FilVideoCard extends StatefulWidget {
  final MediaContent item;
  final bool isCurrent;
  final bool isLiked;
  final int likeCount, commentCount, viewCount;
  final String displayName;
  final String? creatorAvatar;
  final bool showFollow;
  final VoidCallback onLike;
  final VoidCallback onDoubleTapLike;
  final VoidCallback onComment;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenProfile;
  final VoidCallback onFollow;

  const _FilVideoCard({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.displayName,
    required this.creatorAvatar,
    required this.showFollow,
    required this.onLike,
    required this.onDoubleTapLike,
    required this.onComment,
    required this.onOpenDetail,
    required this.onOpenProfile,
    required this.onFollow,
  });

  @override
  State<_FilVideoCard> createState() => _FilVideoCardState();
}

class _FilVideoCardState extends State<_FilVideoCard> {
  bool _showHeart = false;

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeart = true);
    Future.delayed(_MediaConfig.heartPopDuration, () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = _MediaSanitizer.imageUrl(widget.item.coverUrl);
    final avatar = _MediaSanitizer.imageUrl(widget.creatorAvatar);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null) CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover) else Container(color: Colors.black),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(color: Colors.black.withValues(alpha: 0.5))),
          Center(
            child: FeedVideoPlayer(
              videoUrl: widget.item.videoUrl,
              coverUrl: widget.item.coverUrl,
              isPlaying: widget.isCurrent,
              onPlayStateChanged: (_) {},
            ),
          ),
          AnimatedOpacity(
            opacity: _showHeart ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Center(
              child: AnimatedScale(
                scale: _showHeart ? 1.1 : 0.6,
                duration: _MediaConfig.heartPopDuration,
                curve: Curves.elasticOut,
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 110),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 110,
            child: Column(
              children: [
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                              : Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white)),
                        ),
                      ),
                      if (widget.showFollow)
                        Positioned(
                          bottom: -6,
                          left: 13,
                          child: GestureDetector(
                            onTap: widget.onFollow,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sideAction(icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: formatMediaNumber(widget.likeCount), color: widget.isLiked ? ThixPolicy.danger : Colors.white, onTap: widget.onLike),
                const SizedBox(height: 16),
                _sideAction(icon: Icons.chat_bubble_rounded, label: formatMediaNumber(widget.commentCount), color: Colors.white, onTap: widget.onComment),
                const SizedBox(height: 16),
                _sideAction(icon: Icons.fullscreen_rounded, label: '', color: Colors.white, onTap: widget.onOpenDetail),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 88,
            bottom: 28,
            child: GestureDetector(
              onTap: widget.onOpenProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${widget.displayName}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(6)),
                      child: Text(widget.item.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_MediaSanitizer.text(widget.item.title, maxLength: _MediaConfig.maxTitleLength),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.visibility_outlined, color: Colors.white60, size: 12),
                    const SizedBox(width: 4),
                    Text(formatMediaNumber(widget.viewCount), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// LECTEUR VIDÉO
// ============================================================================

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl, coverUrl;
  final bool isPlaying;
  final bool enforcePreviewLimit;
  final int previewSeconds;
  final VoidCallback? onPreviewLimitReached;
  final Function(bool) onPlayStateChanged;

  const FeedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.coverUrl,
    required this.isPlaying,
    required this.onPlayStateChanged,
    this.enforcePreviewLimit = false,
    this.previewSeconds = _MediaConfig.previewSeconds,
    this.onPreviewLimitReached,
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _c;
  bool _init = false, _paused = false, _invalidUrl = false;
  bool _previewTriggered = false;
  final ValueNotifier<Duration> _pos = ValueNotifier(Duration.zero);
  Duration _dur = Duration.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    final safeUrl = _MediaSanitizer.imageUrl(widget.videoUrl);
    if (safeUrl == null) {
      _invalidUrl = true;
      return;
    }
    _c = VideoPlayerController.networkUrl(Uri.parse(safeUrl));
    _c!.initialize().then((_) {
      if (!mounted) return;
      _c!.setLooping(!widget.enforcePreviewLimit);
      _c!.setVolume(1.0);
      _c!.addListener(_onTick);
      setState(() {
        _init = true;
        _dur = _c!.value.duration;
      });
      if (widget.isPlaying) _c!.play();
    });
  }

  void _onTick() {
    if (!mounted || _c == null) return;
    if (!_isDragging) _pos.value = _c!.value.position;
    if (widget.enforcePreviewLimit && !_previewTriggered && _c!.value.position.inSeconds >= widget.previewSeconds) {
      _previewTriggered = true;
      _c!.pause();
      widget.onPreviewLimitReached?.call();
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoPlayer o) {
    super.didUpdateWidget(o);
    if (!_init || _c == null) return;
    if (widget.isPlaying && !o.isPlaying && !_previewTriggered) {
      _paused = false;
      _c!.play();
    } else if (!widget.isPlaying && o.isPlaying) {
      _c!.pause();
      _c!.seekTo(Duration.zero);
      _previewTriggered = false;
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_onTick);
    _c?.dispose();
    _pos.dispose();
    super.dispose();
  }

  void _seekToPercent(double pct) {
    if (!_init || _c == null) return;
    final newPos = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
    _c!.seekTo(newPos);
    _pos.value = newPos;
  }

  @override
  Widget build(BuildContext context) {
    if (_invalidUrl) {
      final cover = _MediaSanitizer.imageUrl(widget.coverUrl);
      return cover == null ? Container(color: Colors.black) : CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover);
    }
    if (!_init) {
      final cover = _MediaSanitizer.imageUrl(widget.coverUrl);
      return cover == null ? Container(color: Colors.black) : CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: () {
        if (_previewTriggered) return;
        if (_c!.value.isPlaying) {
          _c!.pause();
          _paused = true;
        } else {
          _c!.play();
          _paused = false;
        }
        setState(() {});
        widget.onPlayStateChanged(_paused);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: _c!.value.aspectRatio, child: VideoPlayer(_c!)))),
          if (_paused) const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 80)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragStart: (d) {
                _isDragging = true;
                _c!.pause();
              },
              onHorizontalDragUpdate: (d) {
                final pct = (d.localPosition.dx / context.size!.width).clamp(0.0, 1.0);
                _pos.value = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
              },
              onHorizontalDragEnd: (d) {
                _isDragging = false;
                _c!.seekTo(_pos.value);
                if (!_paused) _c!.play();
              },
              onTapDown: (d) => _seekToPercent((d.localPosition.dx / context.size!.width).clamp(0.0, 1.0)),
              child: Container(
                height: 20,
                color: Colors.transparent,
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: _pos,
                  builder: (_, pos, __) {
                    final pct = _dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / _dur.inMilliseconds;
                    return Stack(alignment: Alignment.bottomLeft, children: [
                      Container(height: _isDragging ? 6 : 2, width: double.infinity, color: Colors.white.withValues(alpha: 0.3)),
                      Container(height: _isDragging ? 6 : 2, width: MediaQuery.of(context).size.width * pct, color: Colors.white),
                    ]);
                  },
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
// BOTTOM SHEET COMMENTAIRES
// ============================================================================

class CommentsSheet extends ConsumerStatefulWidget {
  final String mediaId, mediaTitle;
  const CommentsSheet({super.key, required this.mediaId, required this.mediaTitle});
  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _loading = true;

  List<CommentItem> _roots = [];
  final Map<String, List<CommentItem>> _replies = {};
  final Set<String> _expanded = {};

  CommentItem? _replyingTo;
  CommentItem? _editingComment;
  final Set<String> _likedIds = {};
  final Map<String, int> _localCommentLikes = {};

  @override
  void initState() {
    super.initState();
    _fetchRoots();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: ThixPolicy.danger));
    }
  }

  Future<void> _fetchUserLikes() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.from('comment_likes').select('comment_id').eq('user_id', uid).timeout(_MediaConfig.networkTimeout);
      if (mounted) setState(() => _likedIds.addAll((res as List).map((e) => e['comment_id'] as String)));
    } catch (_) {}
  }

  Future<void> _fetchRoots() async {
    final l10n = AppLocalizations.of(context);
    try {
      final res = await Supabase.instance.client
          .from('media_comments')
          .select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count')
          .eq('media_id', widget.mediaId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: false)
          .limit(_MediaConfig.commentsPageSize)
          .timeout(_MediaConfig.networkTimeout);
      if (mounted) {
        setState(() {
          _roots = (res as List).map((e) => CommentItem.fromMap(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
        _fetchUserLikes();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(l10n.t('media_load_comments_error').isNotEmpty ? l10n.t('media_load_comments_error') : "Erreur de chargement");
      }
    }
  }

  Future<void> _fetchReplies(String parentId) async {
    final l10n = AppLocalizations.of(context);
    try {
      final res = await Supabase.instance.client
          .from('media_comments')
          .select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count')
          .eq('parent_id', parentId)
          .order('created_at', ascending: true)
          .timeout(_MediaConfig.networkTimeout);
      if (mounted) {
        setState(() {
          _replies[parentId] = (res as List).map((e) => CommentItem.fromMap(e as Map<String, dynamic>)).toList();
          _expanded.add(parentId);
        });
      }
    } catch (_) {
      _showError(l10n.t('media_load_replies_error').isNotEmpty ? l10n.t('media_load_replies_error') : "Erreur des réponses");
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final t = _MediaSanitizer.text(_controller.text.trim(), maxLength: _MediaConfig.maxCommentLength);
    if (t.isEmpty || _sending) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _showError(l10n.t('media_login_required').isNotEmpty ? l10n.t('media_login_required') : "Connectez-vous.");
      return;
    }

    setState(() => _sending = true);
    try {
      if (_editingComment != null) {
        await Supabase.instance.client.from('media_comments').update({'content': t}).eq('id', _editingComment!.id).timeout(_MediaConfig.networkTimeout);
        setState(() => _editingComment = null);
        await _fetchRoots();
      } else {
        final p = await Supabase.instance.client.from('profiles').select('username, full_name, avatar_url').eq('id', uid).maybeSingle().timeout(_MediaConfig.networkTimeout);
        final authUser = Supabase.instance.client.auth.currentUser;

        String name = 'Utilisateur';
        if (p != null && (p['username'] as String?)?.trim().isNotEmpty == true) {
          name = p['username'].toString();
        } else if (p != null && (p['full_name'] as String?)?.trim().isNotEmpty == true) {
          name = p['full_name'].toString();
        } else if ((authUser?.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true) {
          name = authUser!.userMetadata!['full_name'].toString();
        }

        final parentId = _replyingTo?.parentId ?? _replyingTo?.id;

        await Supabase.instance.client.from('media_comments').insert({
          'media_id': widget.mediaId,
          'user_id': uid,
          'user_name': name,
          'avatar_url': p?['avatar_url'],
          'content': t,
          'parent_id': parentId,
        }).timeout(_MediaConfig.networkTimeout);

        if (parentId != null) {
          await _fetchReplies(parentId);
        } else {
          await _fetchRoots();
        }
      }
      _controller.clear();
      _focusNode.unfocus();
      setState(() => _replyingTo = null);
      ref.invalidate(mediaCommentCountProvider(widget.mediaId));
    } catch (e) {
      _showError(l10n.t('media_send_error').isNotEmpty ? l10n.t('media_send_error') : "Erreur d'envoi");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    final l10n = AppLocalizations.of(context);
    try {
      await Supabase.instance.client.from('media_comments').delete().eq('id', id).timeout(_MediaConfig.networkTimeout);
      _fetchRoots();
      ref.invalidate(mediaCommentCountProvider(widget.mediaId));
    } catch (_) {
      _showError(l10n.t('media_load_comments_error').isNotEmpty ? l10n.t('media_load_comments_error') : "Erreur");
    }
  }

  void _showOptions(CommentItem c) {
    final l10n = AppLocalizations.of(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isAuthor = uid == c.userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: _MediaLightPalette.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.edit, color: _MediaLightPalette.textPrimary),
                title: Text(l10n.t('media_edit').isNotEmpty ? l10n.t('media_edit') : "Modifier", style: const TextStyle(color: _MediaLightPalette.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingComment = c;
                    _replyingTo = null;
                  });
                  _controller.text = c.content;
                  _focusNode.requestFocus();
                },
              ),
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.delete, color: ThixPolicy.danger),
                title: Text(l10n.t('media_delete').isNotEmpty ? l10n.t('media_delete') : "Supprimer", style: const TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _delete(c.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag, color: ThixPolicy.warning),
              title: Text(l10n.t('media_report').isNotEmpty ? l10n.t('media_report') : "Signaler", style: const TextStyle(color: ThixPolicy.warning)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('media_reported_confirmation').isNotEmpty ? l10n.t('media_reported_confirmation') : "Signalé")));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentItem c, AppLocalizations l10n, {bool isReply = false}) {
    final isLiked = _likedIds.contains(c.id);
    final currentLikes = _localCommentLikes[c.id] ?? c.likeCount;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 48 : 0, top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: c.userId))),
            child: CircleAvatar(
              radius: isReply ? 14 : 18,
              backgroundColor: _MediaLightPalette.border,
              backgroundImage: c.avatarUrl != null ? CachedNetworkImageProvider(c.avatarUrl!) : null,
              child: c.avatarUrl == null ? Icon(Icons.person, size: isReply ? 16 : 20, color: _MediaLightPalette.textMuted) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showOptions(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: c.userId))),
                    child: Text(c.userName, style: const TextStyle(color: _MediaLightPalette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Text(c.content, style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 14, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(timeago.format(c.createdAt, locale: 'fr'), style: const TextStyle(color: _MediaLightPalette.textMuted, fontSize: 12)),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingTo = c;
                          _editingComment = null;
                        });
                        _focusNode.requestFocus();
                      },
                      child: Text(l10n.t('post_reply').isNotEmpty ? l10n.t('post_reply') : "Répondre", style: const TextStyle(color: _MediaLightPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        if (uid == null) {
                          _showError(l10n.t('media_login_to_like').isNotEmpty ? l10n.t('media_login_to_like') : "Connectez-vous");
                          return;
                        }
                        setState(() {
                          if (isLiked) {
                            _likedIds.remove(c.id);
                            _localCommentLikes[c.id] = (currentLikes - 1).clamp(0, 999999999);
                          } else {
                            _likedIds.add(c.id);
                            _localCommentLikes[c.id] = currentLikes + 1;
                          }
                        });
                        try {
                          await Supabase.instance.client.rpc('toggle_comment_like', params: {'p_comment_id': c.id}).timeout(_MediaConfig.networkTimeout);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              if (isLiked) {
                                _likedIds.add(c.id);
                              } else {
                                _likedIds.remove(c.id);
                              }
                              _localCommentLikes[c.id] = currentLikes;
                            });
                          }
                        }
                      },
                      child: Row(children: [
                        Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? ThixPolicy.danger : _MediaLightPalette.textMuted, size: 14),
                        const SizedBox(width: 4),
                        Text(currentLikes > 0 ? '$currentLikes' : '', style: TextStyle(color: isLiked ? ThixPolicy.danger : _MediaLightPalette.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                  if (!isReply && (c.replyCount > 0 || _replies.containsKey(c.id))) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        if (_expanded.contains(c.id)) {
                          setState(() => _expanded.remove(c.id));
                        } else {
                          _fetchReplies(c.id);
                        }
                      },
                      child: Row(children: [
                        Container(width: 24, height: 1, color: _MediaLightPalette.border),
                        const SizedBox(width: 8),
                        Text(_expanded.contains(c.id) ? (l10n.t('media_hide_replies').isNotEmpty ? l10n.t('media_hide_replies') : "Masquer") : (l10n.t('media_view_replies', args: ['${c.replyCount}']).isNotEmpty ? l10n.t('media_view_replies', args: ['${c.replyCount}']) : "Voir les réponses"),
                            style: const TextStyle(color: _MediaLightPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                  if (!isReply && _expanded.contains(c.id)) ...[...(_replies[c.id] ?? []).map((r) => _buildCommentTile(r, l10n, isReply: true))],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: BoxDecoration(color: _MediaLightPalette.surface.withValues(alpha: 0.98), border: Border(top: BorderSide(color: _MediaLightPalette.border))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: _MediaLightPalette.border, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                Text(l10n.t('media_comments_count', args: ['${_roots.length}']).isNotEmpty ? l10n.t('media_comments_count', args: ['${_roots.length}']) : "${_roots.length} commentaires", style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
                      : _roots.isEmpty
                          ? Center(child: Text(l10n.t('media_first_comment').isNotEmpty ? l10n.t('media_first_comment') : "Soyez le premier à commenter", style: const TextStyle(color: _MediaLightPalette.textMuted, fontWeight: FontWeight.w500)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: _roots.length,
                              itemBuilder: (c, i) => _buildCommentTile(_roots[i], l10n),
                            ),
                ),
                Container(
                  decoration: BoxDecoration(color: _MediaLightPalette.background, border: Border(top: BorderSide(color: _MediaLightPalette.border))),
                  child: Column(
                    children: [
                      if (_replyingTo != null || _editingComment != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(children: [
                            Text(_editingComment != null ? (l10n.t('media_editing_label').isNotEmpty ? l10n.t('media_editing_label') : "Modification") : (l10n.t('media_reply_to', args: [_replyingTo!.userName]).isNotEmpty ? l10n.t('media_reply_to', args: [_replyingTo!.userName]) : "Réponse"),
                                style: const TextStyle(color: _MediaLightPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _replyingTo = null;
                                  _editingComment = null;
                                });
                                _controller.clear();
                              },
                              child: const Icon(Icons.close_rounded, color: _MediaLightPalette.textMuted, size: 16),
                            ),
                          ]),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(color: _MediaLightPalette.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _MediaLightPalette.border)),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: _MediaConfig.maxCommentLength,
                                  onSubmitted: (_) => _submit(),
                                  style: const TextStyle(color: _MediaLightPalette.textPrimary, fontSize: 14),
                                  cursorColor: ThixPolicy.primary,
                                  decoration: InputDecoration(
                                    hintText: _editingComment != null ? (l10n.t('media_edit_hint').isNotEmpty ? l10n.t('media_edit_hint') : "Modifier") : (_replyingTo != null ? (l10n.t('media_reply_hint').isNotEmpty ? l10n.t('media_reply_hint') : "Répondre") : (l10n.t('media_add_comment_hint').isNotEmpty ? l10n.t('media_add_comment_hint') : "Ajouter un commentaire")),
                                    hintStyle: const TextStyle(color: _MediaLightPalette.textMuted, fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _submit,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: _sending ? _MediaLightPalette.border : ThixPolicy.primary, shape: BoxShape.circle),
                                child: _sending
                                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
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
}
