// lib/presentation/thix_info/thix_info_home.dart
// THIX INFO — VRAIE PAGE D'INFORMATION (design capture, thème clair)
// ✅ Branché sur la logique existante : newsProvider, downloadsProvider,
//    podcastPlayerProvider, AdminRbacService, Supabase.
// ✅ AUCUN mock-up : hero / récentes / vidéos / tendances / fil = prov.articles.
// ✅ HERO EDGE-TO-EDGE : banner occupe 100% de la largeur, image bien cadrée.
// ✅ FINITIONS PREMIUM : skeleton shimmer, pills animées, CTA shimmer,
//    auto-play avec pause tactile, slots notifications push.
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/news_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/podcast_player_provider.dart';
// ✅ Slot prêt pour push "À la une" — importera ton fichier quand tu l'enverras
// import 'package:thix_id/presentation/thix_info/providers/hero_push_provider.dart';
import '../../services/thix_downloader.dart';
import '../../services/admin_rbac_service.dart';
import '../../models/news_article.dart';

// ── Tokens clair (capture) — on garde ThixPolicy pour les espacements / typos ──
const Color _kBg = Color(0xFFF6F7F9);
const Color _kCard = Colors.white;
const Color _kInk = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF64748B);
const Color _kGold = Color(0xFFFFC107);
const Color _kGoldDark = Color(0xFFD4AF37);
const Color _kPurple = Color(0xFF6366F1);
const Color _kBorder = Color(0xFFE2E8F0);

Color _categoryColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'politique':
      return const Color(0xFF2563EB);
    case 'economie':
    case 'économie':
      return const Color(0xFF059669);
    case 'societe':
    case 'société':
      return const Color(0xFFF59E0B);
    case 'tech':
      return const Color(0xFF7C3AED);
    case 'sport':
      return const Color(0xFFEA580C);
    case 'culture':
      return const Color(0xFFDB2777);
    case 'international':
      return const Color(0xFF0891B2);
    case 'magazine':
      return const Color(0xFFD4AF37);
    case 'podcast':
      return const Color(0xFF6366F1);
    case 'découverte':
    case 'decouverte':
      return const Color(0xFF10B981);
    default:
      return _kGoldDark;
  }
}

String _compactViews(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M vues';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k vues';
  return '$n vues';
}

