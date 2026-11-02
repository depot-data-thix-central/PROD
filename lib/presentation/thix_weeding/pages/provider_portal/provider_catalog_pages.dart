// lib/presentation/thix_weeding/pages/provider_portal/provider_catalog_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER CATALOG (PRODUCTION ENTERPRISE)
// ✅ Catalogue public des prestataires vérifiés (filtre catégorie + recherche)
// ✅ Page détail avec galerie, code Thix copiable, réservation
// ✅ Design glassmorphism blanc/rose premium
// ✅ Deep-link : /provider/catalog?category=salle
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE GLASSMORPHISM
// ═══════════════════════════════════════════════════════════════════════════
class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color gold = Color(0xFFFFD700);
}

// ═══════════════════════════════════════════════════════════════════════════
// CATALOGUE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderCatalogPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const ProviderCatalogPage({super.key, this.initialCategory});

  @override
  ConsumerState<ProviderCatalogPage> createState() => _ProviderCatalogPageState();
}

class _ProviderCatalogPageState extends ConsumerState<ProviderCatalogPage> {
  ProviderCategory? _category;
  String _search = '';
  Timer? _debounce;

  // ✅ Params mémorisés en state → évite le refetch en boucle (identité ==)
  late ProviderListParams _params;

  @override
  void initState() {
    super.initState();
    _category = _parseCategory(widget.initialCategory);
    _params = ProviderListParams(limit: 100, category: _category);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  ProviderCategory? _parseCategory(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final c in ProviderCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  void _setCategory(ProviderCategory? cat) {
    HapticFeedback.selectionClick();
    setState(() {
      _category = cat;
      _params = ProviderListParams(
        limit: 100,
        category: cat,
        search: _search.isEmpty ? null : _search,
      );
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim();
        _params = ProviderListParams(
          limit: 100,
          category: _category,
          search: _search.isEmpty ? null : _search,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(providersListProvider(_params));

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ────────────────────────────────────────────────
          SliverToBoxAdapter(child: _CatalogHeader(search: _search, onSearch: _onSearchChanged)),

          // ── CHIPS CATÉGORIES ──────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: ProviderCategory.values.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _CategoryChip(
                      label: 'Tous',
                      isSelected: _category == null,
                      onTap: () => _setCategory(null),
                    );
                  }
                  final cat = ProviderCategory.values[i - 1];
                  return _CategoryChip(
                    label: cat.displayName,
                    isSelected: _category == cat,
                    onTap: () => _setCategory(cat),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── GRILLE ────────────────────────────────────────────────
          providersAsync.when(
            data: (providers) {
              // ✅ Uniquement les prestataires VÉRIFIÉS dans le catalogue public
              final visible = providers
                  .where((p) => p.verificationStatus == ProviderVerificationStatus.verified)
                  .toList();

              if (visible.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.store_outlined, size: 56, color: _P.line),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun prestataire trouvé',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _P.inkSoft),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Essayez une autre catégorie ou revenez plus tard',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CatalogCard(provider: visible[i]),
                    childCount: visible.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator(color: _P.rose)),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _P.inkSoft))),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;

  const _CatalogHeader({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_P.rose, _P.roseLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Catalogue Prestataires',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: TextField(
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _P.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
                hintText: 'Rechercher un prestataire...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _P.rose),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _P.rose : _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _P.rose : _P.line),
          boxShadow: isSelected
              ? [BoxShadow(color: _P.rose.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _P.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final ThixProviderModel provider;

  const _CatalogCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cover = provider.galleryUrls.isNotEmpty
        ? provider.galleryUrls.first
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600&q=80';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${provider.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _P.line),
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
                  Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _P.roseSoft,
                      child: const Icon(Icons.broken_image_outlined, size: 32, color: _P.inkSoft),
                    ),
                  ),
                  if (provider.level == TrackingLevel.platinum)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_P.gold, Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(8),
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
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.verified, size: 14, color: _P.green),
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
                    provider.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${provider.category.displayName} · ${provider.city ?? 'RDC'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: _P.gold),
                          const SizedBox(width: 3),
                          Text(provider.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink)),
                        ],
                      ),
                      Text(
                        provider.minPrice != null ? 'Dès ${provider.minPrice!.toStringAsFixed(0)}\$' : 'Sur devis',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: _P.rose),
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
// PAGE DÉTAIL
// ═══════════════════════════════════════════════════════════════════════════
class ProviderDetailPage extends ConsumerWidget {
  final String providerId;

  const ProviderDetailPage({super.key, required this.providerId});

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copié', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(providerByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            backgroundColor: _P.bg,
            body: Center(child: Text('Prestataire introuvable', style: GoogleFonts.inter(color: _P.inkSoft))),
          );
        }

        final cover = provider.galleryUrls.isNotEmpty
            ? provider.galleryUrls.first
            : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&q=80';

