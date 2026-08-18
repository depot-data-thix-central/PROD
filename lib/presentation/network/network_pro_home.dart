// lib/presentation/network/network_pro_home.dart
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
// PALETTE THIX PRO — Monochrome Entreprise
// ═══════════════════════════════════════════════════════════════════════════
class _Pro {
  _Pro._();
  static const Color ink = ThixPolicy.inkDeep;
  static const Color primary = ThixPolicy.primary;
  static const Color surface = Color(0xFFF6F7F9);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE7E9EE);
  static const Color textMain = Color(0xFF14181F);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color live = Color(0xFFD7263D);
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
// COMPOSANT — AVATAR ROND
// ============================================================================
class RoundAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final Color ringColor;
  final IconData fallbackIcon;
  final double ringWidth;
  final bool isLive;

  const RoundAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.ringColor = _Pro.border,
    this.fallbackIcon = Icons.person,
    this.ringWidth = 1.6,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRingColor = isLive ? _Pro.live : ringColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(ringWidth),
          decoration: BoxDecoration(shape: BoxShape.circle, color: effectiveRingColor),
          child: ClipOval(
            child: Container(
              color: _Pro.surface,
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!, 
                      fit: BoxFit.cover, 
                      placeholder: (_, __) => Container(color: _Pro.surface),
                      errorWidget: (_, __, ___) => Icon(fallbackIcon, size: size * 0.45, color: _Pro.textSecondary)
                    )
                  : Icon(fallbackIcon, size: size * 0.45, color: _Pro.textSecondary),
            ),
          ),
        ),
        if (isLive)
          Positioned(
            bottom: -3, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _Pro.live, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 1.2)),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
              ),
            ),
          ),
      ],
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

  // 🌟 Par défaut, on charge le nouvel algorithme "Pour vous"
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

  Future<void> _openComments(String postId) async {
    _safePush('/network/comments/$postId');
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
    final liveHostIds = (liveSessionsAsync.value ?? const <Map<String, dynamic>>[])
        .map((s) => s['host_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: _Pro.surface,
        body: Center(child: CircularProgressIndicator(color: _Pro.primary)),
      );
    }

    // 🌟 POPSCOPE : Intercepte le bouton retour du téléphone pour rentrer au Hub Central
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Retourne à l'accueil THIX ID CENTRAL (ajuste la route si besoin, ex: '/home')
        context.go('/'); 
      },
      child: Scaffold(
        backgroundColor: _Pro.surface,
        body: Stack(
          children: [
            RefreshIndicator(
              color: _Pro.primary,
              backgroundColor: _Pro.card,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(isLive: liveHostIds.contains(currentUser.id)),

                  SliverToBoxAdapter(
                    child: _QuickPostEntryCard(
                      avatarUrl: currentUser.photoUrl,
                      onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                    ),
                  ),

                  SliverToBoxAdapter(child: _buildStories(currentUser.id, liveHostIds)),

                  SliverToBoxAdapter(child: _buildFilters()),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                      child: _AutoLiveHub(liveSessionsAsync: liveSessionsAsync),
                    ),
                  ),

                  if (_suggestions.isNotEmpty) SliverToBoxAdapter(child: _buildSuggestions(liveHostIds)),

                  feedAsync.when(
                    loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text('Erreur: $e', style: const TextStyle(color: _Pro.textSecondary))),
                      ),
                    ),
                    data: (posts) {
                      if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty());
                      return SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (c, i) {
                          final post = posts[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: ThixPolicy.s8),
                            child: PostCard(
                              key: ValueKey(post.id),
                              post: post,
                              currentProfileId: currentUser.id,
                              onLike: null,
                              onComment: () => _openComments(post.id),
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

  // ─────────────────────────── APP BAR ───────────────────────────
  Widget _buildSliverAppBar({required bool isLive}) {
    return SliverAppBar(
      backgroundColor: _Pro.card,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      toolbarHeight: ThixPolicy.appBarHeight,
      titleSpacing: ThixPolicy.s16,
      title: const Text(
        'THIX PRO',
        style: TextStyle(color: _Pro.ink, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
      ),
      actions: [
        _appBarIcon(icon: Icons.search_rounded, onTap: () => _safePush('/network/search')),
        const SizedBox(width: ThixPolicy.s8),
        _appBarIcon(icon: Icons.notifications_none_rounded, onTap: () => _safePush('/network/notifications')),
        // 🌟 L'icône de message a été retirée ici
        const SizedBox(width: ThixPolicy.s12),
        
        Padding(
          padding: const EdgeInsets.only(right: ThixPolicy.s16),
          child: GestureDetector(
            // 🌟 Correction de la route Profile
            onTap: () => _safePush('/network/profile'), 
            child: RoundAvatar(size: 34, ringWidth: 1.6, isLive: isLive),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _Pro.border),
      ),
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _Pro.border)),
        child: Icon(icon, size: 19, color: _Pro.textMain),
      ),
    );
  }

  // ─────────────────────────── STORIES ───────────────────────────
  Widget _buildStories(String currentUserId, Set<String> liveHostIds) {
    if (_loadingStories) {
      return Container(
        color: _Pro.card,
        height: 150,
        alignment: Alignment.center,
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _Pro.primary)),
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
      color: _Pro.card,
      padding: const EdgeInsets.only(top: ThixPolicy.s12, bottom: ThixPolicy.s16),
      child: SizedBox(
        height: 134,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
          itemCount: otherUsersList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
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
    // 🌟 Mise à jour des filtres pour l'algorithme "Pour Vous"
    final filters = {
      'foryou': ('Pour vous', Icons.auto_awesome_outlined),
      'network': ('Abonnements', Icons.people_alt_outlined),
      'recent': ('Récents', Icons.schedule_outlined),
      'popular': ('Tendances', Icons.trending_up_rounded),
    };

    return Container(
      color: _Pro.card,
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
      margin: const EdgeInsets.only(bottom: ThixPolicy.s8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final sel = _feedType == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: ThixPolicy.s8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (sel) return;
                  setState(() => _feedType = e.key);
                  ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _Pro.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? _Pro.ink : _Pro.border),
                  ),
                  child: Row(
                    children: [
                      Icon(e.value.$2, size: 15, color: sel ? Colors.white : _Pro.textSecondary),
                      const SizedBox(width: 6),
                      Text(e.value.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : _Pro.textMain)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────── SUGGESTIONS ───────────────────────────
  Widget _buildSuggestions(Set<String> liveHostIds) {
    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s8),
      padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s16),
      color: _Pro.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            child: Text('Personnes à découvrir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _Pro.textMain)),
          ),
          const SizedBox(height: ThixPolicy.s12),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
              itemBuilder: (c, i) {
                final u = _suggestions[i];
                return Container(
                  width: 132,
                  padding: const EdgeInsets.all(ThixPolicy.s12),
                  decoration: BoxDecoration(
                    color: _Pro.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Pro.border),
                  ),
                  child: Column(
                    children: [
                      RoundAvatar(size: 52, imageUrl: u.avatar, ringWidth: 1.6, isLive: liveHostIds.contains(u.id)),
                      const SizedBox(height: ThixPolicy.s8),
                      Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Pro.textMain)),
                      const SizedBox(height: 2),
                      Text(u.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _Pro.textSecondary)),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: _Pro.ink,
                            side: const BorderSide(color: _Pro.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            await ref.read(networkServiceProvider).sendConnectionRequest(u.id);
                            setState(() => _suggestions.remove(u));
                          },
                          child: const Text('Se connecter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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

  // ─────────────────────────── FEED UTILS ───────────────────────────
  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: ThixPolicy.s8),
        height: 200,
        color: _Pro.card,
      )),
    );
  }

  Widget _buildEmpty() {
    return Container(
      color: _Pro.card,
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _Pro.border)),
            child: const Icon(Icons.feed_outlined, size: 32, color: _Pro.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text('Aucune publication pour ce filtre', style: TextStyle(color: _Pro.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _onRefresh,
            style: OutlinedButton.styleFrom(foregroundColor: _Pro.ink, side: const BorderSide(color: _Pro.border)),
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
      backgroundColor: _Pro.card,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _Pro.border, borderRadius: BorderRadius.circular(4))),
            ListTile(
              leading: const Icon(Icons.link, color: _Pro.ink),
              title: const Text('Copier le lien', style: TextStyle(color: _Pro.textMain, fontWeight: FontWeight.w600)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                try { await ref.read(networkServiceProvider).sharePost(id); } catch (_) {}
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: _Pro.textSecondary),
              title: const Text('Fermer', style: TextStyle(color: _Pro.textMain)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── BOTTOM NAV ───────────────────────────
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
                      border: Border.all(color: _Pro.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navBtn(Icons.home_rounded, 'Accueil', true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                        _navBtn(Icons.explore_outlined, 'Découvrir', false, () => _safePush('/network/discover')),
                        _navBtn(Icons.add_circle_outline_rounded, 'Publier', false, () => showDialog(context: context, builder: (_) => const CreatePostDialog())),
                        // 🌟 "Réseau" a été remplacé par "Messages" pointant vers la bonne route
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 21, color: active ? _Pro.ink : _Pro.textMuted),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: active ? _Pro.ink : _Pro.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK POST ENTRY
// ============================================================================
class _QuickPostEntryCard extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _QuickPostEntryCard({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Pro.card,
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
      child: Row(
        children: [
          RoundAvatar(size: 38, imageUrl: avatarUrl, ringWidth: 0),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                decoration: BoxDecoration(
                  color: _Pro.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _Pro.border),
                ),
                child: const Text('Commencer un post...', style: TextStyle(color: _Pro.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const SizedBox(width: ThixPolicy.s10),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.image_outlined, color: _Pro.textSecondary, size: 22),
            tooltip: 'Ajouter un média',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HUB LIVE
// ============================================================================
class _AutoLiveHub extends StatefulWidget {
  final AsyncValue<List<Map<String, dynamic>>> liveSessionsAsync;
  const _AutoLiveHub({required this.liveSessionsAsync});

  @override
  State<_AutoLiveHub> createState() => _AutoLiveHubState();
}

class _AutoLiveHubState extends State<_AutoLiveHub> {
  bool _hasLiveNow = false;

  @override
  void didUpdateWidget(covariant _AutoLiveHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncExpansion();
  }

  @override
  void initState() {
    super.initState();
    _syncExpansion();
  }

  void _syncExpansion() {
    final count = widget.liveSessionsAsync.value?.length ?? 0;
    final hasLive = count > 0;
    if (hasLive != _hasLiveNow) {
      setState(() => _hasLiveNow = hasLive);
    }
  }

  void _joinLive([Map<String, dynamic>? session]) {
    if (session == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LivePrepScreen()));
    } else {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => LiveViewerScreen(
            liveId: session['id']?.toString() ?? '',
            channelName: session['channel_name']?.toString() ?? '',
            hostName: session['host_name']?.toString() ?? 'Hôte THIX',
            hostAvatarUrl: session['host_avatar']?.toString(), 
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.liveSessionsAsync.value ?? const <Map<String, dynamic>>[];
    final count = sessions.length;

    return Container(
      decoration: BoxDecoration(
        color: _Pro.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Pro.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _hasLiveNow ? _Pro.live : _Pro.border)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.sensors_rounded, color: _Pro.live, size: 18),
                ),
                const SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Directs & Espaces', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _Pro.textMain)),
                          if (count > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: _Pro.live, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        count > 0 ? '$count en cours' : 'Aucun direct actif',
                        style: const TextStyle(fontSize: 11.5, color: _Pro.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _joinLive(),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Lancer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Pro.ink,
                    side: const BorderSide(color: _Pro.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(76, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            child: !_hasLiveNow
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
                    child: SizedBox(
                      height: 122,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
                        itemBuilder: (context, i) {
                          final s = sessions[i];
                          final type = (s['session_type'] as String?) ?? 'video';
                          return _LiveCard(
                            title: (s['title'] as String?) ?? 'Direct sans titre',
                            host: (s['host_name'] as String?) ?? 'THIX',
                            isVideo: type == 'video',
                            viewers: (s['viewer_count'] as int?) ?? 0,
                            onTap: () => _joinLive(s),
                          );
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

class _LiveCard extends StatelessWidget {
  final String title;
  final String host;
  final bool isVideo;
  final int viewers;
  final VoidCallback onTap;

  const _LiveCard({required this.title, required this.host, required this.isVideo, required this.viewers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _Pro.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _Pro.live, borderRadius: BorderRadius.circular(4)),
                  child: const Text('EN DIRECT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, color: Colors.white70, size: 12),
                    const SizedBox(width: 3),
                    Text(viewers.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Icon(isVideo ? Icons.videocam_outlined : Icons.mic_none_rounded, color: Colors.white38, size: 18),
            const SizedBox(height: 6),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 3),
            Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w500)),
          ],
        ),
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
          color: _Pro.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isLive ? _Pro.live : _Pro.border, width: isLive ? 1.4 : 1),
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
                        placeholder: (_, __) => Container(color: _Pro.surface),
                        errorWidget: (_, __, ___) => Container(color: _Pro.surface),
                      )
                    : Container(color: _Pro.surface),
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
              child: RoundAvatar(size: 28, imageUrl: avatarUrl, ringColor: hasStory || isMe ? _Pro.primary : Colors.transparent, ringWidth: 1.8, isLive: isLive),
            ),
            if (isMe)
              Positioned(
                top: 22, left: 22,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _Pro.primary, border: Border.all(color: Colors.white, width: 1.8)),
                    child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