// ============================================================================
// COMPOSANT RÉUTILISABLE : CARTE CLAIRE
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? _kCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================================
// 🎚️ ÉGALISEUR ANIMÉ
// ============================================================================
class _EqualizerBars extends StatefulWidget {
  final double size;
  final Color color;
  const _EqualizerBars({this.size = 14, this.color = _kPurple});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

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
// 🏆 SKELETON HERO (shimmer premium type Facebook)
// ============================================================================
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE4E4E7),
      highlightColor: const Color(0xFFF4F4F5),
      child: Container(
        height: 340,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 240,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 180,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
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
  final PageController _pageCtrl = PageController();
  final ScrollController _breakingCtrl = ScrollController();
  final ScrollController _mainScrollCtrl = ScrollController();

  Timer? _timer;
  Timer? _breakingTimer;
  int _page = 0;
  bool _isAdmin = false;
  bool _adminChecked = false;
  bool _showAlertBanner = true;
  bool _heroPaused = false;

  final Set<String> _savedIds = <String>{};
  final GlobalKey _feedKey = GlobalKey();
  final GlobalKey _videosKey = GlobalKey();
  final GlobalKey _podcastKey = GlobalKey();
  final GlobalKey _breakingKey = GlobalKey();

  static const Set<String> _spaceCategories = {'Magazine', 'Podcast', 'Découverte'};
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsProvider).fetchArticles(category: 'all');
      ref.read(newsProvider).loadSavedArticles();
      _startAuto();
      _startBreakingScroll();
      _resolveIsAdmin();
      _listenToHeroPush();
    });
  }

  void _listenToHeroPush() {
    // Exemple d'intégration future :
    // ref.listen(heroPushProvider, (prev, next) {
    //   if (next != null && mounted) {
    //     setState(() { /* réorganiser la liste featured */ });
    //   }
    // });
  }

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
      if (!admin) admin = user.email?.endsWith('@thix.info') ?? false;
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
      if (!mounted || _heroPaused) return;
      final list = ref
          .read(newsProvider)
          .articles
          .where((e) => e.isFeatured)
          .toList();
      if (list.isEmpty || !_pageCtrl.hasClients) return;
      _page = (_page + 1) % list.length;
      _pageCtrl.animateToPage(
        _page,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
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

  List<NewsArticle> _spaceItems(String dbCategory) => ref
      .watch(newsProvider)
      .articles
      .where((a) => a.category == dbCategory)
      .toList();

  String _formatTimeAgo(DateTime publishedAt) {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem';
    return DateFormat('dd MMM yyyy', 'fr_FR').format(publishedAt);
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

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  void _selectCat(String slug) {
    setState(() => _cat = slug);
    ref.read(newsProvider).fetchArticles(
          category: slug == 'featured' ? 'all' : slug,
        );
  }

  void _toggleSave(NewsArticle a) {
    setState(() {
      if (_savedIds.contains(a.id)) {
        _savedIds.remove(a.id);
      } else {
        _savedIds.add(a.id);
      }
    });
    ref.read(newsProvider).loadSavedArticles();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _savedIds.contains(a.id) ? 'Ajouté aux favoris' : 'Retiré des favoris'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showAlertsSheet() {
    final breaking = ref
        .read(newsProvider)
        .articles
        .where((e) => e.isBreaking)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Alertes — Flash info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              breaking.isEmpty
                  ? 'Aucune alerte pour le moment.'
                  : '${breaking.length} alerte(s) en cours',
              style: const TextStyle(color: _kMuted),
            ),
            const SizedBox(height: 16),
            if (breaking.isEmpty)
              const Text(
                'Active les alertes pour être prévenu dès qu\'une info urgente est publiée.',
                style: TextStyle(color: _kMuted),
              ),
            for (final a in breaking)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 10, color: Colors.red),
                title: Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                subtitle: Text(
                  _formatTimeAgo(a.publishedAt),
                  style: const TextStyle(color: _kMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/thix-info/article/${a.id}');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet() {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final name = (user?.userMetadata?['full_name'] as String?) ??
        (user?.userMetadata?['name'] as String?) ??
        user?.email?.split('@').first ??
        'Invité';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 32,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: _kGold,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: _kInk,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            if (user?.email != null)
              Text(user!.email!, style: const TextStyle(color: _kMuted)),
            if (_isAdmin)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text('Admin'),
                  backgroundColor: Color(0xFFFEF3C7),
                ),
              ),
            const SizedBox(height: 16),
            if (_isAdmin)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/thix-info/admin');
                  },
                  style: FilledButton.styleFrom(backgroundColor: _kInk),
                  child: const Text('Espace admin'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/thix-info/downloads');
                },
                child: const Text('Mes téléchargements'),
              ),
            ),
            const SizedBox(height: 8),
            if (user != null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Toutes les catégories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 12),
            for (final c in cats)
              ListTile(
                title: Text(
                  c['name']!,
                  style: TextStyle(
                    fontWeight:
                        _cat == c['slug'] ? FontWeight.w800 : FontWeight.w500,
                    color: _cat == c['slug'] ? _kInk : _kMuted,
                  ),
                ),
                trailing: _cat == c['slug']
                    ? const Icon(Icons.check_rounded, color: _kGoldDark)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _selectCat(c['slug']!);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = ref.watch(newsProvider);
    final featured = prov.articles.where((e) => e.isFeatured).toList();
    final breaking = prov.articles.where((e) => e.isBreaking).toList();
    final recents = prov.articles
        .where((a) => !_spaceCategories.contains(a.category))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final videos = prov.articles
        .where((a) => a.category == 'Podcast' && isVideoPodcast(a))
        .toList();
    final trending = [...recents]
      ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
    final trendingTop = trending.take(5).toList();
    final playerArticle =
        ref.watch(podcastPlayerProvider.select((s) => s.article));

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _kInk,
            backgroundColor: Colors.white,
            onRefresh: () async =>
                ref.read(newsProvider).fetchArticles(category: 'all'),
            child: CustomScrollView(
              controller: _mainScrollCtrl,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                _buildAppBar(breaking.length),
                SliverToBoxAdapter(child: _buildSearchBar()),
                if (breaking.isNotEmpty)
                  SliverToBoxAdapter(
                    key: _breakingKey,
                    child: _buildFlashTicker(breaking),
                  ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryHeaderDelegate(
                    child: _buildCategories(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: featured.isNotEmpty
                      ? _buildHeroSection(featured)
                      : const _HeroSkeleton(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildShortcuts()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildRecentsSection(recents)),
                if (_showAlertBanner)
                  SliverToBoxAdapter(child: _buildAlertBanner()),
                SliverToBoxAdapter(
                  key: _videosKey,
                  child: _buildVideosSection(videos),
                ),
                SliverToBoxAdapter(
                  child: _buildTrendingSection(trendingTop),
                ),
                SliverToBoxAdapter(
                  child: _buildMagazineSection(_spaceItems('Magazine')),
                ),
                SliverToBoxAdapter(
                  key: _podcastKey,
                  child: _buildPodcastSection(_spaceItems('Podcast')),
                ),
                SliverToBoxAdapter(
                  child: _buildDecouverteSection(_spaceItems('Découverte')),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  key: _feedKey,
                  child: _buildSectionTitle(
                    "Le fil de l'info",
                    Icons.timeline_rounded,
                    onSeeAll: null,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                _buildNewsFeed(recents, prov),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              reverseDuration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                  ),
                ),
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

  Widget _buildAppBar(int breakingCount) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initial =
        (user?.email?.isNotEmpty == true) ? user!.email![0].toUpperCase() : '?';
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      centerTitle: false,
      toolbarHeight: 64,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: _kInk, size: 26),
        onPressed: _showCategoriesSheet,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.article_rounded, color: _kInk, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'THIX ',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'INFO',
                      style: TextStyle(
                        color: _kGoldDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                "L'information vraie, partout.",
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_isAdmin)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            onPressed: () => context.push('/thix-info/admin'),
          ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: _kInk, size: 26),
              onPressed: _showAlertsSheet,
            ),
            if (breakingCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    breakingCount > 9 ? '9+' : '$breakingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 2),
          child: GestureDetector(
            onTap: _showProfileSheet,
            child: CircleAvatar(
              radius: 18,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: _kGold,
              child: avatarUrl == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GestureDetector(
        onTap: () => context.push('/thix-info/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: _kMuted, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rechercher une actualité, un sujet...',
                  style: TextStyle(color: _kMuted, fontSize: 14),
                ),
              ),
              Icon(Icons.tune_rounded, color: _kInk, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashTicker(List<NewsArticle> list) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border(left: BorderSide(color: Colors.red, width: 4)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FLASH',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 14, color: _kBorder),
            const SizedBox(width: 10),
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
                      padding: const EdgeInsets.only(right: 40),
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/thix-info/article/${a.id}'),
                        child: Text(
                          a.title,
                          style: const TextStyle(
                            color: _kInk,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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

  Widget _buildCategories() {
    return Container(
      color: _kBg,
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == cats.length) {
            return GestureDetector(
              onTap: _showCategoriesSheet,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBorder),
                ),
                child: const Icon(Icons.menu_rounded, size: 18, color: _kInk),
              ),
            );
          }
          final c = cats[i];
          final sel = _cat == c['slug'];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _selectCat(c['slug']!);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? _kGold : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? Colors.transparent : _kBorder,
                ),
              ),
              child: Text(
                c['name']!,
                style: TextStyle(
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  color: _kInk,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🏆 HERO SECTION — EDGE-TO-EDGE + IMAGE BIEN CADRÉE
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildHeroSection(List<NewsArticle> list) {
    return Column(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (v) {
              // ✅ Vibration supprimée ici
              setState(() => _page = v);
            },
            itemCount: list.length,
            itemBuilder: (_, i) => _buildHeroSlide(list[i], i, list.length),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(list.length, (index) {
              final isActive = _page == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 28 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive ? _kGoldDark : _kBorder,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _kGoldDark.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHeroSlide(NewsArticle a, int index, int itemCount) {
    final categoryColor = _categoryColor(a.category);
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${a.id}'),
      onPanDown: (_) => setState(() => _heroPaused = true),
      onPanEnd: (_) => setState(() => _heroPaused = false),
      onPanCancel: () => setState(() => _heroPaused = false),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: w * 0.55,
                    child: a.imageUrl != null
                        ? Image.network(
                            a.imageUrl!,
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            errorBuilder: (_, __, ___) => Container(
                              color: categoryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.image_rounded,
                                color: categoryColor.withOpacity(0.5),
                                size: 48,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  categoryColor.withOpacity(0.15),
                                  categoryColor.withOpacity(0.35),
                                ],
                              ),
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.40, 0.55, 1.0],
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ✅ Suppression du dégradé noir en bas de la photo
                  Positioned(
                    left: 20,
                    top: 20,
                    bottom: 20,
                    width: w * 0.55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _kGold,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kGold.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'À LA UNE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: _kInk,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: categoryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    a.category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: categoryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              a.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                color: _kInk,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (a.summary != null && a.summary!.isNotEmpty)
                              Text(
                                a.summary!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: _kMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 13, color: _kMuted),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimeAgo(a.publishedAt),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _kMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.remove_red_eye_rounded,
                                    size: 13, color: _kMuted),
                                const SizedBox(width: 4),
                                Text(
                                  _compactViews(a.viewsCount),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _kMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ShimmerCta(
                              label: "Lire l'article",
                              onTap: () =>
                                  context.push('/thix-info/article/${a.id}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index > 0)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _heroArrow(
                          Icons.chevron_left_rounded,
                          () => _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                    ),
                  if (index < itemCount - 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _heroArrow(
                          Icons.chevron_right_rounded,
                          () => _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _heroArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: _kInk),
      ),
    );
  }

  Widget _buildShortcuts() {
    final items = [
      {
        'label': 'Fil Info',
        'icon': Icons.feed_rounded,
        'color': const Color(0xFF2563EB),
        'onTap': () => _scrollTo(_feedKey),
      },
      {
        'label': 'Vidéos',
        'icon': Icons.play_circle_fill_rounded,
        'color': const Color(0xFFDC2626),
        'onTap': () => _scrollTo(_videosKey),
      },
      {
        'label': 'Podcasts',
        'icon': Icons.headphones_rounded,
        'color': const Color(0xFF6366F1),
        'onTap': () => _scrollTo(_podcastKey),
      },
      {
        'label': 'Magazines',
        'icon': Icons.auto_stories_rounded,
        'color': const Color(0xFFD4AF37),
        'onTap': () => context.push('/thix-info/space/magazine'),
      },
      {
        'label': 'Communiqués',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF2563EB),
        'onTap': () => _scrollTo(_breakingKey),
      },
      {
        'label': 'Alertes',
        'icon': Icons.notifications_rounded,
        'color': const Color(0xFF059669),
        'onTap': _showAlertsSheet,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final it in items)
            GestureDetector(
              onTap: it['onTap'] as VoidCallback,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (it['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      it['icon'] as IconData,
                      color: it['color'] as Color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    it['label'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String t, IconData icon, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _kInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kInk,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      color: _kGoldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: _kGoldDark),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentsSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Actualités récentes',
          Icons.newspaper_rounded,
          onSeeAll: () => _scrollTo(_feedKey),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.take(10).length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = list[i];
              final saved = _savedIds.contains(a.id);
              return GestureDetector(
                onTap: () => context.push('/thix-info/article/${a.id}'),
                child: SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 104,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              a.imageUrl != null
                                  ? Image.network(
                                      a.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: _kBorder),
                                    )
                                  : Container(
                                      color: _kBorder,
                                      child: const Icon(Icons.image_rounded,
                                          color: _kMuted),
                                    ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _categoryColor(a.category),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    a.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTimeAgo(a.publishedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: _kInk,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.remove_red_eye_rounded,
                              size: 12, color: _kMuted),
                          const SizedBox(width: 4),
                          Text(
                            _compactViews(a.viewsCount),
                            style: const TextStyle(
                                fontSize: 11, color: _kMuted),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _toggleSave(a),
                            child: Icon(
                              saved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 17,
                              color: saved ? _kGoldDark : _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _kGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: _kInk,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Restez informé en temps réel !',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Activez vos notifications et ne manquez aucune information importante.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: _kMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _showAlertsSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _kGold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Activer les alertes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: _kInk,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: _kInk),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => setState(() => _showAlertBanner = false),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: _kMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Vidéos à la une',
          Icons.ondemand_video_rounded,
          onSeeAll: () => context.push('/thix-info/space/podcast'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = list[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(podcastPlayerProvider.notifier).playArticle(a);
                },
                child: SizedBox(
                  width: 168,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 104,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              a.imageUrl != null
                                  ? Image.network(
                                      a.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: _kBorder),
                                    )
                                  : Container(color: _kBorder),
                              Container(color: Colors.black.withOpacity(0.15)),
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: _kInk,
                                    size: 24,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.remove_red_eye_rounded,
                              size: 12, color: _kMuted),
                          const SizedBox(width: 4),
                          Text(
                            _compactViews(a.viewsCount),
                            style: const TextStyle(
                                fontSize: 11, color: _kMuted),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: _kMuted),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeAgo(a.publishedAt),
                            style: const TextStyle(
                                fontSize: 11, color: _kMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle('Tendances', Icons.local_fire_department_rounded),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = list[i];
              return GestureDetector(
                onTap: () => context.push('/thix-info/article/${a.id}'),
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _kGoldDark.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _categoryColor(a.category),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: _kInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _compactViews(a.viewsCount),
                              style: const TextStyle(
                                  fontSize: 11, color: _kMuted),
                            ),
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
    );
  }

  Widget _spaceHeader(_SpaceDef s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.tagline,
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/thix-info/space/${s.slug}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tout voir',
                    style: TextStyle(
                      fontSize: 12,
                      color: s.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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

  Widget _buildMagazineSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _spaceHeader(_spaces[0]),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
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
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    a.imageUrl != null
                        ? Image.network(
                            a.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: _kBorder),
                          )
                        : Container(color: _kBorder),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'THIX MAG',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
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
                            const Icon(
                              Icons.auto_stories_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(a.content.length / 1500).ceil()} min',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              a.category.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a.summary ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: _kMuted,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _spaceHeader(_spaces[1]),
        const SizedBox(height: 14),
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
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
    final isCurrent = ref
        .watch(podcastPlayerProvider.select((s) => s.article?.id == a.id));
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? const Color(0xFF6366F1) : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      a.imageUrl != null
                          ? Image.network(
                              a.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: _kBorder),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF4338CA),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 40,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVideo ? Colors.red : const Color(0xFF6366F1),
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
                                isVideo ? 'VIDEO' : 'AUDIO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCurrent && isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: _kInk,
                            size: 22,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _downloadButton(
                          a,
                          downloading,
                          downloaded,
                          currentItem,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              a.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  isPlaying
                      ? const _EqualizerBars(
                          size: 12, color: Color(0xFF6366F1))
                      : const Icon(
                          Icons.pause_rounded,
                          size: 12,
                          color: Color(0xFF6366F1),
                        ),
                  const SizedBox(width: 6),
                  Text(
                    isPlaying ? 'En cours' : 'En pause',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloadButton(
      NewsArticle a, bool downloading, bool downloaded, DownloadItem? currentItem) {
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
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Text(
              '${(currentItem.progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
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
        child: const Icon(
          Icons.check_rounded,
          color: Color(0xFF10B981),
          size: 18,
        ),
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
        child: const Icon(
          Icons.download_rounded,
          color: Colors.black87,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildDecouverteSection(List<NewsArticle> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _spaceHeader(_spaces[2]),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
        width: 168,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              a.imageUrl != null
                  ? Image.network(
                      a.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: _kBorder),
                    )
                  : Container(color: _kBorder),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(height: 6),
                    Text(
                      a.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsFeed(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Text(
            'Aucune actualité publiée',
            style: TextStyle(color: _kMuted),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final a = list[index];
          final saved = _savedIds.contains(a.id);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: () => context.push('/thix-info/article/${a.id}'),
              child: GlassBox(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                a.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _categoryColor(a.category),
                                  letterSpacing: 1,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _toggleSave(a),
                                child: Icon(
                                  saved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  size: 17,
                                  color: saved ? _kGoldDark : _kMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              color: _kInk,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.remove_red_eye_rounded,
                                  size: 13, color: _kMuted),
                              const SizedBox(width: 4),
                              Text(
                                _compactViews(a.viewsCount),
                                style: const TextStyle(
                                    fontSize: 11.5, color: _kMuted),
                              ),
                              const Spacer(),
                              const Icon(Icons.schedule_rounded,
                                  size: 13, color: _kMuted),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeAgo(a.publishedAt),
                                style: const TextStyle(
                                    fontSize: 11.5, color: _kMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: a.imageUrl != null
                            ? Image.network(
                                a.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: _kBorder),
                              )
                            : Container(
                                color: _kBorder,
                                child: const Icon(Icons.image_rounded,
                                    color: _kMuted),
                              ),
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

  Widget _buildMiniPlayer() {
    final player = ref.watch(podcastPlayerProvider);
    final a = player.article;
    if (a == null) return const SizedBox.shrink();
    final isVideo = isVideoPodcast(a);
    return GestureDetector(
      onTap: _openFullPodcastPlayer,
      child: GlassBox(
        padding: const EdgeInsets.all(8),
        borderRadius: 16,
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.35),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    a.imageUrl != null
                        ? Image.network(
                            a.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: _kBorder),
                          )
                        : Container(
                            color: _kBorder,
                            child: const Icon(Icons.headphones, color: _kMuted),
                          ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: player.isPlaying
                            ? const _EqualizerBars(size: 14, color: Colors.white)
                            : Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.graphic_eq_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _kInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isVideo ? 'Vidéo' : 'Audio'} - ${player.isPlaying ? 'En cours' : 'En pause'}',
                    style: const TextStyle(fontSize: 11, color: _kMuted),
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
                        strokeWidth: 2.5,
                        color: Color(0xFF6366F1),
                      ),
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
              icon: const Icon(Icons.close_rounded, color: _kMuted, size: 20),
              onPressed: () => ref.read(podcastPlayerProvider.notifier).stop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 🎨 CTA AVEC EFFET SHIMMER (bouton "Lire l'article" qui brille)
// ════════════════════════════════════════════════════════════════════════════
class _ShimmerCta extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ShimmerCta({required this.label, required this.onTap});

  @override
  State<_ShimmerCta> createState() => _ShimmerCtaState();
}

class _ShimmerCtaState extends State<_ShimmerCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  _kGold,
                  Color(0xFFFFD54F),
                  _kGold,
                ],
                stops: [
                  (_ctrl.value - 0.3).clamp(0.0, 1.0),
                  _ctrl.value.clamp(0.0, 1.0),
                  (_ctrl.value + 0.3).clamp(0.0, 1.0),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _kGold.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: _kInk,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(sin(_ctrl.value * 2 * pi) * 2, 0),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            if (isVideo)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    image: a.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(a.imageUrl!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.4),
                              BlendMode.darken,
                            ),
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
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white24),
                              ),
                            ),
                            child: player.isLoading
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
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
                        const Positioned(
                          bottom: 10,
                          left: 12,
                          child: Row(
                            children: [
                              _EqualizerBars(size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'PISTE AUDIO EN DIRECT',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
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
                      color: const Color(0xFF6366F1).withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                  image: a.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(a.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: _kBorder,
                ),
                child: Stack(
                  children: [
                    if (a.imageUrl == null)
                      const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 80,
                          color: _kMuted,
                        ),
                      ),
                    if (player.isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: _kInk),
                      ),
                    if (player.isPlaying)
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const _EqualizerBars(
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text(
              a.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam_rounded : Icons.headphones_rounded,
                  size: 14,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  isVideo ? 'THIX Podcast Vidéo' : 'THIX Podcast Audio',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: const Color(0xFF6366F1),
                    inactiveTrackColor: _kBorder,
                    thumbColor: _kInk,
                  ),
                  child: Slider(
                    value: pos.inSeconds.toDouble().clamp(0.0, maxSec),
                    max: maxSec,
                    onChanged: (val) =>
                        notifier.seek(Duration(seconds: val.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmtDur(pos),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kMuted,
                        ),
                      ),
                      Text(
                        _fmtDur(dur),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    color: _kMuted,
                    size: 32,
                  ),
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
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
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
                  icon: const Icon(
                    Icons.forward_30_rounded,
                    color: _kMuted,
                    size: 32,
                  ),
                  onPressed: () => notifier.skipBy(30),
                ),
              ],
            ),
            if (player.error != null) ...[
              const SizedBox(height: 12),
              Text(
                player.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open_rounded, size: 12, color: _kMuted),
                SizedBox(width: 6),
                Text(
                  'Lecture maintenue hors application',
                  style: TextStyle(fontSize: 11, color: _kMuted),
                ),
              ],
            ),
          ],
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;

  @override
  bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) => false;
}
