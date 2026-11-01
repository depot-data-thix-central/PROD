// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
// ============================================================================
// THIX WEDDING HOME PAGE — DESIGN v5.0 GLASSMORPHISM ELITE (PRODUCTION)
// ✅ Design premium glassmorphism blanc/rose/glass flou
// ✅ Nouveau format code unique THIX-W-JJMM-XXXYY
// ✅ Bouton Espace Prestataire ajouté dans l'AppBar
// ✅ Bannière promotionnelle Espace Prestataire
// ✅ Sécurité + Performance optimisée
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

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE v5.0 GLASSMORPHISM — Blanc pur + Rose premium + Glass flou
// ═══════════════════════════════════════════════════════════════════════════
class _W {
  // Base colors - Blanc pur et glass
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color glass = Color(0xFFF5F5F5);
  
  // Rose très rose premium
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseDark = Color(0xFFD6336C);
  static const Color roseGlow = Color(0xFFFF6B9D);
  
  // Textes
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  
  // Accents
  static const Color gold = Color(0xFFFFD700);
  static const Color peach = Color(0xFFFFB8A8);
  static const Color plum = Color(0xFFA855F7);
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
    <String, dynamic>{'name': 'Palais des Congrès', 'category': 'Salle de fête', 'zone': 'Kinshasa', 'rating': 4.8, 'price': r'Dès 600$', 'image': 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80'},
    <String, dynamic>{'name': "Saveurs d'Afrique", 'category': 'Traiteur', 'zone': 'Goma', 'rating': 4.9, 'price': r'Dès 450$', 'image': 'https://images.unsplash.com/photo-1555244162-803834f70033?w=600&q=80'},
    <String, dynamic>{'name': 'Lens Prod', 'category': 'Photographe', 'zone': 'Lubumbashi', 'rating': 4.9, 'price': r'Dès 300$', 'image': 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=600&q=80'},
    <String, dynamic>{'name': 'Dream Décor', 'category': 'Décoration', 'zone': 'Kinshasa', 'rating': 4.7, 'price': r'Dès 250$', 'image': 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=600&q=80'},
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

  // ✅ NOUVEAU : Accès Espace Prestataire
  Future<void> _onProviderAccess() async {
    HapticFeedback.mediumImpact();
    context.push('/thix-weeding/provider/auth');
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
                        color: _W.glass,
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
                      data: (cats) => _CategoryRow(categories: cats, onTap: _onTapGeneric),
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
                      data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric),
                      loading: () => const SizedBox(height: 280),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                // ✅ NOUVEAU : Bannière Espace Prestataire
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
                _AppBarBtn(icon: Icons.notifications_none_rounded, fg: fg, onTap: onNotifications, badge: 3),
                const SizedBox(width: 8),
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

// ✅ NOUVEAU : Bannière Espace Prestataire
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
            gradient: LinearGradient(
              colors: [_W.rose, _W.roseLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _W.rose.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.store_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Espace Prestataire',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rejoignez +300 professionnels vérifiés',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
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
