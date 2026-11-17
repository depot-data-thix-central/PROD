// ════════════════════════════════════════════════════════════════════════════
//  THIX INFO — PAGE D'ACCUEIL « RÉDACTION PREMIUM »
//  Fichier  : lib/presentation/thix_info/pages/thix_info_home_page.dart
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
//
//  En-tête + cloche (compteur des notifications INFO non lues), bandeau
//  EN DIRECT, catégories, carrousel À la une, accès rapides, actualités
//  récentes, bannière alertes, vidéos à la une, barre de navigation.
//
//  Données : table Supabase `info_articles` (voir infoFeedProvider).
//  Cloche  : se rafraîchit à l'arrivée d'un push INFO (InfoPushBus), au
//            retour sur l'app et au tirage pour rafraîchir. Pas de Realtime.
// ════════════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/services/info_push_bus.dart';

// ── Routes (à déclarer dans go_router, ou à adapter ici) ───────────────────
const String kInfoArticleRoute = '/info/article'; // + /:id
const String kInfoSearchRoute = '/info/recherche';
const String kInfoFeedRoute = '/info/fil';
const String kInfoVideosRoute = '/info/videos';
const String kInfoPodcastsRoute = '/info/podcasts';
const String kInfoMagazinesRoute = '/info/magazines';
const String kInfoCommuniquesRoute = '/info/communiques';
const String kInfoAlertsRoute = '/info/alertes';
const String kInfoCategoriesRoute = '/info/categories';
const String kInfoFavoritesRoute = '/info/favoris';
const String kNotificationsRoute = '/notification';
const String kProfileRoute = '/profile';

// ── Palette ────────────────────────────────────────────────────────────────
const Color _kAmber = Color(0xFFFFB400);
const Color _kAmberDark = Color(0xFFB57F00);
const Color _kInk = Color(0xFF0B1B3A);
const Color _kMuted = Color(0xFF64748B);
const Color _kLine = Color(0xFFE5E9F0);
const Color _kBg = Color(0xFFF6F8FB);
const Color _kRed = Color(0xFFE11D48);

const List<String> _kCategories = [
  'À la une',
  'Politique',
  'Économie',
  'Société',
  'Tech',
  'Sport',
  'Culture',
  'International',
];

Color _catColor(String c) {
  switch (c.trim().toLowerCase()) {
    case 'politique':
      return const Color(0xFF1D4ED8);
    case 'économie':
    case 'economie':
      return const Color(0xFF15803D);
    case 'société':
    case 'societe':
      return const Color(0xFF7C3AED);
    case 'tech':
      return const Color(0xFF0369A1);
    case 'sport':
      return const Color(0xFFEA580C);
    case 'culture':
      return const Color(0xFFBE185D);
    case 'international':
      return const Color(0xFF0F766E);
    default:
      return _kInk;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MODÈLE + DATA
// ═════════════════════════════════════════════════════════════════════════════
class InfoArticle {
  const InfoArticle({
    required this.id,
    required this.title,
    this.excerpt,
    this.category = '',
    this.imageUrl,
    this.videoUrl,
    this.duration,
    this.views = 0,
    this.kind = 'article',
    this.isFeatured = false,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String? excerpt;
  final String category;
  final String? imageUrl;
  final String? videoUrl;
  final String? duration;
  final int views;
  final String kind;
  final bool isFeatured;
  final DateTime? publishedAt;

  bool get isVideo =>
      kind == 'video' || (videoUrl != null && videoUrl!.trim().isNotEmpty);

  factory InfoArticle.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return InfoArticle(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      excerpt: s(j['excerpt']),
      category: (j['category'] ?? '').toString(),
      imageUrl: s(j['image_url']),
      videoUrl: s(j['video_url']),
      duration: s(j['duration']),
      views: int.tryParse((j['views'] ?? 0).toString()) ?? 0,
      kind: (j['kind'] ?? 'article').toString().toLowerCase(),
      isFeatured: j['is_featured'] == true,
      publishedAt: DateTime.tryParse((j['published_at'] ?? '').toString())
          ?.toLocal(),
    );
  }
}

final infoFeedProvider =
    FutureProvider.autoDispose<List<InfoArticle>>((ref) async {
  final rows = await Supabase.instance.client
      .from('info_articles')
      .select()
      .order('published_at', ascending: false)
      .limit(60);
  return rows
      .map((e) => InfoArticle.fromJson(Map<String, dynamic>.from(e)))
      .where((a) => a.id.isNotEmpty && a.title.isNotEmpty)
      .toList(growable: false);
});

/// Notifications INFO non lues (cloche).
final infoUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return 0;
  try {
    final c = await Supabase.instance.client
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', uid)
        .eq('is_read', false)
        .like('type', 'info%');
    return c;
  } catch (_) {
    return 0;
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════
String _ago(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return '${d.day}/${d.month}/${d.year}';
}

String _views(int n) => n >= 1000
    ? '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')}k vues'
    : '$n vues';

Widget _netImg(String? url, {BoxFit fit = BoxFit.cover}) {
  const ph = ColoredBox(
    color: Color(0xFFE9EDF3),
    child: Center(
      child: Icon(Icons.image_outlined, color: Color(0xFF9AA6B8), size: 26),
    ),
  );
  if (url == null || url.trim().isEmpty) return ph;
  return Image.network(
    url.trim(),
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    frameBuilder: (c, child, frame, sync) => sync
        ? child
        : AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 350),
            child: child),
    errorBuilder: (_, __, ___) => ph,
  );
}

