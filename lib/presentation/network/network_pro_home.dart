// lib/presentation/network/network_pro_home.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; 

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/network_story.dart';
import 'package:thix_id/data/models/live/live_model.dart'; // ✅ IMPORT AJOUTÉ POUR LIVESESSION
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';

import 'package:thix_id/presentation/network/live/live_prep_screen.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart'; 

// ============================================================================
// PROVIDER — SESSIONS LIVE ACTIVES
// ============================================================================
final activeLiveSessionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  try {
    return Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(10);
  } catch (_) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }
});

// ============================================================================
// COMPOSANT — AVATAR ROND ÉPURÉ
// ============================================================================
class RoundAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final bool isLive;

  const RoundAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isLive ? ThixPolicy.danger : ThixPolicy.border, width: isLive ? 2.0 : 0.5),
        color: ThixPolicy.surfaceSoft,
      ),
      child: ClipOval(
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl!, 
                fit: BoxFit.cover, 
                placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.5, color: ThixPolicy.textSecondary)
              )
            : Icon(Icons.person, size: size * 0.5, color: ThixPolicy.textSecondary),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE — THIX PRO 
// ============================================================================
class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});

  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _navVisible = ValueNotifier(true);

  static DateTime? _lastRefreshTime;
  static const _refreshCooldown = Duration(seconds: 60);

  String _feedType = 'foryou'; 
  
  List<NetworkStory> _stories = [];
  bool _loadingStories = true;
  bool _isLoadingMore = false;

  // ─── GESTION DES SUGGESTIONS (Aléatoire local optimisé) ───
  List<dynamic> _allSuggestions = [];
  List<dynamic> _displayedSuggestions = [];
  Timer? _suggestionTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

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
    if (dir == ScrollDirection.reverse && _navVisible.value) {
      _navVisible.value = false;
    } else if (dir == ScrollDirection.forward && !_navVisible.value) {
      _navVisible.value = true;
    }
  }

  Future<void> _init() async {
    final now = DateTime.now();
    final needsRefresh = _lastRefreshTime == null || now.difference(_lastRefreshTime!) > _refreshCooldown;

    await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: needsRefresh);
    if (needsRefresh) _lastRefreshTime = now;

    await Future.wait([_loadStories(), _loadSuggestions()]);
  }

  Future<void> _loadStories() async {
    try {
      final data = await ref.read(networkServiceProvider).getActiveStories();
      if (mounted) setState(() { _stories = data; _loadingStories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStories = false);
    }
  }

  // ─── CHARGEMENT & MÉLANGE DES SUGGESTIONS ───
  Future<void> _loadSuggestions() async {
    try {
      // On charge 30 suggestions une seule fois pour éviter de spammer la DB
      final data = await ref.read(networkServiceProvider).getSuggestedConnections(limit: 30);
      _allSuggestions = data;
      _shuffleSuggestions();

      // Timer pour remélanger toutes les minutes
      _suggestionTimer?.cancel();
      _suggestionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _shuffleSuggestions();
      });
    } catch (_) {}
  }

  void _shuffleSuggestions() {
    if (_allSuggestions.isEmpty || !mounted) return;
    setState(() {
      final list = List<dynamic>.from(_allSuggestions);
      list.shuffle(Random());
      // On affiche uniquement 8 à 10 personnes à la fois
      _displayedSuggestions = list.take(10).toList();
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: true);
    _lastRefreshTime = DateTime.now();
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
  }

  Future<void> _openCreateStory() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const CreateStoryDialog());
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
    }
  }

  void _safePush(String path) {
    if (!mounted) return;
    try { context.push(path); } catch (e) { debugPrint('nav: $e'); }
  }

  Future<void> _openComments(String postId) async {
    _safePush('/network/comments/$postId');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _navVisible.dispose();
    _suggestionTimer?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authAsync = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUser = authAsync.value;
    
    final liveSessionsAsync = ref.watch(activeLiveSessionsProvider);
    final liveSessions = liveSessionsAsync.value ?? const <Map<String, dynamic>>[];
    final liveHostIds = liveSessions.map((s) => s['host_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/'); 
      },
      child: Scaffold(
        backgroundColor: Colors.white, 
        body: Stack(
          children: [
            RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: Colors.white,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(
                    avatarUrl: currentUser.photoUrl,
                  ),

                  // ─── CRÉATION DE POST ───
                  SliverToBoxAdapter(
                    child: _QuickPostEntryCard(
                      avatarUrl: currentUser.photoUrl,
                      onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                    ),
                  ),

                  // ─── STORIES ───
                  SliverToBoxAdapter(child: _buildStories(currentUser.id, liveHostIds)),

                  // ─── FILTRES DE FLUX ───
                  SliverToBoxAdapter(child: _buildFilters()),

                  // ─── BANDE UNIQUE : SUGGESTIONS (Gauche) + LIVES (Droite) ───
                  if (_displayedSuggestions.isNotEmpty || liveSessions.isNotEmpty)
                    SliverToBoxAdapter(child: _buildUnifiedDiscoveryBand(liveSessions)),

                  // ─── FIL D'ACTUALITÉ ───
                  feedAsync.when(
                    loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text('Erreur: $e', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary))),
                      ),
                    ),
                    data: (posts) {
                      if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty());
                      return SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (c, i) {
                          final post = posts[i];
                          return PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            currentProfileId: currentUser.id,
                            onLike: null,
                            onComment: () => _openComments(post.id),
                            onShare: () => _showShareSheet(post),
                            onDelete: () => ref.read(feedProvider.notifier).deletePost(post.id),
                            onRefresh: null,
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),

            ValueListenableBuilder<bool>(
              valueListenable: _navVisible,
              builder: (context, visible, _) => Positioned(
                left: 0, right: 0, bottom: 0,
                child: _buildBottomNav(visible),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── APP BAR ÉPURÉE (Bouton Live Intégré) ───────────────────────────
  Widget _buildSliverAppBar({required String? avatarUrl}) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      toolbarHeight: 60,
      titleSpacing: 16,
      title: Text('THIX PRO', style: ThixPolicy.h2Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.3, color: ThixPolicy.textMain)),
      actions: [
        // 🔴 SYMBOLE LIVE EN ROUGE POUR LANCER UN DIRECT
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePrepScreen())),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: ThixPolicy.danger.withOpacity(0.08),
            ),
            child: const Icon(Icons.sensors_rounded, size: 20, color: ThixPolicy.danger),
          ),
        ),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.search_rounded, onTap: () => _safePush('/network/search')),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.notifications_none_rounded, onTap: () => _safePush('/network/notifications')),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => _safePush('/network/profile'), 
            child: RoundAvatar(size: 34, imageUrl: avatarUrl),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: ThixPolicy.border),
      ),
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
        child: Icon(icon, size: 19, color: ThixPolicy.textMain),
      ),
    );
  }

  // ─────────────────────────── STORIES ───────────────────────────
  Widget _buildStories(String currentUserId, Set<String> liveHostIds) {
    if (_loadingStories) {
      return Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: ThixPolicy.border))),
        height: 150,
        alignment: Alignment.center,
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
      );
    }

    final myStories = _stories.where((s) => s.userId == currentUserId).toList();
    final Map<String, List<NetworkStory>> groupedOtherStories = {};
    for (final s in _stories) {
      if (s.userId != currentUserId) {
        groupedOtherStories.putIfAbsent(s.userId, () => []).add(s);
      }
    }
    final otherUsersList = groupedOtherStories.keys.toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ThixPolicy.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 134,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: otherUsersList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (c, i) {
            if (i == 0) {
              return _StoryCard(
                isMe: true,
                hasStory: myStories.isNotEmpty,
                isLive: liveHostIds.contains(currentUserId),
                name: myStories.isNotEmpty ? 'Votre story' : 'Créer',
                coverUrl: myStories.isNotEmpty ? (myStories.first.imageUrl.isNotEmpty ? myStories.first.imageUrl : myStories.first.userAvatar) : null,
                avatarUrl: myStories.isNotEmpty ? myStories.first.userAvatar : null,
                onTap: myStories.isNotEmpty ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: myStories, initialIndex: 0))) : _openCreateStory,
                onAdd: _openCreateStory,
              );
            }
            final userId = otherUsersList[i - 1];
            final userStories = groupedOtherStories[userId]!;
            final firstStory = userStories.first;

            return _StoryCard(
              isMe: false,
              hasStory: true,
              isLive: liveHostIds.contains(userId),
              name: firstStory.userName.split(' ').first,
              coverUrl: firstStory.imageUrl.isNotEmpty ? firstStory.imageUrl : null,
              avatarUrl: firstStory.userAvatar,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: userStories, initialIndex: 0))),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────── FILTRES ───────────────────────────
  Widget _buildFilters() {
    final filters = {
      'foryou': 'Pour vous',
      'network': 'Abonnements',
      'recent': 'Récents',
      'popular': 'Tendances',
    };

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ThixPolicy.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final active = _feedType == e.key;
            return GestureDetector(
              onTap: () {
                if (active) return;
                setState(() => _feedType = e.key);
                ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                _lastRefreshTime = DateTime.now();
                HapticFeedback.lightImpact();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 8),
                child: Column(
                  children: [
                    Text(
                      e.value,
                      style: ThixPolicy.bodyStyle.copyWith(
                        color: active ? ThixPolicy.textMain : ThixPolicy.textSecondary,
                        fontWeight: active ? ThixPolicy.bold : ThixPolicy.semiBold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (active)
                      Container(width: 20, height: 3, decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(3)))
                    else
                      const SizedBox(height: 3),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────── BANDE UNIQUE (SUGGESTIONS + LIVES) ───────────────────────────
  Widget _buildUnifiedDiscoveryBand(List<Map<String, dynamic>> liveSessions) {
    final int totalCount = _displayedSuggestions.length + liveSessions.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ThixPolicy.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.explore_rounded, size: 16, color: ThixPolicy.textMain),
                const SizedBox(width: 8),
                Text('À découvrir', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14.5, color: ThixPolicy.textMain)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90, 
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: totalCount,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (c, i) {
                // SUGGESTIONS À GAUCHE
                if (i < _displayedSuggestions.length) {
                  final u = _displayedSuggestions[i];
                  return GestureDetector(
                    onTap: () => context.push('/network/profile/${u.id}'),
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              RoundAvatar(size: 56, imageUrl: u.avatar),
                              Positioned(
                                bottom: -2, right: -2,
                                child: GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    setState(() => _displayedSuggestions.removeAt(i));
                                    try { await ref.read(networkServiceProvider).sendConnectionRequest(u.id); } catch (_) {}
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(u.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
                        ],
                      ),
                    ),
                  );
                } 
                // LIVES EN COURS À DROITE
                else {
                  final liveIndex = i - _displayedSuggestions.length;
                  final s = liveSessions[liveIndex];
                  return GestureDetector(
                    onTap: () {
                      // ✅ CORRECTION ICI : Création de l'objet LiveSession complet
                      final liveSession = LiveSession(
                        id: s['id']?.toString() ?? '',
                        channelName: s['channel_name']?.toString() ?? '',
                        title: s['title']?.toString() ?? 'Live',
                        hostId: s['host_id']?.toString() ?? '',
                        hostName: s['host_name']?.toString() ?? 'Hôte THIX',
                        hostAvatarUrl: s['host_avatar']?.toString(),
                      );

                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => LiveViewerScreen(
                            session: liveSession, // ✅ ON PASSE L'OBJET SESSION ICI
                          ),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              RoundAvatar(size: 56, imageUrl: s['host_avatar']?.toString(), isLive: true),
                              Positioned(
                                bottom: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1.5)),
                                  child: Text('LIVE', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontSize: 8, fontWeight: ThixPolicy.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text((s['host_name']?.toString() ?? 'Hôte').split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── FEED UTILS ───────────────────────────
  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(3, (i) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: ThixPolicy.border)),
        ),
        height: 200,
      )),
    );
  }

  Widget _buildEmpty() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
            child: const Icon(Icons.feed_outlined, size: 32, color: ThixPolicy.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('Aucune publication pour ce filtre', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _onRefresh,
            style: OutlinedButton.styleFrom(foregroundColor: ThixPolicy.textMain, side: const BorderSide(color: ThixPolicy.border)),
            child: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(dynamic post) {
    final id = '${post.id}';
    final link = 'https://thix.id/network/post/$id';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            ListTile(
              leading: const Icon(Icons.link, color: ThixPolicy.textMain),
              title: Text('Copier le lien', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.semiBold)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                try { await ref.read(networkServiceProvider).sharePost(id); } catch (_) {}
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: ThixPolicy.textSecondary),
              title: Text('Fermer', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── BOTTOM NAV EXACT ───────────────────────────
  Widget _buildBottomNav(bool visible) {
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ThixPolicy.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navBtn(Icons.home_rounded, 'Accueil', true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                        _navBtn(Icons.explore_outlined, 'Découvrir', false, () => _safePush('/network/discover')),
                        _navBtn(Icons.add_circle_outline_rounded, 'Publier', false, () => showDialog(context: context, builder: (_) => const CreatePostDialog())),
                        _navBtn(Icons.mail_outline_rounded, 'Messages', false, () => _safePush('/network/messages')), 
                        _navBtn(Icons.diversity_3_outlined, 'Communauté', false, () => _safePush('/network/communities')),
                      ],
                    ),
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
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 21, color: active ? ThixPolicy.primary : ThixPolicy.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: active ? ThixPolicy.primary : ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK POST ENTRY (Design Capture)
// ============================================================================
class _QuickPostEntryCard extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _QuickPostEntryCard({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ThixPolicy.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          RoundAvatar(size: 44, imageUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
                ),
                child: Text('Commencer un post...', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.image_outlined, color: ThixPolicy.primary, size: 26),
            tooltip: 'Ajouter un média',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STORIES
// ============================================================================
class _StoryCard extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? coverUrl;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StoryCard({required this.isMe, required this.hasStory, this.isLive = false, required this.name, this.coverUrl, this.avatarUrl, required this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isLive ? ThixPolicy.danger : ThixPolicy.border, width: isLive ? 1.4 : 1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (coverUrl != null && coverUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                        errorWidget: (_, __, ___) => Container(color: ThixPolicy.surfaceSoft),
                      )
                    : Container(color: ThixPolicy.surfaceSoft),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.55)]),
                ),
              ),
            ),
            Positioned(
              top: 8, left: 8,
              child: RoundAvatar(size: 28, imageUrl: avatarUrl, isLive: isLive),
            ),
            if (isMe)
              Positioned(
                top: 22, left: 22,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 1.8)),
                    child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
