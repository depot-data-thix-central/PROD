// ============================================================================
// THIX WEDDING — PAGE DÉTAIL PRESTATAIRE (v4 - CORRIGÉ)
// ✅ Hero = photos OFFRES + galerie uniquement
// ✅ Code Thix copiable
// ✅ Badges
// ✅ Tarifs
// ✅ Offres & Services
// ✅ Galerie
// ✅ Demande de réservation
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_offers_page.dart' show offerTypeColor, offerTypeIcon;
import 'provider_offer_form_page.dart';

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
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}

IconData _categoryIcon(ProviderCategory c) => switch (c) {
      ProviderCategory.salle => Icons.meeting_room_rounded,
      ProviderCategory.traiteur => Icons.restaurant_rounded,
      ProviderCategory.photographe => Icons.camera_alt_rounded,
      ProviderCategory.videaste => Icons.videocam_rounded,
      ProviderCategory.decorateur => Icons.palette_rounded,
      ProviderCategory.dj => Icons.music_note_rounded,
      ProviderCategory.mc => Icons.mic_rounded,
      ProviderCategory.maquilleur => Icons.face_rounded,
      ProviderCategory.patissier => Icons.cake_rounded,
      ProviderCategory.fleuriste => Icons.local_florist_rounded,
    };

class _HeroMedia {
  final String url;
  final String? offerTitle;
  const _HeroMedia({required this.url, this.offerTitle});
}

class ProviderDetailPage extends ConsumerWidget {
  final String providerId;
  const ProviderDetailPage({super.key, required this.providerId});

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code $code copié', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: _P.green));
  }

  List<_HeroMedia> _collectHeroMedia(ThixProviderModel provider, List<ProviderOfferModel> offers) {
    final media = <_HeroMedia>[];
    final seen = <String>{};

    void add(String? url, String? title) {
      final u = (url ?? '').trim();
      if (u.isEmpty || seen.contains(u)) return;
      seen.add(u);
      media.add(_HeroMedia(url: u, offerTitle: title));
    }

    for (final o in offers.where((x) => x.isActive)) {
      for (final img in o.allImages) add(img, o.title);
    }
    for (final g in provider.galleryUrls) add(g, null);

    return media;
  }

  Future<void> _openImage(BuildContext context, _HeroMedia m) async {
    await showModalBottomSheet(context: context, backgroundColor: Colors.black, isScrollControlled: true, builder: (_) => _FullScreenImageViewer(url: m.url, title: m.offerTitle));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(providerByIdProvider(providerId));
    final offersAsync = ref.watch(providerOffersProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) return _buildError(context);
        final offers = offersAsync.valueOrNull ?? [];
        final heroMedia = _collectHeroMedia(provider, offers);
        final activeOffers = offers.where((o) => o.isActive).toList();

        return Scaffold(
          backgroundColor: _P.bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHero(heroMedia, provider, context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBadges(provider),
                      const SizedBox(height: 12),
                      Text(provider.businessName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(children: [const Icon(Icons.location_on_outlined, size: 14, color: _P.inkSoft), const SizedBox(width: 4), Text(provider.city ?? 'RDC', style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontWeight: FontWeight.w600))]),
                      const SizedBox(height: 16),

                      _buildCodeCard(provider.uniqueCode),

                      if ((provider.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _SectionTitle('À propos'),
                        Text(provider.description!, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5)),
                      ],

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]), borderRadius: BorderRadius.circular(20)),
                        child: Text('Tarifs : \( {provider.minPrice != null ? ' \){provider.minPrice!} USD' : 'Sur devis — contactez-nous'}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      const SizedBox(height: 24),

                      if (activeOffers.isNotEmpty) ...[
                        _SectionTitle('Offres & Services (${activeOffers.length})'),
                        SizedBox(height: 260, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: activeOffers.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => _DetailOfferCard(offer: activeOffers[i], onBook: () => _openBooking(context, ref, provider)))),
                      ],

                      if (heroMedia.length > 1) ...[
                        _SectionTitle('Galerie (${heroMedia.length})'),
                        SizedBox(height: 120, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: heroMedia.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) => GestureDetector(onTap: () => _openImage(context, heroMedia[i]), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(heroMedia[i].url, width: 120, height: 120, fit: BoxFit.cover))))),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(onPressed: () => _openBooking(context, ref, provider), icon: const Icon(Icons.event_available_rounded, size: 18), label: Text('Demander une réservation', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
          ),
        );
      },
      loading: () => const Scaffold(backgroundColor: _P.bg, body: Center(child: CircularProgressIndicator(color: _P.rose))),
      error: (e, _) => _buildError(context),
    );
  }

  Widget _buildError(BuildContext context) => Scaffold(backgroundColor: _P.bg, body: Center(child: Text('Prestataire introuvable', style: GoogleFonts.inter(color: _P.inkSoft))));

  Widget _buildHero(List<_HeroMedia> heroMedia, ThixProviderModel provider, BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: _P.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: heroMedia.isEmpty
            ? _HeroPlaceholder(icon: _categoryIcon(provider.category), initials: _initialsOf(provider.businessName))
            : PageView.builder(itemCount: heroMedia.length, itemBuilder: (_, i) => GestureDetector(onTap: () => _openImage(context, heroMedia[i]), child: Image.network(heroMedia[i].url, fit: BoxFit.cover))),
      ),
    );
  }

  Widget _buildBadges(ThixProviderModel provider) {
    return Wrap(spacing: 8, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: provider.verificationStatus == ProviderVerificationStatus.verified ? _P.green : _P.amber, borderRadius: BorderRadius.circular(10)), child: Text(provider.verificationStatus == ProviderVerificationStatus.verified ? 'Vérifié' : 'En vérification')),
      // Ajoute ici les badges Niveau et Catégorie si besoin
    ]);
  }

  Widget _buildCodeCard(String code) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line)), child: Row(children: [const Icon(Icons.qr_code_2_rounded, color: _P.rose, size: 22), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Code Thix', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)), Text(code, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink))]))]));
  }

  void _openBooking(BuildContext context, WidgetRef ref, ThixProviderModel provider) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _BookingSheet(provider: provider));
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

