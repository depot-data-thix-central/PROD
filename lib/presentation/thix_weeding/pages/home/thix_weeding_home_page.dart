// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // Requis pour le Glassmorphism (UI statique)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../core/failure.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';

// ============================================================
// PALETTE MARIAGE PREMIUM (Luxe & Romance)
// ============================================================
class _WeddingColors {
  static const Color primary = Color(0xFFE25A6A); // Rose THIX Mariage
  static const Color primaryLight = Color(0xFFFF8A9B);
  static const Color peach = Color(0xFFFFB0A3);
  static const Color gold = Color(0xFFFBBF24);
  static const Color bgBase = Color(0xFFFFF5F5); // Fond blanc très légèrement rosé
  static const Color textDark = Color(0xFF1E1E28); // Texte principal très sombre
}

// ============================================================
// PROVIDERS CLASSIQUES STABLES
// ============================================================
final homePromoSlidesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    <String, dynamic>{'tag': 'PROMO FLASH', 'title': "Jusqu'à -40%", 'subtitle': 'Sur les salles de réception & traiteurs', 'detail': "Valable jusqu'au 30 Septembre 2026", 'cta': 'Profiter maintenant', 'imageUrl': 'https://picsum.photos/seed/wedding-venue/900/600'},
    <String, dynamic>{'tag': 'NOUVEAU', 'title': 'Créez votre site', 'subtitle': "De mariage en 5 minutes", 'detail': 'ID unique + invitations digitales', 'cta': 'Commencer', 'imageUrl': 'https://picsum.photos/seed/wedding-couple/900/600'},
    <String, dynamic>{'tag': 'PARTENAIRES', 'title': '+300 prestataires', 'subtitle': 'Vérifiés partout en RDC', 'detail': 'Avis authentiques & prix transparents', 'cta': 'Découvrir', 'imageUrl': 'https://picsum.photos/seed/wedding-deco/900/600'},
  ];
});

final homeCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 150));
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
  return {'Prestataires': 312, 'Avis vérifiés': 1840, 'Offres actives': 26, 'Événements': 97};
});

final homeOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    <String, dynamic>{'title': 'Salles de fête', 'subtitle': 'Réservez votre salle idéale', 'discount': '-30%', 'icon': Icons.villa_outlined, 'color': _WeddingColors.primary},
    <String, dynamic>{'title': 'Traiteurs', 'subtitle': 'Menus spéciaux mariage', 'discount': '-20%', 'icon': Icons.restaurant_outlined, 'color': _WeddingColors.gold},
    <String, dynamic>{'title': 'Photographe', 'subtitle': 'Package complet', 'discount': 'OFFERT', 'icon': Icons.camera_alt_outlined, 'color': const Color(0xFF8B5CF6)},
    <String, dynamic>{'title': 'Décoration', 'subtitle': 'Ambiances inoubliables', 'discount': '-15%', 'icon': Icons.local_florist_outlined, 'color': _WeddingColors.primaryLight},
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
    },
    <String, dynamic>{
      'name': "Saveurs d'Afrique",
      'category': 'Traiteur',
      'zone': 'Goma',
      'rating': 4.9,
      'reviews': 96,
      'price': r'Dès 450$',
    },
    <String, dynamic>{
      'name': 'Lens Prod',
      'category': 'Photographe',
      'zone': 'Lubumbashi',
      'rating': 4.9,
      'reviews': 215,
      'price': r'Dès 300$',
    },
    <String, dynamic>{
      'name': 'Dream Décor',
      'category': 'Décoration',
      'zone': 'Kinshasa',
      'rating': 4.7,
      'reviews': 78,
      'price': r'Dès 250$',
    },
  ];
});

final homeAnnouncementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return [
    <String, dynamic>{
      'tag': 'À VENDRE',
      'title': 'Robe de mariée T38',
      'subtitle': r'450$', 
      'icon': Icons.checkroom_outlined,
    },
    <String, dynamic>{
      'tag': 'À LOUER',
      'title': 'Salle 200 places',
      'subtitle': r'800$ / jour', 
      'icon': Icons.villa_outlined,
    },
    <String, dynamic>{
      'tag': 'SERVICE',
      'title': 'Coiffure & maquillage',
      'subtitle': r'Dès 30$', 
      'icon': Icons.face_retouching_natural_outlined,
    },
  ];
});

// ============================================================
// PAGE PRINCIPALE
// ============================================================
class ThixWeedingHomePage extends ConsumerStatefulWidget {
  const ThixWeedingHomePage({super.key});
  @override
  ConsumerState<ThixWeedingHomePage> createState() => _ThixWeedingHomePageState();
}

