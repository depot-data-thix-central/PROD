// lib/presentation/thix_info/thix_info_home.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

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

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'politique': return ThixPolicy.domainGov;
      case 'economie':
      case 'économie': return ThixPolicy.domainMoney;
      case 'tech': return ThixPolicy.domainNetwork;
      case 'sport': return ThixPolicy.domainMarket;
      case 'societe':
      case 'société': return ThixPolicy.domainOpportunity;
      default: return ThixPolicy.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = ref.watch(newsProvider);
    final featured = prov.articles.where((e) => e.isFeatured).toList();
    final breaking = prov.articles.where((e) => e.isBreaking).toList();
    final recents = prov.articles;
    // Simulation : on prend quelques articles pour les podcasts et décryptage
    final podcasts = prov.articles.take(4).toList(); 
    final decryptages = prov.articles.skip(2).take(3).toList();

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: ThixPolicy.card,
            onRefresh: () async => ref.read(newsProvider).fetchArticles(category: 'all'),
            child: CustomScrollView(
              controller: _mainScrollCtrl,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildAppBar(),
                
                // BANDEAU DIRECT (TV/RADIO)
                SliverToBoxAdapter(child: _buildLiveBanner()),
                
                // BREAKING NEWS
                if (breaking.isNotEmpty) SliverToBoxAdapter(child: _buildBreakingBar(breaking)),
                
                // CATEGORIES (STICKY)
                SliverPersistentHeader(pinned: true, delegate: _CategoryHeaderDelegate(child: _buildCategories())),
                
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),

                // À LA UNE (HERO)
                SliverToBoxAdapter(child: featured.isNotEmpty ? _buildFeaturedCarousel(featured) : _buildLoadingHero()),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s32)),

                // SECTION DÉCRYPTAGE (Fond sombre / Premium)
                SliverToBoxAdapter(child: _buildDecryptageSection(decryptages, prov)),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s32)),

                // SECTION PODCASTS
                SliverToBoxAdapter(child: _buildPodcastsSection(podcasts)),

                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),
                const SliverToBoxAdapter(child: Divider(color: ThixPolicy.border, height: 1)),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),

                // LE FIL D'ACTUALITÉ (CLASSIQUE)
                SliverToBoxAdapter(child: _buildSectionTitle("Le fil de l'info")),
                const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
                _buildAllNewsList(recents, prov),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          
          // BOTTOM NAV
          Positioned(bottom: 0, left: 0, right: 0, child: _buildGlassBottomNav()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 0,
      pinned: true,
      titleSpacing: ThixPolicy.s16,
      leading: IconButton(icon: const Icon(Icons.search_rounded, color: ThixPolicy.textMain), onPressed: () {}),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(4)),
            child: const Text('THIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
          ),
          const SizedBox(width: 4),
          const Text('MEDIA', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w300, fontSize: 16, letterSpacing: 1.5)),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.person_outline_rounded, color: ThixPolicy.textMain), onPressed: () {}),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: ThixPolicy.border, height: 1)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EN DIRECT BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildLiveBanner() {
    return Container(
      color: ThixPolicy.inkDeep,
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: ThixPolicy.s12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EN DIRECT', style: TextStyle(color: ThixPolicy.danger, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text('Édition spéciale : Élections 2026', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Écouter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
          )
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BREAKING NEWS
  // ─────────────────────────────────────────────────────────────
  Widget _buildBreakingBar(List<NewsArticle> list) {
    return Container(
      height: 36,
      color: ThixPolicy.danger.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: ThixPolicy.danger,
            alignment: Alignment.center,
            child: const Text('ALERTE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _breakingCtrl,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length * 50,
              itemBuilder: (_, i) {
                final a = list[i % list.length];
                return GestureDetector(
                  onTap: () => context.push('/thix-info/article/${a.id}'),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(right: 30, left: 10),
                    child: Text(a.title, style: const TextStyle(color: ThixPolicy.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CATEGORIES
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return Container(
      color: ThixPolicy.card,
      height: 48,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ThixPolicy.border))),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 8),
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
              if (c['slug'] == 'featured') {
                ref.read(newsProvider).fetchArticles(category: 'all');
              } else {
                ref.read(newsProvider).fetchArticles(category: c['slug']!);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? ThixPolicy.inkDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? ThixPolicy.inkDeep : ThixPolicy.border),
              ),
              child: Text(
                c['name']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                  color: sel ? Colors.white : ThixPolicy.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO CAROUSEL
  // ─────────────────────────────────────────────────────────────
  Widget _buildFeaturedCarousel(List<NewsArticle> list) {
    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (v) => setState(() => _page = v),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              return GestureDetector(
                onTap: () => context.push('/thix-info/article/${a.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    image: a.imageUrl != null ? DecorationImage(image: NetworkImage(a.imageUrl!), fit: BoxFit.cover) : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.black.withOpacity(0.1), Colors.transparent]),
                    ),
                    padding: const EdgeInsets.all(ThixPolicy.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(a.category.toUpperCase(), style: const TextStyle(color: ThixPolicy.gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                        const SizedBox(height: 8),
                        Text(a.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1, color: Colors.white, letterSpacing: -0.5)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            const Text('Il y a 2h', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(list.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(color: active ? ThixPolicy.inkDeep : ThixPolicy.borderStrong, borderRadius: BorderRadius.circular(3)),
            );
          }),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DÉCRYPTAGE (PREMIUM)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDecryptageSection(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      color: ThixPolicy.surfaceStrong,
      padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            child: Text('DÉCRYPTAGE & ANALYSE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: 0.5)),
          ),
          const SizedBox(height: ThixPolicy.s20),
          SizedBox(
            height: 280,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
              itemBuilder: (_, i) {
                final a = list[i];
                return GestureDetector(
                  onTap: () => context.push('/thix-info/article/${a.id}'),
                  child: Container(
                    width: 240,
                    decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), boxShadow: ThixPolicy.shadowSoft()),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 130, width: double.infinity,
                          child: a.imageUrl != null ? Image.network(a.imageUrl!, fit: BoxFit.cover) : Container(color: ThixPolicy.tint),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(ThixPolicy.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.2, color: ThixPolicy.textMain)),
                              const SizedBox(height: 12),
                              _engagementRow(a, prov),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PODCASTS
  // ─────────────────────────────────────────────────────────────
  Widget _buildPodcastsSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Podcasts & Audio', icon: Icons.headphones_rounded),
        const SizedBox(height: ThixPolicy.s16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
            itemBuilder: (_, i) {
              final a = list[i];
              return SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120, width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        image: a.imageUrl != null ? DecorationImage(image: NetworkImage(a.imageUrl!), fit: BoxFit.cover) : null,
                        color: ThixPolicy.tint,
                      ),
                      child: Center(child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28))),
                    ),
                    const SizedBox(height: 8),
                    Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, height: 1.2)),
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
  // FIL D'ACTUALITÉ
  // ─────────────────────────────────────────────────────────────
  Widget _buildAllNewsList(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) return const Center(child: Text('Aucune actualité publiée', style: TextStyle(color: ThixPolicy.textSecondary)));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final a = list[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
            child: GestureDetector(
              onTap: () => context.push('/thix-info/article/${a.id}'),
              child: Container(
                color: Colors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.category.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _catColor(a.category), letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(a.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.25, color: ThixPolicy.textMain)),
                          const SizedBox(height: 8),
                          Text('Il y a 3h', style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: SizedBox(
                        width: 100, height: 100,
                        child: a.imageUrl != null ? Image.network(a.imageUrl!, fit: BoxFit.cover) : Container(color: ThixPolicy.tint),
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

  Widget _buildSectionTitle(String t, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: ThixPolicy.primaryDeep), const SizedBox(width: 8)],
          Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _engagementRow(NewsArticle a, NewsProvider prov) {
    final isSaved = prov.savedArticles.any((s) => s.id == a.id);
    return Row(
      children: [
        const Icon(Icons.remove_red_eye_rounded, size: 14, color: ThixPolicy.textSecondary),
        const SizedBox(width: 4),
        Text('${a.viewsCount}', style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            isSaved ? ref.read(newsProvider).unsaveArticle(a.id) : ref.read(newsProvider).saveArticle(a.id);
          },
          child: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 18, color: isSaved ? ThixPolicy.primary : ThixPolicy.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLoadingHero() => Container(margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), height: 380, decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(ThixPolicy.rMd)), child: const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)));

  // ─────────────────────────────────────────────────────────────
  // GLASS BOTTOM NAV
  // ─────────────────────────────────────────────────────────────
  Widget _buildGlassBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: ThixPolicy.card.withOpacity(0.9),
            border: const Border(top: BorderSide(color: ThixPolicy.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(Icons.home_filled, 'À la une', 0),
                _navItem(Icons.explore_rounded, 'Explorer', 1),
                // Bouton central "DIRECT"
                GestureDetector(
                  onTap: () => setState(() => _navIndex = 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _navIndex == 2 ? ThixPolicy.danger : ThixPolicy.surfaceStrong, shape: BoxShape.circle),
                        child: Icon(Icons.sensors_rounded, color: _navIndex == 2 ? Colors.white : ThixPolicy.textMain, size: 20),
                      ),
                      const SizedBox(height: 4),
                      Text('Direct', style: TextStyle(fontSize: 10, fontWeight: _navIndex == 2 ? FontWeight.w800 : FontWeight.w600, color: _navIndex == 2 ? ThixPolicy.danger : ThixPolicy.textMain)),
                    ],
                  ),
                ),
                _navItem(Icons.bookmark_rounded, 'Favoris', 3),
                _navItem(Icons.person_rounded, 'Mon Profil', 4),
              ],
            ),
          ),
        ),
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
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? ThixPolicy.inkDeep : ThixPolicy.textSecondary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? ThixPolicy.inkDeep : ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _CategoryHeaderDelegate({required this.child});
  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) => false;
}
