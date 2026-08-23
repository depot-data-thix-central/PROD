// lib/presentation/thix_info/thix_info_home.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/news_provider.dart';
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

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
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
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
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
  int _navIndex = 0;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsProvider).fetchArticles(category: 'all');
      ref.read(newsProvider).loadSavedArticles();
      _startAuto();
      _startBreakingScroll();
    });
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final list = ref.read(newsProvider).articles.where((e) => e.isFeatured).toList();
      if (list.isEmpty || !_pageCtrl.hasClients) return;
      _page = (_page + 1) % list.length;
      _pageCtrl.animateToPage(_page, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
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

  @override
  Widget build(BuildContext context) {
    final prov = ref.watch(newsProvider);
    final featured = prov.articles.where((e) => e.isFeatured).toList();
    final breaking = prov.articles.where((e) => e.isBreaking).toList();
    final recents = prov.articles;
    
    // Simulation du tri des espaces
    final podcasts = prov.articles.take(4).toList(); 
    final documentaires = prov.articles.skip(2).take(3).toList();

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep, // Utilisation du fond premium de la charte
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW (Effet de lumière en fond) ───
          Positioned(
            top: -100, left: -100,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary.withOpacity(0.15),
              boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.2), blurRadius: 100, spreadRadius: 100)])),
          ),

          RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.1),
            onRefresh: () async => ref.read(newsProvider).fetchArticles(category: 'all'),
            child: CustomScrollView(
              controller: _mainScrollCtrl,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildAppBar(),
                
                // FLASH INFO EN TEMPS RÉEL (GLASSMORPHISM)
                if (breaking.isNotEmpty) SliverToBoxAdapter(child: _buildFlashTicker(breaking)),
                
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),

                // ESPACE CHAÎNES & ÉDITEURS (Avec les couleurs de Domaines THIX)
                SliverToBoxAdapter(child: _buildChannelsSection()),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),

                // CATÉGORIES STICKY
                SliverPersistentHeader(pinned: true, delegate: _CategoryHeaderDelegate(child: _buildCategories())),
                
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),

                // HERO : À LA UNE
                SliverToBoxAdapter(child: featured.isNotEmpty ? _buildHeroCarousel(featured) : _buildLoadingHero()),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s40)),

                // ESPACE DOCUMENTAIRES & DÉCOUVERTE
                SliverToBoxAdapter(child: _buildDocumentarySection(documentaires)),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s40)),

                // ESPACE PODCASTS
                SliverToBoxAdapter(child: _buildPodcastsSection(podcasts)),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s32)),

                // LE FIL D'INFO (NEWS FEED)
                SliverToBoxAdapter(child: _buildSectionTitle("Le fil de l'info", Icons.timeline_rounded)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                _buildNewsFeed(recents, prov),

                const SliverToBoxAdapter(child: SizedBox(height: 140)), // Espace pour la Bottom Nav
              ],
            ),
          ),
          
          // BOTTOM NAV FLOTTANTE EN VERRE
          Positioned(bottom: ThixPolicy.s24, left: ThixPolicy.s16, right: ThixPolicy.s16, child: _buildFloatingBottomNav()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APP BAR PREMIUM
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: ThixPolicy.inkDeep.withOpacity(0.8),
      elevation: 0,
      pinned: true,
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.search_rounded, color: Colors.white), onPressed: () {}),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s8, vertical: ThixPolicy.s4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
            child: Text('THIX', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: ThixPolicy.bold, letterSpacing: 1.0)),
          ),
          const SizedBox(width: ThixPolicy.s6),
          Text('INFO', style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.regular, letterSpacing: 1.5)),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.person_outline_rounded, color: Colors.white), onPressed: () {}),
      ],
      flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. FLASH INFO (TEMPS RÉEL)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFlashTicker(List<NewsArticle> list) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s8),
      child: GlassBox(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s10),
        borderRadius: ThixPolicy.rSm,
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle, boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.6), blurRadius: 8)])),
            const SizedBox(width: ThixPolicy.s12),
            Text('FLASH', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, letterSpacing: 1.0)),
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
                        onTap: () => context.push('/thix-info/article/${a.id}'),
                        child: Text(a.title, style: ThixPolicy.bodySmallStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.semiBold)),
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
  // 2. ESPACE CHAÎNES (HUB)
  // ─────────────────────────────────────────────────────────────
  Widget _buildChannelsSection() {
    final channels = [
      {'name': 'THIX TV', 'icon': Icons.tv_rounded, 'color': ThixPolicy.domainMedia},
      {'name': 'THIX Radio', 'icon': Icons.radio_rounded, 'color': ThixPolicy.domainNetwork},
      {'name': 'Le Quotidien', 'icon': Icons.article_rounded, 'color': ThixPolicy.domainInfo},
      {'name': 'Nova Doc', 'icon': Icons.movie_filter_rounded, 'color': ThixPolicy.domainLearning},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Chaînes & Éditeurs', Icons.broadcast_on_personal_rounded),
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
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ThixPolicy.s16),
                    decoration: BoxDecoration(
                      color: (c['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      border: Border.all(color: (c['color'] as Color).withOpacity(0.3), width: 1),
                    ),
                    child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 28), 
                  ),
                  const SizedBox(height: ThixPolicy.s8),
                  Text(c['name'] as String, style: ThixPolicy.captionStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.bold)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CATÉGORIES (STICKY GLASS)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: ThixPolicy.inkDeep.withOpacity(0.6),
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s10),
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
                  ref.read(newsProvider).fetchArticles(category: c['slug'] == 'featured' ? 'all' : c['slug']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                    border: Border.all(color: sel ? Colors.transparent : Colors.white.withOpacity(0.15)),
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
  // 3. HERO (À LA UNE) AVEC GLASS TEXT
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroCarousel(List<NewsArticle> list) {
    return SizedBox(
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
                image: a.imageUrl != null ? DecorationImage(image: NetworkImage(a.imageUrl!), fit: BoxFit.cover) : null,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent, Colors.transparent]),
                    ),
                  ),
                  Positioned(
                    bottom: ThixPolicy.s16, left: ThixPolicy.s16, right: ThixPolicy.s16,
                    child: GlassBox(
                      padding: ThixPolicy.cardPadding,
                      borderRadius: ThixPolicy.rMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s8, vertical: ThixPolicy.s4),
                            decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
                            child: Text(a.category.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, letterSpacing: 1.0)),
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          Text(a.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: ThixPolicy.h2Style.copyWith(color: Colors.white)),
                          const SizedBox(height: ThixPolicy.s12),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 14, color: Colors.white70),
                              const SizedBox(width: ThixPolicy.s6),
                              Text('Il y a 2h', style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.semiBold)),
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
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. DOCUMENTAIRES & DÉCOUVERTE (PAYSAGE)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDocumentarySection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Documentaires & Enquêtes', Icons.movie_filter_rounded),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
            itemBuilder: (_, i) {
              final a = list[i];
              return SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      child: SizedBox(
                        height: 150, width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            a.imageUrl != null ? Image.network(a.imageUrl!, fit: BoxFit.cover) : Container(color: Colors.white.withOpacity(0.08)),
                            const Center(child: GlassBox(padding: EdgeInsets.all(12), borderRadius: ThixPolicy.rFull, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white)),
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
  // 5. PODCASTS & AUDIO
  // ─────────────────────────────────────────────────────────────
  Widget _buildPodcastsSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Podcasts & Audio', Icons.headphones_rounded),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
            itemBuilder: (_, i) {
              final a = list[i];
              return SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 130, width: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        image: a.imageUrl != null ? DecorationImage(image: NetworkImage(a.imageUrl!), fit: BoxFit.cover) : null,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(ThixPolicy.s8),
                          child: GlassBox(padding: const EdgeInsets.all(ThixPolicy.s8), borderRadius: ThixPolicy.rLg, child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodySmallStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white70)),
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
  // 6. FIL D'ACTUALITÉ (NEWS FEED)
  // ─────────────────────────────────────────────────────────────
  Widget _buildNewsFeed(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) return Center(child: Text('Aucune actualité publiée', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white54)));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final a = list[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
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
                          Text(a.category.toUpperCase(), style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.gold, letterSpacing: 1.0)),
                          const SizedBox(height: ThixPolicy.s8),
                          Text(a.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(color: Colors.white)),
                          const SizedBox(height: ThixPolicy.s12),
                          Row(
                            children: [
                              const Icon(Icons.remove_red_eye_rounded, size: 14, color: Colors.white54),
                              const SizedBox(width: ThixPolicy.s6),
                              Text('${a.viewsCount}', style: ThixPolicy.labelStyle.copyWith(color: Colors.white54)),
                              const Spacer(),
                              const Icon(Icons.bookmark_border_rounded, size: 18, color: Colors.white54),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: SizedBox(
                        width: 110, height: 110,
                        child: a.imageUrl != null ? Image.network(a.imageUrl!, fit: BoxFit.cover) : Container(color: Colors.white.withOpacity(0.08)),
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
          Text(t, style: ThixPolicy.h2Style.copyWith(color: Colors.white, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildLoadingHero() => Container(margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), height: 420, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(ThixPolicy.rXl)), child: const Center(child: CircularProgressIndicator(color: Colors.white)));

  // ─────────────────────────────────────────────────────────────
  // BOTTOM NAV FLOTTANTE (GLASSMORPHISM)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFloatingBottomNav() {
    return GlassBox(
      padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s12, horizontal: ThixPolicy.s8),
      borderRadius: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.public_rounded, 'À la une', 0),
          _navItem(Icons.grid_view_rounded, 'Explorer', 1),
          // Bouton central "DIRECT" Accent
          GestureDetector(
            onTap: () => setState(() => _navIndex = 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: ThixPolicy.s10),
              decoration: BoxDecoration(color: _navIndex == 2 ? ThixPolicy.danger : Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
              child: Row(
                children: [
                  Icon(Icons.sensors_rounded, color: _navIndex == 2 ? Colors.white : ThixPolicy.inkDeep, size: 20),
                  const SizedBox(width: ThixPolicy.s6),
                  Text('Direct', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: _navIndex == 2 ? Colors.white : ThixPolicy.inkDeep)),
                ],
              ),
            ),
          ),
          _navItem(Icons.bookmark_rounded, 'Sauvegardes', 3),
          _navItem(Icons.person_rounded, 'Profil', 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final sel = _navIndex == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _navIndex = idx);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: sel ? Colors.white : Colors.white54, size: 26),
          const SizedBox(height: ThixPolicy.s4),
          Text(label, style: ThixPolicy.microStyle.copyWith(fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold, color: sel ? Colors.white : Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _CategoryHeaderDelegate({required this.child});
  @override double get minExtent => 54;
  @override double get maxExtent => 54;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) => false;
}