class _ThixWeedingHomePageState extends ConsumerState<ThixWeedingHomePage> {
  late final TextEditingController _idController;
  late final FocusNode _focusNode;
  bool _isSearching = false;
  final int _notificationCount = 3;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onStaffAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous pour accéder à l\'espace staff')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: ThixPolicy.danger));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ID introuvable, vérifiez et réessayez'), backgroundColor: ThixPolicy.warning));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onScanQr() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner QR bientôt disponible')));
  }

  void _onNotifications() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications bientôt disponibles')));
  }

  void _onTapGeneric(String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final offersAsync = ref.watch(homeOffersProvider);
    final providersAsync = ref.watch(homeProvidersProvider);
    final announcementsAsync = ref.watch(homeAnnouncementsProvider);

    return Scaffold(
      backgroundColor: _WeddingColors.bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.65),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.2))),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_WeddingColors.primary, _WeddingColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: _WeddingColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              ),
              child: const Center(child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Text('THIX ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _WeddingColors.textDark, letterSpacing: -0.3)), Text('MARIAGE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _WeddingColors.primary, letterSpacing: -0.3))]),
                  Text('L\'élégance de votre union', style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _onNotifications, 
            icon: Badge(
              label: Text('$_notificationCount', style: const TextStyle(fontSize: 8)), 
              backgroundColor: _WeddingColors.primary,
              child: const Icon(Icons.notifications_none_rounded, color: _WeddingColors.textDark, size: 24)
            )
          ),
          IconButton(onPressed: _onStaffAccess, icon: const Icon(Icons.account_circle_outlined, color: _WeddingColors.textDark, size: 24)), 
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 🌟 ARRIÈRE-PLAN MAGIQUE (HAUTE PERFORMANCE)
          const Positioned.fill(child: _WeddingAmbientBackground()),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).top + 64 + 16),
              ),
              
              // RECHERCHE HERO
              SliverToBoxAdapter(
                child: _HeroSearchSection(
                  controller: _idController,
                  focusNode: _focusNode,
                  isLoading: _isSearching,
                  onSearch: _onSearch,
                  onScanQr: _onScanQr,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              
              // CATÉGORIES
              SliverToBoxAdapter(
                child: catsAsync.when(
                  data: (cats) => _CategoryGrid(categories: cats, onTap: _onTapGeneric),
                  loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: _WeddingColors.primary))),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              
              // OFFRES DU MOMENT
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Offres du moment'))),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: offersAsync.when(
                  data: (offers) => _OffersRow(offers: offers, onTap: _onTapGeneric),
                  loading: () => const SizedBox(height: 110, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _WeddingColors.primary))),
                  error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              
              // PRESTATAIRES
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Prestataires recommandés'))),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: providersAsync.when(
                  data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric),
                  loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _WeddingColors.primary))),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              
              // ANNONCES
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Dernières Annonces'))),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: announcementsAsync.when(
                  data: (ann) => _AnnouncementsList(items: ann, onTap: _onTapGeneric),
                  loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _WeddingColors.primary))),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              
              // TRUST BADGES
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TrustRow())),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGETS DE SECTIONS (GLASSMORPHISM)
// ============================================================
class _HeroSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;

  const _HeroSearchSection({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSearch,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _WeddingColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.mark_email_read_rounded, color: _WeddingColors.primary, size: 20)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Rejoindre un mariage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _WeddingColors.textDark, letterSpacing: -0.3))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Entrez l\'ID unique de l\'invitation ou scannez directement le QR Code des mariés.', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white)),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _WeddingColors.textDark, letterSpacing: 1.0),
                                decoration: const InputDecoration(isDense: true, hintText: 'ID du mariage...', hintStyle: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                onSubmitted: (_) => onSearch(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: isLoading ? null : onSearch,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_WeddingColors.primary, _WeddingColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight), 
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _WeddingColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        ),
                        child: isLoading
                            ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                            : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: onScanQr,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white)),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: _WeddingColors.textDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _WeddingColors.textDark, letterSpacing: -0.5)), 
        const Row(
          children: [
            Text('Voir tout', style: TextStyle(fontSize: 12, color: _WeddingColors.primary, fontWeight: FontWeight.w700)), 
            Icon(Icons.chevron_right_rounded, size: 16, color: _WeddingColors.primary)
          ]
        )
      ]
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(String) onTap;
  const _CategoryGrid({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.65), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 8, childAspectRatio: 0.75),
        itemBuilder: (context, i) {
          final c = categories[i];
          return GestureDetector(
            onTap: () => onTap(c['label'] as String),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(
                  width: 48, height: 48, 
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white)), 
                  child: Icon(c['icon'] as IconData, size: 22, color: _WeddingColors.primary)
                ), 
                const SizedBox(height: 8), 
                Text(c['label'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _WeddingColors.textDark))
              ]
            ),
          );
        },
      ),
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
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final o = offers[i];
          final color = o['color'] as Color;
          return InkWell(
            onTap: () => onTap(o['title'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 150, 
              padding: const EdgeInsets.all(14), 
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.9)), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Text(o['discount'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5))), 
                  const Spacer(), 
                  Row(
                    children: [
                      Icon(o['icon'] as IconData, size: 18, color: color), 
                      const SizedBox(width: 6), 
                      Expanded(child: Text(o['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _WeddingColors.textDark))),
                    ]
                  ), 
                  const SizedBox(height: 2), 
                  Text(o['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))
                ]
              )
            ),
          );
        },
      ),
    );
  }
}

