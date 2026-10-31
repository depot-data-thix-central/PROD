// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
//
// ThixWeedingHomePage — DESIGN v3 (blanc éditorial + rose romance + glassmorphism)
//
// ÉVOLutions :
//   • Hero carousel géant (62% hauteur) avec photos changeables
//   • Fond crème très clair + glassmorphism hairline (pas opaque)
//   • Catégories en petits ronds compacts (36px) — style iOS
//   • AppBar transparent → blanc au scroll
//   • Sections éditoriales : offres, prestataires, annonces, trust
//   • Background ambient romantique ultra-léger (zéro blur GPU)
//
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../core/failure.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE — BLANC CRÈME + ROSE ROMANCE + OR CHAUD
// ═══════════════════════════════════════════════════════════════════════════
class _W {
  static const Color bg = Color(0xFFFBF7F5);          // Crème très clair
  static const Color surface = Colors.white;
  static const Color tile = Color(0xFFFFF4F2);        // Rose ultra pâle
  static const Color ink = Color(0xFF1E1E28);
  static const Color inkSoft = Color(0xFF7A6B6E);
  static const Color line = Color(0xFFEFDAD5);        // Hairline chaude
  static const Color rose = Color(0xFFD9667A);        // Rose THIX (aligné constellation)
  static const Color roseLight = Color(0xFFFF8A9B);
  static const Color peach = Color(0xFFFFB0A3);
  static const Color gold = Color(0xFFD4A574);        // Or chaleureux
  static const Color plum = Color(0xFF8B5CF6);        // Violet accents
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS MÉTIER (inchangés, logique conservée)
// ═══════════════════════════════════════════════════════════════════════════
final homePromoSlidesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    <String, dynamic>{
      'tag': 'PROMO FLASH',
      'title': "Jusqu'à −40%",
      'subtitle': 'Salles de réception & traiteurs partenaires',
      'cta': 'Profiter',
      'imageUrl': 'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=1200&q=80',
    },
    <String, dynamic>{
      'tag': 'NOUVEAU',
      'title': 'Votre site de mariage',
      'subtitle': 'Créé en 5 minutes — ID unique + invitations',
      'cta': 'Commencer',
      'imageUrl': 'https://images.unsplash.com/photo-1519741497674-611481863552?w=1200&q=80',
    },
    <String, dynamic>{
      'tag': 'PARTENAIRES',
      'title': '+300 prestataires',
      'subtitle': 'Vérifiés partout en RDC — avis authentiques',
      'cta': 'Découvrir',
      'imageUrl': 'https://images.unsplash.com/photo-1478146059778-26028b07395a?w=1200&q=80',
    },
  ];
});

final homeCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 120));
  return [
    <String, dynamic>{'label': 'Salles', 'icon': Icons.villa_outlined},
    <String, dynamic>{'label': 'Traiteurs', 'icon': Icons.restaurant_outlined},
    <String, dynamic>{'label': 'Cérémonie', 'icon': Icons.mic_none_outlined},
    <String, dynamic>{'label': 'Décor', 'icon': Icons.local_florist_outlined},
    <String, dynamic>{'label': 'Photos', 'icon': Icons.camera_alt_outlined},
    <String, dynamic>{'label': 'Vidéos', 'icon': Icons.videocam_outlined},
    <String, dynamic>{'label': 'DJ & Son', 'icon': Icons.music_note_outlined},
    <String, dynamic>{'label': 'Robes', 'icon': Icons.checkroom_outlined},
    <String, dynamic>{'label': 'Costumes', 'icon': Icons.checkroom_outlined},
    <String, dynamic>{'label': 'Plus', 'icon': Icons.grid_view_rounded},
  ];
});

final homeStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return {'Prestataires': 312, 'Avis': 1840, 'Offres': 26, 'Mariages': 97};
});

final homeOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    <String, dynamic>{'title': 'Salles de fête', 'subtitle': 'Réservez la salle idéale', 'discount': '−30%', 'icon': Icons.villa_outlined, 'color': _W.rose},
    <String, dynamic>{'title': 'Traiteurs', 'subtitle': 'Menus spéciaux mariage', 'discount': '−20%', 'icon': Icons.restaurant_outlined, 'color': _W.gold},
    <String, dynamic>{'title': 'Photographe', 'subtitle': 'Package complet', 'discount': 'OFFERT', 'icon': Icons.camera_alt_outlined, 'color': _W.plum},
    <String, dynamic>{'title': 'Décoration', 'subtitle': 'Ambiances inoubliables', 'discount': '−15%', 'icon': Icons.local_florist_outlined, 'color': _W.peach},
  ];
});

final homeProvidersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    <String, dynamic>{
      'name': 'Palais des Congrès',
      'category': 'Salle de fête',
      'zone': 'Kinshasa',
      'rating': 4.8,
      'reviews': 128,
      'price': r'Dès 600$',
      'image': 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80',
    },
    <String, dynamic>{
      'name': "Saveurs d'Afrique",
      'category': 'Traiteur',
      'zone': 'Goma',
      'rating': 4.9,
      'reviews': 96,
      'price': r'Dès 450$',
      'image': 'https://images.unsplash.com/photo-1555244162-803834f70033?w=600&q=80',
    },
    <String, dynamic>{
      'name': 'Lens Prod',
      'category': 'Photographe',
      'zone': 'Lubumbashi',
      'rating': 4.9,
      'reviews': 215,
      'price': r'Dès 300$',
      'image': 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=600&q=80',
    },
    <String, dynamic>{
      'name': 'Dream Décor',
      'category': 'Décoration',
      'zone': 'Kinshasa',
      'rating': 4.7,
      'reviews': 78,
      'price': r'Dès 250$',
      'image': 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=600&q=80',
    },
  ];
});

final homeAnnouncementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return [
    <String, dynamic>{'tag': 'À VENDRE', 'title': 'Robe de mariée T38', 'subtitle': r'450$', 'icon': Icons.checkroom_outlined},
    <String, dynamic>{'tag': 'À LOUER', 'title': 'Salle 200 places', 'subtitle': r'800$ / jour', 'icon': Icons.villa_outlined},
    <String, dynamic>{'tag': 'SERVICE', 'title': 'Coiffure & maquillage', 'subtitle': r'Dès 30$', 'icon': Icons.face_retouching_natural_outlined},
  ];
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class ThixWeedingHomePage extends ConsumerStatefulWidget {
  const ThixWeedingHomePage({super.key});

  @override
  ConsumerState<ThixWeedingHomePage> createState() => _ThixWeedingHomePageState();
}

class _ThixWeedingHomePageState extends ConsumerState<ThixWeedingHomePage> {
  late final TextEditingController _idController;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _focusNode = FocusNode();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  void _onScroll() => _scrollY.value = _scrollController.position.pixels;

