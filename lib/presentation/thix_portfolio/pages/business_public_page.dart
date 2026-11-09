// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « DISPOSITION PROFESSIONNELLE »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 2.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v2.0 — Refonte layout inspirée de la maquette SONATHIX GROUP :
//    • HERO image pleine largeur + overlay dégradé + nom + slogan + CTAs
//    • Carte identité chevauchante (logo ring + nom + badge + compteurs)
//    • Bandeau infos (secteur • ville • depuis • collaborateurs)
//    • À propos AVEC photo (image_url) — mise en page éditoriale
//    • Services en grille 2 colonnes (photo OU icône)
//    • Produits en grille avec photos
//    • Réalisations (galerie) : rangée horizontale snap + légendes
//    • Équipe : avatars photos + nom + fonction
//    • Actualités : vignette photo + chip date + « Lire plus »
//    • Témoignages : cartes citation + étoiles
//    • Contact : carte « Nos informations » lignes icônes cliquables
//    • Footer de marque sombre (dérivé de la couleur du propriétaire)
//    • 100 % des couleurs via BusinessTheme (personnalisation propriétaire)
//    • Toutes les sections rendent leurs photos (fix « chaque branche »)
// ════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/business_repository.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/parallax_cover.dart';
import '../widgets/reveal_on_scroll.dart';

const String kThixPublicBaseUrl = 'https://thixid.com';

// ─────────────────────────────────────────────────────────────────────────────
// Page racine
// ─────────────────────────────────────────────────────────────────────────────

class BusinessPublicPage extends ConsumerWidget {
  const BusinessPublicPage({super.key, required this.thixId});

  final String thixId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(businessPublicBundleProvider(thixId));

