// lib/presentation/mon_pays/mon_pays_page.dart
//
// MonPaysPage — Production Enterprise (Portail Institutionnel RDC)
// Utilise ThixPolicy comme source unique de vérité visuelle
//
// Design : "Presidential Portal" — Premium & Institutionnel
// Couleurs patriotiques RDC préservées (rouge/jaune/bleu)
// Typographie, ombres, rayons, espacements = ThixPolicy

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

// ✅ Design System THIX
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ✅ Providers
import 'providers/news_provider.dart';
import 'providers/provinces_provider.dart';
import 'providers/authorities_provider.dart';
import 'providers/citizens_provider.dart';
import 'pages/news/news_detail_page.dart';

// ============================================================================
// COULEURS PATRIOTIQUES RDC
// ============================================================================
//
// Ces couleurs sont spécifiques au module "Mon Pays" et ne font PAS partie
// du Design System THIX global. Elles représentent l'identité nationale.
// Le bleu RDC (#0A1F44) est identique à ThixPolicy.inkDeep.
// ============================================================================

class _MonPaysColors {
  _MonPaysColors._();
  static const Color rdcRed = Color(0xFFCE1126);
  static const Color rdcYellow = ThixPolicy.gold; // Réutilisé du DS
  static const Color rdcBlue = ThixPolicy.inkDeep; // Réutilisé du DS
  static const Color rdcBlueDeep = Color(0xFF051126);
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
  } catch (e, stack) {
    if (kDebugMode) debugPrint('[MonPays] Admin check failed: $e');
    return false;
  }
});

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class MonPaysPage extends ConsumerStatefulWidget {
  const MonPaysPage({super.key});

  @override
  ConsumerState<MonPaysPage> createState() => _MonPaysPageState();
}