        return Scaffold(
          backgroundColor: _P.bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HERO ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _P.surface,
                foregroundColor: _P.ink,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _P.ink),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.roseSoft)),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: _P.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 13, color: _P.green),
                                const SizedBox(width: 4),
                                Text(provider.level.displayName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.green)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: _P.roseSoft, borderRadius: BorderRadius.circular(10)),
                            child: Text(provider.category.displayName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _P.rose)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Nom + note
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              provider.businessName,
                              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 18, color: _P.gold),
                              const SizedBox(width: 4),
                              Text('${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: _P.inkSoft),
                          const SizedBox(width: 4),
                          Text(provider.city ?? 'RDC', style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Code Thix copiable
                      GestureDetector(
                        onTap: () => _copyCode(context, provider.uniqueCode),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _P.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _P.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_2_rounded, color: _P.rose, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Code Thix (à donner au staff)', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                                    Text(provider.uniqueCode, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: 1)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.copy_rounded, size: 16, color: _P.inkSoft),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      if ((provider.description ?? '').isNotEmpty) ...[
                        Text('À propos', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 6),
                        Text(provider.description!, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5)),
                        const SizedBox(height: 20),
                      ],

                      // Tarifs
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: Colors.white, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tarifs', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                                  Text(
                                    provider.minPrice != null
                                        ? 'À partir de ${provider.minPrice!.toStringAsFixed(0)}${provider.currency == 'USD' ? r'$' : provider.currency}'
                                        : 'Sur devis — contactez-nous',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Galerie
                      if (provider.galleryUrls.isNotEmpty) ...[
                        Text('Galerie (${provider.galleryUrls.length})', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: provider.galleryUrls.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                provider.galleryUrls[i],
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 110, height: 110, color: _P.line),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _P.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _openBooking(context, ref, provider),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text('Demander une réservation', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: _P.bg,
        body: Center(child: CircularProgressIndicator(color: _P.rose)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _P.bg,
        body: Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _P.inkSoft))),
      ),
    );
  }

  void _openBooking(BuildContext context, WidgetRef ref, ThixProviderModel provider) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connectez-vous pour réserver', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.push('/thix-weeding/auth/login');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(provider: provider),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET DE RÉSERVATION
// ═══════════════════════════════════════════════════════════════════════════
class _BookingSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;

  const _BookingSheet({required this.provider});

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  List<Map<String, dynamic>> _weddings = [];
  bool _loadingWeddings = true;
  String? _weddingId;
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  final _phoneCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadWeddings();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _guestsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeddings() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('id, bride_name, groom_name')
          .eq('owner_id', user.id);
      if (!mounted) return;
      setState(() {
        _weddings = List<Map<String, dynamic>>.from(res);
        if (_weddings.length == 1) _weddingId = _weddings.first['id'] as String;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingWeddings = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_weddingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sélectionnez votre mariage', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final wedding = _weddings.firstWhere((w) => w['id'] == _weddingId);
      final clientName = '${wedding['bride_name'] ?? ''} & ${wedding['groom_name'] ?? ''}'.trim();

      await ref.read(createReservationProvider)(
        providerId: widget.provider.id,
        weddingId: _weddingId!,
        clientName: clientName.isEmpty ? 'Réservation' : clientName,
        clientPhone: _phoneCtrl.text.trim(),
        eventDate: _date,
        eventType: widget.provider.category.displayName,
        guestCount: int.tryParse(_guestsCtrl.text.trim()),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande envoyée au prestataire ✔', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Réserver ${widget.provider.businessName}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 16),

            // Choix du mariage
            if (_loadingWeddings)
              const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.rose)))
            else if (_weddings.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _P.roseSoft, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: _P.rose, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Créez d\'abord votre mariage depuis l\'espace staff pour pouvoir réserver.',
                        style: GoogleFonts.inter(fontSize: 12, color: _P.rose, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _weddingId,
                decoration: InputDecoration(
                  labelText: 'Votre mariage',
                  filled: true,
                  fillColor: _P.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.rose, width: 2)),
                ),
                items: _weddings
                    .map((w) => DropdownMenuItem(
                          value: w['id'] as String,
                          child: Text('${w['bride_name'] ?? ''} & ${w['groom_name'] ?? ''}', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _weddingId = v),
              ),
            const SizedBox(height: 14),

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: _P.rose, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(_date),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _sheetInput('Votre téléphone', Icons.phone),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _guestsCtrl,
              keyboardType: TextInputType.number,
              decoration: _sheetInput('Nombre d\'invités (optionnel)', Icons.group_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _sheetInput('Message au prestataire (optionnel)', Icons.edit_note_outlined),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.rose,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Envoyer la demande', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _P.surface,
      prefixIcon: Icon(icon, color: _P.rose, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.rose, width: 2)),
    );
  }
}
