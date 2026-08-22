// lib/presentation/network/network_pro_home.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/models/network_story.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';
import 'package:thix_id/presentation/network/live/live_prep_screen.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE PREMIUM — Inspirée des maquettes (Blanc, Aéré, Navy Blue)
// ═══════════════════════════════════════════════════════════════════════════
class _Pro {
  _Pro._();
  static const Color bg = Color(0xFFF4F7FB); // Gris/Bleu très très clair
  static const Color surface = Colors.white;
  static const Color navyText = Color(0xFF0A1F44); // Bleu marine fort pour les titres
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color primaryBlue = Color(0xFF2D6CDF); // Bleu d'action (comme le bouton +)
  static const Color accentCoral = Color(0xFFFF6B6B); // Corail pour les likes/notifications
  static const Color border = Color(0xFFE2E8F0);
  
  // Ombres ultra douces pour l'effet "flottant" des maquettes
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0A1F44).withOpacity(0.04),
          blurRadius: 20,
          offset: const Offset(0, 4),
        )
      ];
}

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
// AVATAR ROND — Simple et épuré
// ============================================================================
class RoundAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final bool hasBorder;
  final Color borderColor;
  final bool isLive;

  const RoundAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.hasBorder = false,
    this.borderColor = _Pro.primaryBlue,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: isLive ? _Pro.accentCoral : borderColor, width: 2) : null,
            color: _Pro.border.withOpacity(0.5),
            image: (imageUrl != null && imageUrl!.isNotEmpty)
                ? DecorationImage(image: CachedNetworkImageProvider(imageUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? Icon(Icons.person, size: size * 0.5, color: _Pro.textSecondary)
              : null,
        ),
        if (isLive)
          Positioned(
            bottom: -4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _Pro.accentCoral,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE — THIX PRO (Aéré & Blanc)
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
  List<dynamic> _suggestions = [];
  bool _isLoadingMore = false;

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

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref.read(networkServiceProvider).getSuggestedConnections(limit: 8);
      if (mounted) setState(() => _suggestions = data);
    } catch (_) {}
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

  void _openCreatePost() {
    showDialog(context: context, builder: (_) => const CreatePostDialog());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _navVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authAsync = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUser = authAsync.value;
    final liveSessionsAsync = ref.watch(activeLiveSessionsProvider);
    final liveSessions = liveSessionsAsync.value ?? [];
    final liveHostIds = liveSessions.map((s) => s['host_id']?.toString() ?? '').toSet();

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: _Pro.bg,
        body: Center(child: CircularProgressIndicator(color: _Pro.primaryBlue)),
      );
    }

    return Scaffold(
      backgroundColor: _Pro.bg, // Fond aéré et clair
      body: Stack(
        children: [
          RefreshIndicator(
            color: _Pro.primaryBlue,
            backgroundColor: _Pro.surface,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // 1. APP BAR ÉPURÉE
                _buildSliverAppBar(currentUser.photoUrl),

                // 2. STATUTS / STORIES (Style épuré, cercles simples)
                SliverToBoxAdapter(child: _buildStoriesRail(currentUser.id, liveHostIds, currentUser.photoUrl)),

                // 3. BARRE "WHAT'S ON YOUR MIND" (Copie exacte de votre capture)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _buildQuickPostField(currentUser.photoUrl),
                  ),
                ),

                // 4. LIVES EN COURS (Pilules discrètes au lieu d'une grosse carte)
                if (liveSessions.isNotEmpty)
                  SliverToBoxAdapter(child: _buildDiscreteLives(liveSessions)),

                // 5. TABS ÉPURÉS
                SliverToBoxAdapter(child: _buildCleanTabs()),

                // 6. SUGGESTIONS
                if (_suggestions.isNotEmpty) SliverToBoxAdapter(child: _buildSuggestions(liveHostIds)),

                // 7. LE FIL (POSTS)
                feedAsync.when(
                  loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('Erreur: $e', style: const TextStyle(color: _Pro.textSecondary)))),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty());
                    return SliverList.builder(
                      itemCount: posts.length,
                      itemBuilder: (c, i) {
                        final post = posts[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                          // PostCard sera mis à jour dans la prochaine étape.
                          // Pour l'instant, nous l'enveloppons pour qu'il prenne le style "Carte aérée".
                          child: PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            currentProfileId: currentUser.id,
                            onLike: null,
                            onComment: () => _safePush('/network/comments/${post.id}'),
                            onShare: () => _showShareSheet(post),
                            onDelete: () => ref.read(feedProvider.notifier).deletePost(post.id),
                            onRefresh: null,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // 8. NAVIGATION BASSE (Flottante, inspirée de la maquette)
          ValueListenableBuilder<bool>(
            valueListenable: _navVisible,
            builder: (context, visible, _) => Positioned(
              left: 20, right: 20, bottom: 20,
              child: _buildBottomNav(visible),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 1. APP BAR ÉPURÉE ───────────────────────────
  Widget _buildSliverAppBar(String? avatarUrl) {
    return SliverAppBar(
      backgroundColor: _Pro.bg, // Se fond avec le background
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      toolbarHeight: 64,
      titleSpacing: 16,
      // Avatar à gauche selon la maquette
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
        child: GestureDetector(
          onTap: () => _safePush('/network/profile'),
          child: RoundAvatar(size: 40, imageUrl: avatarUrl),
        ),
      ),
      leadingWidth: 56,
      title: const Text(
        'Communauté', // Titre plus convivial
        style: TextStyle(color: _Pro.navyText, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
      ),
      actions: [
        _appBarIcon(icon: Icons.search_rounded, onTap: () => _safePush('/network/search')),
        const SizedBox(width: 8),
        _appBarIcon(icon: Icons.notifications_none_rounded, onTap: () => _safePush('/network/notifications')),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _Pro.surface,
          shape: BoxShape.circle,
          boxShadow: _Pro.softShadow,
        ),
        child: Icon(icon, size: 22, color: _Pro.navyText),
      ),
    );
  }

  // ─────────────────────────── 2. STATUTS / STORIES ───────────────────────────
  Widget _buildStoriesRail(String currentUserId, Set<String> liveHostIds, String? myAvatar) {
    if (_loadingStories) {
      return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(color: _Pro.primaryBlue)));
    }

    final myStories = _stories.where((s) => s.userId == currentUserId).toList();
    final Map<String, List<NetworkStory>> groupedOtherStories = {};
    for (final s in _stories) {
      if (s.userId != currentUserId) {
        groupedOtherStories.putIfAbsent(s.userId, () => []).add(s);
      }
    }
    final otherUsersList = groupedOtherStories.keys.toList();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: otherUsersList.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (c, i) {
          if (i == 0) {
            return _StoryCircle(
              isMe: true,
              hasStory: myStories.isNotEmpty,
              name: 'Mon Statut',
              avatarUrl: myAvatar,
              onTap: myStories.isNotEmpty 
                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: myStories, initialIndex: 0))) 
                  : _openCreateStory,
            );
          }
          final userId = otherUsersList[i - 1];
          final userStories = groupedOtherStories[userId]!;
          final firstStory = userStories.first;

          return _StoryCircle(
            isMe: false,
            hasStory: true,
            isLive: liveHostIds.contains(userId),
            name: firstStory.userName.split(' ').first,
            avatarUrl: firstStory.userAvatar,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: userStories, initialIndex: 0))),
          );
        },
      ),
    );
  }

  // ─────────────────────────── 3. QUICK POST (What's on your mind) ───────────────────────────
  Widget _buildQuickPostField(String? avatarUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _Pro.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: _Pro.softShadow,
      ),
      child: Row(
        children: [
          RoundAvatar(size: 36, imageUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openCreatePost(),
              child: const Text(
                "Quoi de neuf aujourd'hui ?",
                style: TextStyle(color: _Pro.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openCreatePost(),
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                color: _Pro.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 4. LIVES EN COURS (Pilules discrètes) ───────────────────────────
  Widget _buildDiscreteLives(List<Map<String, dynamic>> sessions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final s = sessions[i];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveViewerScreen(
                      liveId: s['id']?.toString() ?? '',
                      channelName: s['channel_name']?.toString() ?? '',
                      hostName: s['host_name']?.toString() ?? 'Hôte THIX',
                      hostAvatarUrl: s['host_avatar']?.toString(),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _Pro.accentCoral.withOpacity(0.3)),
                  boxShadow: _Pro.softShadow,
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _Pro.accentCoral, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      (s['host_name'] as String?)?.split(' ').first ?? 'Live',
                      style: const TextStyle(color: _Pro.navyText, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────── 5. ONGLETS ÉPURÉS ───────────────────────────
  Widget _buildCleanTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _cleanTab('Pour vous', 'foryou'),
          const SizedBox(width: 20),
          _cleanTab('Abonnements', 'network'),
          const SizedBox(width: 20),
          _cleanTab('Récents', 'recent'),
        ],
      ),
    );
  }

  Widget _cleanTab(String title, String key) {
    final active = _feedType == key;
    return GestureDetector(
      onTap: () {
        if (active) return;
        setState(() => _feedType = key);
        ref.read(feedProvider.notifier).loadFeed(feedType: key, force: true);
        _lastRefreshTime = DateTime.now();
        HapticFeedback.lightImpact();
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: active ? _Pro.navyText : _Pro.textSecondary,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          if (active)
            Container(width: 20, height: 3, decoration: BoxDecoration(color: _Pro.primaryBlue, borderRadius: BorderRadius.circular(3)))
          else
            const SizedBox(height: 3),
        ],
      ),
    );
  }

  // ─────────────────────────── 6. SUGGESTIONS (Design aéré) ───────────────────────────
  Widget _buildSuggestions(Set<String> liveHostIds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Suggestions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _Pro.navyText)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final u = _suggestions[i];
                return Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _Pro.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _Pro.softShadow,
                  ),
                  child: Column(
                    children: [
                      RoundAvatar(size: 56, imageUrl: u.avatar, isLive: liveHostIds.contains(u.id)),
                      const SizedBox(height: 8),
                      Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _Pro.navyText)),
                      const SizedBox(height: 2),
                      Text(u.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _Pro.textSecondary)),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _Pro.bg,
                            foregroundColor: _Pro.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            await ref.read(networkServiceProvider).sendConnectionRequest(u.id);
                            setState(() => _suggestions.remove(u));
                          },
                          child: const Text('Suivre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 7. FEED UTILS ───────────────────────────
  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        height: 240,
        decoration: BoxDecoration(color: _Pro.surface, borderRadius: BorderRadius.circular(24)),
      )),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: _Pro.surface, boxShadow: _Pro.softShadow),
            child: const Icon(Icons.auto_awesome_rounded, size: 40, color: _Pro.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text('Votre fil est à jour', style: TextStyle(color: _Pro.navyText, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Suivez plus de créateurs pour voir plus de contenu.', textAlign: TextAlign.center, style: TextStyle(color: _Pro.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  void _showShareSheet(dynamic post) {
    final id = '${post.id}';
    final link = 'https://thix.id/network/post/$id';
    showModalBottomSheet(
      context: context,
      backgroundColor: _Pro.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _Pro.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: _Pro.bg, shape: BoxShape.circle), child: const Icon(Icons.copy_rounded, color: _Pro.navyText)),
              title: const Text('Copier le lien', style: TextStyle(color: _Pro.navyText, fontWeight: FontWeight.w700)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                try { await ref.read(networkServiceProvider).sharePost(id); } catch (_) {}
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── 8. BOTTOM NAV (Flottante style maquette) ───────────────────────────
  Widget _buildBottomNav(bool visible) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: _Pro.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: const Color(0xFF0A1F44).withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navBtn(Icons.home_rounded, true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
              _navBtn(Icons.search_rounded, false, () => _safePush('/network/search')),
              _navBtn(Icons.chat_bubble_outline_rounded, false, () => _safePush('/network/messages')),
              _navBtn(Icons.person_outline_rounded, false, () => _safePush('/network/profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData ic, bool active, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _Pro.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(ic, size: 24, color: active ? _Pro.primaryBlue : _Pro.textSecondary),
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIAIRES
// ============================================================================
class _StoryCircle extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _StoryCircle({
    required this.isMe,
    required this.hasStory,
    this.isLive = false,
    required this.name,
    this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              RoundAvatar(
                size: 64,
                imageUrl: avatarUrl,
                hasBorder: hasStory,
                borderColor: isLive ? _Pro.accentCoral : _Pro.primaryBlue,
                isLive: isLive,
              ),
              if (isMe && !hasStory)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _Pro.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: _Pro.navyText, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
