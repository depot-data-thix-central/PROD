// lib/presentation/thix_info/thix_info_home.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/news_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/podcast_player_provider.dart';
import '../../services/thix_downloader.dart';
import '../../services/admin_rbac_service.dart';
import '../../models/news_article.dart';

// ============================================================================
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE (GLASSMORPHISM)
// ============================================================================
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// 🎚️ ÉGALISEUR ANIMÉ (indicateur "en cours de lecture")
// ============================================================================
class _EqualizerBars extends StatefulWidget {
  final double size;
  final Color color;
  const _EqualizerBars({this.size = 14, this.color = Colors.white});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * pi;
        double h(int i) =>
            widget.size * (0.30 + 0.70 * ((sin(t + i * 1.35) + 1) / 2));
        return SizedBox(
          height: widget.size,
          width: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [0, 1, 2]
                .map((i) => Container(
                      width: 3,
                      height: h(i),
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

String _fmtDur(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

// ============================================================================
// DÉFINITION DES ESPACES
// ============================================================================
class _SpaceDef {
  final String slug;
  final String name;
  final String dbCategory;
  final IconData icon;
  final Color color;
  final String tagline;

  const _SpaceDef({
    required this.slug,
    required this.name,
    required this.dbCategory,
    required this.icon,
    required this.color,
    required this.tagline,
  });
}

// ============================================================================
// PAGE PRINCIPALE : THIX INFO
// ============================================================================
class ThixInfoHome extends ConsumerStatefulWidget {
  const ThixInfoHome({super.key});

  @override
  ConsumerState<ThixInfoHome> createState() => _ThixInfoHomeState();
}

class _ThixInfoHomeState extends ConsumerState<ThixInfoHome> {
  String _cat = 'featured';

  final PageController _pageCtrl = PageController(viewportFraction: 0.92);
  final ScrollController _breakingCtrl = ScrollController();
  final ScrollController _mainScrollCtrl = ScrollController();

  Timer? _timer;
  Timer? _breakingTimer;
  int _page = 0;

  bool _isAdmin = false;
  bool _adminChecked = false;

  // 🚫 Catégories "espaces" exclues du fil d'actualité
  static const Set<String> _spaceCategories = {
    'Magazine',
    'Podcast',
    'Découverte'
  };

  static const List<_SpaceDef> _spaces = [
    _SpaceDef(
      slug: 'magazine',
      name: 'Magazine',
      dbCategory: 'Magazine',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFFD4AF37),
      tagline: 'Lectures pro & longs formats',
    ),
    _SpaceDef(
      slug: 'podcast',
      name: 'Podcasts',
      dbCategory: 'Podcast',
      icon: Icons.headphones_rounded,
      color: Color(0xFF6366F1),
      tagline: 'Audio, Vidéo & conversations',
    ),
    _SpaceDef(
      slug: 'decouverte',
      name: 'Découverte',
      dbCategory: 'Découverte',
      icon: Icons.explore_rounded,
      color: Color(0xFF10B981),
      tagline: 'Explorer le monde',
    ),
  ];

  final List<Map<String, String>> cats = const [
    {'slug': 'featured', 'name': 'À la une'},
    {'slug': 'politique', 'name': 'Politique'},
    {'slug': 'economie', 'name': 'Économie'},
    {'slug': 'societe', 'name': 'Société'},
    {'slug': 'tech', 'name': 'Tech'},
    {'slug': 'sport', 'name': 'Sport'},
    {'slug': 'culture', 'name': 'Culture'},
    {'slug': 'international', 'name': 'International'},
  ];

  final List<String> _trendingTags = [
    '#RDC',
    '#Élections2026',
    '#TechAfrique',
    '#Économie',
    '#THIXExclusif'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsProvider).fetchArticles(category: 'all');
      ref.read(newsProvider).loadSavedArticles();
      _startAuto();
      _startBreakingScroll();
      _resolveIsAdmin();
    });
  }

  // ═══════════════════ DÉTECTION ADMIN ═══════════════════
  Future<void> _resolveIsAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _adminChecked = true);
      return;
    }
    bool admin = false;
    try {
      if (user.appMetadata?['role'] == 'admin' ||
          user.userMetadata?['role'] == 'admin' ||
          user.userMetadata?['is_admin'] == true) {
        admin = true;
      }
      if (!admin) {
        final role = await AdminRbacService().fetchMyRole();
        if (AdminRbacService.canAccess(role: role, minLevel: 5)) admin = true;
      }
      if (!admin) {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        if (res?['role'] == 'admin') admin = true;
      }
      if (!admin) {
        admin = user.email?.endsWith('@thix.info') ?? false;
      }
    } catch (e) {
      debugPrint('[ThixInfo] ⚠️ admin check: $e');
    }
    if (mounted) {
      setState(() {
        _isAdmin = admin;
        _adminChecked = true;
      });
    }
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final list = ref
          .read(newsProvider)
          .articles
          .where((e) => e.isFeatured)
          .toList();
      if (list.isEmpty || !_pageCtrl.hasClients) return;
      _page = (_page + 1) % list.length;
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
    });
  }

  void _startBreakingScroll() {
    _breakingTimer?.cancel();
    _breakingTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_breakingCtrl.hasClients) return;
      final maxExtent = _breakingCtrl.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      double next = _breakingCtrl.offset + 1.0;
      if (next >= maxExtent) next = 0;
      _breakingCtrl.jumpTo(next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breakingTimer?.cancel();
    _pageCtrl.dispose();
    _breakingCtrl.dispose();
    _mainScrollCtrl.dispose();
    super.dispose();
  }

  List<NewsArticle> _spaceItems(String dbCategory) =>
      ref.watch(newsProvider).articles
          .where((a) => a.category == dbCategory)
          .toList();

  String _formatTimeAgo(DateTime publishedAt) {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);

    if (diff.inSeconds < 60) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} j';
    } else if (diff.inDays < 30) {
      return 'Il y a ${(diff.inDays / 7).floor()} sem';
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(publishedAt);
    }
  }

  void _openFullPodcastPlayer() {
    final article = ref.read(podcastPlayerProvider).article;
    if (article == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PodcastPlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = ref.watch(newsProvider);
    final featured = prov.articles.where((e) => e.isFeatured).toList();
    final breaking = prov.articles.where((e) => e.isBreaking).toList();

    // ✅ FIL D'ACTUALITÉ : on exclut Magazine / Podcast / Découverte
    final recents = prov.articles
        .where((a) => !_spaceCategories.contains(a.category))
        .toList();

    // 🎧 État du lecteur global (sélectifs → rebuilds minimaux)
    final playerArticle =
        ref.watch(podcastPlayerProvider.select((s) => s.article));

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW ───
          Positioned(
            top: -100,
            left: -100,
            child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThixPolicy.primary.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                          color: ThixPolicy.primary.withOpacity(0.2),
                          blurRadius: 100,
                          spreadRadius: 100)
                    ])),
          ),

          RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.1),
            onRefresh: () async =>
                ref.read(newsProvider).fetchArticles(category: 'all'),
            child: CustomScrollView(
              controller: _mainScrollCtrl,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildAppBar(),

                if (breaking.isNotEmpty)
                  SliverToBoxAdapter(child: _buildFlashTicker(breaking)),

                const SliverToBoxAdapter(
                    child: SizedBox(height: ThixPolicy.s20)),

                SliverToBoxAdapter(child: _buildChannelsSection()),

                const SliverToBoxAdapter(
                    child: SizedBox(height: ThixPolicy.s24)),

                SliverPersistentHeader(
                    pinned: true,
                    delegate:
                        _CategoryHeaderDelegate(child: _buildCategories())),

                const SliverToBoxAdapter(
                    child: SizedBox(height: ThixPolicy.s20)),

                SliverToBoxAdapter(
                    child: featured.isNotEmpty
                        ? _buildHeroSection(featured)
                        : _buildLoadingHero()),

                SliverToBoxAdapter(
                    child: _buildMagazineSection(_spaceItems('Magazine'))),
                SliverToBoxAdapter(
                    child: _buildPodcastSection(_spaceItems('Podcast'))),
                SliverToBoxAdapter(
                    child: _buildDecouverteSection(_spaceItems('Découverte'))),

                const SliverToBoxAdapter(
                    child: SizedBox(height: ThixPolicy.s32)),
                SliverToBoxAdapter(child: _buildTrendingSection()),

                const SliverToBoxAdapter(
                    child: SizedBox(height: ThixPolicy.s24)),

                SliverToBoxAdapter(
                    child: _buildSectionTitle(
                        "Le fil de l'info", Icons.timeline_rounded)),
                const SliverToBoxAdapter(
                    child: SizedBox(height: ThixPolicy.s16)),
                _buildNewsFeed(recents, prov),

                // Espace pour le mini-player
                const SliverToBoxAdapter(
                    child: SizedBox(height: 100)),
              ],
            ),
          ),

          // 🎧 MINI-PLAYER PODCAST EN BAS (animation d'apparition)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              reverseDuration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: playerArticle != null
                  ? KeyedSubtree(
                      key: const ValueKey('miniplayer'),
                      child: _buildMiniPlayer(),
                    )
                  : const SizedBox.shrink(key: ValueKey('noplayer')),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APP BAR PREMIUM
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: ThixPolicy.inkDeep.withOpacity(0.85),
      elevation: 0,
      pinned: true,
      centerTitle: true,
      leading: IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () => context.push('/thix-info/search')),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ThixPolicy.s8, vertical: ThixPolicy.s4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
            child: Text('THIX',
                style: ThixPolicy.h3Style.copyWith(
                    color: ThixPolicy.inkDeep,
                    fontWeight: ThixPolicy.bold,
                    letterSpacing: 1.0)),
          ),
          const SizedBox(width: ThixPolicy.s6),
          Text('INFO',
              style: ThixPolicy.h3Style.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.regular,
                  letterSpacing: 1.5)),
        ],
      ),
      actions: [
        if (_isAdmin)
          IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 16),
              ),
              onPressed: () => context.push('/thix-info/admin')),
        IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => context.push('/thix-info/downloads')),
        IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
            onPressed: () {}),
      ],
      flexibleSpace: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent))),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FLASH INFO
  // ─────────────────────────────────────────────────────────────
  Widget _buildFlashTicker(List<NewsArticle> list) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ThixPolicy.s16, vertical: ThixPolicy.s8),
      child: GlassBox(
        padding: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s12, vertical: ThixPolicy.s10),
        borderRadius: ThixPolicy.rSm,
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: ThixPolicy.danger.withOpacity(0.6),
                          blurRadius: 8)
                    ])),
            const SizedBox(width: ThixPolicy.s12),
            Text('FLASH',
                style: ThixPolicy.microStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                    letterSpacing: 1.0)),
            const SizedBox(width: ThixPolicy.s12),
            Container(width: 1, height: 12, color: Colors.white24),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: SizedBox(
                height: 18,
                child: ListView.builder(
                  controller: _breakingCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length * 50,
                  itemBuilder: (_, i) {
                    final a = list[i % list.length];
                    return Padding(
                      padding: const EdgeInsets.only(right: ThixPolicy.s40),
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/thix-info/article/${a.id}'),
                        child: Text(a.title,
                            style: ThixPolicy.bodySmallStyle.copyWith(
                                color: Colors.white70,
                                fontWeight: ThixPolicy.semiBold)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHAÎNES & ÉDITEURS
  // ─────────────────────────────────────────────────────────────
  Widget _buildChannelsSection() {
    final channels = [
      {
        'name': 'THIX TV',
        'icon': Icons.tv_rounded,
        'color': ThixPolicy.domainMedia,
        'route': ''
      },
      {
        'name': 'THIX Radio',
        'icon': Icons.radio_rounded,
        'color': ThixPolicy.domainNetwork,
        'route': ''
      },
      {
        'name': 'Magazine',
        'icon': Icons.auto_stories_rounded,
        'color': const Color(0xFFD4AF37),
        'route': '/thix-info/space/magazine'
      },
      {
        'name': 'Podcasts',
        'icon': Icons.headphones_rounded,
        'color': const Color(0xFF6366F1),
        'route': '/thix-info/space/podcast'
      },
      {
        'name': 'Découverte',
        'icon': Icons.explore_rounded,
        'color': const Color(0xFF10B981),
        'route': '/thix-info/space/decouverte'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            'Chaînes & Éditeurs', Icons.broadcast_on_personal_rounded),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
            itemBuilder: (_, i) {
              final c = channels[i];
              final route = c['route'] as String;
              return GestureDetector(
                onTap: route.isEmpty
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        context.push(route);
                      },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ThixPolicy.s16),
                      decoration: BoxDecoration(
                        color: (c['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        border: Border.all(
                            color: (c['color'] as Color).withOpacity(0.3),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: (c['color'] as Color).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(c['icon'] as IconData,
                          color: c['color'] as Color, size: 28),
                    ),
                    const SizedBox(height: ThixPolicy.s8),
                    Text(c['name'] as String,
                        style: ThixPolicy.captionStyle.copyWith(
                            color: Colors.white70,
                            fontWeight: ThixPolicy.bold)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CATÉGORIES STICKY
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: ThixPolicy.inkDeep.withOpacity(0.7),
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: ThixPolicy.s16, vertical: ThixPolicy.s10),
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
            itemBuilder: (_, i) {
              final c = cats[i];
              final sel = _cat == c['slug'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _cat = c['slug']!);
                  ref.read(newsProvider).fetchArticles(
                      category: c['slug'] == 'featured' ? 'all' : c['slug']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                    border: Border.all(
                        color: sel
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(
                    c['name']!,
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold,
                      color: sel ? ThixPolicy.inkDeep : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO CARROUSEL
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroSection(List<NewsArticle> list) {
    return Column(
      children: [
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (v) => setState(() => _page = v),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              return GestureDetector(
                onTap: () => context.push('/thix-info/article/${a.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                    image: a.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(a.imageUrl!), fit: BoxFit.cover)
                        : null,
                    color: Colors.white.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                          gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.9),
                                Colors.black.withOpacity(0.2),
                                Colors.transparent
                              ]),
                        ),
                      ),
                      Positioned(
                        bottom: ThixPolicy.s16,
                        left: ThixPolicy.s16,
                        right: ThixPolicy.s16,
                        child: GlassBox(
                          padding: ThixPolicy.cardPadding,
                          borderRadius: ThixPolicy.rMd,
                          color: Colors.black.withOpacity(0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: ThixPolicy.s8,
                                    vertical: ThixPolicy.s4),
                                decoration: BoxDecoration(
                                    color: ThixPolicy.primary,
                                    borderRadius:
                                        BorderRadius.circular(ThixPolicy.rXs)),
                                child: Text(a.category.toUpperCase(),
                                    style: ThixPolicy.microStyle.copyWith(
                                        color: Colors.white,
                                        fontWeight: ThixPolicy.bold,
                                        letterSpacing: 1.0)),
                              ),
                              const SizedBox(height: ThixPolicy.s12),
                              Text(a.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: ThixPolicy.h2Style
                                      .copyWith(color: Colors.white)),
                              const SizedBox(height: ThixPolicy.s12),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: ThixPolicy.s6),
                                  Text(_formatTimeAgo(a.publishedAt),
                                      style: ThixPolicy.labelStyle.copyWith(
                                          color: Colors.white70,
                                          fontWeight: ThixPolicy.semiBold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ThixPolicy.s16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(list.length, (index) {
            final isActive = _page == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ESPACES : MAGAZINE / PODCASTS / DÉCOUVERTE
  // ═══════════════════════════════════════════════════════════════

  Widget _spaceHeader(_SpaceDef s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ThixPolicy.s8),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: s.color.withOpacity(0.3), width: 1),
            ),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: ThixPolicy.h2Style.copyWith(
                        color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(s.tagline,
                    style: ThixPolicy.microStyle.copyWith(
                        color: Colors.white54, letterSpacing: 0.3)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/thix-info/space/${s.slug}'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s12, vertical: ThixPolicy.s6),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                border: Border.all(color: s.color.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tout voir',
                      style: ThixPolicy.labelStyle.copyWith(
                          color: s.color, fontWeight: ThixPolicy.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 10, color: s.color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAGAZINE ───
  Widget _buildMagazineSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ThixPolicy.s40),
        _spaceHeader(_spaces[0]),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 340,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
            itemBuilder: (_, i) => _magazineCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _magazineCard(NewsArticle a) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/magazine/${a.id}'),
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    a.imageUrl != null
                        ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.white.withOpacity(0.08)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ]),
                      ),
                    ),
                    Positioned(
                      top: ThixPolicy.s12,
                      left: ThixPolicy.s12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: const Text('THIX MAG',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                      ),
                    ),
                    Positioned(
                      bottom: ThixPolicy.s12,
                      right: ThixPolicy.s12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_stories_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${(a.content.length / 1500).ceil()} min',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ThixPolicy.s12),
            Text(a.category.toUpperCase(),
                style: ThixPolicy.microStyle.copyWith(
                    color: const Color(0xFFD4AF37),
                    fontWeight: ThixPolicy.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: ThixPolicy.s4),
            Text(a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.titleStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                    height: 1.2)),
            const SizedBox(height: ThixPolicy.s6),
            Text(a.summary ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.bodySmallStyle.copyWith(
                    color: Colors.white60,
                    height: 1.4,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  // ─── PODCASTS (AUDIO & VIDÉO) — LECTURE RÉELLE ───
  Widget _buildPodcastSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ThixPolicy.s40),
        _spaceHeader(_spaces[1]),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 250,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
            itemBuilder: (_, i) => _podcastCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _podcastCard(NewsArticle a) {
    final dl = ref.watch(downloadsProvider);
    final downloading = dl.isDownloading(a.id);
    final downloaded = dl.isDownloaded(a.id);
    final currentItem = dl.findById(a.id);

    final isCurrent =
        ref.watch(podcastPlayerProvider.select((s) => s.article?.id == a.id));
    final isPlaying = isCurrent &&
        ref.watch(podcastPlayerProvider.select((s) => s.isPlaying));
    final isVideo = isVideoPodcast(a);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(podcastPlayerProvider.notifier).playArticle(a);
      },
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✨ Glow animé autour de l'épisode en cours
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF6366F1)
                        : Colors.transparent,
                    width: 2),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 2)
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                child: SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      a.imageUrl != null
                          ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(0.6),
                                    const Color(0xFF4338CA).withOpacity(0.8),
                                  ],
                                ),
                              ),
                              child: const Center(
                                  child: Icon(Icons.graphic_eq_rounded,
                                      size: 40, color: Colors.white70)),
                            ),

                      // 🎥 BADGE AUDIO / VIDÉO
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVideo
                                ? Colors.redAccent.withOpacity(0.9)
                                : const Color(0xFF6366F1).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.headphones_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVideo ? 'VIDÉO' : 'AUDIO',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Overlay Play/Pause
                      Center(
                        child: GlassBox(
                          padding: const EdgeInsets.all(ThixPolicy.s10),
                          borderRadius: ThixPolicy.rFull,
                          blur: 20,
                          color: isCurrent && isPlaying
                              ? ThixPolicy.primary.withOpacity(0.8)
                              : Colors.white.withOpacity(0.15),
                          child: Icon(
                              isCurrent && isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24),
                        ),
                      ),
                      Positioned(
                        bottom: ThixPolicy.s8,
                        right: ThixPolicy.s8,
                        child: _downloadButton(
                            a, downloading, downloaded, currentItem),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: ThixPolicy.s12),
            Text(a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: ThixPolicy.bold, color: Colors.white70)),
            // 🎚️ Indicateur "En cours"
            if (isCurrent) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  isPlaying
                      ? const _EqualizerBars(size: 12, color: Color(0xFF6366F1))
                      : const Icon(Icons.pause_rounded,
                          size: 12, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(isPlaying ? 'En cours' : 'En pause',
                      style: ThixPolicy.microStyle.copyWith(
                          color: const Color(0xFF6366F1),
                          fontWeight: ThixPolicy.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloadButton(NewsArticle a, bool downloading, bool downloaded,
      DownloadItem? currentItem) {
    if (downloading && currentItem != null) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: currentItem.progress,
                strokeWidth: 2.5,
                backgroundColor: Colors.black45,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Text('${(currentItem.progress * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }
    if (downloaded) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            color: Color(0xFF10B981), size: 18),
      );
    }
    return GestureDetector(
      onTap: () => ref.read(downloadsProvider).downloadArticle(a),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.download_rounded,
            color: Colors.black87, size: 18),
      ),
    );
  }

  // ─── DÉCOUVERTE ───
  Widget _buildDecouverteSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ThixPolicy.s40),
        _spaceHeader(_spaces[2]),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
            itemBuilder: (_, i) => _decouverteCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _decouverteCard(NewsArticle a) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${a.id}'),
      child: SizedBox(
        width: 170,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              a.imageUrl != null
                  ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.4),
                              const Color(0xFF065F46).withOpacity(0.8),
                            ]),
                      ),
                      child: const Center(
                          child: Icon(Icons.explore_rounded,
                              size: 40, color: Colors.white54)),
                    ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.transparent
                      ]),
                ),
              ),
              Positioned(
                bottom: ThixPolicy.s12,
                left: ThixPolicy.s12,
                right: ThixPolicy.s12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(height: ThixPolicy.s6),
                    Text(a.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontWeight: ThixPolicy.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUJETS TENDANCE
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sujets Tendance', Icons.local_fire_department_rounded),
        const SizedBox(height: ThixPolicy.s12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: _trendingTags.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Center(
                  child: Text(
                    _trendingTags[index],
                    style: ThixPolicy.labelStyle.copyWith(
                      color: Colors.white70,
                      fontWeight: ThixPolicy.semiBold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FIL D'ACTUALITÉ (sans Magazine / Podcast / Découverte)
  // ─────────────────────────────────────────────────────────────
  Widget _buildNewsFeed(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
            child: Text('Aucune actualité publiée',
                style:
                    ThixPolicy.bodyStyle.copyWith(color: Colors.white54))),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final a = list[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(
                ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
            child: GestureDetector(
              onTap: () => context.push('/thix-info/article/${a.id}'),
              child: GlassBox(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                borderRadius: ThixPolicy.rMd,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.category.toUpperCase(),
                              style: ThixPolicy.microStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  color: ThixPolicy.gold,
                                  letterSpacing: 1.0)),
                          const SizedBox(height: ThixPolicy.s8),
                          Text(a.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: ThixPolicy.titleStyle
                                      .copyWith(color: Colors.white)),
                          const SizedBox(height: ThixPolicy.s12),
                          Row(
                            children: [
                              const Icon(Icons.remove_red_eye_rounded,
                                  size: 14, color: Colors.white54),
                              const SizedBox(width: ThixPolicy.s6),
                              Text('${a.viewsCount}',
                                  style: ThixPolicy.labelStyle
                                      .copyWith(color: Colors.white54)),
                              const Spacer(),
                              const Icon(Icons.schedule_rounded,
                                  size: 14, color: Colors.white54),
                              const SizedBox(width: ThixPolicy.s4),
                              Text(_formatTimeAgo(a.publishedAt),
                                  style: ThixPolicy.labelStyle
                                      .copyWith(color: Colors.white54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: a.imageUrl != null
                            ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: list.length,
      ),
    );
  }

  Widget _buildSectionTitle(String t, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: ThixPolicy.s10),
          Text(t,
              style: ThixPolicy.h2Style.copyWith(
                  color: Colors.white, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildLoadingHero() => Container(
      margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      height: 420,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
      child: const Center(
          child: CircularProgressIndicator(color: Colors.white)));

  // ═══════════════════════════════════════════════════════════════
  // 🎧 MINI-PLAYER (lié au lecteur global)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMiniPlayer() {
    final player = ref.watch(podcastPlayerProvider);
    final a = player.article;
    if (a == null) return const SizedBox.shrink();
    final isVideo = isVideoPodcast(a);

    return GestureDetector(
      onTap: _openFullPodcastPlayer,
      child: GlassBox(
        padding: const EdgeInsets.all(ThixPolicy.s8),
        borderRadius: ThixPolicy.rLg,
        color: const Color(0xFF1E1E2C).withOpacity(0.95),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    a.imageUrl != null
                        ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.white12,
                            child: const Icon(Icons.headphones,
                                color: Colors.white54)),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: player.isPlaying
                            ? const _EqualizerBars(size: 14)
                            : Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.graphic_eq_rounded,
                                size: 14,
                                color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isVideo ? 'Vidéo' : 'Audio'} • ${player.isPlaying ? 'En cours' : 'En pause'}',
                    style:
                        ThixPolicy.microStyle.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: player.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFF6366F1)),
                    )
                  : Icon(
                      player.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: const Color(0xFF6366F1),
                      size: 36,
                    ),
              onPressed: () =>
                  ref.read(podcastPlayerProvider.notifier).toggle(),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white54, size: 20),
              onPressed: () => ref.read(podcastPlayerProvider.notifier).stop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  LECTEUR COMPLET (BOTTOM SHEET) — ConsumerWidget : se met à jour tout seul
// ============================================================================
class _PodcastPlayerSheet extends ConsumerWidget {
  const _PodcastPlayerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(podcastPlayerProvider);
    final notifier = ref.read(podcastPlayerProvider.notifier);
    final a = player.article;
    if (a == null) return const SizedBox.shrink();

    final isVideo = isVideoPodcast(a);
    final dur = player.duration;
    final pos = player.position;
    final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: ThixPolicy.inkDeep.withOpacity(0.95),
            border:
                Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 30),

              // ═══ COVER / LECTEUR VIDÉO ═══
              if (isVideo)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                      image: a.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(a.imageUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.4),
                                  BlendMode.darken),
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () => notifier.toggle(),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: player.isLoading
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5),
                                    )
                                  : Icon(
                                      player.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        if (player.isPlaying)
                          Positioned(
                            bottom: 10,
                            left: 12,
                            child: Row(
                              children: [
                                const _EqualizerBars(size: 14),
                                const SizedBox(width: 6),
                                Text('PISTE AUDIO EN DIRECT',
                                    style: ThixPolicy.microStyle.copyWith(
                                        color: Colors.white70,
                                        letterSpacing: 1.2)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                    image: a.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(a.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.white10,
                  ),
                  child: Stack(
                    children: [
                      if (a.imageUrl == null)
                        const Center(
                            child: Icon(Icons.graphic_eq_rounded,
                                size: 80, color: Colors.white54)),
                      if (player.isLoading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
                      if (player.isPlaying)
                        Positioned(
                          bottom: 10,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle),
                            child: const _EqualizerBars(size: 14),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Titre
              Text(
                a.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.h2Style.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.headphones_rounded,
                      size: 14,
                      color: const Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    isVideo ? 'THIX Podcast Vidéo' : 'THIX Podcast Audio',
                    style: ThixPolicy.bodyStyle
                        .copyWith(color: const Color(0xFF6366F1)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Progression RÉELLE
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF6366F1),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: pos.inSeconds.toDouble().clamp(0.0, maxSec),
                      max: maxSec,
                      onChanged: (val) => notifier
                          .seek(Duration(seconds: val.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtDur(pos),
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white54)),
                        Text(_fmtDur(dur),
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white54)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded,
                        color: Colors.white70, size: 32),
                    onPressed: () => notifier.skipBy(-10),
                  ),
                  GestureDetector(
                    onTap: () => notifier.toggle(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                      child: player.isLoading
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            )
                          : Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_30_rounded,
                        color: Colors.white70, size: 32),
                    onPressed: () => notifier.skipBy(30),
                  ),
                ],
              ),

              if (player.error != null) ...[
                const SizedBox(height: 12),
                Text(player.error!,
                    textAlign: TextAlign.center,
                    style: ThixPolicy.microStyle
                        .copyWith(color: Colors.redAccent)),
              ],

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded,
                      size: 12, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text('Lecture maintenue hors application',
                      style: ThixPolicy.microStyle
                          .copyWith(color: Colors.white38)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _CategoryHeaderDelegate({required this.child});
  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;
  @override
  bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) => false;
}