class _MonPaysPageState extends ConsumerState<MonPaysPage>
    with WidgetsBindingObserver {
  // ─── Controllers ───
  final PageController _heroCtrl = PageController(viewportFraction: 0.95);
  final ScrollController _scrollCtrl = ScrollController();

  // ─── State ───
  Timer? _carouselTimer;
  int _currentHero = 0;
  bool _isBackgrounded = false;

  final List<Map<String, String>> heroSlides = [
    {
      'title': 'Unité Nationale',
      'subtitle': 'Bendele ya Congo',
      'img': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200',
      'tag': 'PATRIOTISME',
    },
    {
      'title': 'Devoir Civique',
      'subtitle': 'S\'engager pour la Patrie',
      'img': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=1200',
      'tag': 'CITOYENNETÉ',
    },
    {
      'title': 'Mémoire Collective',
      'subtitle': 'Honorer nos Héros',
      'img': 'https://images.unsplash.com/photo-1497895121-66bdc4d7d3b2?w=1200',
      'tag': 'HISTOIRE',
    },
    {
      'title': 'Travail et Progrès',
      'subtitle': 'Bâtir la RDC',
      'img': 'https://images.unsplash.com/photo-1516026672322-bc52d61a55e5?w=1200',
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
      if (_heroCtrl.hasClients && !_isBackgrounded && mounted) {
        _currentHero = (_currentHero + 1) % heroSlides.length;
        _heroCtrl.animateToPage(
          _currentHero,
          duration: const Duration(milliseconds: 800),
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
            const Icon(Icons.construction_rounded, color: ThixPolicy.onBrand, size: 20),
            const SizedBox(width: ThixPolicy.s12),
            Text(
              l10n.t('common_coming_soon'),
              style: ThixPolicy.bodyMediumStyle.copyWith(color: ThixPolicy.onBrand),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: ThixPolicy.onBrand, size: 20),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Text(message, style: ThixPolicy.bodyMediumStyle.copyWith(color: ThixPolicy.onBrand)),
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
          // Filigrane carte RDC (subtile, 2% opacité)
          Positioned(
            top: 150,
            right: -100,
            child: Opacity(
              opacity: 0.02,
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Democratic_Republic_of_the_Congo_location_map.svg/1024px-Democratic_Republic_of_the_Congo_location_map.svg.png',
                width: 550,
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
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Column(
                    children: [
                      const SizedBox(height: ThixPolicy.s16),
                      _buildHeroCarousel(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildAuthoritiesSection(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildNewsSection(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildInstitutionsGrid(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildProvincesCarousel(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildPrideSection(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildQuickAccessDock(),
                      const SizedBox(height: ThixPolicy.s32),
                      _buildAlertsRow(),
                      const SizedBox(height: ThixPolicy.s32),
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

  // ============================================================================
  // TOP BAR (Glassmorphism)
  // ============================================================================

  Widget _buildTopBar(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: ThixPolicy.card.withOpacity(0.85),
              border: Border(
                bottom: BorderSide(
                  color: ThixPolicy.border.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
            ),
          ),
        ),
      ),
      title: Semantics(
        header: true,
        child: Row(
          children: [
            const Icon(Icons.menu_rounded, color: ThixPolicy.inkDeep, size: 28),
            const SizedBox(width: ThixPolicy.s16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: ThixPolicy.brandGradient,
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.primary),
              ),
              child: Text(
                'CD',
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.onBrand,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Text(
                'RÉPUBLIQUE DÉMOCRATIQUE\nDU CONGO',
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            _buildCircleButton(Icons.search_rounded, () => _showComingSoon()),
            const SizedBox(width: ThixPolicy.s12),
            _buildCircleButton(Icons.notifications_none_rounded, () {}, hasBadge: true),
            if (isAdmin) ...[
              const SizedBox(width: ThixPolicy.s12),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.card,
                border: Border.all(color: ThixPolicy.border, width: 1.5),
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
              ),
              child: Icon(icon, size: 20, color: ThixPolicy.inkDeep),
            ),
          ),
          if (hasBadge)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: ThixPolicy.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.card, width: 2),
                  boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.gold),
                ),
                child: Text(
                  '3',
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.inkDeep,
                    fontWeight: FontWeight.w900,
                  ),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _MonPaysColors.rdcRed.withOpacity(0.1),
            border: Border.all(
              color: _MonPaysColors.rdcRed.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: _MonPaysColors.rdcRed,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // HERO CAROUSEL
  // ============================================================================

  Widget _buildHeroCarousel() {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _heroCtrl,
        itemCount: heroSlides.length,
        onPageChanged: (index) => setState(() => _currentHero = index),
        itemBuilder: (context, index) {
          final slide = heroSlides[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rXl),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: slide['img']!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: ThixPolicy.surfaceStrong,
                      child: const Center(
                        child: CircularProgressIndicator(color: ThixPolicy.primary),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: ThixPolicy.surfaceStrong,
                      child: const Icon(Icons.image_not_supported, color: ThixPolicy.textMuted, size: 48),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _MonPaysColors.rdcBlueDeep.withOpacity(0.95),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: ThixPolicy.s24,
                    left: ThixPolicy.s24,
                    right: ThixPolicy.s24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ThixPolicy.gold,
                            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                            boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.gold),
                          ),
                          child: Text(
                            slide['tag']!.toUpperCase(),
                            style: ThixPolicy.microStyle.copyWith(
                              color: ThixPolicy.inkDeep,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: ThixPolicy.s12),
                        Text(
                          slide['title']!,
                          style: ThixPolicy.displayStyle.copyWith(
                            color: ThixPolicy.onBrand,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: ThixPolicy.s6),
                        Text(
                          slide['subtitle']!,
                          style: ThixPolicy.bodyStyle.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: ThixPolicy.s12,
                    right: ThixPolicy.s24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        heroSlides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(left: 6),
                          width: i == _currentHero ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _currentHero
                                ? ThixPolicy.gold
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
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

  // ============================================================================
  // AUTHORITIES SECTION (CLASSEMENT PRÉSERVÉ)
  // ============================================================================

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
            const SizedBox(height: ThixPolicy.s24),
            authAsync.when(
              loading: () => _buildSkeletonCard(height: 280),
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
                    const SizedBox(height: ThixPolicy.s24),
                    if (others.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: others.map((a) => Expanded(child: _buildAuthorityCard(a))).toList(),
                      ),
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
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: Container(
          padding: const EdgeInsets.all(ThixPolicy.s16),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(
              color: ThixPolicy.gold.withOpacity(0.6),
              width: 2,
            ),
            boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.gold),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ThixPolicy.inkDeep,
                      _MonPaysColors.rdcRed,
                      ThixPolicy.gold,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: ThixPolicy.card,
                  backgroundImage: CachedNetworkImageProvider(imgUrl),
                ),
              ),
              const SizedBox(width: ThixPolicy.s20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _MonPaysColors.rdcBlueDeep,
                        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                      ),
                      child: Text(
                        'PRÉSIDENT DE LA RÉPUBLIQUE',
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    Text(
                      president.name,
                      style: ThixPolicy.h2Style.copyWith(
                        fontSize: 20,
                        color: ThixPolicy.inkDeep,
                      ),
                    ),
                    if (president.title != null) ...[
                      const SizedBox(height: ThixPolicy.s6),
                      Text(
                        president.title,
                        style: ThixPolicy.captionStyle,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ThixPolicy.inkDeep,
                size: 24,
              ),
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
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Padding(
          padding: const EdgeInsets.all(ThixPolicy.s8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.border, width: 2),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: ThixPolicy.card,
                  backgroundImage: CachedNetworkImageProvider(imgUrl),
                ),
              ),
              const SizedBox(height: ThixPolicy.s12),
              Text(
                authority.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                ),
              ),
              const SizedBox(height: ThixPolicy.s4),
              Text(
                authority.title ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ThixPolicy.microStyle.copyWith(height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // NEWS SECTION
  // ============================================================================

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
            const SizedBox(height: ThixPolicy.s20),
            SizedBox(
              height: 200,
              child: newsState.when(
                loading: () => _buildSkeletonCard(height: 200),
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
                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
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
          width: 180,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border, width: 1.5),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: imgUrl != null && imgUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgUrl,
                        height: 110,
                        width: 180,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 110,
                          width: 180,
                          color: ThixPolicy.surfaceSoft,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 110,
                          width: 180,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.newspaper_rounded, color: ThixPolicy.textMuted, size: 40),
                        ),
                      )
                    : Container(
                        height: 110,
                        width: 180,
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.newspaper_rounded, color: ThixPolicy.textMuted, size: 40),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(ThixPolicy.s14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr.toUpperCase(),
                        style: ThixPolicy.microStyle.copyWith(
                          color: _MonPaysColors.rdcRed,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    const SizedBox(height: ThixPolicy.s6),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        height: 1.3,
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

  // ============================================================================
  // INSTITUTIONS GRID
  // ============================================================================

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
            const SizedBox(height: ThixPolicy.s24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: ThixPolicy.s14,
                mainAxisSpacing: ThixPolicy.s14,
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
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.card, width: 2),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  shape: BoxShape.circle,
                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: ThixPolicy.inkDeep,
                  size: 24,
                ),
              ),
              const SizedBox(height: ThixPolicy.s10),
              Text(
                item['label'] as String,
                textAlign: TextAlign.center,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // PROVINCES
  // ============================================================================

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
            const SizedBox(height: ThixPolicy.s20),
            SizedBox(
              height: 90,
              child: prov.when(
                loading: () => _buildSkeletonCard(height: 90),
                error: (_, __) => _buildErrorState('Erreur de chargement'),
                data: (list) {
                  if (list.isEmpty) return _buildEmptyState('Aucune province disponible');
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s14),
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
          width: 200,
          padding: const EdgeInsets.all(ThixPolicy.s14),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border, width: 1.5),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surfaceSoft,
                  border: Border.all(color: ThixPolicy.border, width: 1.5),
                  image: coatUrl != null && coatUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(coatUrl),
                          fit: BoxFit.contain,
                        )
                      : null,
                ),
                child: (coatUrl == null || coatUrl.isEmpty)
                    ? Center(
                        child: Text(
                          p.code.substring(0, 2),
                          style: ThixPolicy.labelStyle.copyWith(
                            color: ThixPolicy.inkDeep,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: ThixPolicy.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s4),
                    Text(
                      p.capital,
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

  // ============================================================================
  // PRIDE SECTION
  // ============================================================================

  Widget _buildPrideSection() {
    final citizensAsync = ref.watch(citizensProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Fierté de la Nation',
              actionText: 'Tous les profils',
              onTap: () => _showComingSoon(),
            ),
            const SizedBox(height: ThixPolicy.s8),
            Text(
              'Ils bâtissent la RDC au quotidien par leur excellence.',
              style: ThixPolicy.bodySmallStyle,
            ),
            const SizedBox(height: ThixPolicy.s24),
            SizedBox(
              height: 130,
              child: citizensAsync.when(
                loading: () => _buildSkeletonCard(height: 130),
                error: (_, __) => _buildErrorState('Erreur de chargement'),
                data: (citizens) {
                  if (citizens.isEmpty) {
                    return _buildEmptyState('Aucun profil pour le moment');
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: citizens.length,
                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s18 = 18),
                    itemBuilder: (context, i) => _buildCitizenCard(citizens[i]),
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
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold, width: 2.5),
                boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.gold),
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person_rounded, color: ThixPolicy.inkDeep, size: 32)
                    : null,
              ),
            ),
            const SizedBox(height: ThixPolicy.s10),
            Text(
              citizen.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ThixPolicy.labelStyle.copyWith(
                color: ThixPolicy.inkDeep,
              ),
            ),
            const SizedBox(height: ThixPolicy.s4),
            Text(
              citizen.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ThixPolicy.microStyle.copyWith(
                color: _MonPaysColors.rdcRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // QUICK ACCESS DOCK
  // ============================================================================

  Widget _buildQuickAccessDock() {
    final items = [
      {'icon': Icons.play_circle_filled_rounded, 'label': 'Vidéos'},
      {'icon': Icons.folder_shared_rounded, 'label': 'Documents'},
      {'icon': Icons.account_balance_rounded, 'label': 'Lois', 'route': '/mon-pays/laws'},
      {'icon': Icons.campaign_rounded, 'label': 'Participer'},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s14),
        itemBuilder: (c, i) {
          final item = items[i];
          final route = item['route'] as String?;
          return Semantics(
            button: true,
            label: item['label'] as String,
            child: InkWell(
              onTap: () => route != null ? _navigateTo(route) : _showComingSoon(),
              child: Container(
                width: 100,
                padding: const EdgeInsets.all(ThixPolicy.s16),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border, width: 1.5),
                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData, color: ThixPolicy.inkDeep, size: 32),
                    const SizedBox(height: ThixPolicy.s10),
                    Text(
                      item['label'] as String,
                      textAlign: TextAlign.center,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.inkDeep,
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

  // ============================================================================
  // ALERTS ROW
  // ============================================================================

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
          const SizedBox(width: ThixPolicy.s16),
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
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: _buildCard(
          padding: const EdgeInsets.all(ThixPolicy.s18 = 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: ThixPolicy.s14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: ThixPolicy.labelStyle.copyWith(
                    color: color,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // HISTORICAL FIGURES
  // ============================================================================

  Widget _buildHistoricalFigures() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Figures Historiques',
              actionText: 'Explorer',
              onTap: () => _showComingSoon(),
            ),
            const SizedBox(height: ThixPolicy.s8),
            Text(
              'Découvrez ceux qui ont marqué notre histoire.',
              style: ThixPolicy.bodySmallStyle,
            ),
            const SizedBox(height: ThixPolicy.s24),
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.card, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_edu_rounded, size: 56, color: ThixPolicy.textMuted),
                    const SizedBox(height: ThixPolicy.s16),
                    Text(
                      'Module en préparation',
                      style: ThixPolicy.bodyMediumStyle.copyWith(
                        color: ThixPolicy.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UTILITIES — Card / Section Header / States
  // ============================================================================

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(ThixPolicy.s24),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.card, width: 2),
        boxShadow: ThixPolicy.shadowCard(opacity: 0.05),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onTap}) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 24,
          decoration: BoxDecoration(
            color: _MonPaysColors.rdcRed,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: ThixPolicy.s12),
        Text(
          title,
          style: ThixPolicy.h2Style.copyWith(
            color: ThixPolicy.inkDeep,
          ),
        ),
        const Spacer(),
        if (actionText != null && onTap != null)
          Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: ThixPolicy.inkDeep.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                ),
                child: Row(
                  children: [
                    Text(
                      actionText,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: ThixPolicy.inkDeep,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonCard({double height = 100}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceStrong,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
      ),
    );
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s32),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: ThixPolicy.danger, size: 48),
          const SizedBox(height: ThixPolicy.s16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyMediumStyle.copyWith(color: ThixPolicy.danger),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: ThixPolicy.s16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s32),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: ThixPolicy.textMuted, size: 48),
          const SizedBox(height: ThixPolicy.s16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyMediumStyle.copyWith(color: ThixPolicy.textSecondary),
          ),
        ],
      ),
    );
  }
}
