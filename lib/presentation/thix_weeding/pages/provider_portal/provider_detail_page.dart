// lib/presentation/thix_weeding/pages/provider_portal/provider_detail_page.dart
// ============================================================================
// THIX WEDDING — FICHE PUBLIQUE PRESTATAIRE (PRODUCTION v7)
// ✅ ?offer=<id> : affiche UNIQUEMENT l'offre cliquée (photos du service,
//    vidéos, promo, points forts, description complète, capacité/durée)
// ✅ Sans paramètre : fiche complète du prestataire (comportement v6)
// ✅ CTA réservation → ordersProvider.createOrder (wedding_orders)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_offers_page.dart' show offerTypeIcon, offerTypeColor;
import 'orders/orders_provider.dart' show ordersProvider;

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF14B8A6);
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderDetailPage extends ConsumerStatefulWidget {
  final String providerId;
  final String? offerId; // ✅ NEW : offre cliquée (query ?offer=)
  const ProviderDetailPage({super.key, required this.providerId, this.offerId});

  @override
  ConsumerState<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends ConsumerState<ProviderDetailPage> {
  ProviderOfferModel? _selectedOffer; // sélection manuelle dans la page

  String _verifLabel(ProviderVerificationStatus s) => switch (s) {
        ProviderVerificationStatus.pending => 'En vérification',
        ProviderVerificationStatus.verified => 'Vérifié',
        ProviderVerificationStatus.rejected => 'Non vérifié',
      };

  Color _verifColor(ProviderVerificationStatus s) => switch (s) {
        ProviderVerificationStatus.pending => _P.amber,
        ProviderVerificationStatus.verified => _P.green,
        ProviderVerificationStatus.rejected => _P.red,
      };

  void _openReservationSheet(ThixProviderModel provider, ProviderOfferModel? offer) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationSheet(provider: provider, offer: offer),
    );
  }

  void _back() {
    // Sélection manuelle → retour fiche complète ; sinon → quitte la page
    if (_selectedOffer != null) {
      setState(() => _selectedOffer = null);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerAsync = ref.watch(providerByIdProvider(widget.providerId));
    final offersAsync = ref.watch(providerOffersProvider(widget.providerId));

    return providerAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _P.bg,
        body: Center(child: CircularProgressIndicator(color: _P.rose)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _P.bg,
        appBar: AppBar(backgroundColor: _P.bg, elevation: 0),
        body: Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _P.inkSoft))),
      ),
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            backgroundColor: _P.bg,
            appBar: AppBar(backgroundColor: _P.bg, elevation: 0),
            body: const Center(child: Text('Prestataire introuvable')),
          );
        }
        final offers = (offersAsync.valueOrNull ?? []).where((o) => o.isActive).toList();

        // ✅ Offre cliquée depuis l'extérieur (?offer=) OU sélection interne
        final initialOffer = widget.offerId != null
            ? offers.where((o) => o.id == widget.offerId).firstOrNull
            : null;
        final selected = _selectedOffer ?? initialOffer;

        return Scaffold(
          backgroundColor: _P.bg,
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openReservationSheet(provider, selected),
                  icon: const Icon(Icons.event_available_rounded, size: 20),
                  label: Text(
                    selected == null ? 'Demander une réservation' : 'Réserver « ${selected.title} »',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
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
          body: selected == null
              ? _ProviderFullView(
                  provider: provider,
                  offers: offers,
                  verifLabel: _verifLabel(provider.verificationStatus),
                  verifColor: _verifColor(provider.verificationStatus),
                  onSelect: (o) => setState(() => _selectedOffer = o),
                  onReserve: (o) => _openReservationSheet(provider, o),
                )
              : _ServiceDetailView(
                  provider: provider,
                  offer: selected,
                  onBack: _back,
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VUE COMPLÈTE DU PRESTATAIRE (sans ?offer=)
// ═══════════════════════════════════════════════════════════════════════════
class _ProviderFullView extends StatelessWidget {
  final ThixProviderModel provider;
  final List<ProviderOfferModel> offers;
  final String verifLabel;
  final Color verifColor;
  final ValueChanged<ProviderOfferModel> onSelect;
  final ValueChanged<ProviderOfferModel> onReserve;

  const _ProviderFullView({
    required this.provider,
    required this.offers,
    required this.verifLabel,
    required this.verifColor,
    required this.onSelect,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final heroUrl = provider.galleryUrls.isNotEmpty ? provider.galleryUrls.first : null;
    final hasPrice = provider.minPrice != null || provider.maxPrice != null;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: _P.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _P.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: heroUrl != null
                ? Image.network(heroUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _P.rose.withOpacity(0.2)))
                : Container(color: _P.rose.withOpacity(0.2)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: verifColor, borderRadius: BorderRadius.circular(12)),
                child: Text(verifLabel,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Text(provider.businessName,
                  style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 16, color: _P.inkSoft),
                const SizedBox(width: 4),
                Text(provider.city ?? 'RDC', style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft)),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _P.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _P.line),
                ),
                child: Row(children: [
                  const Icon(Icons.qr_code_2, color: _P.rose, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code Thix', style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                        Text(provider.uniqueCode,
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: _P.inkSoft, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: provider.uniqueCode));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Code copié'),
                        backgroundColor: _P.green,
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  hasPrice
                      ? 'Tarifs : ${provider.minPrice?.toStringAsFixed(0) ?? '…'} – ${provider.maxPrice?.toStringAsFixed(0) ?? '…'} ${provider.currency}'
                      : 'Tarifs : Sur devis — contactez-nous',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Container(width: 4, height: 20, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('Offres & Services', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
              ]),
              const SizedBox(height: 12),
              if (offers.isEmpty)
                Text('Aucune offre publiée pour le moment.',
                    style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic))
              else
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: offers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _OfferCard(
                      offer: offers[i],
                      categoryLabel: provider.category.displayName,
                      onTap: () => onSelect(offers[i]),
                      onReserve: () => onReserve(offers[i]),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (provider.galleryUrls.isNotEmpty) ...[
                Row(children: [
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('Galerie (${provider.galleryUrls.length})',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                ]),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: provider.galleryUrls
                      .map((u) => ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(u, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: _P.line)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (provider.videoUrls.isNotEmpty) ...[
                Row(children: [
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('Vidéos (${provider.videoUrls.length})',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                ]),
                const SizedBox(height: 12),
                ...provider.videoUrls.map((u) => _VideoTile(url: u)),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE D'OFFRE (vue complète)
// ═══════════════════════════════════════════════════════════════════════════
class _OfferCard extends StatelessWidget {
  final ProviderOfferModel offer;
  final String categoryLabel;
  final VoidCallback onTap;
  final VoidCallback onReserve;

  const _OfferCard({
    required this.offer,
    required this.categoryLabel,
    required this.onTap,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  offer.imageUrl != null && offer.imageUrl!.isNotEmpty
                      ? Image.network(offer.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: color.withOpacity(0.15)))
                      : Container(
                          color: color.withOpacity(0.15),
                          child: Icon(offerTypeIcon(offer.type), size: 40, color: color)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.type.displayName.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_outward_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink)),
                    const SizedBox(height: 4),
                    if ((offer.description ?? '').isNotEmpty)
                      Text(offer.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _P.inkSoft, height: 1.35)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _P.rose.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _P.rose.withOpacity(0.25)),
                      ),
                      child: Text(categoryLabel,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _P.rose)),
                    ),
                    const Spacer(),
                    Row(children: [
                      Expanded(
                        child: Text(
                          offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.rose),
                        ),
                      ),
                      GestureDetector(
                        onTap: onReserve,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Réserver',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ]),
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
// ✅ VUE "OFFRE CLIQUÉE" : SEULEMENT ce service (photos/vidéos/promo/détails)
//    Lit la ligne Supabase pour les champs étendus (image_urls, video_urls…)
// ═══════════════════════════════════════════════════════════════════════════
class _ServiceDetailView extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final ProviderOfferModel offer;
  final VoidCallback onBack;

  const _ServiceDetailView({
    required this.provider,
    required this.offer,
    required this.onBack,
  });

  @override
  ConsumerState<_ServiceDetailView> createState() => _ServiceDetailViewState();
}

class _ServiceDetailViewState extends ConsumerState<_ServiceDetailView> {
  Map<String, dynamic>? _row;
  final _pageCtrl = PageController();
  int _currentImg = 0;

  @override
  void initState() {
    super.initState();
    _loadRow();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRow() async {
    try {
      final r = await Supabase.instance.client
          .from('thix_weeding_offers')
          .select()
          .eq('id', widget.offer.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _row = r == null ? null : Map<String, dynamic>.from(r));
    } catch (_) {}
  }

  // ── Photos UNIQUEMENT du service (pas celles du profil) ──
  List<String> get _images {
    final list = <String>[];    final r = _row;
    if (r != null) {
      for (final u in (r['image_urls'] as List?)?.cast<String>() ?? []) {
        if (u.isNotEmpty && !list.contains(u)) list.add(u);
      }
      for (final u in (r['gallery_urls'] as List?)?.cast<String>() ?? []) {
        if (u.isNotEmpty && !list.contains(u)) list.add(u);
      }
    }
    for (final u in widget.offer.galleryUrls) {
      if (u.isNotEmpty && !list.contains(u)) list.add(u);
    }
    final cover = (_row?['image_url'] as String?) ?? widget.offer.imageUrl;
    if ((cover ?? '').isNotEmpty && !list.contains(cover)) list.insert(0, cover!);
    return list;
  }

  List<String> get _videos => (_row?['video_urls'] as List?)?.cast<String>() ?? [];

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(widget.offer.type);
    final images = _images;
    final videos = _videos;
    final r = _row;
    final promo = r?['promo_active'] == true;
    final promoPercent = (r?['promo_percent'] as int?) ?? 0;
    final oldPrice = (r?['promo_old_price'] as num?)?.toDouble();
    final capacity = r?['capacity'] as int?;
    final duration = r?['duration_hours'] as int?;
    final eventCat = r?['category'] as String?;
    final highlights = (r?['highlights'] as List?)?.cast<String>() ?? [];
    final description = (r?['description'] as String?) ?? widget.offer.description ?? '';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ═══════════ HERO : galerie swipe du service ═══════════
        SliverAppBar(
          expandedHeight: images.isNotEmpty ? 300 : 110,
          pinned: true,
          backgroundColor: _P.bg,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: _P.ink, size: 20),
            ),
            onPressed: widget.onBack,
          ),
          title: Text(widget.offer.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
          flexibleSpace: FlexibleSpaceBar(
            background: images.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _pageCtrl,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImg = i),
                        itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: color.withOpacity(0.15))),
                      ),
                      Positioned(
                        top: 56,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(12)),
                          child: Text('${_currentImg + 1}/${images.length}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length > 8 ? 8 : images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _currentImg ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(color: color.withOpacity(0.15)),
          ),
        ),

        // ═══════════ Miniatures ═══════════
        if (images.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(i,
                      duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i == _currentImg ? _P.rose : _P.line, width: i == _currentImg ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(images[i], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _P.line)),
                  ),
                ),
              ),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ═══════════ Badges type + prix + promo ═══════════
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(offerTypeIcon(widget.offer.type), size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(widget.offer.type.displayName.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _P.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (promo && oldPrice != null) ...[
                        Text('${oldPrice.toStringAsFixed(0)}\$',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _P.inkSoft,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 6),
                      ],
                      Text(widget.offer.price != null ? '${widget.offer.price!.toStringAsFixed(0)} \$' : 'Sur devis',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _P.green)),
                    ]),
                  ),
                  if (promo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_P.amber, Color(0xFFFFB84D)]),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text('PROMO −$promoPercent%',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _P.rose.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Text(widget.provider.category.displayName,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.rose)),
                  ),
                  if (eventCat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _P.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.celebration_rounded, size: 13, color: _P.purple),
                        const SizedBox(width: 5),
                        Text(eventCat,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.purple)),
                      ]),
                    ),
                  if (capacity != null)
                    _chip('${capacity} pers.', _P.blue, Icons.people_rounded),
                  if (duration != null)
                    _chip('$duration h', _P.teal, Icons.schedule_rounded),
                  if (videos.isNotEmpty)
                    _chip('${videos.length} vidéo(s)', _P.red, Icons.videocam_rounded),
                ],
              ),
              const SizedBox(height: 16),

              // ═══════════ Titre ═══════════
              Text(widget.offer.title,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)),
              const SizedBox(height: 12),

              // ═══════════ Description complète ═══════════
              if (description.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: _P.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line)),
                  child: Text(description, style: GoogleFonts.inter(fontSize: 14, color: _P.ink, height: 1.6)),
                ),
              const SizedBox(height: 16),

              // ═══════════ Points forts ═══════════
              if (highlights.isNotEmpty) ...[
                _sectionTitle('Points forts', Icons.star_rounded),
                const SizedBox(height: 10),
                ...highlights.map((h) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _P.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.amber.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: _P.amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(h,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink))),
                      ]),
                    )),
                const SizedBox(height: 16),
              ],

              // ═══════════ Photos du service ═══════════
              _sectionTitle('Photos du service (${images.length})', Icons.photo_library_rounded),
              const SizedBox(height: 10),
              if (images.isEmpty)
                Text('Aucune photo pour ce service.',
                    style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic))
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: images
                      .map((u) => ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(u, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: _P.line)),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 20),

              // ═══════════ Vidéos du service ═══════════
              if (videos.isNotEmpty) ...[
                _sectionTitle('Vidéos du service', Icons.videocam_rounded),
                const SizedBox(height: 10),
                ...videos.map((v) => _VideoTile(url: v)),
                const SizedBox(height: 16),
              ],

              // ═══════════ Prestataire ═══════════
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _P.blue.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: _P.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.provider.businessName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                        Text('${widget.provider.city ?? 'RDC'} • ${widget.provider.uniqueCode}',
                            style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _sectionTitle(String label, IconData icon) => Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: _P.rose),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
      ]);
}

