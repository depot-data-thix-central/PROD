// lib/presentation/thix_info/thix_info_home.dart
import 'dart:async';
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

  // 🎧 ÉTAT DU LECTEUR PODCAST LOCAL (Audio & Vidéo)
  NewsArticle? _activePodcast;
  bool _isPlaying = false;
  double _podcastProgress = 0.0;
  Timer? _podcastMockTimer;

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
    _podcastMockTimer?.cancel();
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

  // 🎥 DÉTERMINER SI C'EST UNE VIDÉO OU UN AUDIO
  // (Simulation basée sur le titre/ID pour l'UI, à remplacer par votre logique DB)
  bool _isVideoPodcast(NewsArticle a) {
    return a.title.toLowerCase().contains('vidéo') ||
        a.title.toLowerCase().contains('interview') ||
        (a.id.hashCode % 2 == 0); // Alterne pour la démo
  }

  // ═══════════════════ LOGIQUE LECTEUR PODCAST ═══════════════════
  void _togglePodcast(NewsArticle article) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_activePodcast?.id == article.id) {
        _isPlaying = !_isPlaying;
      } else {
        _activePodcast = article;
        _isPlaying = true;
        _podcastProgress = 0.0;
      }
    });

    if (_isPlaying) {
      _startPodcastMockTimer();
    } else {
      _podcastMockTimer?.cancel();
    }
  }

  void _startPodcastMockTimer() {
    _podcastMockTimer?.cancel();
    _podcastMockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_isPlaying) return;
      setState(() {
        _podcastProgress += 0.005;
        if (_podcastProgress >= 1.0) {
          _podcastProgress = 0.0;
          _isPlaying = false;
          _podcastMockTimer?.cancel();
        }
      });
    });
  }

  void _openFullPodcastPlayer() {
    if (_activePodcast == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPodcastBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = ref.watch(newsProvider);
    final featured = prov.articles.where((e) => e.isFeatured).toList();
    final breaking = prov.articles.where((e) => e.isBreaking).toList();
    final recents = prov.articles;

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

          // 🎧 MINI-PLAYER PODCAST EN BAS
          if (_activePodcast != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildMiniPlayer(),
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
                    color: Colors.white60, height: 1.4, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  // ─── PODCASTS (AUDIO & VIDÉO) ───
  Widget _buildPodcastSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ThixPolicy.s40),
        _spaceHeader(_spaces[1]),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 230,
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
    final isCurrent = _activePodcast?.id == a.id;
    final isVideo = _isVideoPodcast(a);

    return GestureDetector(
      onTap: () => _togglePodcast(a),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVideo ? Colors.redAccent.withOpacity(0.9) : const Color(0xFF6366F1).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVideo ? Icons.videocam_rounded : Icons.headphones_rounded,
                              size: 10, color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVideo ? 'VIDÉO' : 'AUDIO',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
                        color: isCurrent && _isPlaying
                            ? ThixPolicy.primary.withOpacity(0.8)
                            : Colors.white.withOpacity(0.15),
                        child: Icon(
                            isCurrent && _isPlaying
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
            const SizedBox(height: ThixPolicy.s12),
            Text(a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: ThixPolicy.bold, color: Colors.white70)),
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
  // FIL D'ACTUALITÉ
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
  // 🎧 LECTEUR LOCAL (MINI-PLAYER & BOTTOM SHEET) - ADAPTATIF AUDIO/VIDÉO
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMiniPlayer() {
    if (_activePodcast == null) return const SizedBox.shrink();
    final isVideo = _isVideoPodcast(_activePodcast!);
    
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
                    _activePodcast!.imageUrl != null
                        ? Image.network(_activePodcast!.imageUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.white12, child: const Icon(Icons.headphones, color: Colors.white54)),
                    // Petite icône overlay pour le mini-player
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(isVideo ? Icons.videocam_rounded : Icons.graphic_eq_rounded, size: 14, color: Colors.white),
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
                    _activePodcast!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVideo ? 'Vidéo • En cours' : 'Audio • En cours',
                    style: ThixPolicy.microStyle.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: const Color(0xFF6366F1),
                size: 36,
              ),
              onPressed: () => _togglePodcast(_activePodcast!),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              onPressed: () {
                _podcastMockTimer?.cancel();
                setState(() {
                  _activePodcast = null;
                  _isPlaying = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastBottomSheet() {
    final isVideo = _isVideoPodcast(_activePodcast!);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ThixPolicy.inkDeep.withOpacity(0.95),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
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
                // Mode Vidéo (Format 16:9)
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
                      image: _activePodcast?.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_activePodcast!.imageUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                            )
                          : null,
                    ),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _togglePodcast(_activePodcast!),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Mode Audio (Format Carré)
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
                    image: _activePodcast?.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_activePodcast!.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.white10,
                  ),
                  child: _activePodcast?.imageUrl == null
                      ? const Icon(Icons.graphic_eq_rounded, size: 80, color: Colors.white54)
                      : null,
                ),

              const SizedBox(height: 30),
              
              // Titre
              Text(
                _activePodcast?.title ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.h2Style.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isVideo ? Icons.videocam_rounded : Icons.headphones_rounded, size: 14, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    isVideo ? 'THIX Podcast Vidéo' : 'THIX Podcast Audio',
                    style: ThixPolicy.bodyStyle.copyWith(color: const Color(0xFF6366F1)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              // Progress
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF6366F1),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _podcastProgress.clamp(0.0, 1.0),
                      onChanged: (val) {
                        setState(() => _podcastProgress = val);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(_podcastProgress * 45).toInt()}:00',
                          style: ThixPolicy.microStyle.copyWith(color: Colors.white54),
                        ),
                        Text(
                          '45:00',
                          style: ThixPolicy.microStyle.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 32),
                    onPressed: () {},
                  ),
                  GestureDetector(
                    onTap: () => _togglePodcast(_activePodcast!),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_30_rounded, color: Colors.white70, size: 32),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
