// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
// ============================================================================
// THIX WEDDING HOME PAGE — DESIGN v5.0 GLASSMORPHISM (PRODUCTION)
// ✅ Design premium glassmorphism blanc/rose
// ✅ Bouton Espace Prestataire dans l'appbar
// ✅ Vrais prestataires depuis Supabase (Gold/Platinum)
// ✅ Bannière promotionnelle Espace Prestataire
// ✅ FIX : Color green ajoutée à _W
// ============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE v5.0 GLASSMORPHISM
// ═══════════════════════════════════════════════════════════════════════════
class _W {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color glass = Color(0xFFF5F5F5);
  static const Color tile = Color(0xFFFFF4F2);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);

  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);

  static const Color peach = Color(0xFFFFB8A8);
  static const Color gold = Color(0xFFFFD700);
  static const Color plum = Color(0xFFA855F7);

  // ✅ AJOUTÉ : green pour le badge CERTIFIÉ
  static const Color green = Color(0xFF10B981);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
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
      'subtitle': 'Créé en 5 minutes — Code unique + invitations',
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
    <String, dynamic>{'label': 'Salles', 'icon': Icons.villa_outlined, 'category': ProviderCategory.salle},
    <String, dynamic>{'label': 'Traiteurs', 'icon': Icons.restaurant_outlined, 'category': ProviderCategory.traiteur},
    <String, dynamic>{'label': 'Cérémonie', 'icon': Icons.mic_none_outlined, 'category': ProviderCategory.mc},
    <String, dynamic>{'label': 'Décor', 'icon': Icons.local_florist_outlined, 'category': ProviderCategory.decorateur},
    <String, dynamic>{'label': 'Photos', 'icon': Icons.camera_alt_outlined, 'category': ProviderCategory.photographe},
    <String, dynamic>{'label': 'Vidéos', 'icon': Icons.videocam_outlined, 'category': ProviderCategory.videaste},
    <String, dynamic>{'label': 'DJ & Son', 'icon': Icons.music_note_outlined, 'category': ProviderCategory.dj},
    <String, dynamic>{'label': 'Beauté', 'icon': Icons.face_outlined, 'category': ProviderCategory.maquilleur},
    <String, dynamic>{'label': 'Gâteaux', 'icon': Icons.cake_outlined, 'category': ProviderCategory.patissier},
    <String, dynamic>{'label': 'Plus', 'icon': Icons.grid_view_rounded, 'category': null},
  ];
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