  Future<void> _onStaffAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _snack('Connectez-vous pour accéder à l\'espace staff');
      context.push('/thix-weeding/auth/login');
      return;
    }
    try {
      final repo = ref.read(weddingRepositoryProvider);
      final weddings = await repo.getWeddingsByOwnerId(user.id);
      if (!mounted) return;
      if (weddings.isEmpty) {
        context.push('/thix-weeding/create');
      } else if (weddings.length == 1) {
        context.push('/thix-weeding/staff/${weddings.first.id}');
      } else {
        context.push('/thix-weeding/staff/my-weddings');
      }
    } catch (_) {
      if (!mounted) return;
      context.push('/thix-weeding/staff/my-weddings');
    }
  }

  Future<void> _onSearch() async {
    HapticFeedback.mediumImpact();
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    if (_isSearching) return;
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();
    try {
      final repo = ref.read(weddingRepositoryProvider);
      final WeddingEntity wedding = await repo.getWeddingById(id);
      if (!mounted) return;
      context.push('/thix-weeding/guest/${wedding.id}');
    } on Failure catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _snack('ID introuvable, vérifiez et réessayez', error: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onScanQr() {
    HapticFeedback.lightImpact();
    _snack('Scanner QR bientôt disponible');
  }

  void _onNotifications() {
    HapticFeedback.lightImpact();
    _snack('Notifications bientôt disponibles');
  }

  void _onTapGeneric(String label) {
    HapticFeedback.selectionClick();
    _snack('$label — bientôt disponible');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _W.rose : _W.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ));
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final offersAsync = ref.watch(homeOffersProvider);
    final providersAsync = ref.watch(homeProvidersProvider);
    final announcementsAsync = ref.watch(homeAnnouncementsProvider);
    final promosAsync = ref.watch(homePromoSlidesProvider);

    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _W.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── BACKGROUND AMBIENT TRÈS LÉGER ──
          const Positioned.fill(child: _AmbientBackground()),

          // ── SCROLL ──
          RefreshIndicator(
            color: _W.rose,
            backgroundColor: _W.surface,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(homePromoSlidesProvider);
              ref.invalidate(homeCategoriesProvider);
              ref.invalidate(homeOffersProvider);
              ref.invalidate(homeProvidersProvider);
              ref.invalidate(homeAnnouncementsProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ── HERO CAROUSEL GÉANT (62% de l'écran) ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.62,
                    child: promosAsync.when(
                      data: (slides) => _HeroCarousel(slides: slides, topPad: topPad),
                      loading: () => Container(
                        color: _W.tile,
                        child: const Center(child: CircularProgressIndicator(color: _W.rose, strokeWidth: 2.5)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // ── RECHERCHE PAR ID (overlay glass) ──
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -36),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _JoinSearchCard(
                        controller: _idController,
                        focusNode: _focusNode,
                        isLoading: _isSearching,
                        onSearch: _onSearch,
                        onScanQr: _onScanQr,
                      ),
                    ),
                  ),
                ),

                // ── CATÉGORIES EN PETITS RONDS ──
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: catsAsync.when(
                      data: (cats) => _CategoryRow(categories: cats, onTap: _onTapGeneric),
                      loading: () => const SizedBox(height: 88),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // ── OFFRES DU MOMENT ──
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Offres du moment', action: 'Voir tout'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: offersAsync.when(
                    data: (offers) => _OffersRow(offers: offers, onTap: _onTapGeneric),
                    loading: () => const SizedBox(height: 120),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // ── PRESTATAIRES RECOMMANDÉS ──
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Prestataires recommandés', action: 'Voir tout'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: providersAsync.when(
                      data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric),
                      loading: () => const SizedBox(height: 280),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // ── ANNONCES ──
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Dernières annonces', action: 'Voir tout'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: announcementsAsync.when(
                    data: (ann) => _AnnouncementsRow(items: ann, onTap: _onTapGeneric),
                    loading: () => const SizedBox(height: 160),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // ── TRUST BADGES ──
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _TrustRow(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),

          // ── APP BAR (transparent → blanc au scroll) ──
          _GlassAppBar(
            topPad: topPad,
            scrollY: _scrollY,
            onNotifications: _onNotifications,
            onStaff: _onStaffAccess,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR — TRANSPARENT → BLANC GLASS AU SCROLL
// ═══════════════════════════════════════════════════════════════════════════
class _GlassAppBar extends StatelessWidget {
  final double topPad;
  final ValueNotifier<double> scrollY;
  final VoidCallback onNotifications;
  final VoidCallback onStaff;

  const _GlassAppBar({
    required this.topPad,
    required this.scrollY,
    required this.onNotifications,
    required this.onStaff,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: scrollY,
        builder: (_, y, __) {
          final t = (y / 280).clamp(0.0, 1.0).toDouble();
          final fg = Color.lerp(Colors.white, _W.ink, t)!;
          final bg = Colors.white.withOpacity(0.85 * t);

          return Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 10),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                bottom: BorderSide(color: _W.line.withOpacity(t), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Logo carré
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_W.rose, _W.roseLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: _W.rose.withOpacity(0.25 * (1 - t)),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'THIX ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: fg,
                                letterSpacing: -0.3,
                              ),
                            ),
                            TextSpan(
                              text: 'WED',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: _W.rose,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'L\'élégance de votre union',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color.lerp(Colors.white70, _W.inkSoft, t)!,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _AppBarBtn(icon: Icons.notifications_none_rounded, fg: fg, onTap: onNotifications, badge: 3),
                const SizedBox(width: 8),
                _AppBarBtn(icon: Icons.account_circle_outlined, fg: fg, onTap: onStaff),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final VoidCallback onTap;
  final int badge;

  const _AppBarBtn({
    required this.icon,
    required this.fg,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: fg),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _W.rose,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO CAROUSEL — PHOTOS CHANGEABLES
// ═══════════════════════════════════════════════════════════════════════════
class _HeroCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> slides;
  final double topPad;

  const _HeroCarousel({required this.slides, required this.topPad});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pageCtrl = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.slides.length <= 1) return;
      final next = (_current + 1) % widget.slides.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onChangePhotos() {
    // TODO: Ouvrir une galerie d'admin pour modifier les slides
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _W.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(children: [
          Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gestion des photos disponible depuis l\'espace staff',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── PHOTOS ──
        PageView.builder(
          controller: _pageCtrl,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final slide = slides[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  slide['imageUrl'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _W.tile,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: _W.inkSoft, size: 48),
                    ),
                  ),
                ),
                // ── OVERLAY GRADIENT DOUX ──
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                        Colors.black.withOpacity(0.15),
                        _W.bg.withOpacity(0.85),
                        _W.bg,
                      ],
                      stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // ── CONTENU TEXTUEL ──
        Positioned(
          left: 20,
          right: 20,
          bottom: 90,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _HeroContent(key: ValueKey(_current), slide: slides[_current]),
          ),
        ),

        // ── BOUTON CHANGER PHOTOS (en haut à droite) ──
        Positioned(
          top: widget.topPad + 70,
          right: 16,
          child: GestureDetector(
            onTap: _onChangePhotos,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Changer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── PAGINATION DOTS ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _W.rose : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  final Map<String, dynamic> slide;
  const _HeroContent({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _W.rose,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (slide['tag'] as String).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Titre
        Text(
          slide['title'] as String,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide['subtitle'] as String,
          style: TextStyle(
            color: Colors.white.withOpacity(0.88),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 18),
        // CTA
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: _W.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: const Text('Fonctionnalité en cours de déploiement'),
              ));
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(
              slide['cta'] as String,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _W.ink,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE REJOINDRE (overlay glass après hero)
// ═══════════════════════════════════════════════════════════════════════════
class _JoinSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;

  const _JoinSearchCard({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSearch,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(color: _W.rose.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _W.rose.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: _W.rose, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Rejoindre un mariage',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _W.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Entrez l\'ID unique de l\'invitation ou scannez le QR Code.',
            style: TextStyle(fontSize: 11.5, color: _W.inkSoft, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _W.tile,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _W.line),
                ),
                child: Row(children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, size: 18, color: _W.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _W.ink, letterSpacing: 1),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'ID du mariage...',
                        hintStyle: TextStyle(fontSize: 12, color: _W.inkSoft, fontWeight: FontWeight.w500, letterSpacing: 0),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => onSearch(),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.arrow_forward_rounded,
              onTap: isLoading ? null : onSearch,
              filled: true,
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : null,
            ),
            const SizedBox(width: 6),
            _IconBtn(icon: Icons.qr_code_scanner_rounded, onTap: onScanQr),
          ]),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final Widget? child;

  const _IconBtn({required this.icon, this.onTap, this.filled = false, this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: filled ? _W.rose : _W.tile,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: filled ? _W.rose : _W.line),
        ),
        child: child ?? Icon(icon, size: 20, color: filled ? Colors.white : _W.ink),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CATÉGORIES EN PETITS RONDS (36px) — HORIZONTAL
// ═══════════════════════════════════════════════════════════════════════════
class _CategoryRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(String) onTap;

  const _CategoryRow({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = categories[i];
          final label = c['label'] as String;
          final icon = c['icon'] as IconData;

          return GestureDetector(
            onTap: () => onTap(label),
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _W.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _W.line, width: 1.2),
                      boxShadow: [
                        BoxShadow(color: _W.rose.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(icon, size: 20, color: _W.rose),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _W.ink,
                      letterSpacing: -0.1,
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
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HEADER ÉDITORIAL
// ═══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;

  const _SectionHeader({required this.title, this.action = 'Voir tout'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_W.rose, _W.roseLight]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _W.ink,
              letterSpacing: -0.4,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => HapticFeedback.selectionClick(),
          child: Row(children: [
            Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _W.rose,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: _W.rose),
          ]),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OFFRES DU MOMENT
// ═══════════════════════════════════════════════════════════════════════════
class _OffersRow extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final void Function(String) onTap;

  const _OffersRow({required this.offers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final o = offers[i];
          final color = o['color'] as Color;
          return GestureDetector(
            onTap: () => onTap(o['title'] as String),
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _W.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _W.line),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      o['discount'] as String,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                  const Spacer(),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(o['icon'] as IconData, size: 14, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        o['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.2),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    o['subtitle'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: _W.inkSoft, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRESTATAIRES (grille 2 colonnes)
// ═══════════════════════════════════════════════════════════════════════════
class _ProvidersGrid extends StatelessWidget {
  final List<Map<String, dynamic>> providers;
  final void Function(String) onTap;

  const _ProvidersGrid({required this.providers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: providers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, i) {
        final p = providers[i];
        return GestureDetector(
          onTap: () => onTap(p['name'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: _W.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _W.line),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        p['image'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _W.tile,
                          child: const Icon(Icons.broken_image_outlined, size: 32, color: _W.inkSoft),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white),
                          ),
                          child: const Icon(Icons.favorite_border_rounded, size: 15, color: _W.rose),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p['category']} · ${p['zone']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: _W.inkSoft, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.star_rounded, size: 13, color: _W.gold),
                            const SizedBox(width: 3),
                            Text(
                              '${p['rating']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _W.ink),
                            ),
                          ]),
                          Text(
                            p['price'] as String,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: _W.rose),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANNONCES
// ═══════════════════════════════════════════════════════════════════════════
class _AnnouncementsRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onTap;

  const _AnnouncementsRow({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = items[i];
          return GestureDetector(
            onTap: () => onTap(a['title'] as String),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: _W.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _W.line),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 78,
                    child: Stack(children: [
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_W.tile, Color(0xFFFFE8E3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(a['icon'] as IconData, size: 28, color: _W.rose.withOpacity(0.7)),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _W.ink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (a['tag'] as String).toUpperCase(),
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _W.ink),
                        ),
                        const Spacer(),
                        Text(
                          a['subtitle'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _W.rose),
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRUST ROW
// ═══════════════════════════════════════════════════════════════════════════
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  static const _items = [
    {'icon': Icons.verified_outlined, 'title': 'Vérifiés', 'subtitle': 'Garantis'},
    {'icon': Icons.lock_outline_rounded, 'title': 'Paiement', 'subtitle': 'Sécurisé'},
    {'icon': Icons.headset_mic_outlined, 'title': 'Support', 'subtitle': '24/7'},
    {'icon': Icons.star_outline_rounded, 'title': 'Avis', 'subtitle': 'Certifiés'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: _W.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _W.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _W.rose.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(e['icon'] as IconData, size: 18, color: _W.rose),
                ),
                const SizedBox(height: 6),
                Text(
                  e['title'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: _W.ink, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 1),
                Text(
                  e['subtitle'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, color: _W.inkSoft, fontWeight: FontWeight.w600, height: 1.2),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BACKGROUND AMBIENT — ROMANTIQUE LÉGER (ZÉRO BLUR GPU)
// ═══════════════════════════════════════════════════════════════════════════
class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _orb(double left, double top, double w, double h, Color color, double angle) {
    return Positioned(
      left: left - w / 2,
      top: top - h / 2,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(w, h)),
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0.0)],
              stops: const [0.1, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value * 2 * math.pi;
            return Stack(children: [
              Positioned.fill(child: Container(color: _W.bg)),
              _orb(s.width * 0.2, s.height * 0.15 + math.sin(t * 0.8) * 20, 520, 480, _W.roseLight.withOpacity(0.09), t * 0.2),
              _orb(s.width * 0.85, s.height * 0.5 + math.cos(t * 0.6) * 25, 600, 540, _W.peach.withOpacity(0.08), -t * 0.15),
              _orb(s.width * 0.3, s.height * 0.85 + math.sin(t * 0.7) * 15, 480, 420, _W.gold.withOpacity(0.05), t * 0.25),
            ]);
          },
        ),
      ),
    );
  }
}