class _ProvidersGrid extends StatelessWidget {
  final List<Map<String, dynamic>> providers;
  final void Function(String) onTap;
  const _ProvidersGrid({required this.providers, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: providers.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72),
        itemBuilder: (context, i) {
          final p = providers[i];
          return InkWell(
            onTap: () => onTap(p['name'] as String),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand, 
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), 
                          child: Image.network('https://picsum.photos/seed/${p['name']}/300/300', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: ThixPolicy.surface, child: const Icon(Icons.broken_image_rounded, size: 32, color: ThixPolicy.textSecondary)))
                        ), 
                        Positioned(top: 10, right: 10, child: ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 16, color: _WeddingColors.primary)))))
                      ]
                    )
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _WeddingColors.textDark, letterSpacing: -0.3)), 
                        const SizedBox(height: 2), 
                        Text('${p['category']} · ${p['zone']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)), 
                        const SizedBox(height: 8), 
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [const Icon(Icons.star_rounded, size: 14, color: _WeddingColors.gold), const SizedBox(width: 4), Text('${p['rating']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _WeddingColors.textDark))]), 
                            Text(p['price'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _WeddingColors.primary))
                          ]
                        )
                      ]
                    )
                  ),
                ]
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onTap;
  const _AnnouncementsList({required this.items, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = items[i];
          return InkWell(
            onTap: () => onTap(a['title'] as String),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 150, 
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  SizedBox(
                    height: 70, 
                    child: Stack(
                      children: [
                        Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(22))), child: Center(child: Icon(a['icon'] as IconData, size: 28, color: ThixPolicy.textSecondary.withOpacity(0.5)))), 
                        Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _WeddingColors.textDark, borderRadius: BorderRadius.circular(8)), child: Text(a['tag'] as String, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5))))
                      ]
                    )
                  ), 
                  Padding(
                    padding: const EdgeInsets.all(12), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(a['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _WeddingColors.textDark)), 
                        const Spacer(), 
                        Text(a['subtitle'] as String, style: const TextStyle(fontSize: 12, color: _WeddingColors.primary, fontWeight: FontWeight.w900))
                      ]
                    )
                  )
                ]
              )
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
    {'icon': Icons.shield_outlined, 'title': 'Vérifiés', 'subtitle': 'Garantis'},
    {'icon': Icons.lock_outline_rounded, 'title': 'Paiement', 'subtitle': 'Sécurisé'},
    {'icon': Icons.headset_mic_outlined, 'title': 'Support', 'subtitle': '24/7'},
    {'icon': Icons.star_border_rounded, 'title': 'Avis', 'subtitle': 'Certifiés'},
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.65), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e['icon'] as IconData, size: 24, color: _WeddingColors.primary),
                const SizedBox(height: 8),
                Text(e['title'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _WeddingColors.textDark, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 2),
                Text(e['subtitle'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, height: 1.2)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// WIDGET : BACKGROUND ROMANTIQUE ANIMÉ (OPTIMISÉ HAUTE PERFORMANCE)
// ============================================================================
class _WeddingAmbientBackground extends StatefulWidget {
  const _WeddingAmbientBackground();

  @override
  State<_WeddingAmbientBackground> createState() => _WeddingAmbientBackgroundState();
}

class _WeddingAmbientBackgroundState extends State<_WeddingAmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Cycle fluide et très lent (20s) pour un effet doux et romantique
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🌟 HELPER HAUTE PERFORMANCE : Utilise un RadialGradient (Zéro Flou GPU)
  Widget _buildPerformanceOrb(double left, double top, double width, double height, Color color, double angle) {
    return Positioned(
      left: left - (width / 2),
      top: top - (height / 2),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(0.0), // Fondu doux et naturel
              ],
              stops: const [0.1, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            // Orb 1 : Rose poudré (Bouge doucement en haut)
            final p1X = size.width * 0.4 + math.cos(t * 0.8) * 150.0;
            final p1Y = size.height * 0.2 + math.sin(t * 1.1) * 120.0;

            // Orb 2 : Pêche (Bouge au centre)
            final p2X = size.width * 0.7 + math.sin(t * 1.3) * 180.0;
            final p2Y = size.height * 0.5 + math.cos(t * 0.9) * 180.0;

            // Orb 3 : Or doux (Bouge en bas)
            final p3X = size.width * 0.3 + math.cos(t * 1.5) * 120.0;
            final p3Y = size.height * 0.8 + math.sin(t * 0.7) * 100.0;

            return Stack(
              children: [
                // Orbes dessinés via RadialGradient (Coût GPU = 0)
                _buildPerformanceOrb(p1X, p1Y, 700, 600, _WeddingColors.primaryLight.withOpacity(0.12), t * 0.3),
                _buildPerformanceOrb(p2X, p2Y, 800, 700, _WeddingColors.peach.withOpacity(0.12), -t * 0.4),
                _buildPerformanceOrb(p3X, p3Y, 650, 450, _WeddingColors.gold.withOpacity(0.08), t * 0.5),

                // Voile clair très subtil par-dessus pour adoucir encore plus
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.5),
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
