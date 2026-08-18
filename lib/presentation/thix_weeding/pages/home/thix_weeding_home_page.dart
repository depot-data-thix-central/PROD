// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../core/failure.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';

// ⚠️ AUCUN "part 'thix_weeding_home_page.g.dart';" ici pour éviter tout blocage du build

const Color kWeedingPrimary = Color(0xFFE25A6A);
const Color kWeedingLight = Color(0xFFFF8A9B);

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
    <String, dynamic>{'label': 'Décoration', 'icon': Icons.local_florist_outlined},
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
    <String, dynamic>{'title': 'Salles de fête', 'subtitle': 'Réservez votre salle idéale', 'discount': '-30%', 'icon': Icons.villa_outlined, 'color': kWeedingPrimary},
    <String, dynamic>{'title': 'Traiteurs', 'subtitle': 'Menus spéciaux mariage', 'discount': '-20%', 'icon': Icons.restaurant_outlined, 'color': ThixPolicy.gold},
    <String, dynamic>{'title': 'Photographe', 'subtitle': 'Package complet', 'discount': 'OFFERT', 'icon': Icons.camera_alt_outlined, 'color': ThixPolicy.primaryDeep},
    <String, dynamic>{'title': 'Décoration', 'subtitle': 'Ambiances inoubliables', 'discount': '-15%', 'icon': Icons.local_florist_outlined, 'color': ThixPolicy.primary},
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
      'price': r'Dès 600$', // ✅ raw string — $ littéral
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
      'subtitle': r'450$', // ✅
      'icon': Icons.checkroom_outlined,
    },
    <String, dynamic>{
      'tag': 'À LOUER',
      'title': 'Salle 200 places',
      'subtitle': r'800$ / jour', // ✅
      'icon': Icons.villa_outlined,
    },
    <String, dynamic>{
      'tag': 'SERVICE',
      'title': 'Coiffure & maquillage',
      'subtitle': r'Dès 30$', // ✅
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner QR bientôt disponible')));
  }

  void _onNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications bientôt disponibles')));
  }

  void _onTapGeneric(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final offersAsync = ref.watch(homeOffersProvider);
    final providersAsync = ref.watch(homeProvidersProvider);
    final announcementsAsync = ref.watch(homeAnnouncementsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: kWeedingPrimary, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18)),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Text('THIX ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain)), Text('MARIAGE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kWeedingPrimary))]),
                  Text('Tout pour un mariage parfait', style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
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
              backgroundColor: ThixPolicy.danger,
              child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain, size: 22)
            )
          ),
          IconButton(onPressed: _onStaffAccess, icon: const Icon(Icons.account_circle_outlined, color: ThixPolicy.textMain, size: 22)), 
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSearchSection(
              controller: _idController,
              focusNode: _focusNode,
              isLoading: _isSearching,
              onSearch: _onSearch,
              onScanQr: _onScanQr,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: catsAsync.when(
              data: (cats) => _CategoryGrid(categories: cats, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: kWeedingPrimary))),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Offres du moment'))),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: offersAsync.when(
              data: (offers) => _OffersRow(offers: offers, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kWeedingPrimary))),
              error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Prestataires recommandés'))),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: providersAsync.when(
              data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kWeedingPrimary))),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _SectionHeader(title: 'Dernières Annonces'))),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: announcementsAsync.when(
              data: (ann) => _AnnouncementsList(items: ann, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kWeedingPrimary))),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TrustRow())),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

// ============================================================
// HERO SECTION
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kWeedingPrimary, kWeedingLight]),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.15,
                child: const Icon(Icons.favorite_rounded, size: 140, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Rejoindre un mariage ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 4),
                  const Text('Entrez l\'ID unique ou scannez le QR Code.', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search_rounded, size: 18, color: ThixPolicy.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  textCapitalization: TextCapitalization.characters,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThixPolicy.textMain),
                                  decoration: const InputDecoration(isDense: true, hintText: 'Entrez l\'ID...', hintStyle: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                  onSubmitted: (_) => onSearch(),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: InkWell(
                                  onTap: isLoading ? null : onSearch,
                                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(color: kWeedingPrimary, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                                    child: isLoading
                                        ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                        : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onScanQr,
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: Colors.white54)),
                          child: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                        ),
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain)), 
        const Row(
          children: [
            Text('Voir tout', style: TextStyle(fontSize: 11, color: kWeedingPrimary, fontWeight: FontWeight.w600)), 
            Icon(Icons.chevron_right_rounded, size: 14, color: kWeedingPrimary)
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 4, childAspectRatio: 0.75),
        itemBuilder: (context, i) {
          final c = categories[i];
          return InkWell(
            onTap: () => onTap(c['label'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(
                  width: ThixPolicy.constellationNodeSize,
                  height: ThixPolicy.constellationNodeSize, 
                  decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border)), 
                  child: Icon(c['icon'] as IconData, size: ThixPolicy.constellationNodeIconSize, color: kWeedingPrimary)
                ), 
                const SizedBox(height: 6), 
                Text(c['label'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMain))
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
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final o = offers[i];
          final color = o['color'] as Color;
          return InkWell(
            onTap: () => onTap(o['title'] as String),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: Container(
              width: 140, 
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: color.withOpacity(0.15))), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Text(o['discount'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))), 
                  const Spacer(), 
                  Row(
                    children: [
                      Icon(o['icon'] as IconData, size: 16, color: color), 
                      const SizedBox(width: 6), 
                      Expanded(child: Text(o['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain))),
                    ]
                  ), 
                  const SizedBox(height: 2), 
                  Text(o['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500))
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        itemBuilder: (context, i) {
          final p = providers[i];
          return InkWell(
            onTap: () => onTap(p['name'] as String),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand, 
                      children: [
                        ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)), child: Image.network('https://picsum.photos/seed/${p['name']}/300/300', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: ThixPolicy.surface, child: Icon(Icons.broken_image, size: 32, color: ThixPolicy.textSecondary)))), 
                        Positioned(top: 8, right: 8, child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 14, color: kWeedingPrimary)))
                      ]
                    )
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)), 
                        const SizedBox(height: 2), 
                        Text('${p['category']} · ${p['zone']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)), 
                        const SizedBox(height: 6), 
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [const Icon(Icons.star_rounded, size: 12, color: ThixPolicy.gold), const SizedBox(width: 3), Text('${p['rating']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textMain))]), 
                            Text(p['price'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kWeedingPrimary))
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
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = items[i];
          return InkWell(
            onTap: () => onTap(a['title'] as String),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            child: Container(
              width: 140, 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  SizedBox(
                    height: 56, 
                    child: Stack(
                      children: [
                        Container(width: double.infinity, decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd))), child: Center(child: Icon(a['icon'] as IconData, size: 22, color: ThixPolicy.textSecondary))), 
                        Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ThixPolicy.primaryDeep, borderRadius: BorderRadius.circular(6)), child: Text(a['tag'] as String, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))))
                      ]
                    )
                  ), 
                  Padding(
                    padding: const EdgeInsets.all(10), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(a['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)), 
                        const Spacer(), 
                        Text(a['subtitle'] as String, style: const TextStyle(fontSize: 10, color: kWeedingPrimary, fontWeight: FontWeight.w800))
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e['icon'] as IconData, size: 20, color: kWeedingPrimary),
                const SizedBox(height: 6),
                Text(e['title'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: ThixPolicy.textMain, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 2),
                Text(e['subtitle'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500, height: 1.2)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
