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
// PAGE PRINCIPALE MEDIA — DESIGN ULTRA PRO
// ============================================================================
class ThixMediaPage extends ConsumerStatefulWidget {
  const ThixMediaPage({super.key});
  @override
  ConsumerState<ThixMediaPage> createState() => _ThixMediaPageState();
}

class _ThixMediaPageState extends ConsumerState<ThixMediaPage> with WidgetsBindingObserver {
  late PageController _feedController;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Set<String> _likedMediaIds = {};
  Set<String> _savedMediaIds = {}; // NOUVEAU: Favoris
  final Set<String> _viewedMediaIds = {};
  final Set<String> _newlyFollowedIds = {};
  final Map<String, int> _localLikeCounts = {};
  final Map<String, int> _localViewCounts = {};
  final Set<String> _unlockedPaidVideos = {};

  final Map<String, bool> _previewExpired = {};
  static const int _paidPreviewSeconds = 30;
  final Map<String, int> _episodeIndex = {};

  bool _immersive = false;
  int _currentFeedIndex = 0;
  List<MediaContent> _filItems = [];

  static final Set<String> _globalSeenIds = {};
  bool _appWasBackgrounded = false;
  bool _showRefreshToast = false; // NOUVEAU: Toast au retour

  bool _filLoading = false;
  bool _filInitialized = false;
  double _pullDistance = 0;
  bool _pullTriggering = false;
  static const double _pullThreshold = 90;