// ═══════════════════════════════════════════════════════════════════════════
// TUILE VIDÉO
// ═══════════════════════════════════════════════════════════════════════════
class _VideoTile extends StatelessWidget {
  final String url;
  const _VideoTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _P.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.play_circle_fill_rounded, color: _P.red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Regarder la vidéo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: _P.blue, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.open_in_new_rounded, size: 16, color: _P.inkSoft),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET DE RÉSERVATION → crée la COMMANDE (wedding_orders)
// ═══════════════════════════════════════════════════════════════════════════
class _ReservationSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final ProviderOfferModel? offer;
  const _ReservationSheet({required this.provider, this.offer});

  @override
  ConsumerState<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends ConsumerState<_ReservationSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  late DateTime _date = DateTime.now().add(const Duration(days: 30));
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _guestsCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
    if (_nameCtrl.text.trim().length < 2) {
      _toast('Indiquez votre nom complet', _P.amber);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _toast('Indiquez un téléphone de contact', _P.amber);
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = _emailCtrl.text.trim().isEmpty
          ? '${_phoneCtrl.text.trim().replaceAll(RegExp(r'[^\w]'), '')}@client.thix'
          : _emailCtrl.text.trim();

      await ref.read(ordersProvider(widget.provider.id).notifier).createOrder(
            offerId: widget.offer?.id ?? 'reservation_directe',
            offerTitle: widget.offer?.title ?? 'Réservation ${widget.provider.businessName}',
            clientId: user?.id ?? 'client_externe',
            clientName: _nameCtrl.text.trim(),
            clientEmail: email,
            clientPhone: _phoneCtrl.text.trim(),
            providerId: widget.provider.id,
            providerName: widget.provider.businessName,
            eventDate: _date,
            eventLocation: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
            orderData: {
              'guest_count': int.tryParse(_guestsCtrl.text.trim()),
              'message': _msgCtrl.text.trim(),
              'offer_type': widget.offer?.type.name ?? 'service',
              'source': 'fiche_prestataire',
            },
            totalAmount: widget.offer?.price ?? widget.provider.minPrice ?? 0,
            notes: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
            isTraiteur: widget.provider.category == ProviderCategory.traiteur ||
                widget.provider.category == ProviderCategory.patissier,
          );

      if (!mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _P.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_circle_rounded, color: _P.green, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Demande envoyée ✓',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
            ),
          ]),
          content: Text(
            'Votre commande a été transmise à ${widget.provider.businessName}. '
            'Le prestataire la verra dans son espace (Commandes → En attente) et pourra la confirmer.',
            style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Parfait', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Envoi impossible: $e', _P.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.event_available_rounded, color: _P.rose, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Demander une réservation',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
                    Text(
                      offer != null
                          ? 'Service : ${offer.title} • ${widget.provider.businessName}'
                          : widget.provider.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11.5, color: _P.inkSoft),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _field('Nom complet *', _nameCtrl, Icons.person_rounded),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Téléphone *', _phoneCtrl, Icons.phone_rounded, keyboard: TextInputType.phone)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Email', _emailCtrl, Icons.email_rounded, keyboard: TextInputType.emailAddress)),
                ]),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: _P.rose),
                      const SizedBox(width: 10),
                      Text('Date : ${DateFormat('EEEE dd MMM yyyy', 'fr_FR').format(_date)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_rounded, size: 18, color: _P.inkSoft),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Lieu de l\'événement', _locationCtrl, Icons.place_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Invités', _guestsCtrl, Icons.people_rounded, keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                _field('Message / précisions', _msgCtrl, Icons.chat_bubble_outline_rounded, maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_busy ? 'Envoi en cours…' : 'Envoyer la demande',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _P.rose,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
          {TextInputType? keyboard, int maxLines = 1}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
          prefixIcon: Icon(icon, size: 18, color: _P.rose),
          filled: true,
          fillColor: _P.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}
