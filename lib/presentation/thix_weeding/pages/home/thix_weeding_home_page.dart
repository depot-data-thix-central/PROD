// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
// ============================================================================
// THIX WEDDING HOME PAGE — DESIGN v8.0 (DONNÉES RÉELLES — PLUS DE MOCK-UPS)
// ✅ SUPPRIMÉ : offres statiques "−30% / −20% / OFFERT" (mock-ups)
// ✅ SUPPRIMÉ : annonces statiques "Robe T38 / Salle 200 places" (mock-ups)
// ✅ NOUVEAU : sections dynamiques alimentées par les offres publiées :
//    • Offre de la semaine (grande carte vedette)
//    • Promotions (offres type promo)
//    • Dernières annonces (offres récentes)
//    • Service traiteur (offres catégorie traiteur)
//    • Le plus réservé (prestataires triés par avis)
//    • Sections par catégorie (Salles, Traiteurs, Photos…)
// ✅ CARTES AGRANDIES : offres 240×280, prestataires 260×320, vedette pleine largeur
// ✅ Multi-photos (PageView) sur toutes les cartes offres & prestataires
// ✅ Filtre prestataires assoupli : pending inclus, rejected exclu
// ✅ Hero admin 12 photos conservé · Appbar verre · Orbe invitations conservés
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import '../provider_portal/provider_offers_page.dart' show offerTypeColor, offerTypeIcon;

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE
// ═══════════════════════════════════════════════════════════════════════════
class _W {
  static const Color bg = Color(0xFFFFFBFC);
  static const Color surface = Colors.white;
  static const Color tile = Color(0xFFFFF4F7);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFF1E3E8);

  static const Color rose = Color(0xFFD81B60);
  static const Color roseLight = Color(0xFFFF6F9C);
  static const Color roseSoft = Color(0xFFFCE4EC);

  static const Color peach = Color(0xFFFFB8A8);
  static const Color gold = Color(0xFFFFD700);
  static const Color plum = Color(0xFFA855F7);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);

  static const LinearGradient roseG = LinearGradient(
    colors: [Color(0xFFE91E78), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const int kHeroMax = 12;
const String _kHeroBucket = 'thix-weeding-hero';
const String _kHeroTable = 'thix_weeding_home_hero';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE HERO + PROVIDERS DYNAMIQUES
// ═══════════════════════════════════════════════════════════════════════════
class HomeHeroPhoto {
  final String id;
  final String url;
  final String? path;
  final String? title;
  final String? subtitle;
  final int position;

  const HomeHeroPhoto({
    required this.id,
    required this.url,
    this.path,
    this.title,
    this.subtitle,
    required this.position,
  });

  factory HomeHeroPhoto.fromJson(Map<String, dynamic> j) => HomeHeroPhoto(
        id: j['id'].toString(),
        url: (j['image_url'] as String?) ?? '',
        path: j['storage_path'] as String?,
        title: j['title'] as String?,
        subtitle: j['subtitle'] as String?,
        position: (j['position'] as num?)?.toInt() ?? 0,
      );
}

final homeHeroPhotosProvider = FutureProvider<List<HomeHeroPhoto>>((ref) async {
  try {
    final rows = await Supabase.instance.client
        .from(_kHeroTable)
        .select()
        .order('position', ascending: true)
        .limit(kHeroMax);
    return (rows as List)
        .map((e) => HomeHeroPhoto.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.url.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Détection du rôle Admin ──
const Set<String> _adminWords = {
  'admin',
  'super_admin',
  'superadmin',
  'super-admin',
  'administrator',
  'owner',
  'founder',
};

bool _truthy(dynamic v) {
  if (v == true) return true;
  final s = '$v'.toLowerCase().trim();
  return s == 'true' || s == 't' || s == '1';
}

bool _rowIsAdmin(Map<String, dynamic> r) {
  const roleKeys = ['role', 'user_role', 'account_type', 'type', 'roles', 'app_role', 'profile_role'];
  for (final k in roleKeys) {
    final v = r[k];
    if (v == null) continue;
    if (v is List) {
      if (v.any((e) => _adminWords.contains('$e'.toLowerCase().trim()))) return true;
    } else if (_adminWords.contains('$v'.toLowerCase().trim())) {
      return true;
    }
  }
  const flagKeys = ['is_admin', 'admin', 'is_super_admin', 'is_superadmin'];
  for (final k in flagKeys) {
    if (r.containsKey(k) && _truthy(r[k])) return true;
  }
  return false;
}

Future<bool> _profileSaysAdmin(String uid) async {
  final supa = Supabase.instance.client;
  for (final col in ['id', 'user_id']) {
    try {
      final row = await supa.from('profiles').select().eq(col, uid).maybeSingle();
      if (row != null) return _rowIsAdmin(Map<String, dynamic>.from(row));
    } catch (_) {}
  }
  return false;
}

final homeIsAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final supa = Supabase.instance.client;
  final user = supa.auth.currentUser;
  if (user == null) return false;
  try {
    final r = await supa.rpc('thix_weeding_is_admin');
    if (r == true) return true;
  } catch (_) {}
  return _profileSaysAdmin(user.id);
});

// ── Slides du hero : photos admin uniquement (fallback branding si vide) ──
final homePromoSlidesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 150));
  return [
    <String, dynamic>{
      'tag': 'THIX WEDDING',
      'title': "L'élégance de votre union",
      'subtitle': 'Organisez le plus beau jour de votre vie',
      'cta': 'Découvrir',
      'imageUrl': 'https://images.unsplash.com/photo-1519741497674-611481863552?w=1200&q=80',
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

// ✅ Prestataires groupés par catégorie — pending inclus, rejected exclu
final homeProvidersByCategoryProvider =
    FutureProvider<Map<ProviderCategory, List<ThixProviderModel>>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  try {
    final allProviders = await service.getAllProviders(limit: 100, isAvailable: true);
    final usable = allProviders
        .where((p) => p.verificationStatus != ProviderVerificationStatus.rejected)
        .toList();

    final grouped = <ProviderCategory, List<ThixProviderModel>>{};
    for (final p in usable) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final scoreA = a.rating * 10 + a.reviewCount;
        final scoreB = b.rating * 10 + b.reviewCount;
        return scoreB.compareTo(scoreA);
      });
    }
    return grouped;
  } catch (e) {
    return {};
  }
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

  RealtimeChannel? _heroChannel;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _focusNode = FocusNode();
    _scrollController.addListener(_onScroll);

    _heroChannel = Supabase.instance.client
        .channel('home-hero')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _kHeroTable,
          callback: (_) {
            if (mounted) ref.invalidate(homeHeroPhotosProvider);
          },
        )
        .subscribe();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) ref.invalidate(homeIsAdminProvider);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    if (_heroChannel != null) Supabase.instance.client.removeChannel(_heroChannel!);
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
      final provider = await ref.read(providerServiceProvider).getByOwner(user.id);
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

  void _onCategoryTap(ProviderCategory? category) {
    HapticFeedback.mediumImpact();
    if (category != null) {
      context.push('/thix-weeding/provider/catalog?category=${category.name}');
    } else {
      context.push('/thix-weeding/provider/catalog');
    }
  }

  void _openOffer(ProviderOfferModel offer) {
    HapticFeedback.mediumImpact();
    context.push('/thix-weeding/provider/detail/${offer.providerId}');
  }

  void _openProvider(ThixProviderModel provider) {
    HapticFeedback.mediumImpact();
    context.push('/thix-weeding/provider/detail/${provider.id}');
  }

  void _openHeroManager() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HeroManagerSheet(
        onChanged: () => ref.invalidate(homeHeroPhotosProvider),
      ),
    );
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

  List<Map<String, dynamic>> _mergeSlides(
    List<Map<String, dynamic>> promos,
    List<HomeHeroPhoto> photos,
  ) {
    if (photos.isEmpty) return promos;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < photos.length; i++) {
      final p = photos[i];
      final base = promos.isEmpty ? const <String, dynamic>{} : promos[i % promos.length];
      final hasTitle = (p.title ?? '').trim().isNotEmpty;
      final hasSub = (p.subtitle ?? '').trim().isNotEmpty;
      out.add(<String, dynamic>{
        'tag': hasTitle ? 'THIX WEDDING' : (base['tag'] ?? 'THIX WEDDING'),
        'title': hasTitle ? p.title!.trim() : (base['title'] ?? "L'élégance de votre union"),
        'subtitle': hasSub ? p.subtitle!.trim() : (base['subtitle'] ?? 'Organisez le plus beau jour de votre vie'),
        'cta': base['cta'] ?? 'Découvrir',
        'imageUrl': p.url,
      });
    }
    return out;
  }

  /// ✅ Offre vedette : dernière offre active avec photo (sinon la plus récente)
  ProviderOfferModel? _pickFeatured(List<ProviderOfferModel> offers) {
    if (offers.isEmpty) return null;
    final withImg = offers.where((o) => o.allImages.isNotEmpty).toList();
    return (withImg.isNotEmpty ? withImg : offers).first;
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final providersByCategoryAsync = ref.watch(homeProvidersByCategoryProvider);
    final offersAsync = ref.watch(activeOffersProvider); // ✅ OFFRES RÉELLES
    final promosAsync = ref.watch(homePromoSlidesProvider);
    final heroAsync = ref.watch(homeHeroPhotosProvider);
    final activeInvitesAsync = ref.watch(myActiveInvitationsProvider);
    final isAdmin = ref.watch(homeIsAdminProvider).value ?? false;
    final topPad = MediaQuery.paddingOf(context);
    final screenH = MediaQuery.of(context).size.height;
    final heroH = (screenH * 0.62).clamp(470.0, 580.0).toDouble();

    return Scaffold(
      backgroundColor: _W.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
          RefreshIndicator(
            color: _W.rose,
            backgroundColor: _W.surface,
            edgeOffset: topPad.top + 60,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(homePromoSlidesProvider);
              ref.invalidate(homeHeroPhotosProvider);
              ref.invalidate(homeIsAdminProvider);
              ref.invalidate(homeCategoriesProvider);
              ref.invalidate(homeProvidersByCategoryProvider);
              ref.invalidate(activeOffersProvider); // ✅ rafraîchit les offres
              ref.invalidate(myActiveInvitationsProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ═══════════════ HERO ═══════════════
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: heroH,
                    child: promosAsync.when(
                      data: (promos) {
                        if (heroAsync.isLoading && !heroAsync.hasValue) {
                          return Container(
                            color: _W.tile,
                            child: const Center(
                              child: CircularProgressIndicator(color: _W.rose, strokeWidth: 2.5),
                            ),
                          );
                        }
                        final photos = heroAsync.value ?? const <HomeHeroPhoto>[];
                        return _HeroCarousel(
                          slides: _mergeSlides(promos, photos),
                          topPad: topPad.top,
                          idController: _idController,
                          focusNode: _focusNode,
                          isSearching: _isSearching,
                          onSearch: _onSearch,
                          onScanQr: _onScanQr,
                          isAdmin: isAdmin,
                          photoCount: photos.length,
                          onManage: _openHeroManager,
                        );
                      },
                      loading: () => Container(
                        color: _W.tile,
                        child: const Center(child: CircularProgressIndicator(color: _W.rose, strokeWidth: 2.5)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ═══════════════ CATÉGORIES ═══════════════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: catsAsync.when(
                      data: (cats) => _CategoryRow(categories: cats, onTap: _onCategoryTap),
                      loading: () => const SizedBox(height: 86),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // ═══════════════ SECTIONS OFFRES RÉELLES ═══════════════
                offersAsync.when(
                  data: (allOffers) {
                    if (allOffers.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                    final featured = _pickFeatured(allOffers);
                    final promoOffers = allOffers.where((o) => o.type == OfferType.promo).toList();
                    final latestOffers = allOffers.take(10).toList();
                    final traiteurOffers =
                        allOffers.where((o) => o.category == ProviderCategory.traiteur).toList();

                    return SliverList(
                      delegate: SliverChildListDelegate([
                        // ── 1. OFFRE DE LA SEMAINE ──
                        if (featured != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: _SectionHeader(title: 'Offre de la semaine'),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _FeaturedOfferCard(offer: featured, onTap: () => _openOffer(featured)),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // ── 2. PROMOTIONS ──
                        if (promoOffers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _SectionHeader(
                              title: 'Promotions',
                              showSeeAll: true,
                              onSeeAll: () => _onCategoryTap(null),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _OffersRowDynamic(offers: promoOffers, onTap: _openOffer),
                          const SizedBox(height: 28),
                        ],

                        // ── 3. DERNIÈRES ANNONCES ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _SectionHeader(
                            title: 'Dernières annonces',
                            showSeeAll: true,
                            onSeeAll: () => _onCategoryTap(null),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _OffersRowDynamic(offers: latestOffers, onTap: _openOffer),
                        const SizedBox(height: 28),

                        // ── 4. SERVICE TRAITEUR ──
                        if (traiteurOffers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _SectionHeader(
                              title: 'Service traiteur',
                              showSeeAll: true,
                              onSeeAll: () => _onCategoryTap(ProviderCategory.traiteur),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _OffersRowDynamic(offers: traiteurOffers, onTap: _openOffer),
                          const SizedBox(height: 28),
                        ],
                      ]),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: _W.rose))),
                  ),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                // ═══════════════ SECTIONS PRESTATAIRES RÉELS ═══════════════
                providersByCategoryAsync.when(
                  data: (providersByCategory) {
                    final offersCount = offersAsync.valueOrNull?.length ?? 0;

                    if (providersByCategory.isEmpty && offersCount == 0) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: _EmptyProviders(),
                        ),
                      );
                    }
                    if (providersByCategory.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    // ── 5. LE PLUS RÉSERVÉ (toutes catégories, trié par avis) ──
                    final allProviders = providersByCategory.values.expand((l) => l).toList();
                    allProviders.sort((a, b) {
                      final scoreA = a.reviewCount * 10 + (a.rating * 100).toInt();
                      final scoreB = b.reviewCount * 10 + (b.rating * 100).toInt();
                      return scoreB.compareTo(scoreA);
                    });
                    final topReserved = allProviders.take(10).toList();

                    return SliverList(
                      delegate: SliverChildListDelegate([
                        if (topReserved.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: _SectionHeader(title: 'Le plus réservé'),
                          ),
                          const SizedBox(height: 12),
                          _ProvidersRowDynamic(providers: topReserved, onTap: _openProvider),
                          const SizedBox(height: 28),
                        ],

                        // ── 6. SECTIONS PAR CATÉGORIE ──
                        ...providersByCategory.entries.map((entry) {
                          final category = entry.key;
                          final providers = entry.value.take(10).toList();
                          if (providers.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                child: _SectionHeader(
                                  title: category.displayName,
                                  showSeeAll: true,
                                  onSeeAll: () => _onCategoryTap(category),
                                ),
                              ),
                              _ProvidersRowDynamic(providers: providers, onTap: _openProvider),
                              const SizedBox(height: 28),
                            ],
                          );
                        }),
                      ]),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator(color: _W.rose)),
                    ),
                  ),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _TrustRow()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 70)),
              ],
            ),
          ),
          activeInvitesAsync.when(
            data: (invites) {
              if (invites.isEmpty) return const SizedBox.shrink();
              return Positioned(
                right: 12,
                top: topPad.top + 70,
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
            onStaff: _onStaffAccess,
            onProvider: _onProviderAccess,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ CARTE VEDETTE "OFFRE DE LA SEMAINE" (pleine largeur, 300 de haut)
// ═══════════════════════════════════════════════════════════════════════════
class _FeaturedOfferCard extends StatelessWidget {
  final ProviderOfferModel offer;
  final VoidCallback onTap;

  const _FeaturedOfferCard({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    final images = offer.allImages;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Images (carrousel si multi-photos)
            if (images.isNotEmpty)
              PageView.builder(
                itemCount: images.length,
                itemBuilder: (_, i) => Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: _W.tile),
                ),
              )
            else
              Container(
                color: color.withOpacity(0.15),
                child: Icon(offerTypeIcon(offer.type), size: 64, color: color),
              ),

            // Dégradé de lisibilité
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                    Colors.black.withOpacity(0.72),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Badge vedette
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(gradient: _W.roseG, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('OFFRE DE LA SEMAINE',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ),

            // Badge type + compteur photos
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                children: [
                  if (images.length > 1)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${images.length}',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                    child: Text(offer.type.displayName.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),

            // Contenu bas
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${offer.providerBusinessName ?? ''} · ${offer.providerCategoryName != null ? stringToProviderCategory(offer.providerCategoryName).displayName : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _W.rose),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Voir l\'offre',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                          ],
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

// ═══════════════════════════════════════════════════════════════════════════
// ✅ RANGÉE D'OFFRES DYNAMIQUE (cartes agrandies 240×280)
// ═══════════════════════════════════════════════════════════════════════════
class _OffersRowDynamic extends StatelessWidget {
  final List<ProviderOfferModel> offers;
  final void Function(ProviderOfferModel) onTap;

  const _OffersRowDynamic({required this.offers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        clipBehavior: Clip.none,
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _OfferCardLarge(offer: offers[i], onTap: () => onTap(offers[i])),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ CARTE OFFRE AGRANDIE (240 de large, multi-photos)
// ═══════════════════════════════════════════════════════════════════════════
class _OfferCardLarge extends StatelessWidget {
  final ProviderOfferModel offer;
  final VoidCallback onTap;

  const _OfferCardLarge({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    final images = offer.allImages;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: _W.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _W.line),
          boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withOpacity(0.12),
                          child: Icon(offerTypeIcon(offer.type), size: 40, color: color),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: color.withOpacity(0.12),
                      child: Icon(offerTypeIcon(offer.type), size: 40, color: color),
                    ),

                  // Badge type
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.type.displayName.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),

                  // Compteur photos
                  if (images.length > 1)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('${images.length}',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  // Badge catégorie (en bas de l'image)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        offer.category.displayName,
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: _W.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          offer.providerBusinessName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11, color: _W.inkSoft, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _W.rose),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _W.rose),
                      ],
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
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ RANGÉE PRESTATAIRES DYNAMIQUE (cartes agrandies 260×320)
// ═══════════════════════════════════════════════════════════════════════════
class _ProvidersRowDynamic extends StatelessWidget {
  final List<ThixProviderModel> providers;
  final void Function(ThixProviderModel) onTap;

  const _ProvidersRowDynamic({required this.providers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        clipBehavior: Clip.none,
        itemCount: providers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _ProviderCardLarge(provider: providers[i], onTap: () => onTap(providers[i])),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ CARTE PRESTATAIRE AGRANDIE (260 de large, multi-photos, badge statut)
// ═══════════════════════════════════════════════════════════════════════════
class _ProviderCardLarge extends StatelessWidget {
  final ThixProviderModel provider;
  final VoidCallback onTap;

  const _ProviderCardLarge({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final images = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls
        : ['https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: _W.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _W.line),
          boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 9))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (_, i) => Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _W.tile,
                        child: const Icon(Icons.broken_image_outlined, size: 32, color: _W.inkSoft),
                      ),
                    ),
                  ),

                  // Badge Premium / Certifié
                  if (provider.level == TrackingLevel.platinum)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_W.gold, Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: _W.gold.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('PREMIUM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    )
                  else if (provider.level == TrackingLevel.gold)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _W.green, borderRadius: BorderRadius.circular(10)),
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

                  // Badge statut vérification
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                      ),
                      child: Icon(
                        provider.verificationStatus == ProviderVerificationStatus.verified
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                        size: 15,
                        color: provider.verificationStatus == ProviderVerificationStatus.verified ? _W.green : _W.amber,
                      ),
                    ),
                  ),

                  // Compteur photos
                  if (images.length > 1)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('${images.length}',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${provider.category.displayName} · ${provider.city ?? 'RDC'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _W.inkSoft, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: _W.gold),
                            const SizedBox(width: 3),
                            Text(provider.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: _W.ink)),
                            Text(' (${provider.reviewCount})', style: GoogleFonts.inter(fontSize: 10.5, color: _W.inkSoft)),
                          ],
                        ),
                        Text(
                          provider.minPrice != null ? 'Dès ${provider.minPrice!.toStringAsFixed(0)}\$' : 'Sur devis',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: _W.rose),
                        ),
                      ],
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
}

// ✅ État vide quand aucun prestataire & aucune offre
class _EmptyProviders extends StatelessWidget {
  const _EmptyProviders();

  @override
  Widget build(BuildContext context) {
    return ThixGlass(
      radius: 20,
      opacity: 0.55,
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.store_outlined, size: 40, color: _W.inkSoft),
            const SizedBox(height: 10),
            Text('Aucun prestataire disponible', style: GoogleFonts.inter(fontSize: 13, color: _W.inkSoft)),
            const SizedBox(height: 4),
            Text('Les offres publiées apparaîtront ici.', style: GoogleFonts.inter(fontSize: 11, color: _W.inkSoft)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR VERRE DÉPOLI (compacte)
// ═══════════════════════════════════════════════════════════════════════════
class _GlassAppBar extends StatelessWidget {
  final double topPad;
  final ValueNotifier<double> scrollY;
  final VoidCallback onStaff;
  final VoidCallback onProvider;

  const _GlassAppBar({required this.topPad, required this.scrollY, required this.onStaff, required this.onProvider});

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
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: EdgeInsets.fromLTRB(14, topPad + 8, 14, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.30 + 0.45 * t),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.75), width: 1.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: _W.roseG,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'THIX WEDDING',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              color: const Color(0xFF3B3B44).withOpacity(0.82),
                            ),
                          ),
                          Text(
                            "L'élégance de votre union",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 9.5, color: _W.ink.withOpacity(0.55), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    _AppBarBtn(icon: Icons.store_outlined, onTap: onProvider),
                    const SizedBox(width: 7),
                    _AppBarBtn(icon: Icons.account_circle_outlined, onTap: onStaff),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
          boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, size: 18, color: _W.rose),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO : PHOTOS EN DÉFILEMENT AUTOMATIQUE
// ═══════════════════════════════════════════════════════════════════════════
class _HeroCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> slides;
  final double topPad;
  final TextEditingController idController;
  final FocusNode focusNode;
  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;
  final bool isAdmin;
  final int photoCount;
  final VoidCallback onManage;

  const _HeroCarousel({
    required this.slides,
    required this.topPad,
    required this.idController,
    required this.focusNode,
    required this.isSearching,
    required this.onSearch,
    required this.onScanQr,
    required this.isAdmin,
    required this.photoCount,
    required this.onManage,
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
  void didUpdateWidget(covariant _HeroCarousel old) {
    super.didUpdateWidget(old);
    if (_current >= widget.slides.length) {
      _current = 0;
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || widget.slides.length <= 1 || !_pageCtrl.hasClients) return;
      _pageCtrl.animateToPage(
        (_current + 1) % widget.slides.length,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return Container(color: _W.tile);
    final cur = _current.clamp(0, slides.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (_) => _startAuto(),
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final slide = slides[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey('kb-$i-${slide['imageUrl']}'),
                    tween: Tween(begin: 1.0, end: 1.08),
                    duration: const Duration(seconds: 7),
                    curve: Curves.easeOut,
                    builder: (_, s, child) => Transform.scale(scale: s, child: child),
                    child: Image.network(
                      slide['imageUrl'] as String,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      frameBuilder: (ctx, child, frame, sync) => AnimatedOpacity(
                        opacity: (frame != null || sync) ? 1 : 0,
                        duration: const Duration(milliseconds: 450),
                        child: child,
                      ),
                      errorBuilder: (_, __, ___) => Container(
                        color: _W.tile,
                        child: const Center(child: Icon(Icons.broken_image_outlined, color: _W.inkSoft, size: 44)),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.18),
                          Colors.transparent,
                          Colors.black.withOpacity(0.32),
                          Colors.black.withOpacity(0.55),
                        ],
                        stops: const [0.0, 0.3, 0.68, 1.0],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        if (widget.isAdmin)
          Positioned(
            top: widget.topPad + 70,
            left: 12,
            child: GestureDetector(
              onTap: widget.onManage,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                decoration: BoxDecoration(
                  gradient: _W.roseG,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.4),
                  boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, size: 17, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Photos ${widget.photoCount}/$kHeroMax',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(6)),
                      child: Text('ADMIN',
                          style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w900, color: _W.rose, letterSpacing: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          left: 18,
          right: 18,
          bottom: 168,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: _HeroContent(key: ValueKey(cur), slide: slides[cur]),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 148,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == cur;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: active ? 18 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? _W.rose : Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: _JoinBar(
            controller: widget.idController,
            focusNode: widget.focusNode,
            isLoading: widget.isSearching,
            onSearch: widget.onSearch,
            onScanQr: widget.onScanQr,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(gradient: _W.roseG, borderRadius: BorderRadius.circular(11)),
          child: Text(
            (slide['tag'] as String).toUpperCase(),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide['title'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w700,
            height: 1.05,
            fontStyle: FontStyle.italic,
            shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 14)],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slide['subtitle'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.95),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
            shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 10)],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: _W.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: Text('Fonctionnalité en cours de déploiement', style: GoogleFonts.inter(color: Colors.white)),
              ));
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: Text(slide['cta'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _W.ink,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BARRE « REJOINDRE UN MARIAGE »
// ═══════════════════════════════════════════════════════════════════════════
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
    return ThixGlass(
      radius: 24,
      blur: 22,
      opacity: 0.58,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _W.rose.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_read_rounded, color: _W.rose, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Rejoindre un mariage',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _focused ? _W.rose : _W.line, width: _focused ? 1.6 : 1.1),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _W.ink, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      hintText: 'THIX-W-1510-482AB',
                      hintStyle: GoogleFonts.inter(fontSize: 11.5, color: _W.inkSoft, fontWeight: FontWeight.w500, letterSpacing: 0.6),
                      prefixIcon: Icon(Icons.search_rounded, size: 17, color: _focused ? _W.rose : _W.inkSoft),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      suffixIcon: _hasText
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.cancel_rounded, size: 16, color: _W.inkSoft),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                widget.controller.clear();
                                widget.focusNode.requestFocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => widget.onSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              InkWell(
                onTap: widget.isLoading ? null : widget.onSearch,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _W.roseG,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.32), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: widget.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: widget.onScanQr,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _W.line),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 19, color: _W.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 11, color: _W.inkSoft),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Code sur l'invitation (THIX-W-JJMM-XXXYY)",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10, color: _W.inkSoft, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FEUILLE ADMIN : GÉRER LES 12 PHOTOS DU HERO
// ═══════════════════════════════════════════════════════════════════════════
class _HeroManagerSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _HeroManagerSheet({required this.onChanged});

  @override
  State<_HeroManagerSheet> createState() => _HeroManagerSheetState();
}

class _HeroManagerSheetState extends State<_HeroManagerSheet> {
  final _supa = Supabase.instance.client;
  List<HomeHeroPhoto> _photos = [];
  bool _loading = true;
  bool _busy = false;
  String _msg = '';
  bool _msgError = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _say(String m, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _msg = m;
      _msgError = error;
    });
  }

  Future<void> _reload() async {
    try {
      final rows = await _supa.from(_kHeroTable).select().order('position', ascending: true);
      if (!mounted) return;
      setState(() {
        _photos = (rows as List)
            .map((e) => HomeHeroPhoto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _say('Chargement impossible : $e', error: true);
    }
  }

  String _mime(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _add() async {
    final remaining = kHeroMax - _photos.length;
    if (remaining <= 0) {
      _say('Maximum $kHeroMax photos atteint. Supprimez-en une d\'abord.', error: true);
      return;
    }
    List<XFile> picked;
    try {
      picked = await ImagePicker().pickMultiImage(maxWidth: 1800, imageQuality: 82);
    } catch (e) {
      _say('Galerie inaccessible : $e', error: true);
      return;
    }
    if (picked.isEmpty) return;

    final toSend = picked.take(remaining).toList();
    final skipped = picked.length - toSend.length;
    setState(() => _busy = true);

    final basePos = _photos.isEmpty ? 0 : _photos.map((p) => p.position).reduce(math.max) + 1;
    var ok = 0;

    for (var i = 0; i < toSend.length; i++) {
      _say('Envoi ${i + 1}/${toSend.length}…');
      String? path;
      try {
        final x = toSend[i];
        final bytes = await x.readAsBytes();
        var ext = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpg';
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
        path = 'hero/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await _supa.storage.from(_kHeroBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: _mime(ext), upsert: false),
            );
        final url = _supa.storage.from(_kHeroBucket).getPublicUrl(path);
        await _supa.from(_kHeroTable).insert({
          'image_url': url,
          'storage_path': path,
          'position': basePos + i,
        });
        ok++;
      } catch (e) {
        if (path != null) {
          try {
            await _supa.storage.from(_kHeroBucket).remove([path]);
          } catch (_) {}
        }
        _say('Échec : $e', error: true);
      }
    }

    await _reload();
    widget.onChanged();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok > 0) {
      _say('$ok photo(s) ajoutée(s)${skipped > 0 ? ' — $skipped ignorée(s) (limite de $kHeroMax)' : ''}');
    }
  }

  Future<void> _delete(HomeHeroPhoto p) async {
    setState(() => _busy = true);
    try {
      if (p.path != null && p.path!.isNotEmpty) {
        try {
          await _supa.storage.from(_kHeroBucket).remove([p.path!]);
        } catch (_) {}
      }
      await _supa.from(_kHeroTable).delete().eq('id', p.id);
      await _reload();
      widget.onChanged();
      _say('Photo supprimée');
    } catch (e) {
      _say('Suppression impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move(int i, int dir) async {
    final j = i + dir;
    if (j < 0 || j >= _photos.length) return;
    setState(() => _busy = true);
    try {
      final a = _photos[i];
      final b = _photos[j];
      await _supa.from(_kHeroTable).update({'position': j}).eq('id', a.id);
      await _supa.from(_kHeroTable).update({'position': i}).eq('id', b.id);
      await _reload();
      widget.onChanged();
    } catch (e) {
      _say('Réorganisation impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(HomeHeroPhoto p) async {
    final tCtrl = TextEditingController(text: p.title ?? '');
    final sCtrl = TextEditingController(text: p.subtitle ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Texte de la photo', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tCtrl, maxLength: 60, decoration: const InputDecoration(labelText: 'Titre (optionnel)')),
            TextField(controller: sCtrl, maxLength: 110, maxLines: 2, decoration: const InputDecoration(labelText: 'Sous-titre (optionnel)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _W.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    final title = tCtrl.text.trim();
    final sub = sCtrl.text.trim();
    tCtrl.dispose();
    sCtrl.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _supa.from(_kHeroTable).update({
        'title': title.isEmpty ? null : title,
        'subtitle': sub.isEmpty ? null : sub,
      }).eq('id', p.id);
      await _reload();
      widget.onChanged();
    } catch (e) {
      _say('Modification impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final full = _photos.length >= kHeroMax;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.86),
        child: ThixGlass(
          radius: 30,
          opacity: 0.78,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: _W.inkSoft.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(gradient: _W.roseG, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Photos du hero', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _W.ink)),
                        Text('${_photos.length}/$kHeroMax · défilement automatique',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _W.inkSoft, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: (_msgError ? _W.rose : _W.green).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (_msgError ? _W.rose : _W.green).withOpacity(0.4)),
                  ),
                  child: Text(_msg,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _msgError ? _W.rose : _W.green)),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: _W.rose, strokeWidth: 2.5))
                    : GridView.builder(
                        shrinkWrap: true,
                        itemCount: _photos.length + (full ? 0 : 1),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (_, i) {
                          if (i == _photos.length) {
                            return GestureDetector(
                              onTap: _busy ? null : _add,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _W.roseSoft.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: _W.rose.withOpacity(0.5), width: 1.6),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_rounded, color: _W.rose, size: 30),
                                    const SizedBox(height: 6),
                                    Text('Ajouter', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _W.rose)),
                                    Text('${kHeroMax - _photos.length} restante(s)', style: GoogleFonts.inter(fontSize: 9.5, color: _W.inkSoft)),
                                  ],
                                ),
                              ),
                            );
                          }
                          final p = _photos[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  p.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: _W.tile, child: const Icon(Icons.broken_image_outlined, color: _W.inkSoft)),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                                      stops: const [0.5, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(color: _W.rose, shape: BoxShape.circle),
                                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _busy ? null : () => _delete(p),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                                      child: const Icon(Icons.delete_outline_rounded, size: 16, color: _W.rose),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 2,
                                  right: 2,
                                  bottom: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _tinyBtn(Icons.chevron_left_rounded, i > 0 && !_busy ? () => _move(i, -1) : null),
                                      _tinyBtn(Icons.edit_rounded, _busy ? null : () => _edit(p)),
                                      _tinyBtn(Icons.chevron_right_rounded, i < _photos.length - 1 && !_busy ? () => _move(i, 1) : null),
                                    ],
                                  ),
                                ),
                                if ((p.title ?? '').trim().isNotEmpty)
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    bottom: 30,
                                    child: Text(p.title!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_busy)
                const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: _W.rose, backgroundColor: _W.roseSoft, minHeight: 3)),
              const SizedBox(height: 10),
              Text(
                'Formats JPG, PNG, WebP · 8 Mo max par photo · l\'ordre = l\'ordre de défilement.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 10.5, color: _W.inkSoft, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(onTap == null ? 0.25 : 0.85),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: onTap == null ? Colors.white54 : _W.ink),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// CATÉGORIES (boutons ronds compacts)
// ═══════════════════════════════════════════════════════════════════════════
class _CategoryRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(ProviderCategory?) onTap;

  const _CategoryRow({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFFFEFF4)]),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.16), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Icon(c['icon'] as IconData, size: 22, color: _W.rose),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c['label'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _W.ink),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.showSeeAll = false, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3.5, height: 17, decoration: BoxDecoration(gradient: _W.roseG, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _W.ink, letterSpacing: -0.4)),
        ),
        if (showSeeAll && onSeeAll != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSeeAll!();
            },
            child: Row(
              children: [
                Text('Voir tout', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: _W.rose)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _W.rose),
              ],
            ),
          ),
      ],
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
    return ThixGlass(
      radius: 22,
      opacity: 0.55,
      borderColor: _W.rose.withOpacity(0.14),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _W.rose.withOpacity(0.10), shape: BoxShape.circle),
                  child: Icon(e['icon'] as IconData, size: 16, color: _W.rose),
                ),
                const SizedBox(height: 5),
                Text(e['title'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10.5, color: _W.ink, fontWeight: FontWeight.w800, height: 1.2)),
                Text(e['subtitle'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 9, color: _W.inkSoft, fontWeight: FontWeight.w600, height: 1.2)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOND AMBIANT
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
                _orb(s.width * 0.2, s.height * 0.15 + math.sin(t * 0.8) * 20, 520, 480, _W.roseLight.withOpacity(0.10), t * 0.2),
                _orb(s.width * 0.85, s.height * 0.5 + math.cos(t * 0.6) * 25, 600, 540, _W.peach.withOpacity(0.09), -t * 0.15),
                _orb(s.width * 0.3, s.height * 0.85 + math.sin(t * 0.7) * 15, 480, 420, _W.gold.withOpacity(0.05), t * 0.25),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ORBE « MES INVITATIONS »
// ═══════════════════════════════════════════════════════════════════════════
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
                  final glow = 8.0 + 8.0 * _pulse.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 52 + 4 * _pulse.value,
                        height: 52 + 4 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.28 * p), blurRadius: glow, spreadRadius: 1)],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.72), _W.roseLight.withOpacity(0.35)],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.95), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_W.rose.withOpacity(0.95), _W.roseLight.withOpacity(0.9)],
                                ),
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 17),
                            ),
                            Positioned.fill(
                              child: ClipOval(
                                child: Transform.translate(
                                  offset: Offset((-34 + 84 * _shimmer.value), 0),
                                  child: Container(
                                    width: 24,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.transparent, Colors.white.withOpacity(0.35), Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 15,
                          height: 15,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF3B4A), Color(0xFFE31C4E)]),
                            border: Border.all(color: Colors.white, width: 1.8),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => widget.onTap(first['wedding_id'] as String),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: _W.ink, letterSpacing: -0.2),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topRight,
              child: _expanded && count > 1
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: widget.invites.skip(1).take(3).map((inv) {
                          final c = '${inv['bride_name'] ?? ''} & ${inv['groom_name'] ?? ''}'.trim();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _GlassInviteChip(
                              title: c.isEmpty || c == '&' ? 'Invitation' : c,
                              onTap: () => widget.onTap(inv['wedding_id'] as String),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHIP D'INVITATION (quand plusieurs invitations sont affichées)
// ═══════════════════════════════════════════════════════════════════════════
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white),
            boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _W.roseG),
                child: const Icon(Icons.favorite_rounded, size: 10, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: _W.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