final homeProvidersProvider = FutureProvider<List<ThixProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  try {
    final providers = await service.getAllProviders(limit: 10, isAvailable: true);
    return providers
        .where((p) => p.level == TrackingLevel.gold || p.level == TrackingLevel.platinum)
        .toList();
  } catch (e) {
    return [];
  }
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
      final weddings = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('id')
          .eq('owner_id', user.id);
      if (!mounted) return;
      if (weddings.isEmpty) {
        context.push('/thix-weeding/create');
      } else if (weddings.length == 1) {
        context.push('/thix-weeding/staff/${weddings.first['id']}');
      } else {
        context.push('/thix-weeding/staff/my-weddings');
      }
    } catch (_) {
      if (!mounted) return;
      context.push('/thix-weeding/staff/my-weddings');
    }
  }

  Future<void> _onProviderAccess() async {
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.push('/thix-weeding/provider/auth');
      return;
    }
    try {
      final provider = await ref.read(providerServiceProvider).getProviderByUserId(user.id);
      if (!mounted) return;
      if (provider != null) {
        context.push('/thix-weeding/provider/dashboard');
      } else {
        context.push('/thix-weeding/provider/register');
      }
    } catch (e) {
      if (!mounted) return;
      context.push('/thix-weeding/provider/auth');
    }
  }

  Future<void> _onSearch() async {
    HapticFeedback.mediumImpact();
    final code = _idController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    if (_isSearching) return;
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();
    try {
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('id, unique_code, invitation_published')
          .eq('unique_code', code)
          .maybeSingle();
      if (!mounted) return;
      if (res == null) {
        _snack('Code "$code" introuvable. Vérifiez et réessayez.', error: true);
        return;
      }
      final weddingId = res['id'] as String;
      final published = res['invitation_published'] as bool? ?? false;
      if (!published) {
        _snack('Cette invitation n\'est pas encore publiée.', error: true);
        return;
      }
      context.push('/thix-weeding/guest/$weddingId');
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur de connexion. Réessayez.', error: true);
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

  void _onCategoryTap(ProviderCategory? category) {
    HapticFeedback.mediumImpact();
    if (category != null) {
      context.push('/thix-weeding/provider/catalog?category=${category.name}');
    } else {
      context.push('/thix-weeding/provider/catalog');
    }
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
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final offersAsync = ref.watch(homeOffersProvider);
    final providersAsync = ref.watch(homeProvidersProvider);
    final announcementsAsync = ref.watch(homeAnnouncementsProvider);
    final promosAsync = ref.watch(homePromoSlidesProvider);
    final activeInvitesAsync = ref.watch(myActiveInvitationsProvider);
    final topPad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: _W.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
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
              ref.invalidate(myActiveInvitationsProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.68,
                    child: promosAsync.when(
                      data: (slides) => _HeroCarousel(
                        slides: slides,
                        topPad: topPad.top,
                        idController: _idController,
                        focusNode: _focusNode,
                        isSearching: _isSearching,
                        onSearch: _onSearch,
                        onScanQr: _onScanQr,
                      ),
                      loading: () => Container(
                        color: _W.tile,
                        child: const Center(child: CircularProgressIndicator(color: _W.rose, strokeWidth: 2.5)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: catsAsync.when(
                      data: (cats) => _CategoryRow(categories: cats, onTap: _onCategoryTap),
                      loading: () => const SizedBox(height: 88),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Offres du moment')),
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
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Prestataires recommandés')),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: providersAsync.when(
                      data: (providers) => _ProvidersGrid(providers: providers),
                      loading: () => const SizedBox(height: 280),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                const SliverToBoxAdapter(child: _ProviderBanner()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Dernières annonces')),
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
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TrustRow()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
          activeInvitesAsync.when(
            data: (invites) {
              if (invites.isEmpty) return const SizedBox.shrink();
              return Positioned(
                right: 14,
                bottom: MediaQuery.of(context).size.height * 0.68 - 62,
                child: _ActiveInvitesOrb(
                  invites: invites,
                  onTap: (weddingId) {
                    HapticFeedback.mediumImpact();
                    context.push('/thix-weeding/guest/$weddingId');
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          _GlassAppBar(
            topPad: topPad.top,
            scrollY: _scrollY,
            onNotifications: _onNotifications,
            onStaff: _onStaffAccess,
            onProvider: _onProviderAccess,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR GLASSMORPHISM
// ═══════════════════════════════════════════════════════════════════════════
class _GlassAppBar extends StatelessWidget {
  final double topPad;
  final ValueNotifier<double> scrollY;
  final VoidCallback onNotifications;
  final VoidCallback onStaff;
  final VoidCallback onProvider;

  const _GlassAppBar({
    required this.topPad,
    required this.scrollY,
    required this.onNotifications,
    required this.onStaff,
    required this.onProvider,
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
          return Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85 * t),
              border: Border(bottom: BorderSide(color: _W.line.withOpacity(t), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_W.rose, _W.roseLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: 'THIX ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: fg, letterSpacing: -0.3)),
                            const TextSpan(text: 'WED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _W.rose, letterSpacing: -0.3)),
                          ],
                        ),
                      ),
                      Text(
                        "L'élégance de votre union",
                        style: TextStyle(fontSize: 10, color: Color.lerp(Colors.white70, _W.inkSoft, t)!, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _AppBarBtn(icon: Icons.store_outlined, fg: fg, onTap: onProvider),
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

  const _AppBarBtn({required this.icon, required this.fg, required this.onTap, this.badge = 0});

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
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3))),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: fg),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: _W.rose, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderBanner extends StatelessWidget {
  const _ProviderBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/thix-weeding/provider/auth');
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_W.rose, _W.roseLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.store_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Espace Prestataire', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text('Rejoignez +300 professionnels vérifiés', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> slides;
  final double topPad;
  final TextEditingController idController;
  final FocusNode focusNode;
  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;

  const _HeroCarousel({
    required this.slides,
    required this.topPad,
    required this.idController,
    required this.focusNode,
    required this.isSearching,
    required this.onSearch,
    required this.onScanQr,
  });

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
      _pageCtrl.animateToPage((_current + 1) % widget.slides.length, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageCtrl,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final slide = slides[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(slide['imageUrl'] as String, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _W.tile, child: const Center(child: Icon(Icons.broken_image_outlined, color: _W.inkSoft, size: 48)))),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.35), Colors.transparent, Colors.black.withOpacity(0.25), Colors.black.withOpacity(0.45)],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          top: widget.topPad + 70,
          right: 16,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: _W.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  content: Row(children: [
                    const Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Gestion des photos disponible depuis l\'espace staff', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                  ]),
                ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.photo_library_outlined, size: 14, color: Colors.white), SizedBox(width: 6), Text('Changer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))]),
            ),
          ),
        ),
        Positioned(left: 20, right: 20, bottom: 200, child: AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: _HeroContent(key: ValueKey(_current), slide: slides[_current]))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 178,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == _current;
              return AnimatedContainer(duration: const Duration(milliseconds: 280), margin: const EdgeInsets.symmetric(horizontal: 3), width: active ? 22 : 6, height: 6, decoration: BoxDecoration(color: active ? _W.rose : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(3)));
            }),
          ),
        ),
        Positioned(left: 16, right: 16, bottom: 14, child: _JoinBar(controller: widget.idController, focusNode: widget.focusNode, isLoading: widget.isSearching, onSearch: widget.onSearch, onScanQr: widget.onScanQr)),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _W.rose, borderRadius: BorderRadius.circular(12)),
          child: Text((slide['tag'] as String).toUpperCase(), style: GoogleFonts.inter(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        const SizedBox(height: 12),
        Text(slide['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1.05, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        Text(slide['subtitle'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: _W.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), content: Text('Fonctionnalité en cours de déploiement', style: GoogleFonts.inter(color: Colors.white))));
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(slide['cta'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _W.ink, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), padding: const EdgeInsets.symmetric(horizontal: 22)),
          ),
        ),
      ],
    );
  }
}

class _JoinBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;

  const _JoinBar({required this.controller, required this.focusNode, required this.isLoading, required this.onSearch, required this.onScanQr});

  @override
  State<_JoinBar> createState() => _JoinBarState();
}

class _JoinBarState extends State<_JoinBar> {
  bool _focused = false;
  bool _hasText = false;

  void _syncFocus() => setState(() => _focused = widget.focusNode.hasFocus);
  void _syncText() => setState(() => _hasText = widget.controller.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_syncFocus);
    widget.controller.addListener(_syncText);
    _syncText();
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_syncFocus);
    widget.controller.removeListener(_syncText);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(color: _W.rose.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _W.rose.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.mark_email_read_rounded, color: _W.rose, size: 17)),
              const SizedBox(width: 10),
              Expanded(child: Text('Rejoindre un mariage', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.3))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _focused ? _W.rose : _W.line, width: _focused ? 1.6 : 1.2),
                    boxShadow: _focused ? [BoxShadow(color: _W.rose.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4))] : null,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _W.ink, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      hintText: 'Ex: THIX-W-1510-482AB',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: _W.inkSoft, fontWeight: FontWeight.w500, letterSpacing: 0.8),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: _focused ? _W.rose : _W.inkSoft),
                      suffixIcon: _hasText
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 17, color: _W.inkSoft),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                widget.controller.clear();
                                widget.focusNode.requestFocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => widget.onSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Rejoindre',
                child: InkWell(
                  onTap: widget.isLoading ? null : widget.onSearch,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_W.rose, _W.roseLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: widget.isLoading
                        ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 21),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Scanner le QR',
                child: InkWell(
                  onTap: widget.onScanQr,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: _W.tile, borderRadius: BorderRadius.circular(16), border: Border.all(color: _W.line)),
                    child: const Icon(Icons.qr_code_scanner_rounded, size: 21, color: _W.ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: _W.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Le code figure sur l'invitation (format: THIX-W-JJMM-XXXYY)",
                  style: GoogleFonts.inter(fontSize: 10.5, color: _W.inkSoft, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(ProviderCategory?) onTap;

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
          return GestureDetector(
            onTap: () => onTap(c['category'] as ProviderCategory?),
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
                      boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Icon(c['icon'] as IconData, size: 20, color: _W.rose),
                  ),
                  const SizedBox(height: 6),
                  Text(c['label'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _W.ink)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_W.rose, _W.roseLight]), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.4))),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/thix-weeding/provider/catalog');
          },
          child: Row(children: [Text('Voir tout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _W.rose)), const SizedBox(width: 2), const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: _W.rose)]),
        ),
      ],
    );
  }
}

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
                boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                    child: Text(o['discount'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  ),
                  const Spacer(),
                  Row(children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(o['icon'] as IconData, size: 14, color: color)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.2))),
                  ]),
                  const SizedBox(height: 3),
                  Text(o['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10.5, color: _W.inkSoft, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProvidersGrid extends StatelessWidget {
  final List<ThixProviderModel> providers;

  const _ProvidersGrid({required this.providers});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: _W.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _W.line)),
        child: Column(
          children: [
            Icon(Icons.store_outlined, size: 48, color: _W.inkSoft),
            const SizedBox(height: 12),
            Text('Aucun prestataire disponible', style: GoogleFonts.inter(fontSize: 14, color: _W.inkSoft)),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: providers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.72),
      itemBuilder: (_, i) {
        final p = providers[i];
        final coverImage = p.galleryUrls.isNotEmpty ? p.galleryUrls.first : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80';

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/thix-weeding/provider/detail/${p.id}');
          },
          child: Container(
            decoration: BoxDecoration(
              color: _W.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _W.line),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(coverImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _W.tile, child: const Icon(Icons.broken_image_outlined, size: 32, color: _W.inkSoft))),
                      if (p.level == TrackingLevel.platinum)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_W.gold, Color(0xFFFFA500)]),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: _W.gold.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text('PREMIUM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        )
                      else if (p.level == TrackingLevel.gold)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _W.green, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text('CERTIFIÉ', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, border: Border.all(color: Colors.white)),
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
                      Text(p.businessName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text('${p.category.displayName} · ${p.city ?? 'RDC'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10.5, color: _W.inkSoft, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: _W.gold),
                              const SizedBox(width: 3),
                              Text(p.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _W.ink)),
                            ],
                          ),
                          if (p.minPrice != null)
                            Text(
                              'Dès ${p.minPrice!.toStringAsFixed(0)}${p.currency == 'USD' ? r'$' : p.currency}',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: _W.rose),
                            )
                          else
                            Text('Sur devis', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _W.inkSoft)),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 78,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_W.tile, Color(0xFFFFE8E3)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                          child: Center(child: Icon(a['icon'] as IconData, size: 28, color: _W.rose.withOpacity(0.7))),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _W.ink, borderRadius: BorderRadius.circular(8)),
                            child: Text((a['tag'] as String).toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
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
                        Text(a['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _W.ink)),
                        const Spacer(),
                        Text(a['subtitle'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _W.rose)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _W.rose.withOpacity(0.1), shape: BoxShape.circle), child: Icon(e['icon'] as IconData, size: 18, color: _W.rose)),
                const SizedBox(height: 6),
                Text(e['title'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: _W.ink, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 1),
                Text(e['subtitle'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 9.5, color: _W.inkSoft, fontWeight: FontWeight.w600, height: 1.2)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

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
            gradient: RadialGradient(colors: [color, color.withOpacity(0.0)], stops: const [0.1, 1.0]),
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
        child: ValueListenableBuilder<double>(
          valueListenable: _ctrl,
          builder: (_, __, ___) {
            final t = _ctrl.value * 2 * math.pi;
            return Stack(
              children: [
                Positioned.fill(child: Container(color: _W.bg)),
                _orb(s.width * 0.2, s.height * 0.15 + math.sin(t * 0.8) * 20, 520, 480, _W.roseLight.withOpacity(0.09), t * 0.2),
                _orb(s.width * 0.85, s.height * 0.5 + math.cos(t * 0.6) * 25, 600, 540, _W.peach.withOpacity(0.08), -t * 0.15),
                _orb(s.width * 0.3, s.height * 0.85 + math.sin(t * 0.7) * 15, 480, 420, _W.gold.withOpacity(0.05), t * 0.25),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActiveInvitesOrb extends StatefulWidget {
  final List<Map<String, dynamic>> invites;
  final void Function(String weddingId) onTap;

  const _ActiveInvitesOrb({required this.invites, required this.onTap});

  @override
  State<_ActiveInvitesOrb> createState() => _ActiveInvitesOrbState();
}

class _ActiveInvitesOrbState extends State<_ActiveInvitesOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  late final AnimationController _enter;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shimmer.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.invites.length;
    final first = widget.invites.first;
    final couple = '${first['bride_name'] ?? ''} & ${first['groom_name'] ?? ''}'.trim();
    final label = couple.isEmpty || couple == '&' ? 'Invitation' : couple;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1.0).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutBack)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomRight,
              child: _expanded && count > 1
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: widget.invites.skip(1).take(3).map((inv) {
                          final c = '${inv['bride_name'] ?? ''} & ${inv['groom_name'] ?? ''}'.trim();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GlassInviteChip(title: c.isEmpty || c == '&' ? 'Invitation' : c, onTap: () => widget.onTap(inv['wedding_id'] as String)),
                          );
                        }).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            GestureDetector(
              onTap: () {
                if (count == 1) {
                  widget.onTap(first['wedding_id'] as String);
                } else {
                  setState(() => _expanded = !_expanded);
                }
              },
              onLongPress: () => widget.onTap(first['wedding_id'] as String),
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, _shimmer]),
                builder: (_, __) {
                  final p = 0.55 + 0.45 * _pulse.value;
                  final glow = 10.0 + 10.0 * _pulse.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 64 + 6 * _pulse.value,
                        height: 64 + 6 * _pulse.value,
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.28 * p), blurRadius: glow, spreadRadius: 1)]),
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.72), _W.roseLight.withOpacity(0.35)],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.95), width: 1.6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
                            BoxShadow(color: _W.rose.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_W.rose.withOpacity(0.95), _W.roseLight.withOpacity(0.9)]),
                                boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.35 * p), blurRadius: 8)],
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                            ),
                            Positioned.fill(
                              child: ClipOval(
                                child: Transform.translate(
                                  offset: Offset((-40 + 100 * _shimmer.value), 0),
                                  child: Container(
                                    width: 28,
                                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.35), Colors.transparent])),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF3B4A), Color(0xFFE31C4E)]),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: const Color(0xFFFF3B4A).withOpacity(0.45 * p), blurRadius: 6)],
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => widget.onTap(first['wedding_id'] as String),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 140),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _W.ink, letterSpacing: -0.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassInviteChip extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _GlassInviteChip({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white),
            boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_W.rose, _W.roseLight])),
                child: const Icon(Icons.favorite_rounded, size: 11, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _W.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
