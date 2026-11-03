// lib/presentation/thix_weeding/pages/provider_portal/provider_detail_page.dart
// ============================================================================
// THIX WEDDING — PAGE DÉTAIL PRESTATAIRE (PRODUCTION v3)
// ✅ Hero = photos + VIDÉOS des OFFRES/PRODUITS (plus de photo Unsplash trompeuse)
// ✅ Placeholder élégant (icône catégorie + initiales) si aucun média
// ✅ Section Vidéos dédiée (lancement externe compatible web + mobile)
// ✅ Galerie alimentée par les offres + galleryUrls
// ✅ Code THIX copiable, badges, sheet de réservation sans auth
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_offers_page.dart' show offerTypeColor, offerTypeIcon;

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

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE MÉDIA DU HERO (image OU vidéo issue d'une offre)
// ═══════════════════════════════════════════════════════════════════════════
class _HeroMedia {
  final String url;
  final bool isVideo;
  final String? offerTitle;
  const _HeroMedia.image(this.url, {this.offerTitle}) : isVideo = false;
  const _HeroMedia.video(this.url, {this.offerTitle}) : isVideo = true;
}

class ProviderDetailPage extends ConsumerWidget {
  final String providerId;
  const ProviderDetailPage({super.key, required this.providerId});

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copié',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// ✅ COLLECTE DES MÉDIAS : d'abord les offres/produits (images + vidéos),
  ///    ensuite la galerie propre du prestataire. AUCUN fallback Unsplash.
  List<_HeroMedia> _collectHeroMedia(
      ThixProviderModel provider, List<ProviderOfferModel> offers) {
    final media = <_HeroMedia>[];
    final seen = <String>{};

    void addImage(String? url, String? title) {
      final u = (url ?? '').trim();
      if (u.isEmpty || seen.contains(u)) return;
      seen.add(u);
      media.add(_HeroMedia.image(u, offerTitle: title));
    }

    void addVideo(String? url, String? title) {
      final u = (url ?? '').trim();
      if (u.isEmpty || seen.contains(u)) return;
      seen.add(u);
      media.add(_HeroMedia.video(u, offerTitle: title));
    }

    // 1) Médias des offres actives (priorité absolue = le vrai produit)
    for (final o in offers.where((x) => x.isActive)) {
      for (final img in o.allImages) {
        addImage(img, o.title);
      }
      addVideo(o.videoUrl, o.title);
    }

    // 2) Galerie propre du prestataire (complément)
    for (final g in provider.galleryUrls) {
      addImage(g, null);
    }

    return media;
  }

  List<String> _collectVideos(List<ProviderOfferModel> offers) {
    final vids = <String>[];
    final seen = <String>{};
    for (final o in offers.where((x) => x.isActive)) {
      final v = (o.videoUrl ?? '').trim();
      if (v.isNotEmpty && !seen.contains(v)) {
        seen.add(v);
        vids.add(v);
      }
    }
    return vids;
  }

  Future<void> _openMedia(BuildContext context, _HeroMedia m) async {
    HapticFeedback.selectionClick();
    if (m.isVideo) {
      // Lancement externe (fiable web + mobile, pas de dépendance video_player)
      final uri = Uri.parse(m.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Impossible d\'ouvrir la vidéo',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } else {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.black,
        isScrollControlled: true,
        builder: (_) => _FullScreenImageViewer(url: m.url, title: m.offerTitle),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(providerByIdProvider(providerId));
    final offersAsync = ref.watch(providerOffersProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            backgroundColor: _P.bg,
            body: Center(
                child: Text('Prestataire introuvable',
                    style: GoogleFonts.inter(color: _P.inkSoft))),
          );
        }

        final offers = offersAsync.valueOrNull ?? const <ProviderOfferModel>[];
        final heroMedia = _collectHeroMedia(provider, offers);
        final videos = _collectVideos(offers);
        final activeOffers = offers.where((o) => o.isActive).toList();

        return Scaffold(
          backgroundColor: _P.bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ═══════════════ HERO (offres + galerie, placeholder sinon) ═══════════════
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: _P.surface,
                foregroundColor: _P.ink,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: _P.ink),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (heroMedia.isEmpty)
                        _HeroPlaceholder(
                          icon: _categoryIcon(provider.category),
                          initials: _initialsOf(provider.businessName),
                        )
                      else
                        PageView.builder(
                          itemCount: heroMedia.length,
                          onPageChanged: (_) {},
                          itemBuilder: (_, i) {
                            final m = heroMedia[i];
                            return GestureDetector(
                              onTap: () => _openMedia(context, m),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (m.isVideo)
                                    _VideoHeroTile(url: m.url)
                                  else
                                    Image.network(
                                      m.url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _HeroPlaceholder(
                                        icon: _categoryIcon(provider.category),
                                        initials:
                                            _initialsOf(provider.businessName),
                                      ),
                                    ),
                                  if (m.isVideo)
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded,
                                            color: Colors.white, size: 40),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                      // Indicateurs de page
                      if (heroMedia.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              heroMedia.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _currentPage(heroMedia) ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(i == _currentPage(heroMedia) ? 1 : 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Compteur média (photos · vidéos)
                      if (heroMedia.isNotEmpty)
                        Positioned(
                          top: 70,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  heroMedia.any((m) => m.isVideo)
                                      ? Icons.movie_creation_rounded
                                      : Icons.photo_library_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text('${heroMedia.length}',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ═══════════════ BADGES ═══════════════
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (provider.verificationStatus ==
                                      ProviderVerificationStatus.verified
                                  ? _P.green
                                  : _P.amber)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  provider.verificationStatus ==
                                          ProviderVerificationStatus.verified
                                      ? Icons.verified_rounded
                                      : Icons.hourglass_top_rounded,
                                  size: 13,
                                  color: provider.verificationStatus ==
                                          ProviderVerificationStatus.verified
                                      ? _P.green
                                      : _P.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider.verificationStatus ==
                                          ProviderVerificationStatus.verified
                                      ? 'Vérifié'
                                      : 'En vérification',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: provider.verificationStatus ==
                                              ProviderVerificationStatus.verified
                                          ? _P.green
                                          : _P.amber),
                                ),
                              ],
                            ),
                          ),
                          if (provider.level == TrackingLevel.platinum ||
                              provider.level == TrackingLevel.gold)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: provider.level == TrackingLevel.platinum
                                    ? const LinearGradient(
                                        colors: [_P.gold, Color(0xFFFFA500)])
                                    : null,
                                color: provider.level == TrackingLevel.gold
                                    ? _P.green
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    provider.level == TrackingLevel.platinum
                                        ? Icons.workspace_premium_rounded
                                        : Icons.verified_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                      provider.level.displayName.toUpperCase(),
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: _P.roseSoft,
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_categoryIcon(provider.category),
                                    size: 13, color: _P.rose),
                                const SizedBox(width: 4),
                                Text(provider.category.displayName,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _P.rose)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ═══════════════ NOM + NOTE ═══════════════
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(provider.businessName,
                                style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: _P.ink,
                                    letterSpacing: -0.5)),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 18, color: _P.gold),
                              const SizedBox(width: 4),
                              Text(
                                  '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _P.ink)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: _P.inkSoft),
                          const SizedBox(width: 4),
                          Text(provider.city ?? 'RDC',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _P.inkSoft,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ═══════════════ CODE THIX ═══════════════
                      GestureDetector(
                        onTap: () => _copyCode(context, provider.uniqueCode),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: _P.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _P.line)),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_2_rounded,
                                  color: _P.rose, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Code Thix',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: _P.inkSoft,
                                            fontWeight: FontWeight.w600)),
                                    Text(provider.uniqueCode,
                                        style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: _P.ink,
                                            letterSpacing: 1)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.copy_rounded,
                                  size: 16, color: _P.inkSoft),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ═══════════════ DESCRIPTION ═══════════════
                      if ((provider.description ?? '').isNotEmpty) ...[
                        _SectionTitle('À propos'),
                        const SizedBox(height: 6),
                        Text(provider.description!,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _P.inkSoft, height: 1.5)),
                        const SizedBox(height: 20),
                      ],

                      // ═══════════════ TARIFS ═══════════════
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_P.rose, _P.roseLight]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tarifs',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    provider.minPrice != null
                                        ? 'À partir de ${provider.minPrice!.toStringAsFixed(0)}${provider.currency == 'USD' ? r'$' : provider.currency}'
                                        : 'Sur devis — contactez-nous',
                                    style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ═══════════════ OFFRES & SERVICES ═══════════════
                      if (activeOffers.isNotEmpty) ...[
                        _SectionTitle(
                            'Offres & Services (${activeOffers.length})'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.none,
                            itemCount: activeOffers.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => _DetailOfferCard(
                              offer: activeOffers[i],
                              onBook: () => _openBooking(context, ref, provider),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ═══════════════ VIDÉOS (nouvelle section) ═══════════════
                      if (videos.isNotEmpty) ...[
                        _SectionTitle('Vidéos (${videos.length})'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.none,
                            itemCount: videos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => _VideoThumbCard(
                              url: videos[i],
                              onTap: () => _openMedia(
                                  context, _HeroMedia.video(videos[i])),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ═══════════════ GALERIE (offres + galleryUrls) ═══════════════
                      if (heroMedia.where((m) => !m.isVideo).length > 1) ...[
                        _SectionTitle(
                            'Galerie (${heroMedia.where((m) => !m.isVideo).length})'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.none,
                            itemCount:
                                heroMedia.where((m) => !m.isVideo).length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final imgs =
                                  heroMedia.where((m) => !m.isVideo).toList();
                              return GestureDetector(
                                onTap: () => _openMedia(context, imgs[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    imgs[i].url,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        width: 120,
                                        height: 120,
                                        color: _P.line),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
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
            decoration: BoxDecoration(
              color: _P.surface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4))
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _openBooking(context, ref, provider),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text('Demander une réservation',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
          backgroundColor: _P.bg,
          body: Center(child: CircularProgressIndicator(color: _P.rose))),
      error: (e, _) => Scaffold(
          backgroundColor: _P.bg,
          body: Center(
              child: Text('Erreur: $e',
                  style: GoogleFonts.inter(color: _P.inkSoft)))),
    );
  }

  // Track page courante du hero (pour les indicateurs)
  int _currentPage(List<_HeroMedia> media) => 0;

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  void _openBooking(
      BuildContext context, WidgetRef ref, ThixProviderModel provider) {
    final user = Supabase.instance.client.auth.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(provider: provider, hasAuth: user != null),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLACEHOLDER HERO (quand aucun média — remplace l'ancienne photo Unsplash)
// ═══════════════════════════════════════════════════════════════════════════
class _HeroPlaceholder extends StatelessWidget {
  final IconData icon;
  final String initials;
  const _HeroPlaceholder({required this.icon, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_P.roseSoft, Color(0xFFFFE4EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _P.rose.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(icon, size: 40, color: _P.rose),
            ),
            const SizedBox(height: 12),
            Text(initials,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _P.rose,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('Médias à venir',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _P.inkSoft,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// tuile vidéo dans le hero (thumbnail via première frame si possible)
// ═══════════════════════════════════════════════════════════════════════════
class _VideoHeroTile extends StatelessWidget {
  final String url;
  const _VideoHeroTile({required this.url});

  @override
  Widget build(BuildContext context) {
    // On tente de charger une miniature ; à défaut fond sombre + icône film
    return Container(
      color: const Color(0xFF111111),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.movie_creation_rounded,
              size: 56, color: Colors.white54),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VIGNETTE VIDÉO (section Vidéos)
// ═══════════════════════════════════════════════════════════════════════════
class _VideoThumbCard extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _VideoThumbCard({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    size: 48, color: Colors.white54),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _P.rose,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_rounded,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('Vidéo',
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
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
// VIEWER IMAGE PLEIN ÉCRAN
// ═══════════════════════════════════════════════════════════════════════════
class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  final String? title;
  const _FullScreenImageViewer({required this.url, this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    size: 64,
                    color: Colors.white38),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
        if ((title ?? '').isNotEmpty)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Text(title!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TITRE DE SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 17,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_P.rose, _P.roseLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _P.ink,
                letterSpacing: -0.4)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE OFFRE (inchangée — déjà multi-photos + catégories)
// ═══════════════════════════════════════════════════════════════════════════
class _DetailOfferCard extends StatelessWidget {
  final ProviderOfferModel offer;
  final VoidCallback onBook;

  const _DetailOfferCard({required this.offer, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    final images = offer.allImages;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
              color: _P.rose.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
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
                        child: Icon(offerTypeIcon(offer.type),
                            size: 36, color: color),
                      ),
                    ),
                  )
                else
                  Container(
                    color: color.withOpacity(0.12),
                    child: Icon(offerTypeIcon(offer.type),
                        size: 36, color: color),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(7)),
                    child: Text(offer.type.displayName.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded,
                              size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${images.length}',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _P.ink,
                          height: 1.2)),
                  if ((offer.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(offer.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: _P.inkSoft,
                            height: 1.3)),
                  ],
                  const SizedBox(height: 6),
                  if (offer.categories.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: offer.categories.take(2).map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _P.rose.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _P.rose.withOpacity(0.25)),
                          ),
                          child: Text(c.displayName,
                              style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: _P.rose)),
                        );
                      }).toList(),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        offer.price != null
                            ? '${offer.price!.toStringAsFixed(0)}\$'
                            : 'Sur devis',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _P.rose),
                      ),
                      GestureDetector(
                        onTap: onBook,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_P.rose, _P.roseLight]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Réserver',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET DE RÉSERVATION (inchangée)
// ═══════════════════════════════════════════════════════════════════════════
class _BookingSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final bool hasAuth;
  const _BookingSheet({required this.provider, required this.hasAuth});

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  List<Map<String, dynamic>> _weddings = [];
  bool _loadingWeddings = true;
  String? _weddingId;
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  final _nameCtrl = TextEditingController();
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
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _guestsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeddings() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _loadingWeddings = false);
        return;
      }
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
    if (!widget.hasAuth && _nameCtrl.text.trim().isEmpty) {
      _snack('Veuillez saisir votre nom', error: true);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _snack('Téléphone requis', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      String clientName;
      String weddingId;
      if (widget.hasAuth && _weddingId != null) {
        final wedding = _weddings.firstWhere((w) => w['id'] == _weddingId);
        clientName =
            '${wedding['bride_name'] ?? ''} & ${wedding['groom_name'] ?? ''}'
                .trim();
        weddingId = _weddingId!;
      } else {
        clientName = _nameCtrl.text.trim();
        weddingId = 'guest-${DateTime.now().millisecondsSinceEpoch}';
      }
      await ref.read(createReservationProvider)(
        providerId: widget.provider.id,
        weddingId: weddingId,
        clientName: clientName.isEmpty ? 'Client invité' : clientName,
        clientPhone: _phoneCtrl.text.trim(),
        eventDate: _date,
        eventType: widget.provider.category.displayName,
        guestCount: int.tryParse(_guestsCtrl.text.trim()),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Demande envoyée au prestataire ✔');
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: error ? _P.rose : _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: _P.bg,
        borderRadius:
            BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _P.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Réserver ${widget.provider.businessName}',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
            const SizedBox(height: 16),
            if (widget.hasAuth) ...[
              if (_loadingWeddings)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _P.rose)))
              else if (_weddings.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _P.roseSoft, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: _P.rose, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Créez d\'abord votre mariage depuis l\'espace staff pour pouvoir réserver.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _P.rose,
                              fontWeight: FontWeight.w600),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _P.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _P.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _P.rose, width: 2)),
                  ),
                  items: _weddings
                      .map((w) => DropdownMenuItem(
                            value: w['id'] as String,
                            child: Text(
                                '${w['bride_name'] ?? ''} & ${w['groom_name'] ?? ''}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _weddingId = v),
                ),
              const SizedBox(height: 14),
            ],
            if (!widget.hasAuth) ...[
              TextField(
                controller: _nameCtrl,
                decoration: _sheetInput('Votre nom complet *', Icons.person_outline),
              ),
              const SizedBox(height: 14),
            ],
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _P.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _P.line)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: _P.rose, size: 18),
                    const SizedBox(width: 10),
                    Text(DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(_date),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _P.ink)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _sheetInput('Votre téléphone *', Icons.phone)),
            const SizedBox(height: 14),
            TextField(
                controller: _guestsCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    _sheetInput('Nombre d\'invités (optionnel)', Icons.group_outlined)),
            const SizedBox(height: 14),
            TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: _sheetInput(
                    'Message au prestataire (optionnel)', Icons.edit_note_outlined)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Envoyer la demande',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w800)),
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
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _P.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _P.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _P.rose, width: 2)),
    );
  }
}
