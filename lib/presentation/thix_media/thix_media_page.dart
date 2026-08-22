// lib/presentation/media/thix_media_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'video_player_page.dart';
import '../../models/media_content.dart';
import 'providers/thix_media_provider.dart';
import 'package:thix_id/nav.dart' show AppRoutes;
import 'admin/thix_media_admin_page.dart';
import '../../services/media_service.dart';

import 'create_post_page.dart';
import 'user_profile_page.dart';

// ============================================================================
// PALETTE — Charte THIX ID (Or remplacé par Blanc Premium selon la demande)
// ============================================================================
class _MediaColors {
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const primary = Color(0xFF2D6CDF);
  static const whiteAccent = Colors.white; // Remplace l'or
  static const whiteMuted = Color(0xFFE2E8F0);
  static const ivory = Color(0xFFF6F7FB);
  static const card = Color(0xFF11213F);
  static const cardLight = Color(0xFF16294D);
  static const border = Color(0x1AFFFFFF);
  static const textMuted = Color(0xFFAEB9D4);
  static const danger = ThixPolicy.danger;
  static const success = ThixPolicy.success;

  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navy],
  );
  
  static const gradientWhite = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, whiteMuted],
  );
}

// ============================================================================
// MODELS & SERVICES
// ============================================================================
class MediaCounts {
  final int likeCount, viewCount, commentCount;
  const MediaCounts({
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
  });
}

class _AnalyticsBatcher {
  static final Set<String> _pending = {};
  static Timer? _timer;

  static void register(String id) {
    _pending.add(id);
    _timer ??= Timer(const Duration(seconds: 8), _flush);
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
      await Supabase.instance.client.rpc('batch_register_views', params: {'p_media_ids': batch});
    } catch (_) {
      _pending.addAll(batch);
    }
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

final mediaCreatorIdProvider = FutureProvider.autoDispose.family<String?, String>((ref, mediaId) async {
  if (mediaId.isEmpty) return null;
  try {
    final res = await Supabase.instance.client.from('media_content').select('user_id').eq('id', mediaId).maybeSingle();
    return res?['user_id'] as String?;
  } catch (_) {
    return null;
  }
});

final userProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  try {
    final res = await Supabase.instance.client.from('profiles').select('username, full_name, avatar_url, role').eq('id', userId).maybeSingle();
    return res;
  } catch (_) {
    return null;
  }
});

final isFollowingProvider = FutureProvider.autoDispose.family<bool, String>((ref, targetId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || uid == targetId) return true;
  try {
    final res = await Supabase.instance.client.from('follows').select().eq('follower_id', uid).eq('following_id', targetId).maybeSingle();
    return res != null;
  } catch (_) {
    return true;
  }
});

class CommentItem {
  final String id, userId, userName, content;
  final String? avatarUrl, parentId;
  final DateTime createdAt;
  final int likeCount, replyCount;

  CommentItem({
    required this.id, required this.userId, required this.userName, required this.content,
    required this.createdAt, this.avatarUrl, this.parentId, this.likeCount = 0, this.replyCount = 0,
  });

  factory CommentItem.fromMap(Map<String, dynamic> m) {
    DateTime parsedDate;
    try { parsedDate = m['created_at'] != null ? DateTime.parse(m['created_at'].toString()).toLocal() : DateTime.now(); } catch (_) { parsedDate = DateTime.now(); }
    return CommentItem(
      id: m['id']?.toString() ?? '', userId: m['user_id']?.toString() ?? '',
      userName: (m['user_name'] as String?)?.trim().isNotEmpty == true ? m['user_name'] as String : 'Utilisateur',
      avatarUrl: m['avatar_url'] as String?, content: m['content']?.toString() ?? '',
      createdAt: parsedDate, parentId: m['parent_id'] as String?,
      likeCount: (m['like_count'] as num?)?.toInt() ?? 0, replyCount: (m['reply_count'] as num?)?.toInt() ?? 0,
    );
  }
}

final commentCountProvider = FutureProvider.autoDispose.family<int, String>((ref, mediaId) async {
  try {
    final r = await Supabase.instance.client.from('media_stats').select('comment_count').eq('media_id', mediaId).maybeSingle();
    return (r?['comment_count'] as int?) ?? 0;
  } catch (_) { return 0; }
});

final mediaCountsStreamProvider = StreamProvider.autoDispose.family<MediaCounts, String>((ref, mediaId) async* {
  while (true) {
    try {
      final r = await Supabase.instance.client.from('media_stats').select('like_count,view_count,comment_count').eq('media_id', mediaId).maybeSingle();
      yield MediaCounts(likeCount: (r?['like_count'] as int?) ?? 0, viewCount: (r?['view_count'] as int?) ?? 0, commentCount: (r?['comment_count'] as int?) ?? 0);
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 12));
  }
});

