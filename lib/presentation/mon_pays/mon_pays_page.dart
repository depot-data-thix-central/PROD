// lib/presentation/mon_pays/mon_pays_page.dart
//
// MonPaysPage — Production Enterprise (Portail Institutionnel RDC)
// VERSION COMPACTE : densité visuelle accrue, éléments réduits ~35%
// Design System ThixPolicy + couleurs patriotiques RDC

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'pages/citizens_page.dart';
import 'providers/news_provider.dart';
import 'providers/provinces_provider.dart';
import 'providers/authorities_provider.dart';
import 'providers/citizens_provider.dart';
import 'pages/news/news_detail_page.dart';
import 'mon_pays_routes.dart';
import 'providers/historical_figures_provider.dart';
import 'pages/historical_figures_page.dart';
import 'providers/hero_banners_provider.dart';
import 'models/hero_banner.dart';
// ============================================================================
// COULEURS PATRIOTIQUES RDC
// ============================================================================
class _MonPaysColors {
  _MonPaysColors._();
  static const Color rdcRed = Color(0xFFCE1126);
  static const Color rdcYellow = ThixPolicy.gold;
  static const Color rdcBlue = ThixPolicy.inkDeep;
  static const Color rdcBlueDeep = Color(0xFF051126);
}

// ============================================================================
// TOKENS COMPACTS (centralisés pour ajustement facile)
// ============================================================================
class _Compact {
  _Compact._();
  // Hauteurs
  static const double topBarHeight = 60;
  static const double heroHeight = 165;
  static const double newsHeight = 165;
  static const double provinceHeight = 74;
  static const double prideHeight = 104;
  static const double dockHeight = 78;
  // Largeurs
  static const double newsCardWidth = 150;
  static const double newsImgHeight = 85;
  static const double provinceCardWidth = 165;
  static const double citizenWidth = 74;
  static const double dockWidth = 82;
  // Avatars
  static const double presidentAvatar = 32;
  static const double authorityAvatar = 26;
  static const double citizenAvatar = 27;
  static const double provinceCoat = 40;
  // Paddings / gaps
  static const double cardPad = 16;
  static const double sectionGap = 20;
  static const double innerGap = 12;
  // Icônes
  static const double institutionIcon = 20;
  static const double dockIcon = 22;
  static const double alertIcon = 20;
}

// ============================================================================
// PROVIDER ADMIN
// ============================================================================
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = (res?['role'] ?? '').toString().toLowerCase();
    return role == 'admin' || role == 'super_admin';
  } catch (e) {
    if (kDebugMode) debugPrint('[MonPays] Admin check failed: $e');
    return false;
  }
});

// ============================================================================
// PAGE
// ============================================================================
class MonPaysPage extends ConsumerStatefulWidget {
  const MonPaysPage({super.key});

  @override
  ConsumerState<MonPaysPage> createState() => _MonPaysPageState();
}