    return bundle.when(
      loading: () => const _PublicSkeleton(),
      error: (error, _) => _PublicNotFound(
        thixId: thixId,
        invalid: error is BusinessIdInvalidException,
        onRetry: () => ref.invalidate(businessPublicBundleProvider(thixId)),
      ),
      data: (bundle) {
        final ext = BusinessThemeExt(
          style: bundle.theme.animationStyle,
          radius: bundle.theme.radius,
        );
        return Theme(
          data: bundle.theme.toThemeData().copyWith(extensions: [ext]),
          child: _BusinessSite(bundle: bundle),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton / introuvable
// ─────────────────────────────────────────────────────────────────────────────

class _PublicSkeleton extends StatelessWidget {
  const _PublicSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: const FlexibleSpaceBar(
                background:
                    DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(
                      height: 120,
                      child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white))),
                  const SizedBox(height: 16),
                  const SizedBox(
                      height: 200,
                      child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicNotFound extends StatelessWidget {
  const _PublicNotFound({
    required this.thixId,
    this.invalid = false,
    this.onRetry,
  });

  final String thixId;
  final bool invalid;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 84, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                invalid ? 'Identifiant invalide' : 'Entreprise introuvable',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                invalid
                    ? '« $thixId » n\'est pas un THIX ID Business valide.'
                    : 'Aucune entreprise publiée ne correspond à\n« $thixId ».',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SITE — structure professionnelle
// ─────────────────────────────────────────────────────────────────────────────

class _BusinessSite extends StatelessWidget {
  const _BusinessSite({required this.bundle});

  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final sections = bundle.visibleSections;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openContactSheet(context),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Contacter'),
      ),
      body: CustomScrollView(
        slivers: [
          // ── HERO PRO : image + overlay + nom + slogan + CTAs ──
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            stretch: true,
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Copier l\'ID',
                icon: const Icon(Icons.content_copy),
                onPressed: () => _copyId(context),
              ),
              IconButton(
                tooltip: 'QR code',
                icon: const Icon(Icons.qr_code_2),
                onPressed: () => _showQr(context),
              ),
              IconButton(
                tooltip: 'Partager',
                icon: const Icon(Icons.share),
                onPressed: () => _share(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
              title: Text(
                bundle.business.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              background: _HeroCover(
                bundle: bundle,
                onContact: () => _openContactSheet(context),
                onShare: () => _share(context),
              ),
            ),
          ),

          // ── Carte identité chevauchante + compteurs ──
          SliverToBoxAdapter(child: _IdentityCard(bundle: bundle)),

          // ── Bandeau infos ──
          SliverToBoxAdapter(child: _InfoStrip(business: bundle.business)),

          // ── Sections éditoriales ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => RevealOnScroll(
                  style: theme.animationStyle,
                  staggerIndex: i,
                  child: _SectionRenderer(section: sections[i]),
                ),
                childCount: sections.length,
              ),
            ),
          ),

          // ── Footer de marque ──
          SliverToBoxAdapter(child: _Footer(bundle: bundle)),
        ],
      ),
    );
  }

  Future<void> _copyId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: bundle.business.thixId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ID copié : ${bundle.business.thixId}')),
    );
  }

  void _share(BuildContext context) {
    final url = '$kThixPublicBaseUrl/b/${bundle.business.thixId}';
    Share.share(
      'Découvrez ${bundle.business.name} sur THIX 🚀\n$url\n'
      'ID : ${bundle.business.thixId}',
    );
  }

  void _showQr(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(bundle.business.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: bundle.theme.radiusSm,
              ),
              child: QrImageView(
                data: bundle.business.thixId,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              bundle.business.thixId,
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _openContactSheet(BuildContext context) {
    final section = bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent
        ? (section!.content as ContactContent).channels
        : const <ContactChannel>[];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: channels.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucun canal de contact renseigné.'),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Contacter ${bundle.business.name}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    for (final c in channels)
                      ListTile(
                        leading: Icon(_channelIcon(c.type)),
                        title: Text(c.label ?? c.type.name),
                        subtitle: Text(c.value),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          final uri = c.launchUri;
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  static IconData _channelIcon(ContactChannelType type) {
    switch (type) {
      case ContactChannelType.phone:
        return Icons.phone;
      case ContactChannelType.email:
        return Icons.mail_outline;
      case ContactChannelType.whatsapp:
        return Icons.chat;
      case ContactChannelType.website:
        return Icons.language;
      case ContactChannelType.address:
        return Icons.place_outlined;
      case ContactChannelType.map:
        return Icons.map_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO COVER (image + overlay + contenu bas-gauche)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.bundle,
    required this.onContact,
    required this.onShare,
  });

  final BusinessBundle bundle;
  final VoidCallback onContact;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;

    return Stack(
      fit: StackFit.expand,
      children: [
        ParallaxCover(
          colors: theme.heroGradient,
          imageUrl: b.coverUrl,
          factor: theme.animationStyle.parallax,
          height: 380,
          overlayOpacity: 0.35,
        ),
        // Voile bas pour lisibilité
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
        // Contenu
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.verified)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('ENTREPRISE VÉRIFIÉE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              _SlideIn(
                duration: Duration(
                    milliseconds: (650 * theme.animationStyle.durationScale).round()),
                beginY: 0.25,
                child: Text(
                  b.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                  ),
                ),
              ),
              if (b.claim != null && b.claim!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _FadeIn(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 250),
                    child: Text(
                      b.claim!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onContact,
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Nous contacter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: theme.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 17),
                      label: const Text('Partager'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: theme.radiusSm),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE IDENTITÉ CHEVAUCHANTE (logo ring + compteurs)
// ─────────────────────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.bundle});
  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;
    final style = theme.animationStyle;

    return Transform.translate(
      offset: const Offset(0, -18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: theme.radius,
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: -34,
                child: _ScaleFadeIn(
                  duration: Duration(
                      milliseconds: (700 * style.durationScale).round()),
                  beginScale: 0.5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(color: theme.accent, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: b.logoUrl != null
                          ? NetworkImage(b.logoUrl!)
                          : null,
                      child: b.logoUrl == null
                          ? Text(
                              b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onPrimaryContainer),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 76),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      [b.sector, b.city].whereType<String>().join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 58),
              Padding(
                padding: const EdgeInsets.only(top: 58),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (b.ageYears != null && b.ageYears! > 0)
                      AnimatedCounter(
                        value: b.ageYears!,
                        label: 'ans d\'expérience',
                        compact: false,
                        duration: Duration(
                            milliseconds:
                                (1200 * style.durationScale).round()),
                      ),
                    if (b.employees != null && b.employees! > 0)
                      AnimatedCounter(
                        value: b.employees!,
                        label: 'collaborateurs',
                        compact: false,
                        duration: Duration(
                            milliseconds:
                                (1200 * style.durationScale).round()),
                      ),
                    AnimatedCounter(
                      value: bundle.stats?.views ?? 0,
                      label: 'visites',
                      duration: Duration(
                          milliseconds: (1400 * style.durationScale).round()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANDEAU INFOS (chips horizontales)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <(IconData, String)>[
      if (business.sector != null) (Icons.category_rounded, business.sector!),
      if (business.city != null) (Icons.place_rounded, business.city!),
      if (business.sinceYear != null)
        (Icons.event_rounded, 'Depuis ${business.sinceYear}'),
      if (business.employees != null)
        (Icons.groups_rounded, '${business.employees} collaborateurs'),
      if (business.website != null) (Icons.language_rounded, business.website!),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(chips[i].$1, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(chips[i].$2,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RENDERER DE SECTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionRenderer extends StatelessWidget {
  const _SectionRenderer({required this.section});
  final BusinessSection section;

  @override
  Widget build(BuildContext context) {
    final content = section.content;
    switch (section.type) {
      case BusinessSectionType.about:
        return _AboutSection(content: content as AboutContent);
      case BusinessSectionType.services:
        return _ServicesSection(content: content as ServicesContent);
      case BusinessSectionType.products:
        return _ProductsSection(content: content as ProductsContent);
      case BusinessSectionType.gallery:
        return _GallerySection(content: content as GalleryContent);
      case BusinessSectionType.team:
        return _TeamSection(content: content as TeamContent);
      case BusinessSectionType.news:
        return _NewsSection(content: content as NewsContent);
      case BusinessSectionType.testimonials:
        return _TestimonialsSection(content: content as TestimonialsContent);
      case BusinessSectionType.contact:
        return _ContactSection(content: content as ContactContent);
    }
  }
}

Widget _sectionHeader(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
        ),
      ],
    ),
  );
}

Card _card(BuildContext context, {required Widget child, Clip clip = Clip.none}) {
  final theme = Theme.of(context);
  final radius = theme.extension<BusinessThemeExt>()?.radius ??
      BorderRadius.circular(24);
  return Card(
    clipBehavior: clip,
    elevation: 0,
    color: theme.colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    ),
    child: child,
  );
}

// ── À PROPOS (éditorial + photo) ──
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;

  @override
  Widget build(BuildContext context) {
    if (content.body.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final hasImage = content.imageUrl != null && content.imageUrl!.isNotEmpty;

    return _card(
      context,
      clip: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: content.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const ColoredBox(color: Colors.black12),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Colors.black12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, content.title),
                if (content.tagline != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      content.tagline!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                    ),
                  ),
                Text(content.body,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SERVICES (grille 2 colonnes, photo OU icône) ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;

  @override
  Widget build(BuildContext context) {
    if (content.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final radius = Theme.of(context).extension<BusinessThemeExt>()?.radius ??
        BorderRadius.circular(24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
          children: [
            for (final s in content.items)
              _card(
                context,
                clip: Clip.antiAlias,
                child: Column(
                  children: [
                    if (s.imageUrl != null && s.imageUrl!.isNotEmpty)
                      SizedBox(
                        height: 84,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: s.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: Colors.black12),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.bolt_rounded,
                              color: scheme.primary, size: 22),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13.5)),
                            if (s.description != null) ...[
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(s.description!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ),
                            ],
                            if (s.price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.tertiary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(s.price!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.tertiary)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // radius utilisé pour cohérence (évite warning unused)
        SizedBox.shrink(child: radius == null ? null : null),
      ],
    );
  }
}

// ── PRODUITS (grille photos) ──
class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;

  @override
  Widget build(BuildContext context) {
    if (content.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
          children: [
            for (final p in content.items)
              _card(
                context,
                clip: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: p.imageUrl == null
                          ? const ColoredBox(color: Colors.black12)
                          : CachedNetworkImage(
                              imageUrl: p.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) =>
                                  const ColoredBox(color: Colors.black12),
                              errorWidget: (_, __, ___) =>
                                  const ColoredBox(color: Colors.black12),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          if (p.price != null)
                            Text(p.price!,
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── RÉALISATIONS / GALERIE (rangée snap + légendes) ──
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;

  @override
  Widget build(BuildContext context) {
    if (content.images.isEmpty) return const SizedBox.shrink();
    final radius = Theme.of(context).extension<BusinessThemeExt>()?.radius ??
        BorderRadius.circular(24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: content.images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final img = content.images[i];
              return ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: img.url,
                      fit: BoxFit.cover,
                      width: 260,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Colors.black12),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Colors.black12),
                    ),
                    if (img.caption != null && img.caption!.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black60],
                            ),
                          ),
                          child: Text(img.caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── ÉQUIPE (avatars photos + nom + fonction) ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;

  @override
  Widget build(BuildContext context) {
    if (content.members.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: content.members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final m = content.members[i];
              return SizedBox(
                width: 108,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: scheme.primaryContainer,
                        backgroundImage: m.photoUrl != null
                            ? NetworkImage(m.photoUrl!)
                            : null,
                        child: m.photoUrl == null
                            ? Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 22),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(m.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12.5)),
                    if (m.role != null)
                      Text(m.role!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── ACTUALITÉS (✅ vignette photo + chip date + lire plus) ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;

  @override
  Widget build(BuildContext context) {
    if (content.posts.isEmpty) return const SizedBox.shrink();
    final fmt = DateFormat.yMMMd('fr_FR');
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        for (final p in content.posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _card(
              context,
              clip: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                    Stack(
                      children: [
                        SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: CachedNetworkImage(
                            imageUrl: p.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const ColoredBox(color: Colors.black12),
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: Colors.black12),
                          ),
                        ),
                        if (p.publishedAt != null)
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(fmt.format(p.publishedAt!),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.publishedAt != null &&
                            (p.imageUrl == null || p.imageUrl!.isEmpty))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(fmt.format(p.publishedAt!),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600)),
                          ),
                        Text(p.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                        if (p.excerpt != null) ...[
                          const SizedBox(height: 6),
                          Text(p.excerpt!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        if (p.url != null && p.url!.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => launchUrl(Uri.parse(p.url!),
                                  mode: LaunchMode.externalApplication),
                              child: const Text('Lire plus →'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── TÉMOIGNAGES ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;

  @override
  Widget build(BuildContext context) {
    if (content.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        SizedBox(
          height: 190,
          child: PageView(
            children: [
              for (final t in content.items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _card(
                    context,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              color: scheme.primary, size: 28),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(t.quote,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.5)),
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (t.author != null)
                                      Text(t.author!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5)),
                                    if (t.role != null)
                                      Text(t.role!,
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              color:
                                                  scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (t.rating != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < 5; i++)
                                      Icon(
                                        i < t.rating!
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 15,
                                        color: scheme.tertiary,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── CONTACT : carte « Nos informations » (lignes icônes cliquables) ──
class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.content});
  final ContactContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, content.title),
            for (final c in content.channels)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconOf(c.type), size: 18, color: scheme.primary),
                ),
                title: Text(c.label ?? c.type.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: Text(c.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () async {
                  final uri = c.launchUri;
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconOf(ContactChannelType type) {
    switch (type) {
      case ContactChannelType.phone:
        return Icons.phone_rounded;
      case ContactChannelType.email:
        return Icons.mail_rounded;
      case ContactChannelType.whatsapp:
        return Icons.chat_rounded;
      case ContactChannelType.website:
        return Icons.language_rounded;
      case ContactChannelType.address:
        return Icons.place_rounded;
      case ContactChannelType.map:
        return Icons.map_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER DE MARQUE (sombre, dérivé de la couleur propriétaire)
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.bundle});
  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final dark = Color.lerp(theme.primary, Colors.black, 0.55)!;

    return Container(
      width: double.infinity,
      color: dark,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                backgroundImage: bundle.business.logoUrl != null
                    ? NetworkImage(bundle.business.logoUrl!)
                    : null,
                child: bundle.business.logoUrl == null
                    ? const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bundle.business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    if (bundle.business.claim != null)
                      Text(bundle.business.claim!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          SelectableText(
            bundle.business.thixId,
            style: TextStyle(
              color: theme.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} ${bundle.business.name}. '
            'Tous droits réservés.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.verified_rounded,
                  size: 12, color: Colors.white.withValues(alpha: 0.65)),
              const SizedBox(width: 5),
              Text(
                'Propulsé par THIX HUB',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animations natives (réutilisées)
// ─────────────────────────────────────────────────────────────────────────────

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, required this.duration, this.delay = Duration.zero});
  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted && !_started) {
        _started = true;
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: widget.child);
}

class _SlideIn extends StatefulWidget {
  const _SlideIn({
    required this.child,
    required this.duration,
    this.delay = Duration.zero,
    this.beginY = 0.1,
  });
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginY;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted && !_started) {
        _started = true;
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, widget.beginY), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}

class _ScaleFadeIn extends StatefulWidget {
  const _ScaleFadeIn({
    required this.child,
    required this.duration,
    this.beginScale = 0.88,
  });
  final Widget child;
  final Duration duration;
  final double beginScale;

  @override
  State<_ScaleFadeIn> createState() => _ScaleFadeInState();
}

class _ScaleFadeInState extends State<_ScaleFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: widget.beginScale, end: 1).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension Theme (style + radius)
// ─────────────────────────────────────────────────────────────────────────────

class BusinessThemeExt extends ThemeExtension<BusinessThemeExt> {
  const BusinessThemeExt({required this.style, required this.radius});
  final BusinessAnimationStyle style;
  final BorderRadius radius;

  @override
  BusinessThemeExt copyWith({BusinessAnimationStyle? style, BorderRadius? radius}) =>
      BusinessThemeExt(
        style: style ?? this.style,
        radius: radius ?? this.radius,
      );

  @override
  BusinessThemeExt lerp(BusinessThemeExt? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