// ============================================================================
// ============================================================================
// PAGE PRINCIPALE — TDIA CATALOGUE
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
  
  // ✅ CLÉ GLOBALE pour stabiliser le champ de recherche et empêcher le clavier de sauter
  final GlobalKey _searchKey = GlobalKey(); 
  
  Timer? _searchDebounce;

  List<MediaContent> _catalog = [];
  bool _loading = false;
  bool _initialized = false;
  String _selectedCategory = 'Tous';

  List<MediaContent> _searchResults = [];
  bool _searching = false;

  static final Set<String> _globalSeenIds = {};

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // ❌ ÉCOUTEUR SUPPRIMÉ POUR ÉVITER LES RECONSTRUCTIONS INUTILES DU CLAVIER
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedCategoryProvider.notifier).state = 'Tous';
      _initCatalog();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600 && !_loading) {
      _loadMore();
    }
  }

  MediaContent _mapMedia(Map<String, dynamic> e) {
    final s = e['media_stats'] as Map<String, dynamic>?;
    if (s != null) {
      e = {
        ...e,
        'likeCount': s['like_count'] ?? e['likeCount'] ?? 0,
        'viewCount': s['view_count'] ?? e['viewCount'] ?? 0,
        'commentCount': s['comment_count'] ?? e['commentCount'] ?? 0,
      };
    }
    return MediaContent.fromJson(e);
  }

  Future<void> _initCatalog({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (refresh) _globalSeenIds.clear();
      dynamic res = await Supabase.instance.client.rpc('get_shuffled_feed', params: {'p_seen_ids': _globalSeenIds.toList(), 'p_limit': 24});
      List<MediaContent> items = (res as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _catalog = refresh ? items : [..._catalog, ...items.where((x) => !_globalSeenIds.contains(x.id))];
        _globalSeenIds.addAll(_catalog.map((e) => e.id));
        _initialized = true;
      });
    } catch (_) {
      try {
        final res = await Supabase.instance.client.from('media_content').select('*, media_stats(like_count,view_count,comment_count)').order('created_at', ascending: false).limit(24);
        final items = (res as List).map((e) => _mapMedia(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted) setState(() { _catalog = items; _initialized = true; });
      } catch (_) {
        if (mounted) setState(() => _initialized = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('get_shuffled_feed', params: {'p_seen_ids': _globalSeenIds.toList(), 'p_limit': 18});
      final items = (res as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _catalog.addAll(items.where((e) => !_globalSeenIds.contains(e.id)));
        _globalSeenIds.addAll(items.map((e) => e.id));
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = v;
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _performSearch(v));
  }

  Future<void> _performSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) { if (mounted) setState(() => _searchResults = []); return; }
    if (mounted) setState(() => _searching = true);
    try {
      final res = await Supabase.instance.client.from('media_content').select('*, media_stats(like_count,view_count,comment_count)').ilike('title', '%$query%').limit(24);
      final items = (res as List).map((e) => _mapMedia(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _searchResults = items; _searching = false; });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  void _openDetail(MediaContent item) {
    _registerView(item);
    Navigator.push(context, MaterialPageRoute(builder: (_) => _MediaDetailPage(item: item, catalog: _catalog)));
  }

  void _registerView(MediaContent item) {
    _AnalyticsBatcher.register(item.id);
    () async {
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) await Supabase.instance.client.from('media_views').insert({'media_id': item.id, 'user_id': uid});
      } catch (_) {}
    }();
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.trim().isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_MediaColors.cardLight, _MediaColors.card],
          )
        ),
        child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white24, size: 40)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url, fit: fit,
      placeholder: (c, url) => Container(color: _MediaColors.card),
      errorWidget: (c, e, s) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_MediaColors.cardLight, _MediaColors.card],
          )
        ),
        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 30)),
      ),
    );
  }

  List<String> _categories() {
    final types = _catalog.map((e) => e.type).where((t) => t.isNotEmpty).toSet().toList();
    return ['Tous', 'Fil', ...types];
  }

  List<MediaContent> get _filteredCatalog {
    if (_selectedCategory == 'Tous' || _selectedCategory == 'Fil') return _catalog;
    return _catalog.where((e) => e.type == _selectedCategory).toList();
  }

  List<MediaContent> get _seriesRail =>
      _catalog.where((e) => e.episodesUrls.isNotEmpty || (e.videoUrl.isNotEmpty && e.episodesUrls.length + 1 > 1)).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    
    // ✅ UTILISATION DIRECTE DE HASFOCUS 
    final showSearchOverlay = _searchFocusNode.hasFocus && hasQuery;

    return Scaffold(
      backgroundColor: _MediaColors.navyDeep,
      body: asyncMedia.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _MediaColors.whiteAccent)),
        error: (e, st) => Center(child: Text('ERREUR : $e', style: const TextStyle(color: _MediaColors.danger, fontWeight: FontWeight.bold))),
        data: (_) {
          return Stack(
            children: [
              RefreshIndicator(
                color: _MediaColors.navyDeep,
                backgroundColor: _MediaColors.whiteAccent,
                onRefresh: () => _initCatalog(refresh: true),
                child: !_initialized
                    ? const Center(child: CircularProgressIndicator(color: _MediaColors.whiteAccent))
                    : _selectedCategory == 'Fil'
                        ? _FilFeedView(
                            catalog: _catalog,
                            onOpenDetail: _openDetail,
                            buildImage: _buildImage,
                            formatNumber: _formatNumber,
                          )
                        : CustomScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            slivers: [
                              _buildSliverHeader(isAdmin, hasQuery),
                              if (_catalog.isEmpty)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(60),
                                    child: Center(child: Text('Aucun contenu', style: TextStyle(color: Colors.white54))),
                                  ),
                                )
                              else ...[
                                SliverToBoxAdapter(child: _buildHero()),
                                SliverToBoxAdapter(child: _buildCategoryChips()),
                                if (_seriesRail.isNotEmpty) SliverToBoxAdapter(child: _buildSeriesRail()),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                                    child: Text(
                                      _selectedCategory == 'Tous' ? 'Catalogue' : _selectedCategory,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: 0.62,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (c, i) => _MediaPosterCard(
                                        item: _filteredCatalog[i],
                                        formatNumber: _formatNumber,
                                        buildImage: _buildImage,
                                        onTap: () => _openDetail(_filteredCatalog[i]),
                                      ),
                                      childCount: _filteredCatalog.length,
                                    ),
                                  ),
                                ),
                                if (_loading)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(child: CircularProgressIndicator(color: _MediaColors.whiteAccent, strokeWidth: 2)),
                                    ),
                                  ),
                              ],
                            ],
                          ),
              ),
              if (_selectedCategory == 'Fil')
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTransparentHeader(isAdmin),
                        _buildCategoryChips(),
                      ],
                    ),
                  ),
                ),
              if (showSearchOverlay) _searchOverlay(),
            ],
          );
        },
      ),
    );
  }

  // ── HEADER PRINCIPAL ──
  Widget _buildSliverHeader(bool isAdmin, bool hasQuery) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: _MediaColors.navyDeep,
      elevation: 0,
      toolbarHeight: 64,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: _MediaColors.gradientHeader)),
      title: Row(
        children: const [
          Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 26),
          SizedBox(width: 8),
          Text('TDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 0.5)),
        ],
      ),
      actions: [
        if (isAdmin)
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThixMediaAdminPage())),
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())),
          icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 22),
        ),
        IconButton(
          onPressed: () {
            final currentUid = Supabase.instance.client.auth.currentUser?.id;
            if (currentUid != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: currentUid)));
            }
          },
          icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: _searchKey, // ✅ CLÉ GLOBALE AJOUTÉE ICI
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.white,
                    autocorrect: false, // Désactive la correction auto pour éviter les sauts
                    enableSuggestions: false, 
                    decoration: const InputDecoration(
                      hintText: 'Découvrir des vidéos, séries, créateurs…',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 13.5),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasQuery)
                  GestureDetector(
                    onTap: () { 
                      _searchFocusNode.unfocus(); 
                      _searchController.clear(); 
                      setState(() => _searchResults = []); 
                    },
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER TRANSPARENT (Spécifique au mode Fil) ──
  Widget _buildTransparentHeader(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          const Text('TDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 0.5)),
          const Spacer(),
          if (isAdmin)
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThixMediaAdminPage())),
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
            ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())),
            icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 24),
          ),
          IconButton(
            onPressed: () {
              final currentUid = Supabase.instance.client.auth.currentUser?.id;
              if (currentUid != null) Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: currentUid)));
            },
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final featured = _catalog.take(6).toList();
    if (featured.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 210,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        itemCount: featured.length,
        itemBuilder: (c, i) {
          final item = featured[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => _openDetail(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(item.coverUrl),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, _MediaColors.navyDeep.withValues(alpha: 0.92)],
                          stops: const [0.35, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16, right: 16, top: 14,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(gradient: _MediaColors.gradientWhite, borderRadius: BorderRadius.circular(20)),
                            child: const Text('À LA UNE', style: TextStyle(color: _MediaColors.navyDeep, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ),
                          if (item.isPaid) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.lock_rounded, size: 11, color: Colors.white),
                                SizedBox(width: 3),
                                Text('Premium', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16, right: 16, bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(_formatNumber(item.viewCount), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    final cats = _categories();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final cat = cats[i];
          final sel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: sel ? _MediaColors.gradientWhite : null,
                color: sel ? null : Colors.black.withValues(alpha: 0.3), 
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: sel ? Colors.transparent : Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: sel ? _MediaColors.navyDeep : Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeriesRail() {
    final series = _seriesRail;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.video_library_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Séries', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) => SizedBox(
                width: 128,
                child: _MediaPosterCard(
                  item: series[i],
                  formatNumber: _formatNumber,
                  buildImage: _buildImage,
                  onTap: () => _openDetail(series[i]),
                  compact: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () { 
          _searchFocusNode.unfocus(); 
          setState(() {}); 
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: _MediaColors.navyDeep.withValues(alpha: 0.94),
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 130, left: 16, right: 16),
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _searchResults.isEmpty
                    ? const Center(child: Text('Recherchez des vidéos, créateurs…', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final item = _searchResults[i];
                          return GestureDetector(
                            onTap: () {
                              _searchFocusNode.unfocus();
                              _searchController.clear();
                              setState(() { _searchResults = []; });
                              _openDetail(item);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildImage(item.coverUrl),
                                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent]))),
                                  Positioned(left: 6, right: 6, bottom: 6, child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }
}

                            

// ============================================================================
// VUE DU FIL D'ACTUALITÉ (Vertical Autoplay, Design Premium)
// ============================================================================
class _FilFeedView extends StatefulWidget {
  final List<MediaContent> catalog;
  final Function(MediaContent) onOpenDetail;
  final Widget Function(String, {BoxFit fit}) buildImage;
  final String Function(int) formatNumber;

  const _FilFeedView({
    required this.catalog,
    required this.onOpenDetail,
    required this.buildImage,
    required this.formatNumber,
  });

  @override
  State<_FilFeedView> createState() => _FilFeedViewState();
}

class _FilFeedViewState extends State<_FilFeedView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.catalog.isEmpty) {
      return const Center(child: Text('Le fil est vide pour le moment.', style: TextStyle(color: Colors.white54)));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemCount: widget.catalog.length,
      itemBuilder: (context, index) {
        final item = widget.catalog[index];
        final isCurrent = index == _currentIndex;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Fond flouté pour un rendu très premium
            widget.buildImage(item.coverUrl, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
            
            // Le lecteur vidéo au centre (S'adapte dynamiquement)
            Center(
              child: FeedVideoPlayer(
                videoUrl: item.videoUrl,
                coverUrl: item.coverUrl,
                isPlaying: isCurrent,
                onPlayStateChanged: (_) {},
              ),
            ),
            
            // L'overlay d'informations (Glassmorphism en bas)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: GestureDetector(
                onTap: () => widget.onOpenDetail(item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
// ============================================================================
// VUE DU FIL D'ACTUALITÉ (Vertical Autoplay, Actions Directes)
// ============================================================================
class _FilFeedView extends ConsumerStatefulWidget {
  final List<MediaContent> catalog;
  final Function(MediaContent) onOpenDetail;
  final Widget Function(String, {BoxFit fit}) buildImage;
  final String Function(int) formatNumber;

  const _FilFeedView({
    required this.catalog,
    required this.onOpenDetail,
    required this.buildImage,
    required this.formatNumber,
  });

  @override
  ConsumerState<_FilFeedView> createState() => _FilFeedViewState();
}

class _FilFeedViewState extends ConsumerState<_FilFeedView> {
  int _currentIndex = 0;
  
  // États locaux pour gérer les likes de manière optimiste dans le Fil
  final Map<String, bool> _localLikes = {};
  final Map<String, int> _localLikeCounts = {};

  @override
  void initState() {
    super.initState();
    _initLikes();
  }
  
  // Initialise les compteurs locaux à partir du catalogue
  void _initLikes() {
    for (var item in widget.catalog) {
      _localLikeCounts[item.id] = item.likeCount;
    }
    _syncLikedStatus();
  }

  // Vérifie en arrière-plan quels médias le user a déjà liké
  Future<void> _syncLikedStatus() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || widget.catalog.isEmpty) return;
    
    try {
      final ids = widget.catalog.map((e) => e.id).toList();
      final res = await Supabase.instance.client.rpc('get_liked_media_ids', params: {'p_media_ids': ids});
      if (mounted && res is List) {
        setState(() {
          for (var id in res) {
            _localLikes[id.toString()] = true;
          }
        });
      }
    } catch (_) {}
  }

  // Fonction de Like direct
  Future<void> _toggleLike(MediaContent item) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous pour aimer.')));
      return;
    }
    
    HapticFeedback.selectionClick();
    final isCurrentlyLiked = _localLikes[item.id] ?? false;
    final currentCount = _localLikeCounts[item.id] ?? item.likeCount;
    
    setState(() {
      _localLikes[item.id] = !isCurrentlyLiked;
      _localLikeCounts[item.id] = isCurrentlyLiked ? (currentCount - 1).clamp(0, 999999) : currentCount + 1;
    });
    
    try {
      await Supabase.instance.client.rpc('toggle_media_like', params: {'p_media_id': item.id});
    } catch (_) {
      // Revert en cas d'erreur
      if (mounted) {
        setState(() {
          _localLikes[item.id] = isCurrentlyLiked;
          _localLikeCounts[item.id] = currentCount;
        });
      }
    }
  }

  // Ouvre le BottomSheet des commentaires directement sur le Fil
  void _openCommentsDirectly(MediaContent item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(mediaId: item.id, mediaTitle: item.title),
    ).then((_) { 
      ref.invalidate(commentCountProvider(item.id)); 
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.catalog.isEmpty) {
      return const Center(child: Text('Le fil est vide pour le moment.', style: TextStyle(color: Colors.white54)));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemCount: widget.catalog.length,
      itemBuilder: (context, index) {
        final item = widget.catalog[index];
        final isCurrent = index == _currentIndex;
        
        final isLiked = _localLikes[item.id] ?? false;
        final likeCount = _localLikeCounts[item.id] ?? item.likeCount;
        
        // On écoute les commentaires en temps réel si disponible
        final live = ref.watch(mediaCountsStreamProvider(item.id)).valueOrNull;
        final commentCount = live?.commentCount ?? item.commentCount;
        final viewCount = live?.viewCount ?? item.viewCount;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Fond flouté
            widget.buildImage(item.coverUrl, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
            
            // Le lecteur vidéo au centre
            Center(
              child: FeedVideoPlayer(
                videoUrl: item.videoUrl,
                coverUrl: item.coverUrl,
                isPlaying: isCurrent,
                onPlayStateChanged: (_) {},
              ),
            ),
            
            // ── L'overlay d'informations (Glassmorphism en bas) ──
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Zone cliquable pour voir les détails/description complète
                        GestureDetector(
                          onTap: () => widget.onOpenDetail(item),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _MediaColors.primary, borderRadius: BorderRadius.circular(8)),
                                    child: Text(item.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(item.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 8),
                        
                        // ── ZONE DES ACTIONS DIRECTES ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Bouton J'aime
                            _actionBtn(
                              icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                              text: widget.formatNumber(likeCount), 
                              color: isLiked ? _MediaColors.danger : Colors.white,
                              onTap: () => _toggleLike(item),
                            ),
                            
                            // Bouton Commenter
                            _actionBtn(
                              icon: Icons.chat_bubble_outline_rounded, 
                              text: widget.formatNumber(commentCount), 
                              color: Colors.white,
                              onTap: () => _openCommentsDirectly(item),
                            ),
                            
                            // Compteur de vues (Non cliquable)
                            _actionBtn(
                              icon: Icons.visibility_outlined, 
                              text: widget.formatNumber(viewCount), 
                              color: Colors.white70,
                              onTap: null,
                            ),
                            
                            // Bouton Plein écran / Détails
                            _actionBtn(
                              icon: Icons.fullscreen_rounded, 
                              text: '', 
                              color: Colors.white,
                              onTap: () => widget.onOpenDetail(item),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget utilitaire pour les boutons d'action
  Widget _actionBtn({required IconData icon, required String text, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            if (text.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE AFFICHE — style catalogue (poster + méta)
// ============================================================================
class _MediaPosterCard extends StatelessWidget {
  final MediaContent item;
  final String Function(int) formatNumber;
  final Widget Function(String, {BoxFit fit}) buildImage;
  final VoidCallback onTap;
  final bool compact;

  const _MediaPosterCard({
    required this.item,
    required this.formatNumber,
    required this.buildImage,
    required this.onTap,
    this.compact = false,
  });

  bool get _isSeries => item.episodesUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildImage(item.coverUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                        stops: const [0.5, 1],
                      ),
                    ),
                  ),
                  if (item.isPaid)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.lock_rounded, size: 12, color: _MediaColors.navyDeep),
                      ),
                    ),
                  if (_isSeries)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(6)),
                        child: Text('${item.episodesUrls.length + 1} parties', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  Positioned(
                    left: 8, right: 8, bottom: 8,
                    child: Row(children: [
                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(formatNumber(item.viewCount), style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE DÉTAIL — (Avec suggestions et taille adaptative)
// ============================================================================
class _MediaDetailPage extends ConsumerStatefulWidget {
  final MediaContent item;
  final List<MediaContent> catalog; // Requis pour afficher les suggestions
  const _MediaDetailPage({required this.item, required this.catalog});

  @override
  ConsumerState<_MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends ConsumerState<_MediaDetailPage> {
  late List<String> _episodes;
  int _currentEpisode = 0;
  bool _liked = false;
  bool _saved = false;
  bool _previewExpired = false;
  bool _unlocked = false;
  static const int _previewSeconds = 30;
  final Set<String> _newlyFollowed = {};
  
  List<MediaContent> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _episodes = [widget.item.videoUrl, ...widget.item.episodesUrls].where((u) => u.isNotEmpty).toList();
    _syncLiked();
    _loadSuggestions();
  }
  
  void _loadSuggestions() {
    // Prend au hasard quelques vidéos du catalogue pour les suggestions (sauf la vidéo actuelle)
    final otherVideos = widget.catalog.where((e) => e.id != widget.item.id).toList();
    otherVideos.shuffle();
    _suggestions = otherVideos.take(4).toList(); // Limite à 4 suggestions
  }

  Future<void> _syncLiked() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.rpc('get_liked_media_ids', params: {'p_media_ids': [widget.item.id]});
      if (mounted && (res as List).contains(widget.item.id)) setState(() => _liked = true);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous pour aimer.'))); return; }
    HapticFeedback.selectionClick();
    setState(() => _liked = !_liked);
    try { await Supabase.instance.client.rpc('toggle_media_like', params: {'p_media_id': widget.item.id}); } catch (_) {}
  }

  void _toggleSave() {
    HapticFeedback.lightImpact();
    setState(() => _saved = !_saved);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(mediaId: widget.item.id, mediaTitle: widget.item.title),
    ).then((_) { ref.invalidate(commentCountProvider(widget.item.id)); });
  }

  String _formatPrice() => '\$${widget.item.price}';
  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSeries = _episodes.length > 1;
    final requiresPayment = item.isPaid && !_unlocked && _previewExpired;
    final enforcePreview = item.isPaid && !_unlocked;

    final live = ref.watch(mediaCountsStreamProvider(item.id)).valueOrNull;
    final creatorId = item.userId ?? '';
    final creatorProfile = creatorId.isNotEmpty ? ref.watch(userProfileProvider(creatorId)).valueOrNull : null;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isFollowing = creatorId.isNotEmpty ? (ref.watch(isFollowingProvider(creatorId)).valueOrNull ?? true) : true;
    final creatorIsOfficial = creatorId.isEmpty;
    final showFollowBtn = !creatorIsOfficial && creatorId.isNotEmpty && creatorId != currentUid && !isFollowing && !_newlyFollowed.contains(creatorId);
    final displayName = creatorIsOfficial ? 'TDIA' : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? 'Créateur');

    return Scaffold(
      backgroundColor: _MediaColors.navyDeep,
      appBar: AppBar(
        backgroundColor: _MediaColors.navyDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LECTEUR VIDÉO (Taille adaptative) ──
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.70),
              color: Colors.black,
              child: Center(
                child: requiresPayment
                    ? _buildPaywall(item)
                    : FeedVideoPlayer(
                        key: ValueKey('${item.id}_$_currentEpisode'),
                        videoUrl: _episodes.isEmpty ? item.videoUrl : _episodes[_currentEpisode.clamp(0, _episodes.length - 1)],
                        coverUrl: item.coverUrl,
                        isPlaying: true,
                        enforcePreviewLimit: enforcePreview,
                        previewSeconds: _previewSeconds,
                        onPreviewLimitReached: () { if (mounted) setState(() => _previewExpired = true); },
                        onPlayStateChanged: (_) {},
                      ),
              ),
            ),

            // ── SÉLECTEUR D'ÉPISODES ──
            if (isSeries && !requiresPayment)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Épisodes', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_episodes.length, (i) {
                        final active = i == _currentEpisode;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() { _currentEpisode = i; });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: active ? _MediaColors.gradientWhite : null,
                              color: active ? null : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: 0.14)),
                            ),
                            child: Text(
                              'Partie ${i + 1}',
                              style: TextStyle(
                                color: active ? _MediaColors.navyDeep : Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

            // ── AUTEUR + SUIVRE ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { if (!creatorIsOfficial && creatorId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: creatorId))); },
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.6),
                        image: creatorProfile != null && creatorProfile['avatar_url'] != null
                            ? DecorationImage(image: CachedNetworkImageProvider(creatorProfile['avatar_url']), fit: BoxFit.cover)
                            : null,
                      ),
                      child: creatorProfile == null || creatorProfile['avatar_url'] == null
                          ? const Icon(Icons.person, size: 20, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$displayName', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                        Text(item.type, style: const TextStyle(color: _MediaColors.textMuted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  if (showFollowBtn)
                    GestureDetector(
                      onTap: () { setState(() => _newlyFollowed.add(creatorId)); MediaService().toggleFollow(creatorId); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(gradient: _MediaColors.gradientWhite, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Suivre', style: TextStyle(color: _MediaColors.navyDeep, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),

            // ── BARRE D'ACTIONS HORIZONTALE (Avec vues) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    _detailActionBtn(
                      icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: _formatNumber(live?.likeCount ?? item.likeCount),
                      color: _liked ? _MediaColors.danger : Colors.white,
                      onTap: _toggleLike,
                    ),
                    _detailActionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: _formatNumber(live?.commentCount ?? item.commentCount),
                      color: Colors.white,
                      onTap: _openComments,
                    ),
                    _detailActionBtn(
                      icon: Icons.remove_red_eye_outlined,
                      label: _formatNumber(live?.viewCount ?? item.viewCount),
                      color: Colors.white,
                      onTap: () {},
                    ),
                    _detailActionBtn(
                      icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      label: 'Sauver',
                      color: _saved ? _MediaColors.whiteAccent : Colors.white,
                      onTap: _toggleSave,
                    ),
                  ],
                ),
              ),
            ),

            // ── DESCRIPTION ──
            if (item.subtitle != null && item.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Text(item.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              )
            else
              const SizedBox(height: 24),
              
            // ── VIDÉOS SUGGÉRÉES ──
            if (_suggestions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('À découvrir aussi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: 0.62,
                ),
                itemCount: _suggestions.length,
                                itemBuilder: (c, i) => _MediaPosterCard(
                  item: _suggestions[i],
                  formatNumber: _formatNumber,
                  buildImage: (url, {BoxFit? fit}) { // CORRECTION ICI
                    if (url.trim().isEmpty) return Container(color: _MediaColors.card, child: const Icon(Icons.play_circle_outline, color: Colors.white24));
                    return CachedNetworkImage(imageUrl: url, fit: fit ?? BoxFit.cover);
                  },
                  onTap: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _MediaDetailPage(item: _suggestions[i], catalog: widget.catalog)));
                  },
                ),
              ),
              const SizedBox(height: 40),
            ]
          ],
        ),
      ),
    );
  }

  Widget _detailActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaywall(MediaContent item) {
    return Container(
      decoration: item.coverUrl.isNotEmpty ? BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(item.coverUrl), fit: BoxFit.cover)) : const BoxDecoration(color: _MediaColors.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          color: _MediaColors.navyDeep.withValues(alpha: 0.88),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _MediaColors.gradientWhite),
                child: const Icon(Icons.lock_rounded, size: 36, color: _MediaColors.navyDeep),
              ),
              const SizedBox(height: 18),
              const Text('Contenu Premium', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  "Fin de l'aperçu gratuit. Débloquez la suite pour ${_formatPrice()}.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _MediaColors.navyDeep,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  setState(() { _unlocked = true; _previewExpired = false; });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vidéo débloquée avec succès !'), backgroundColor: _MediaColors.success));
                },
                child: Text('Débloquer (${_formatPrice()})', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LECTEUR VIDEO (Progress bar fine & fluide — taille adaptative intégrée)
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
    required this.videoUrl, required this.coverUrl, required this.isPlaying, required this.onPlayStateChanged,
    this.enforcePreviewLimit = false, this.previewSeconds = 30, this.onPreviewLimitReached,
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  late VideoPlayerController _c;
  bool _init = false, _paused = false;
  bool _previewTriggered = false;
  final ValueNotifier<Duration> _pos = ValueNotifier(Duration.zero);
  Duration _dur = Duration.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.setLooping(!widget.enforcePreviewLimit);
      _c.setVolume(1.0);
      _c.addListener(_onTick);
      setState(() { _init = true; _dur = _c.value.duration; });
      if (widget.isPlaying) _c.play();
    });
  }

  void _onTick() {
    if (!mounted) return;
    if (!_isDragging) _pos.value = _c.value.position;
    if (widget.enforcePreviewLimit && !_previewTriggered && _c.value.position.inSeconds >= widget.previewSeconds) {
      _previewTriggered = true; _c.pause(); widget.onPreviewLimitReached?.call();
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoPlayer o) {
    super.didUpdateWidget(o);
    if (!_init) return;
    if (widget.isPlaying && !o.isPlaying && !_previewTriggered) { _paused = false; _c.play(); }
    else if (!widget.isPlaying && o.isPlaying) { _c.pause(); _c.seekTo(Duration.zero); _previewTriggered = false; }
  }

  @override
  void dispose() { _c.removeListener(_onTick); _c.dispose(); _pos.dispose(); super.dispose(); }

  void _seekToPercent(double pct) {
    if (!_init) return;
    final newPos = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
    _c.seekTo(newPos); _pos.value = newPos;
  }

  @override
  Widget build(BuildContext context) {
    if (!_init) {
      if (widget.coverUrl.trim().isEmpty) return Container(color: Colors.black);
      return CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: () {
        if (_previewTriggered) return;
        if (_c.value.isPlaying) { _c.pause(); _paused = true; } else { _c.play(); _paused = false; }
        setState(() {}); widget.onPlayStateChanged(_paused);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Le lecteur encapsulé dans AspectRatio pour s'adapter à la vidéo réelle
          Container(
            color: Colors.black, 
            child: Center(
              child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))
            )
          ),
          if (_paused) const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 80)),

          // Progress Bar Ultra Fine
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: GestureDetector(
              onHorizontalDragStart: (d) { _isDragging = true; _c.pause(); },
              onHorizontalDragUpdate: (d) { final pct = (d.localPosition.dx / context.size!.width).clamp(0.0, 1.0); _pos.value = Duration(milliseconds: (_dur.inMilliseconds * pct).round()); },
              onHorizontalDragEnd: (d) { _isDragging = false; _c.seekTo(_pos.value); if (!_paused) _c.play(); },
              onTapDown: (d) => _seekToPercent((d.localPosition.dx / context.size!.width).clamp(0.0, 1.0)),
              child: Container(
                height: 20, color: Colors.transparent, alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: _pos,
                  builder: (_, pos, __) {
                    final pct = _dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / _dur.inMilliseconds;
                    return Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        Container(height: _isDragging ? 4 : 1.5, width: double.infinity, color: Colors.white.withValues(alpha: 0.3)),
                        Container(height: _isDragging ? 4 : 1.5, width: MediaQuery.of(context).size.width * pct, color: Colors.white),
                      ],
                    );
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// COMMENTAIRES BOTTOM SHEET
// ============================================================================
class _CommentsSheet extends ConsumerStatefulWidget {
  final String mediaId, mediaTitle;
  const _CommentsSheet({required this.mediaId, required this.mediaTitle});
  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
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
  void initState() { super.initState(); _fetchRoots(); }

  void _showError(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: _MediaColors.danger)); }

  Future<void> _fetchUserLikes() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.from('comment_likes').select('comment_id').eq('user_id', uid);
      if (mounted) setState(() => _likedIds.addAll((res as List).map((e) => e['comment_id'] as String)));
    } catch (_) {}
  }

  Future<void> _fetchRoots() async {
    try {
      final res = await Supabase.instance.client.from('media_comments').select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count').eq('media_id', widget.mediaId).isFilter('parent_id', null).order('created_at', ascending: false).limit(50);
      if (mounted) { setState(() { _roots = (res as List).map((e) => CommentItem.fromMap(e as Map<String, dynamic>)).toList(); _loading = false; }); _fetchUserLikes(); }
    } catch (_) { if (mounted) { setState(() => _loading = false); _showError("Impossible de charger les commentaires."); } }
  }

  Future<void> _fetchReplies(String parentId) async {
    try {
      final res = await Supabase.instance.client.from('media_comments').select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count').eq('parent_id', parentId).order('created_at', ascending: true);
      if (mounted) setState(() { _replies[parentId] = (res as List).map((e) => CommentItem.fromMap(e as Map<String, dynamic>)).toList(); _expanded.add(parentId); });
    } catch (_) { _showError("Impossible de charger les réponses."); }
  }

  Future<void> _submit() async {
    final t = _controller.text.trim();
    if (t.isEmpty || _sending) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) { _showError('Veuillez vous connecter.'); return; }

    setState(() => _sending = true);
    try {
      if (_editingComment != null) {
        await Supabase.instance.client.from('media_comments').update({'content': t}).eq('id', _editingComment!.id);
        setState(() => _editingComment = null);
        await _fetchRoots();
      } else {
        final p = await Supabase.instance.client.from('profiles').select('username, full_name, avatar_url').eq('id', uid).maybeSingle();
        final authUser = Supabase.instance.client.auth.currentUser;
        final name = (p?['username'] as String?)?.isNotEmpty == true ? p!['username'] : (p?['full_name'] as String?)?.isNotEmpty == true ? p!['full_name'] : (authUser?.userMetadata?['full_name'] as String?)?.isNotEmpty == true ? authUser!.userMetadata!['full_name'] : 'Utilisateur';
        final parentId = _replyingTo?.parentId ?? _replyingTo?.id;

        await Supabase.instance.client.from('media_comments').insert({'media_id': widget.mediaId, 'user_id': uid, 'user_name': name, 'avatar_url': p?['avatar_url'], 'content': t, 'parent_id': parentId});
        if (parentId != null) await _fetchReplies(parentId); else await _fetchRoots();
      }
      _controller.clear(); _focusNode.unfocus(); setState(() => _replyingTo = null); ref.invalidate(commentCountProvider(widget.mediaId));
    } catch (e) { _showError("Échec de l'envoi."); } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _delete(String id) async {
    try { await Supabase.instance.client.from('media_comments').delete().eq('id', id); _fetchRoots(); ref.invalidate(commentCountProvider(widget.mediaId)); } catch (_) { _showError("Impossible de supprimer ce commentaire."); }
  }

  void _showOptions(CommentItem c) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isAuthor = uid == c.userId;
    showModalBottomSheet(
      context: context, backgroundColor: _MediaColors.card,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor) ListTile(leading: const Icon(Icons.edit, color: Colors.white), title: const Text('Modifier', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); setState(() { _editingComment = c; _replyingTo = null; }); _controller.text = c.content; _focusNode.requestFocus(); }),
            if (isAuthor) ListTile(leading: const Icon(Icons.delete, color: _MediaColors.danger), title: const Text('Supprimer', style: TextStyle(color: _MediaColors.danger)), onTap: () { Navigator.pop(context); _delete(c.id); }),
            ListTile(leading: const Icon(Icons.flag, color: ThixPolicy.warning), title: const Text('Signaler', style: TextStyle(color: ThixPolicy.warning)), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalé aux modérateurs'))); }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}j";
  }

  Widget _buildCommentTile(CommentItem c, {bool isReply = false}) {
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
              radius: isReply ? 14 : 18, backgroundColor: Colors.white12,
              backgroundImage: c.avatarUrl != null && c.avatarUrl!.isNotEmpty ? CachedNetworkImageProvider(c.avatarUrl!) : null,
              child: c.avatarUrl == null ? Icon(Icons.person, size: isReply ? 16 : 20, color: Colors.white54) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showOptions(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: c.userId))), child: Text(c.userName, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(_formatDate(c.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () { setState(() { _replyingTo = c; _editingComment = null; }); _focusNode.requestFocus(); },
                        child: const Text('Répondre', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid == null) { _showError('Connectez-vous pour aimer.'); return; }
                          setState(() { if (isLiked) { _likedIds.remove(c.id); _localCommentLikes[c.id] = (currentLikes - 1).clamp(0, 999999); } else { _likedIds.add(c.id); _localCommentLikes[c.id] = currentLikes + 1; } });
                          try { await Supabase.instance.client.rpc('toggle_comment_like', params: {'p_comment_id': c.id}); } catch (_) { if (mounted) { setState(() { if (isLiked) { _likedIds.add(c.id); _localCommentLikes[c.id] = currentLikes; } else { _likedIds.remove(c.id); _localCommentLikes[c.id] = currentLikes; } }); } }
                        },
                        child: Row(children: [Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? _MediaColors.danger : Colors.white54, size: 14), const SizedBox(width: 4), Text(currentLikes > 0 ? '$currentLikes' : "", style: TextStyle(color: isLiked ? _MediaColors.danger : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))]),
                      )
                    ],
                  ),
                  if (!isReply && (c.replyCount > 0 || _replies.containsKey(c.id))) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () { if (_expanded.contains(c.id)) setState(() => _expanded.remove(c.id)); else _fetchReplies(c.id); },
                      child: Row(
                        children: [
                          Container(width: 24, height: 1, color: Colors.white24),
                          const SizedBox(width: 8),
                          Text(_expanded.contains(c.id) ? 'Masquer' : 'Voir les ${c.replyCount} réponses', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  ],
                  if (!isReply && _expanded.contains(c.id)) ...[...(_replies[c.id] ?? []).map((r) => _buildCommentTile(r, isReply: true))]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.70,
            decoration: BoxDecoration(
              color: _MediaColors.card.withValues(alpha: 0.97),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                Text('${_roots.length} commentaires', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _roots.isEmpty
                          ? const Center(child: Text('Soyez le premier à commenter !', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _roots.length,
                              itemBuilder: (c, i) => _buildCommentTile(_roots[i]),
                            ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: _MediaColors.cardLight,
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                  ),
                  child: Column(
                    children: [
                      if (_replyingTo != null || _editingComment != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.black26,
                          child: Row(
                            children: [
                              Text(_editingComment != null ? 'Modification' : 'Réponse à @${_replyingTo!.userName}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              GestureDetector(onTap: () { setState(() { _replyingTo = null; _editingComment = null; }); _controller.clear(); }, child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16)),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  onSubmitted: (_) => _submit(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    hintText: _editingComment != null ? 'Modifier...' : (_replyingTo != null ? 'Votre réponse...' : 'Ajouter un commentaire...'),
                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _submit,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: _sending ? null : _MediaColors.gradientWhite,
                                  color: _sending ? Colors.white10 : null,
                                  shape: BoxShape.circle,
                                ),
                                child: _sending
                                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: _MediaColors.navyDeep, strokeWidth: 2))
                                    : const Icon(Icons.send_rounded, color: _MediaColors.navyDeep, size: 18),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