class _MonPaysPageState extends ConsumerState<MonPaysPage>
    with WidgetsBindingObserver {
  final PageController _heroCtrl = PageController(viewportFraction: 0.95);
  final ScrollController _scrollCtrl = ScrollController();

  Timer? _carouselTimer;
  int _currentHero = 0;
  bool _isBackgrounded = false;
  int _slideCount = 0;

  final List<Map<String, String?>> heroSlides = [
    {
      'title': 'Unité Nationale',
      'subtitle': 'Bendele ya Congo',
      'img': null, // ✅ Dégradé premium automatique
      'tag': 'PATRIOTISME',
    },
    {
      'title': 'Devoir Civique',
      'subtitle': 'S\'engager pour la Patrie',
      'img': null, // ✅ Dégradé premium automatique
      'tag': 'CITOYENNETÉ',
    },
    {
      'title': 'Mémoire Collective',
      'subtitle': 'Honorer nos Héros',
      'img': null, // ✅ Dégradé premium automatique
      'tag': 'HISTOIRE',
    },
    {
      'title': 'Travail et Progrès',
      'subtitle': 'Bâtir la RDC',
      'img': null, // ✅ Dégradé premium automatique
      'tag': 'DÉVELOPPEMENT',
    },
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCarousel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carouselTimer?.cancel();
    _heroCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackgrounded = state != AppLifecycleState.resumed;
    if (_isBackgrounded) {
      _carouselTimer?.cancel();
    } else {
      _startCarousel();
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (_heroCtrl.hasClients && !_isBackgrounded && mounted && _slideCount > 0) {
        _currentHero = (_currentHero + 1) % _slideCount;
        _heroCtrl.animateToPage(
          _currentHero,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _navigateTo(String route) {
    HapticFeedback.lightImpact();
    try {
      context.push(route);
    } catch (_) {
      _showErrorSnackBar('Navigation impossible');
    }
  }

  void _showComingSoon() {
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.construction_rounded, color: ThixPolicy.onBrand, size: 18),
            const SizedBox(width: ThixPolicy.s10),
            Text(
              l10n.t('common_coming_soon'),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.onBrand),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: ThixPolicy.onBrand, size: 18),
            const SizedBox(width: ThixPolicy.s10),
            Expanded(
              child: Text(message, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.onBrand)),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: 110,
            right: -90,
            child: Opacity(
              opacity: 0.02,
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Democratic_Republic_of_the_Congo_location_map.svg/1024px-Democratic_Republic_of_the_Congo_location_map.svg.png',
                width: 420,
                color: ThixPolicy.inkDeep,
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildTopBar(isAdmin),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      const SizedBox(height: ThixPolicy.s10),
                      _buildHeroCarousel(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildAuthoritiesSection(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildNewsSection(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildInstitutionsGrid(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildProvincesCarousel(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildPrideSection(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildQuickAccessDock(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildAlertsRow(),
                      const SizedBox(height: _Compact.sectionGap),
                      _buildHistoricalFigures(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TOP BAR ───────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: _Compact.topBarHeight,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: ThixPolicy.card.withOpacity(0.85),
              border: Border(
                bottom: BorderSide(color: ThixPolicy.border.withOpacity(0.6), width: 1),
              ),
            ),
          ),
        ),
      ),
      title: Semantics(
        header: true,
        child: Row(
          children: [
            const Icon(Icons.menu_rounded, color: ThixPolicy.inkDeep, size: 22),
            const SizedBox(width: ThixPolicy.s12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: ThixPolicy.brandGradient,
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Text(
                'CD',
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.onBrand,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: ThixPolicy.s10),
            Expanded(
              child: Text(
                'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
                maxLines: 2,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            _buildCircleButton(Icons.search_rounded, () => _showComingSoon()),
            const SizedBox(width: ThixPolicy.s10),
            _buildCircleButton(Icons.notifications_none_rounded, () {}, hasBadge: true),
            if (isAdmin) ...[
              const SizedBox(width: ThixPolicy.s10),
              _buildAdminButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {bool hasBadge = false}) {
    return Semantics(
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.card,
                border: Border.all(color: ThixPolicy.border, width: 1),
              ),
              child: Icon(icon, size: 17, color: ThixPolicy.inkDeep),
            ),
          ),
          if (hasBadge)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ThixPolicy.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.card, width: 1.5),
                ),
                child: Text(
                  '3',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminButton() {
    return Semantics(
      button: true,
      label: 'Espace Admin',
      child: InkWell(
        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
        onTap: () => _navigateTo('/mon-pays/admin'),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _MonPaysColors.rdcRed.withOpacity(0.1),
            border: Border.all(color: _MonPaysColors.rdcRed.withOpacity(0.2), width: 1),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded, color: _MonPaysColors.rdcRed, size: 17),
        ),
      ),
    );
  }

  
  // ─── HERO CAROUSEL ─────────────────────────────────────────────────────
  Widget _buildHeroCarousel() {
    final banners = ref.watch(heroBannersProvider).valueOrNull ?? const <HeroBanner>[];

    // Construit la liste avec typage explicite
    final List<Map<String, String?>> slides = <Map<String, String?>>[];
    
    if (banners.isNotEmpty) {
      for (final b in banners) {
        slides.add({
          'tag': b.tag,
          'title': b.title,
          'subtitle': b.subtitle,
          'img': b.imageUrl,
        });
      }
    } else {
      for (final s in heroSlides) {
        slides.add({
          'tag': s['tag'],
          'title': s['title'],
          'subtitle': s['subtitle'],
          'img': null, // force le dégradé premium (Unsplash cassé)
        });
      }
    }

    // Synchronise le compteur pour le timer
    if (_slideCount != slides.length) {
      _slideCount = slides.length;
      if (_currentHero >= _slideCount) _currentHero = 0;
    }

    return SizedBox(
      height: _Compact.heroHeight,
      child: PageView.builder(
        controller: _heroCtrl,
        itemCount: slides.length,
        onPageChanged: (index) => setState(() => _currentHero = index),
        itemBuilder: (context, index) {
          final slide = slides[index];
          final rawImg = slide['img'];
          final imgUrl = (rawImg == null ||
                  rawImg.trim().isEmpty ||
                  !(rawImg.startsWith('http://') || rawImg.startsWith('https://')))
              ? null
              : rawImg;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ Image réseau OU dégradé premium (jamais d'image cassée)
                  imgUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 400),
                          placeholder: (_, __) => _heroGradientFallback(),
                          errorWidget: (_, __, ___) => _heroGradientFallback(),
                        )
                      : _heroGradientFallback(),

                  // Overlay dégradé lisibilité
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _MonPaysColors.rdcBlueDeep.withOpacity(0.95),
                        ],
                        stops: const [0.35, 1.0],
                      ),
                    ),
                  ),

                  // Contenu texte
                  Positioned(
                    bottom: ThixPolicy.s16,
                    left: ThixPolicy.s16,
                    right: ThixPolicy.s16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ThixPolicy.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (slide['tag'] ?? 'RDC').toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: ThixPolicy.inkDeep,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: ThixPolicy.s8),
                        Text(
                          slide['title'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.h2Style.copyWith(
                            color: ThixPolicy.onBrand,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if ((slide['subtitle'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            slide['subtitle']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.captionStyle
                                .copyWith(color: Colors.white.withOpacity(0.85)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Indicateurs de pagination
                  Positioned(
                    bottom: ThixPolicy.s8,
                    right: ThixPolicy.s16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(left: 4),
                          width: i == _currentHero ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _currentHero
                                ? ThixPolicy.gold
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
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
  /// 🎨 Fond de secours premium : dégradé bleu nuit + bande rouge + étoile dorée
  Widget _heroGradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF12234F),
            _MonPaysColors.rdcBlueDeep,
            Color(0xFF050D1F),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Bande diagonale rouge (rappel drapeau RDC)
          Positioned(
            right: -30,
            top: -30,
            child: Transform.rotate(
              angle: 0.6,
              child: Container(
                width: 220,
                height: 34,
                color: _MonPaysColors.rdcRed.withOpacity(0.35),
              ),
            ),
          ),
          // Étoile dorée (symbole du drapeau)
          Positioned(
            right: 18,
            bottom: 34,
            child: Icon(
              Icons.star_rounded,
              size: 110,
              color: ThixPolicy.gold.withOpacity(0.18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AUTORITÉS (CLASSEMENT PRÉSERVÉ) ───────────────────────────────────
  Widget _buildAuthoritiesSection() {
    final authAsync = ref.watch(topAuthoritiesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Les Hautes Autorités',
              actionText: 'Annuaire',
              onTap: () => _navigateTo('/mon-pays/authorities'),
            ),
            const SizedBox(height: _Compact.innerGap),
            authAsync.when(
              loading: () => _buildSkeletonCard(height: 190),
              error: (_, __) => _buildErrorState(
                'Erreur de chargement',
                onRetry: () => ref.invalidate(topAuthoritiesProvider),
              ),
              data: (authorities) {
                if (authorities.isEmpty) {
                  return _buildEmptyState('Aucune autorité enregistrée');
                }

                int getPriority(String? title) {
                  final t = (title ?? '').toLowerCase();
                  if (t.contains('république') || t.contains('republique')) return 1;
                  if (t.contains('premier') || t.contains('première')) return 2;
                  if (t.contains('sénat') || t.contains('senat')) return 3;
                  if (t.contains('assemblée') || t.contains('assemblee')) return 4;
                  return 99;
                }

                final sortedList = authorities
                  ..sort((a, b) => getPriority(a.title).compareTo(getPriority(b.title)));

                final president = sortedList.first;
                final others = sortedList.length > 1 ? sortedList.sublist(1).take(3).toList() : [];

                return Column(
                  children: [
                    _buildPresidentCard(president),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: _Compact.innerGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: others.map((a) => Expanded(child: _buildAuthorityCard(a))).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresidentCard(dynamic president) {
    final imgUrl = president.imageUrl ?? 'https://i.pravatar.cc/200';

    return Semantics(
      button: true,
      label: 'Président de la République: ${president.name}',
      child: InkWell(
        onTap: () => _navigateTo('/mon-pays/authorities/${president.id}'),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          padding: const EdgeInsets.all(ThixPolicy.s12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.gold.withOpacity(0.6), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [ThixPolicy.inkDeep, _MonPaysColors.rdcRed, ThixPolicy.gold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: _Compact.presidentAvatar,
                  backgroundColor: ThixPolicy.card,
                  backgroundImage: CachedNetworkImageProvider(imgUrl),
                ),
              ),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _MonPaysColors.rdcBlueDeep,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PRÉSIDENT DE LA RÉPUBLIQUE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: ThixPolicy.gold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s6),
                    Text(
                      president.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.titleStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: ThixPolicy.inkDeep,
                      ),
                    ),
                    if (president.title != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        president.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.microStyle,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ThixPolicy.inkDeep, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorityCard(dynamic authority) {
    final imgUrl = authority.imageUrl ?? 'https://i.pravatar.cc/100';

    return Semantics(
      button: true,
      label: '${authority.name}, ${authority.title}',
      child: InkWell(
        onTap: () => _navigateTo('/mon-pays/authorities/${authority.id}'),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s6),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.border, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: _Compact.authorityAvatar,
                  backgroundColor: ThixPolicy.card,
                  backgroundImage: CachedNetworkImageProvider(imgUrl),
                ),
              ),
              const SizedBox(height: ThixPolicy.s8),
              Text(
                authority.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                authority.title ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ThixPolicy.microStyle.copyWith(height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── À LA UNE ──────────────────────────────────────────────────────────
  Widget _buildNewsSection() {
    final newsState = ref.watch(newsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'À la Une',
              actionText: 'Tout lire',
              onTap: () => _navigateTo('/mon-pays/news'),
            ),
            const SizedBox(height: _Compact.innerGap),
            SizedBox(
              height: _Compact.newsHeight,
              child: newsState.when(
                loading: () => _buildSkeletonCard(height: _Compact.newsHeight),
                error: (e, _) => _buildErrorState(
                  'Erreur de chargement des actualités',
                  onRetry: () => ref.invalidate(newsProvider),
                ),
                data: (articles) {
                  if (articles.isEmpty) {
                    return _buildEmptyState('Aucune actualité disponible');
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
                    itemBuilder: (context, i) => _buildNewsCard(articles[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(dynamic article) {
    final imgUrl = article.coverImageUrl;
    final dateStr = article.publishedAt != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(article.publishedAt!)
        : '';

    return Semantics(
      button: true,
      label: article.title,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NewsDetailPage(article: article)),
        ),
        child: Container(
          width: _Compact.newsCardWidth,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: ThixPolicy.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: imgUrl != null && imgUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgUrl,
                        height: _Compact.newsImgHeight,
                        width: _Compact.newsCardWidth,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: _Compact.newsImgHeight,
                          width: _Compact.newsCardWidth,
                          color: ThixPolicy.surfaceSoft,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: _Compact.newsImgHeight,
                          width: _Compact.newsCardWidth,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.newspaper_rounded, color: ThixPolicy.textMuted, size: 28),
                        ),
                      )
                    : Container(
                        height: _Compact.newsImgHeight,
                        width: _Compact.newsCardWidth,
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.newspaper_rounded, color: ThixPolicy.textMuted, size: 28),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(ThixPolicy.s10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: _MonPaysColors.rdcRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
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

  // ─── INSTITUTIONS ──────────────────────────────────────────────────────
  Widget _buildInstitutionsGrid() {
    final items = [
      {'icon': Icons.account_balance_rounded, 'label': 'Présidence'},
      {'icon': Icons.flag_rounded, 'label': 'Gouvernement'},
      {'icon': Icons.gavel_rounded, 'label': 'Parlement'},
      {'icon': Icons.work_rounded, 'label': 'Ministères'},
      {'icon': Icons.business_rounded, 'label': 'Entreprises'},
      {'icon': Icons.shield_rounded, 'label': 'Sécurité'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          children: [
            _buildSectionHeader(
              'Institutions',
              actionText: 'Explorer',
              onTap: () => _showComingSoon(),
            ),
            const SizedBox(height: _Compact.innerGap),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.15,
                crossAxisSpacing: ThixPolicy.s10,
                mainAxisSpacing: ThixPolicy.s10,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _buildInstitutionTile(items[i]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionTile(Map<String, dynamic> item) {
    return Semantics(
      button: true,
      label: item['label'] as String,
      child: InkWell(
        onTap: _showComingSoon,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: ThixPolicy.card, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s10),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  shape: BoxShape.circle,
                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
                ),
                child: Icon(item['icon'] as IconData, color: ThixPolicy.inkDeep, size: _Compact.institutionIcon),
              ),
              const SizedBox(height: ThixPolicy.s8),
              Text(
                item['label'] as String,
                textAlign: TextAlign.center,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PROVINCES ─────────────────────────────────────────────────────────
  Widget _buildProvincesCarousel() {
    final prov = ref.watch(provincesProvider(null));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          children: [
            _buildSectionHeader(
              'Découpage Territorial',
              actionText: 'Carte',
              onTap: () => _navigateTo('/mon-pays/provinces'),
            ),
            const SizedBox(height: _Compact.innerGap),
            SizedBox(
              height: _Compact.provinceHeight,
              child: prov.when(
                loading: () => _buildSkeletonCard(height: _Compact.provinceHeight),
                error: (_, __) => _buildErrorState('Erreur de chargement'),
                data: (list) {
                  if (list.isEmpty) return _buildEmptyState('Aucune province disponible');
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
                    itemBuilder: (c, i) => _buildProvinceCard(list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvinceCard(dynamic p) {
    final coatUrl = p.coatOfArmsUrl;

    return Semantics(
      button: true,
      label: 'Province: ${p.name}, Capitale: ${p.capital}',
      child: InkWell(
        onTap: () => _navigateTo('/mon-pays/provinces/${p.id}'),
        child: Container(
          width: _Compact.provinceCardWidth,
          padding: const EdgeInsets.all(ThixPolicy.s10),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: ThixPolicy.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: _Compact.provinceCoat,
                height: _Compact.provinceCoat,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surfaceSoft,
                  border: Border.all(color: ThixPolicy.border, width: 1),
                  image: coatUrl != null && coatUrl.isNotEmpty
                      ? DecorationImage(image: CachedNetworkImageProvider(coatUrl), fit: BoxFit.contain)
                      : null,
                ),
                child: (coatUrl == null || coatUrl.isEmpty)
                    ? Center(
                        child: Text(
                          p.code.substring(0, 2),
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.inkDeep,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: ThixPolicy.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.capital,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.microStyle,
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

  // ─── FIERTÉ DE LA NATION ───────────────────────────────────────────────
  Widget _buildPrideSection() {
    final l10n = AppLocalizations.of(context);
    final citizensAsync = ref.watch(citizensProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              l10n.t('mon_pays_citizens_title'),
              actionText: 'Tous les profils',
              onTap: () => _navigateTo(MonPaysRoutes.citizens),
            ),
            const SizedBox(height: 4),
            Text(
              'Ils bâtissent la RDC au quotidien par leur excellence.',
              style: ThixPolicy.microStyle,
            ),
            const SizedBox(height: _Compact.innerGap),
            SizedBox(
              height: _Compact.prideHeight,
              child: citizensAsync.when(
                loading: () => _buildSkeletonCard(height: _Compact.prideHeight),
                error: (e, _) => _buildErrorState(
                  l10n.t('mon_pays_citizens_error'),
                  onRetry: () => ref.invalidate(citizensProvider),
                ),
                data: (citizens) {
                  if (citizens.isEmpty) {
                    return _buildEmptyState(l10n.t('mon_pays_citizens_empty'));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: citizens.length,
                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                    itemBuilder: (context, i) {
                      final citizen = citizens[i];
                      return InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showCitizenDetailSheet(context, citizen);
                        },
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        child: _buildCitizenCard(citizen),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitizenCard(dynamic citizen) {
    final photoUrl = citizen.photoUrl;

    return Semantics(
      button: true,
      label: '${citizen.fullName}, ${citizen.domain}',
      child: SizedBox(
        width: _Compact.citizenWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold, width: 2),
              ),
              child: CircleAvatar(
                radius: _Compact.citizenAvatar,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person_rounded, color: ThixPolicy.inkDeep, size: 22)
                    : null,
              ),
            ),
            const SizedBox(height: ThixPolicy.s6),
            Text(
              citizen.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.inkDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              citizen.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: _MonPaysColors.rdcRed, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACCÈS RAPIDES ─────────────────────────────────────────────────────
  Widget _buildQuickAccessDock() {
    final items = [
      {'icon': Icons.play_circle_filled_rounded, 'label': 'Vidéos'},
      {'icon': Icons.folder_shared_rounded, 'label': 'Documents'},
      {'icon': Icons.account_balance_rounded, 'label': 'Lois', 'route': '/mon-pays/laws'},
      {'icon': Icons.campaign_rounded, 'label': 'Participer'},
    ];

    return SizedBox(
      height: _Compact.dockHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          return Semantics(
            button: true,
            label: item['label'] as String,
            child: InkWell(
              onTap: () => route != null ? _navigateTo(route) : _showComingSoon(),
              child: Container(
                width: _Compact.dockWidth,
                padding: const EdgeInsets.all(ThixPolicy.s10),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.border, width: 1),
                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData, color: ThixPolicy.inkDeep, size: _Compact.dockIcon),
                    const SizedBox(height: ThixPolicy.s6),
                    Text(
                      item['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── ALERTES ───────────────────────────────────────────────────────────
  Widget _buildAlertsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          Expanded(
            child: _buildAlertCard(
              _MonPaysColors.rdcRed,
              'Personne\nRecherchée',
              Icons.warning_amber_rounded,
            ),
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: _buildAlertCard(
              ThixPolicy.inkDeep,
              'Recherche\nCitoyenne',
              Icons.person_search_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Color color, String title, IconData icon) {
    return Semantics(
      button: true,
      label: title.replaceAll('\n', ' '),
      child: InkWell(
        onTap: _showComingSoon,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: _buildCard(
          padding: const EdgeInsets.all(ThixPolicy.s12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: _Compact.alertIcon),
              ),
              const SizedBox(width: ThixPolicy.s10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FIGURES HISTORIQUES ───────────────────────────────────────────────
  Widget _buildHistoricalFigures() {
    final l10n = AppLocalizations.of(context);
    final figuresAsync = ref.watch(historicalFiguresProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              l10n.t('mon_pays_figures_title'),
              actionText: l10n.t('mon_pays_figures_explore'),
              onTap: () => _navigateTo(MonPaysRoutes.historicalFigures),
            ),
            const SizedBox(height: 4),
            Text(l10n.t('mon_pays_figures_subtitle'), style: ThixPolicy.microStyle),
            const SizedBox(height: _Compact.innerGap),
            SizedBox(
              height: 150,
              child: figuresAsync.when(
                loading: () => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => Container(
                    width: 110,
                    decoration: BoxDecoration(
                      color: ThixPolicy.surfaceStrong,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    ),
                  ),
                ),
                error: (_, __) => Center(
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(historicalFiguresProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.t('common_retry'),
                        style: ThixPolicy.captionStyle),
                  ),
                ),
                data: (figures) {
                  if (figures.isEmpty) {
                    return Center(
                      child: Text(l10n.t('mon_pays_figures_empty'),
                          style: ThixPolicy.captionStyle),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: figures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) =>
                        HistoricalFigureTile(figure: figures[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UTILITAIRES ───────────────────────────────────────────────────────
  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(_Compact.cardPad),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.card, width: 1.5),
        boxShadow: ThixPolicy.shadowCard(opacity: 0.04),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _MonPaysColors.rdcRed,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: ThixPolicy.s10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ThixPolicy.h3Style.copyWith(
              color: ThixPolicy.inkDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionText != null && onTap != null)
          Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ThixPolicy.inkDeep.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText,
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: ThixPolicy.inkDeep),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonCard({double height = 80}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceStrong,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
      ),
    );
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: ThixPolicy.danger, size: 34),
          const SizedBox(height: ThixPolicy.s10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: ThixPolicy.s10),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 34),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: ThixPolicy.textMuted, size: 34),
          const SizedBox(height: ThixPolicy.s10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
          ),
        ],
      ),
    );
  }
}