void _go(BuildContext c, String route) {
  try {
    c.push(route);
  } catch (_) {}
}

void _openArticle(BuildContext c, InfoArticle a) =>
    _go(c, '$kInfoArticleRoute/${a.id}');

BoxDecoration _card({double r = 16}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: _kLine),
      boxShadow: [
        BoxShadow(
            color: _kInk.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6)),
      ],
    );

// ═════════════════════════════════════════════════════════════════════════════
// PAGE
// ═════════════════════════════════════════════════════════════════════════════
class ThixInfoHomePage extends ConsumerStatefulWidget {
  const ThixInfoHomePage({super.key});

  @override
  ConsumerState<ThixInfoHomePage> createState() => _ThixInfoHomePageState();
}

class _ThixInfoHomePageState extends ConsumerState<ThixInfoHomePage>
    with WidgetsBindingObserver {
  String _cat = _kCategories.first;
  bool _bannerHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InfoPushBus.tick.addListener(_onInfoPush);
  }

  @override
  void dispose() {
    InfoPushBus.tick.removeListener(_onInfoPush);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onInfoPush() {
    if (!mounted) return;
    ref.invalidate(infoUnreadProvider);
    ref.invalidate(infoFeedProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(infoUnreadProvider);
      ref.invalidate(infoFeedProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(infoUnreadProvider);
    ref.invalidate(infoFeedProvider);
    try {
      await ref.read(infoFeedProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(infoFeedProvider);
    final unread = ref.watch(infoUnreadProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );
    final w = MediaQuery.sizeOf(context).width;
    final side = w >= 900 ? (w - 860) / 2 : 16.0;

    return Scaffold(
      backgroundColor: _kBg,
      bottomNavigationBar: _BottomBar(
        onCategories: () => _go(context, kInfoCategoriesRoute),
        onFeed: () => _go(context, kInfoFeedRoute),
        onFavorites: () => _go(context, kInfoFavoritesRoute),
        onProfile: () => _go(context, kProfileRoute),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _kAmberDark,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 8, side, 24),
            children: [
              _Header(
                unread: unread,
                onMenu: () => _go(context, kInfoCategoriesRoute),
                onBell: () => _go(context, kNotificationsRoute),
                onAvatar: () => _go(context, kProfileRoute),
              ),
              const SizedBox(height: 14),
              _SearchBar(onTap: () => _go(context, kInfoSearchRoute)),
              const SizedBox(height: 14),
              _CategoryChips(
                value: _cat,
                onChanged: (c) => setState(() => _cat = c),
              ),
              const SizedBox(height: 14),
              feed.when(
                loading: () => const _Skeleton(),
                error: (e, _) => _ErrorCard(onRetry: _refresh),
                data: (all) => _content(context, all),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<InfoArticle> all) {
    final filtered = _cat == _kCategories.first
        ? all
        : all
            .where((a) => a.category.toLowerCase() == _cat.toLowerCase())
            .toList();

    if (all.isEmpty) {
      return const _EmptyCard(
          text: 'Aucune actualité publiée pour le moment.');
    }

    final articles = filtered.where((a) => !a.isVideo).toList();
    final videos = filtered.where((a) => a.isVideo).toList();
    final featured = filtered.where((a) => a.isFeatured).take(5).toList();
    final hero = featured.isNotEmpty ? featured : filtered.take(3).toList();
    final ticker = all.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Ticker(article: ticker, onTap: () => _openArticle(context, ticker)),
        const SizedBox(height: 14),
        if (hero.isNotEmpty) ...[
          _HeroCarousel(items: hero),
          const SizedBox(height: 16),
        ],
        _QuickAccess(
          onTap: (r) => _go(context, r),
        ),
        const SizedBox(height: 22),
        if (articles.isNotEmpty) ...[
          _SectionTitle(
              title: 'Actualités récentes',
              onAll: () => _go(context, kInfoFeedRoute)),
          const SizedBox(height: 12),
          SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: articles.length > 12 ? 12 : articles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _NewsCard(
                article: articles[i],
                onTap: () => _openArticle(context, articles[i]),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (!_bannerHidden) ...[
          _AlertsBanner(
            onActivate: () => _go(context, kInfoAlertsRoute),
            onClose: () => setState(() => _bannerHidden = true),
          ),
          const SizedBox(height: 22),
        ],
        if (videos.isNotEmpty) ...[
          _SectionTitle(
              title: 'Vidéos à la une',
              onAll: () => _go(context, kInfoVideosRoute)),
          const SizedBox(height: 12),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: videos.length > 10 ? 10 : videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _VideoCard(
                article: videos[i],
                onTap: () => _openArticle(context, videos[i]),
              ),
            ),
          ),
        ],
        if (filtered.isEmpty)
          _EmptyCard(text: 'Aucune actualité dans « $_cat » pour le moment.'),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EN-TÊTE
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({
    required this.unread,
    required this.onMenu,
    required this.onBell,
    required this.onAvatar,
  });
  final int unread;
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? const <String, dynamic>{};
    final name =
        (meta['full_name'] ?? meta['name'] ?? user?.email ?? 'T').toString();
    final avatar = meta['avatar_url']?.toString();
    final initial = name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase();

    return Row(
      children: [
        IconButton(
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded, color: _kInk, size: 26),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _kAmber,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                  color: _kAmber.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: const Icon(Icons.newspaper_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'THIX ', style: TextStyle(color: _kInk)),
                    TextSpan(text: 'INFO', style: TextStyle(color: _kAmber)),
                  ]),
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.05),
                ),
              ),
              const Text("L'information vraie, partout.",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: _kMuted)),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onBell,
              icon: const Icon(Icons.notifications_none_rounded,
                  color: _kInk, size: 27),
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _kRed,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _kBg, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: onAvatar,
          child: CircleAvatar(
            radius: 21,
            backgroundColor: _kAmber,
            foregroundImage: (avatar != null && avatar.startsWith('http'))
                ? NetworkImage(avatar)
                : null,
            child: Text(initial,
                style: const TextStyle(
                    color: _kInk, fontWeight: FontWeight.w900, fontSize: 17)),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _card(),
        child: const Row(children: [
          Icon(Icons.search_rounded, color: _kMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text('Rechercher une actualité, un sujet…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _kMuted, fontSize: 14.5)),
          ),
          Icon(Icons.tune_rounded, color: _kInk, size: 22),
        ]),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _kCategories[i];
          final on = c == value;
          return InkWell(
            onTap: () => onChanged(c),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? _kAmber : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(c,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: on ? _kInk : _kInk.withValues(alpha: 0.8))),
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BANDEAU EN DIRECT
// ═════════════════════════════════════════════════════════════════════════════
class _Ticker extends StatelessWidget {
  const _Ticker({required this.article, required this.onTap});
  final InfoArticle article;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: _kInk,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _kRed, borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 7, color: Colors.white),
              SizedBox(width: 6),
              Text('EN DIRECT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(article.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CARROUSEL À LA UNE
// ═════════════════════════════════════════════════════════════════════════════
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.items});
  final List<InfoArticle> items;
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pc = PageController();
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_pc.hasClients) return;
        _pc.animateToPage((_i + 1) % widget.items.length,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _step(int d) {
    final n = widget.items.length;
    if (n < 2 || !_pc.hasClients) return;
    _pc.animateToPage((_i + d + n) % n,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    return Container(
      height: 250,
      decoration: _card(r: 20),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PageView.builder(
          controller: _pc,
          itemCount: n,
          onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (_, k) {
            final a = widget.items[k];
            return InkWell(
              onTap: () => _openArticle(context, a),
              child: Stack(fit: StackFit.expand, children: [
                _netImg(a.imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.92),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 18, 30),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.66,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: _kAmber.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                                a.category.isEmpty
                                    ? 'À LA UNE'
                                    : 'À LA UNE · ${a.category.toUpperCase()}',
                                style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: _kAmberDark)),
                          ),
                          const SizedBox(height: 10),
                          Text(a.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  height: 1.18,
                                  letterSpacing: -0.4,
                                  color: _kInk)),
                          if (a.excerpt != null) ...[
                            const SizedBox(height: 6),
                            Text(a.excerpt!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, height: 1.4, color: _kMuted)),
                          ],
                          const SizedBox(height: 8),
                          Text(
                              [
                                _ago(a.publishedAt),
                                if (a.views > 0) _views(a.views)
                              ].where((e) => e.isNotEmpty).join('  ·  '),
                              style: const TextStyle(
                                  fontSize: 11, color: _kMuted)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                                color: _kAmber,
                                borderRadius: BorderRadius.circular(999)),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Lire l'article",
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: _kInk)),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 14, color: _kInk),
                                ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
        if (n > 1) ...[
          Positioned(
              left: 6,
              top: 0,
              bottom: 0,
              child: Center(child: _Arrow(Icons.chevron_left, () => _step(-1)))),
          Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(child: _Arrow(Icons.chevron_right, () => _step(1)))),
          Positioned(
            right: 0,
            left: 0,
            bottom: 10,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var d = 0; d < n; d++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: d == _i ? 22 : 8,
                  height: 5,
                  decoration: BoxDecoration(
                      color: d == _i ? _kAmber : Colors.white70,
                      borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12), blurRadius: 10),
            ],
          ),
          child: Icon(icon, size: 22, color: _kInk),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// ACCÈS RAPIDES
// ═════════════════════════════════════════════════════════════════════════════
class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, Color, String)>[
      ('Fil Info', Icons.dynamic_feed_rounded, const Color(0xFF2563EB),
          kInfoFeedRoute),
      ('Vidéos', Icons.play_circle_fill_rounded, const Color(0xFFE11D48),
          kInfoVideosRoute),
      ('Podcasts', Icons.headphones_rounded, const Color(0xFF7C3AED),
          kInfoPodcastsRoute),
      ('Magazines', Icons.menu_book_rounded, const Color(0xFFEA580C),
          kInfoMagazinesRoute),
      ('Communiqués', Icons.campaign_rounded, const Color(0xFF0369A1),
          kInfoCommuniquesRoute),
      ('Alertes', Icons.notifications_active_rounded, const Color(0xFF16A34A),
          kInfoAlertsRoute),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _card(r: 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          for (final it in items)
            InkWell(
              onTap: () => onTap(it.$4),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: it.$3.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(it.$2, color: it.$3, size: 25),
                  ),
                  const SizedBox(height: 8),
                  Text(it.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kInk)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTIONS
// ═════════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onAll});
  final String title;
  final VoidCallback onAll;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: _kInk)),
        ),
        InkWell(
          onTap: onAll,
          child: const Row(children: [
            Text('Voir tout',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kAmberDark)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: _kAmberDark),
          ]),
        ),
      ]);
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.article, required this.onTap});
  final InfoArticle article;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = article;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 196,
        decoration: _card(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 112,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              _netImg(a.imageUrl),
              if (a.category.isNotEmpty)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _catColor(a.category),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(a.category.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_ago(a.publishedAt),
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                  const SizedBox(height: 6),
                  Text(a.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: _kInk)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(_views(a.views),
                          style:
                              const TextStyle(fontSize: 11, color: _kMuted)),
                    ),
                    const Icon(Icons.bookmark_border_rounded,
                        size: 20, color: _kMuted),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.article, required this.onTap});
  final InfoArticle article;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = article;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 216,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 126,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                _netImg(a.imageUrl),
                Container(color: Colors.black.withValues(alpha: 0.15)),
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: _kInk, size: 28),
                  ),
                ),
                if (a.duration != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(a.duration!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(a.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: _kInk)),
          const SizedBox(height: 5),
          Text(
              [
                if (a.views > 0) _views(a.views),
                _ago(a.publishedAt),
              ].where((e) => e.isNotEmpty).join('  ·  '),
              style: const TextStyle(fontSize: 11, color: _kMuted)),
        ]),
      ),
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.onActivate, required this.onClose});
  final VoidCallback onActivate;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFF4D1), Color(0xFFFFFAEB)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_active_rounded,
              color: _kAmberDark),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Restez informé en temps réel !',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _kInk)),
                const SizedBox(height: 4),
                const Text(
                    'Activez les alertes et ne manquez aucune information importante.',
                    style:
                        TextStyle(fontSize: 12.5, height: 1.4, color: _kInk)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onActivate,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: _kAmber,
                        borderRadius: BorderRadius.circular(999)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Activer les alertes',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _kInk)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: _kInk),
                    ]),
                  ),
                ),
              ]),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: IconButton(
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ÉTATS : chargement / erreur / vide
// ═════════════════════════════════════════════════════════════════════════════
class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: const Color(0xFFE9EDF3),
              borderRadius: BorderRadius.circular(18)),
        );
    return Column(children: [block(44), block(250), block(96), block(220)]);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: _card(),
        child: Column(children: [
          const Icon(Icons.wifi_off_rounded, size: 38, color: _kMuted),
          const SizedBox(height: 12),
          const Text('Impossible de charger les actualités.',
              style: TextStyle(fontWeight: FontWeight.w800, color: _kInk)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
                backgroundColor: _kAmber, foregroundColor: _kInk),
            child: const Text('Réessayer'),
          ),
        ]),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(28),
        decoration: _card(),
        child: Column(children: [
          const Icon(Icons.article_outlined, size: 38, color: _kMuted),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, height: 1.4)),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// BARRE DU BAS
// ═════════════════════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onCategories,
    required this.onFeed,
    required this.onFavorites,
    required this.onProfile,
  });
  final VoidCallback onCategories;
  final VoidCallback onFeed;
  final VoidCallback onFavorites;
  final VoidCallback onProfile;

  Widget _item(IconData icon, String label, bool on, VoidCallback? tap) =>
      Expanded(
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 26, color: on ? _kAmber : _kMuted),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: on ? _kAmber : _kMuted)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 92 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: _kInk.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _item(Icons.home_rounded, 'Accueil', true, null),
        _item(Icons.grid_view_rounded, 'Catégories', false, onCategories),
        Expanded(
          child: InkWell(
            onTap: onFeed,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 66,
                height: 66,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: _kAmber,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _kAmber.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.newspaper_rounded, color: Colors.white, size: 26),
                      SizedBox(height: 2),
                      Text('Fil Info',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
            ),
          ),
        ),
        _item(Icons.bookmark_border_rounded, 'Favoris', false, onFavorites),
        _item(Icons.person_outline_rounded, 'Profil', false, onProfile),
      ]),
    );
  }
}