  List<MediaContent> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedController = PageController();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedCategoryProvider.notifier).state = "Fil";
      _initFilFeed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _feedController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── AUTO-MIX: Détecte le retour au premier plan pour renouveler le mix ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _appWasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _appWasBackgrounded) {
      _appWasBackgrounded = false;
      _smartReshuffleOnReturn();
    }
  }

  Future<void> _smartReshuffleOnReturn() async {
    if (_filItems.isEmpty) return;
    try {
      final res = await Supabase.instance.client.rpc('get_shuffled_feed', params: {'p_seen_ids': _globalSeenIds.toList(), 'p_limit': 12});
      final fresh = (res as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted || fresh.isEmpty) return;
      
      setState(() {
        final keep = _filItems.take(_currentFeedIndex + 1).toList();
        final keepIds = keep.map((e) => e.id).toSet();
        _filItems = [...keep, ...fresh.where((f) => !keepIds.contains(f.id))];
        _globalSeenIds.addAll(fresh.map((e) => e.id));
        
        // Afficher l'indicateur visuel de rafraichissement
        _showRefreshToast = true;
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showRefreshToast = false);
      });
    } catch (_) {}
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

  Future<void> _initFilFeed({bool reshuffle = false}) async {
    if (_filLoading) return;
    setState(() => _filLoading = true);

    try {
      if (reshuffle) _globalSeenIds.clear();

      dynamic res = await Supabase.instance.client.rpc('get_shuffled_feed', params: {'p_seen_ids': _globalSeenIds.toList(), 'p_limit': 12});
      List<MediaContent> items = (res as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();

      if (items.isEmpty && _globalSeenIds.isNotEmpty) {
        _globalSeenIds.clear();
        res = await Supabase.instance.client.rpc('get_shuffled_feed', params: {'p_seen_ids': [], 'p_limit': 12});
        items = (res as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
      }

      if (!mounted) return;

      setState(() {
        _filItems = reshuffle ? items : [..._filItems, ...items.where((x) => !_globalSeenIds.contains(x.id))];
        _globalSeenIds.addAll(_filItems.map((e) => e.id));
        _filInitialized = true;
        if (reshuffle) _currentFeedIndex = 0;
      });

      await _syncLiked(_filItems.isNotEmpty ? [_filItems.first] : []);
      if (_filItems.isNotEmpty) _registerView(_filItems.first);
      if (reshuffle && _feedController.hasClients) _feedController.jumpToPage(0);
    } catch (_) {
      try {
        final res = await Supabase.instance.client.from('media_content').select('*, media_stats(like_count,view_count,comment_count)').order('created_at', ascending: false).limit(12);
        final items = (res as List).map((e) => _mapMedia(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted) setState(() { _filItems = items; _filInitialized = true; });
      } catch (e2) {
        if (mounted) setState(() { _filInitialized = true; });
      }
    } finally {
      if (mounted) setState(() => _filLoading = false);
    }
  }

  Future<void> _loadMoreFil() async {
    if (_filLoading) return;
    setState(() => _filLoading = true);
    try {
      dynamic res = await Supabase.instance.client.rpc('get_shuffled_feed', params: {'p_seen_ids': _globalSeenIds.toList(), 'p_limit': 12});
      List<MediaContent> items = (res as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _filItems.addAll(items.where((e) => !_globalSeenIds.contains(e.id)));
        _globalSeenIds.addAll(items.map((e) => e.id));
      });
      await _syncLiked(items);
    } catch (_) {} finally {
      if (mounted) setState(() => _filLoading = false);
    }
  }

  Future<void> _syncLiked(List<MediaContent> items) async {
    if (items.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.rpc('get_liked_media_ids', params: {'p_media_ids': items.map((e) => e.id).toList()});
      if (mounted) setState(() => _likedMediaIds.addAll((res as List).map((e) => e as String)));
    } catch (_) {}
  }

  // ── Recherche Fonctionnelle ──
  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = v;
    _searchDebounce = Timer(const Duration(milliseconds: 320), () => _performSearch(v));
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

  void _selectSearchResult(MediaContent item) {
    _searchFocusNode.unfocus(); _searchController.clear();
    setState(() { _searchResults = []; final withoutDup = _filItems.where((e) => e.id != item.id).toList(); _filItems = [item, ...withoutDup]; _currentFeedIndex = 0; });
    if (_feedController.hasClients) _feedController.jumpToPage(0);
    _registerView(item);
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  String _formatPrice(MediaContent item) => '\$${item.price}';

  Widget _buildImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url.isEmpty) return Container(color: const Color(0xFF0F141E), child: const Icon(Icons.broken_image_rounded, color: Colors.white24));
    return CachedNetworkImage(
      imageUrl: url, width: width, height: height, fit: fit,
      placeholder: (c, url) => Container(color: const Color(0xFF0F141E)),
      errorWidget: (c, e, s) => Container(color: const Color(0xFF0F141E), child: const Icon(Icons.broken_image_rounded, color: Colors.white24)),
    );
  }

  void _registerView(MediaContent item) async {
    if (_viewedMediaIds.contains(item.id)) return;
    _viewedMediaIds.add(item.id);
    setState(() { _localViewCounts[item.id] = (_localViewCounts[item.id] ?? item.viewCount) + 1; });
    _AnalyticsBatcher.register(item.id);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) await Supabase.instance.client.from('media_views').insert({'media_id': item.id, 'user_id': uid});
    } catch (_) {}
  }

  Future<void> _toggleLike(MediaContent item) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous pour aimer.'))); return; }
    final wasLiked = _likedMediaIds.contains(item.id);
    HapticFeedback.selectionClick();

    setState(() {
      if (wasLiked) { _likedMediaIds.remove(item.id); _localLikeCounts[item.id] = (_localLikeCounts[item.id] ?? item.likeCount) - 1; } 
      else { _likedMediaIds.add(item.id); _localLikeCounts[item.id] = (_localLikeCounts[item.id] ?? item.likeCount) + 1; }
    });

    try { await Supabase.instance.client.rpc('toggle_media_like', params: {'p_media_id': item.id}); } catch (_) {}
  }

  void _toggleSave(MediaContent item) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_savedMediaIds.contains(item.id)) _savedMediaIds.remove(item.id);
      else _savedMediaIds.add(item.id);
    });
  }

  void _openComments(MediaContent item) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, // Transparent pour laisser place au Container décoré
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(mediaId: item.id, mediaTitle: item.title),
    ).then((_) { ref.invalidate(commentCountProvider(item.id)); });
  }

  void _handlePageChanged(int index) {
    if (index < 0 || index >= _filItems.length) return;
    if (index >= _filItems.length - 4) _loadMoreFil();
    _registerView(_filItems[index]);
  }

  Widget _buildMediaContentLayer(MediaContent item, bool isFocused) {
    final currentEp = _episodeIndex[item.id] ?? 0;
    final allEpisodes = [item.videoUrl, ...item.episodesUrls].where((url) => url.isNotEmpty).toList();
    final isSeries = allEpisodes.length > 1;
    final activeUrl = allEpisodes.isEmpty ? item.videoUrl : allEpisodes[currentEp.clamp(0, allEpisodes.length - 1)];

    final previewExpired = _previewExpired[item.id] ?? false;
    final requiresPayment = item.isPaid && !_unlockedPaidVideos.contains(item.id) && previewExpired;
    final enforcePreview = item.isPaid && !_unlockedPaidVideos.contains(item.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!requiresPayment)
          FeedVideoPlayer(
            key: ValueKey('${item.id}_$currentEp'),
            videoUrl: activeUrl,
            coverUrl: item.coverUrl,
            isPlaying: isFocused,
            enforcePreviewLimit: enforcePreview,
            previewSeconds: _paidPreviewSeconds,
            onPreviewLimitReached: () { if (mounted) setState(() => _previewExpired[item.id] = true); },
            onPlayStateChanged: (paused) { if (paused) setState(() => _immersive = false); },
          )
        else
          Container(
            decoration: BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(item.coverUrl), fit: BoxFit.cover)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [ThixPolicy.gold, ThixPolicy.gold.withOpacity(0.5)]), boxShadow: [BoxShadow(color: ThixPolicy.gold.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)]),
                      child: const Icon(Icons.lock_rounded, size: 44, color: Colors.black),
                    ),
                    const SizedBox(height: 24),
                    const Text('Contenu Premium', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Fin de l'aperçu gratuit. Débloquez la suite de cette vidéo pour seulement ${_formatPrice(item)}.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 10,
                        shadowColor: ThixPolicy.gold.withOpacity(0.5),
                      ),
                      onPressed: () {
                        setState(() { _unlockedPaidVideos.add(item.id); _previewExpired.remove(item.id); });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vidéo débloquée avec succès !'), backgroundColor: ThixPolicy.success));
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Débloquer (${_formatPrice(item)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Marqueurs Séries (Épisodes) ──
        if (isSeries && !requiresPayment)
          Positioned(
            left: 16, bottom: 20,
            child: Wrap(
              spacing: 6,
              children: List.generate(allEpisodes.length, (i) {
                final active = i == currentEp;
                return GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _episodeIndex[item.id] = i); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 28 : 8, height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: active ? ThixPolicy.primary : Colors.white.withOpacity(0.4),
                      boxShadow: active ? [BoxShadow(color: ThixPolicy.primary.withOpacity(0.5), blurRadius: 8)] : null,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncMedia = ref.watch(thixMediaListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: asyncMedia.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, st) => Center(child: Text('ERREUR : $e', style: const TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.bold))),
        data: (_) {
          final currentItem = _filItems.isNotEmpty ? _filItems[_currentFeedIndex.clamp(0, _filItems.length - 1)] : null;
          final showTopBar = !_immersive;
          final showSearchOverlay = _searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty;

          return Stack(
            children: [
              _buildTikTokFeed(),

              // RIGHT SIDEBAR (Actions)
              if (currentItem != null)
                Positioned(
                  right: 12, bottom: 40,
                  child: _buildRightSidebar(currentItem),
                ),
                
              // BOTTOM INFO (Texte)
              if (currentItem != null)
                Positioned(
                  left: 16, right: 80, bottom: 40,
                  child: _buildBottomInfo(currentItem),
                ),

              // HEADER TOP
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                top: showTopBar ? 0 : -100,
                left: 0, right: 0,
                child: IgnorePointer(
                  ignoring: !showTopBar,
                  child: AnimatedOpacity(duration: const Duration(milliseconds: 250), opacity: showTopBar ? 1 : 0, child: _header()),
                ),
              ),

              // TOAST NOUVEAUTÉ (Smart Mix)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                top: _showRefreshToast ? 110 : -60,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Nouveau contenu ajouté au fil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
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

  Widget _buildTikTokFeed() {
    if (!_filInitialized) return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
    if (_filItems.isEmpty) return const Center(child: Text("Aucun contenu", style: TextStyle(color: Colors.white)));

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (_currentFeedIndex == 0 && d.delta.dy > 0 && !_filLoading) {
          setState(() => _pullDistance = (_pullDistance + d.delta.dy).clamp(0, _pullThreshold * 1.6));
        }
      },
      onVerticalDragEnd: (d) async {
        if (_pullDistance >= _pullThreshold && !_pullTriggering) {
          _pullTriggering = true;
          await _initFilFeed(reshuffle: true);
          _pullTriggering = false;
        }
        setState(() => _pullDistance = 0);
      },
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && (n is ScrollUpdateNotification || n is ScrollStartNotification)) {
                if (!_immersive) setState(() => _immersive = true);
              }
              return false;
            },
            child: PageView.builder(
              controller: _feedController,
              scrollDirection: Axis.vertical,
              itemCount: _filItems.length,
              onPageChanged: (i) {
                setState(() { _currentFeedIndex = i; _immersive = false; });
                _handlePageChanged(i);
              },
              itemBuilder: (c, idx) {
                final item = _filItems[idx];
                final isFocused = _currentFeedIndex == idx;
                return _buildMediaContentLayer(item, isFocused);
              },
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0, height: 150,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () { if (_immersive) setState(() => _immersive = false); },
              child: Container(color: Colors.transparent),
            ),
          ),

          if (_pullDistance > 0 || _filLoading)
            Positioned(
              top: 100, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: _filLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Icon(Icons.arrow_downward_rounded, color: Colors.white, size: (18 + (_pullDistance / _pullThreshold) * 6).clamp(18, 26)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── INFOS BAS GAUCHE (Titre, Auteur, Tags) ──
  Widget _buildBottomInfo(MediaContent item) {
    final creatorId = item.userId;
    final creatorProfile = creatorId.isNotEmpty ? ref.watch(userProfileProvider(creatorId)).valueOrNull : null;
    final creatorIsOfficial = creatorId.isEmpty;
    String displayName = creatorIsOfficial ? 'THIX' : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? 'Créateur');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
              child: Text(item.type, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            if (item.filterApplied != 'Normal') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('✨ ${item.filterApplied}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
            if (item.isPaid) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(4)),
                child: Text(_formatPrice(item), style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text('@$displayName', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
        const SizedBox(height: 4),
        Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w400, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(item.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
        ],
      ],
    );
  }

  // ── RIGHT SIDEBAR (Actions: Like, Comment, Share) ──
  Widget _buildRightSidebar(MediaContent cur) {
    final isLiked = _likedMediaIds.contains(cur.id);
    final isSaved = _savedMediaIds.contains(cur.id);

    MediaCounts? live = ref.watch(mediaCountsStreamProvider(cur.id)).valueOrNull;
    int displayLikes = _localLikeCounts[cur.id] ?? live?.likeCount ?? cur.likeCount;

    final creatorId = cur.userId;
    final creatorProfile = creatorId.isNotEmpty ? ref.watch(userProfileProvider(creatorId)).valueOrNull : null;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isFollowing = creatorId.isNotEmpty ? (ref.watch(isFollowingProvider(creatorId)).valueOrNull ?? true) : true;
    final creatorIsOfficial = creatorId.isEmpty;
    final showPlusBtn = !creatorIsOfficial && creatorId.isNotEmpty && creatorId != currentUid && !isFollowing && !_newlyFollowedIds.contains(creatorId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar avec bouton follow
        GestureDetector(
          onTap: () { if (creatorId.isNotEmpty && !creatorIsOfficial) Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: creatorId))); },
          child: SizedBox(
            width: 48, height: 60,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
                    image: creatorProfile != null && creatorProfile['avatar_url'] != null ? DecorationImage(image: CachedNetworkImageProvider(creatorProfile['avatar_url']), fit: BoxFit.cover) : null,
                  ),
                  child: creatorProfile == null || creatorProfile['avatar_url'] == null ? const Icon(Icons.person, size: 24, color: Colors.white) : null,
                ),
                if (showPlusBtn)
                  Positioned(
                    bottom: 8,
                    child: GestureDetector(
                      onTap: () { setState(() => _newlyFollowedIds.add(creatorId)); MediaService().toggleFollow(creatorId); },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildActionIcon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, _formatNumber(displayLikes), isLiked ? ThixPolicy.danger : Colors.white, () => _toggleLike(cur)),
        _buildActionIcon(Icons.chat_bubble_rounded, _formatNumber(live?.commentCount ?? cur.commentCount), Colors.white, () => _openComments(cur)),
        _buildActionIcon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 'Sauver', isSaved ? ThixPolicy.gold : Colors.white, () => _toggleSave(cur)),
        _buildActionIcon(Icons.share_rounded, 'Partager', Colors.white, () { HapticFeedback.selectionClick(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié dans le presse-papier !'))); }),
        
        const SizedBox(height: 24),
        // Rotation Record Disc / Créer Post
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 8),
              gradient: ThixPolicy.brandGradient,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 34, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
          ],
        ),
      ),
    );
  }

  // ── HEADER ULTRA PRO (Glassmorphism) ──
  Widget _header() {
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Text('THIX MEDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(hintText: "Découvrir...", hintStyle: TextStyle(color: Colors.white54, fontSize: 14), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          ),
                        ),
                        if (hasQuery)
                          GestureDetector(
                            onTap: () { _searchController.clear(); setState(() => _searchResults = []); },
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (isAdmin) ...[
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThixMediaAdminPage())),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.danger.withOpacity(0.2)),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: ThixPolicy.danger, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
                  child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _searchFocusNode.unfocus(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.8),
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 80, left: 16, right: 16),
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
                : _searchResults.isEmpty
                    ? const Center(child: Text('Recherchez des vidéos, créateurs...', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final item = _searchResults[i];
                          return GestureDetector(
                            onTap: () => _selectSearchResult(item),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildImage(item.coverUrl),
                                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]))),
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
// LECTEUR VIDEO FEED (Progress bar fine & fluide)
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
    if (!_init) return CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover);

    return GestureDetector(
      onTap: () {
        if (_previewTriggered) return;
        if (_c.value.isPlaying) { _c.pause(); _paused = true; } else { _c.play(); _paused = false; }
        setState(() {}); widget.onPlayStateChanged(_paused);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)))),
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
                        Container(height: _isDragging ? 4 : 1.5, width: double.infinity, color: Colors.white.withOpacity(0.3)),
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
// COMMENTAIRES BOTTOM SHEET — FOND SOMBRE FORCÉ (Plus jamais blanc)
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

  void _showError(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger)); }

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
      context: context, backgroundColor: const Color(0xFF161B22), // Fond sombre strict
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor) ListTile(leading: const Icon(Icons.edit, color: Colors.white), title: const Text('Modifier', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); setState(() { _editingComment = c; _replyingTo = null; }); _controller.text = c.content; _focusNode.requestFocus(); }),
            if (isAuthor) ListTile(leading: const Icon(Icons.delete, color: ThixPolicy.danger), title: const Text('Supprimer', style: TextStyle(color: ThixPolicy.danger)), onTap: () { Navigator.pop(context); _delete(c.id); }),
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
                        child: Row(children: [Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? ThixPolicy.danger : Colors.white54, size: 14), const SizedBox(width: 4), Text(currentLikes > 0 ? '$currentLikes' : "", style: TextStyle(color: isLiked ? ThixPolicy.danger : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))]),
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
            // 🌟 CORRECTION: Forcé en gris très sombre opaque pour ne jamais être blanc
            decoration: BoxDecoration(
              color: const Color(0xFF0F141E).withOpacity(0.95), 
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1))
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
                    color: const Color(0xFF161B22),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))
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
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(24)),
                                child: TextField(
                                  controller: _controller, focusNode: _focusNode, minLines: 1, maxLines: 4, onSubmitted: (_) => _submit(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: _editingComment != null ? 'Modifier...' : (_replyingTo != null ? 'Votre réponse...' : 'Ajouter un commentaire...'),
                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14), border: InputBorder.none, isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _submit,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: _sending ? Colors.white10 : ThixPolicy.primary, shape: BoxShape.circle),
                                child: _sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