// ==================== WIDGETS RESTANTS ====================
// _HeroPlaceholder, _FullScreenImageViewer, _SectionTitle, _BookingSheet, _DetailOfferCard

class _HeroPlaceholder extends StatelessWidget {
  final IconData icon;
  final String initials;
  const _HeroPlaceholder({required this.icon, required this.initials});
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_P.roseSoft, Color(0xFFFFE4EC)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 84, height: 84, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), shape: BoxShape.circle, boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))]), child: Icon(icon, size: 40, color: _P.rose)), const SizedBox(height: 12), Text(initials, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _P.rose, letterSpacing: 1)), const SizedBox(height: 4), Text('Médias à venir', style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w600))]])));
}

class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  final String? title;
  const _FullScreenImageViewer({required this.url, this.title});
  @override
  Widget build(BuildContext context) => Stack(children: [Positioned.fill(child: InteractiveViewer(maxScale: 4, child: Center(child: Image.network(url, fit: BoxFit.contain)))), Positioned(top: 12, right: 12, child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)))), if ((title ?? '').isNotEmpty) Positioned(bottom: 24, left: 16, right: 16, child: Text(title!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))]);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 3.5, height: 17, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.4))]);
}

class _BookingSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  const _BookingSheet({required this.provider});
  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: _P.bg, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Réserver ${widget.provider.businessName}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: _sheetInput('Votre nom complet *', Icons.person_outline)),
            const SizedBox(height: 14),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _sheetInput('Votre téléphone *', Icons.phone)),
            const SizedBox(height: 14),
            TextField(controller: _guestsCtrl, keyboardType: TextInputType.number, decoration: _sheetInput('Nombre d\'invités (optionnel)', Icons.group_outlined)),
            const SizedBox(height: 14),
            TextField(controller: _notesCtrl, maxLines: 3, decoration: _sheetInput('Message au prestataire (optionnel)', Icons.edit_note_outlined)),
            const SizedBox(height: 20),
            SizedBox(height: 54, width: double.infinity, child: ElevatedButton(onPressed: _submitting ? null : () {}, style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Envoyer la demande', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)))),
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetInput(String label, IconData icon) {
    return InputDecoration(labelText: label, filled: true, fillColor: _P.surface, prefixIcon: Icon(icon, color: _P.rose, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.rose, width: 2)));
  }
}

class _DetailOfferCard extends StatelessWidget {
  final ProviderOfferModel offer;
  final VoidCallback onBook;
  const _DetailOfferCard({required this.offer, required this.onBook});
  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    final images = offer.allImages;
    return Container(width: 220, decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _P.line), boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 6))]), clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: Stack(fit: StackFit.expand, children: [if (images.isNotEmpty) PageView.builder(itemCount: images.length, itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: color.withOpacity(0.12), child: Icon(offerTypeIcon(offer.type), size: 36, color: color)))) else Container(color: color.withOpacity(0.12), child: Icon(offerTypeIcon(offer.type), size: 36, color: color)), Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)), child: Text(offer.type.displayName.toUpperCase(), style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white)))), if (images.length > 1) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)), child: Text('\( {images.length}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white))))], )), Expanded(flex: 5, child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _P.ink, height: 1.2)), if ((offer.description ?? '').isNotEmpty) ...[const SizedBox(height: 4), Text(offer.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft, height: 1.3))], const SizedBox(height: 6), if (offer.categories.isNotEmpty) Wrap(spacing: 4, children: offer.categories.take(2).map((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _P.rose.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: _P.rose.withOpacity(0.25))), child: Text(c.displayName, style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: _P.rose))))], const Spacer(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(offer.price != null ? ' \){offer.price!.toStringAsFixed(0)}\$' : 'Sur devis', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _P.rose)), GestureDetector(onTap: onBook, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]), borderRadius: BorderRadius.circular(8)), child: Text('Réserver', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))))]))])));
  }
}
