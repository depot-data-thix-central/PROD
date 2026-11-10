// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « SITE INSTITUTIONNEL »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 3.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v3.0 :
//    • HERO bannière qui défile (cover + galerie) + points indicateurs
//    • Fix titre doublé (le titre n'apparaît dans la barre qu'une fois réduite)
//    • Toutes les rubriques glissent GAUCHE ↔ DROITE (tactile + souris web)
//    • FR / EN intégré (bouton dans la barre) — libellés UI + titres par défaut
//    • 10 rubriques avancées (vidéos, partenaires, clients, certifications,
//      projets, méthode, événements, carrières, tarifs, agences)
//      avec photos et vidéos (table business_extras)
//    • 100 % des couleurs via BusinessTheme (Studio inchangé)
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/business_extras.dart';
import '../data/business_repository.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/reveal_on_scroll.dart';

const String kThixPublicBaseUrl = 'https://thixid.com';

// ─────────────────────────────────────────────────────────────────────────────
// i18n FR / EN
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> _i18n = {
  'fr': {
    'contact_us': 'Nous contacter',
    'share': 'Partager',
    'contact': 'Contacter',
    'verified': 'ENTREPRISE VÉRIFIÉE',
    'years': "ans d'expérience",
    'staff': 'collaborateurs',
    'visits': 'visites',
    'since': 'Depuis',
    'read_more': 'Lire plus →',
    'copy_id': "Copier l'ID",
    'copied': 'ID copié : ',
    'qr': 'QR code',
    'close': 'Fermer',
    'no_channel': 'Aucun canal de contact renseigné.',
    'contact_prefix': 'Contacter',
    'rights': 'Tous droits réservés.',
    'powered': 'Propulsé par THIX HUB',
    'watch': 'Voir la vidéo',
    'learn_more': 'En savoir plus',
    'apply': 'Postuler',
    'lang_tip': 'English',
    'share_msg': 'Découvrez {name} sur THIX 🚀',
    'not_found': 'Entreprise introuvable',
    'invalid': 'Identifiant invalide',
    'retry': 'Réessayer',
  },
  'en': {
    'contact_us': 'Contact us',
    'share': 'Share',
    'contact': 'Contact',
    'verified': 'VERIFIED COMPANY',
    'years': 'years of experience',
    'staff': 'team members',
    'visits': 'visits',
    'since': 'Since',
    'read_more': 'Read more →',
    'copy_id': 'Copy ID',
    'copied': 'ID copied: ',
    'qr': 'QR code',
    'close': 'Close',
    'no_channel': 'No contact channel provided.',
    'contact_prefix': 'Contact',
    'rights': 'All rights reserved.',
    'powered': 'Powered by THIX HUB',
    'watch': 'Watch video',
    'learn_more': 'Learn more',
    'apply': 'Apply',
    'lang_tip': 'Français',
    'share_msg': 'Discover {name} on THIX 🚀',
    'not_found': 'Business not found',
    'invalid': 'Invalid identifier',
    'retry': 'Retry',
  },
};

/// Titres par défaut (FR → EN) pour les sections standard.
const Map<String, String> _titlesEn = {
  'À propos': 'About',
  'À propos de nous': 'About us',
  'Nos services': 'Our services',
  'Services': 'Services',
  'Produits': 'Products',
  'Nos produits': 'Our products',
  'Galerie': 'Gallery',
  'Nos réalisations': 'Our work',
  'Équipe': 'Team',
  'Notre équipe': 'Our team',
  'Actualités': 'News',
  'Témoignages': 'Testimonials',
  'Contact': 'Contact',
  'Nos informations': 'Our information',
};

String _t(String lang, String key) => _i18n[lang]?[key] ?? key;

class _LangScope extends InheritedWidget {
  const _LangScope({required this.code, required super.child});
  final String code;

  static String of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<_LangScope>()?.code ?? 'fr';

  @override
  bool updateShouldNotify(_LangScope old) => old.code != code;
}
String _tr(BuildContext c, String key) => _t(_LangScope.of(c), key);

String _tt(BuildContext c, String title) =>
    _LangScope.of(c) == 'en' ? (_titlesEn[title.trim()] ?? title) : title;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

Future<void> _openUrl(String? url) async {
  if (url == null || url.trim().isEmpty) return;
  var u = url.trim();
  if (!u.startsWith('http')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Widget _img(String url, {BoxFit fit = BoxFit.cover}) => CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const ColoredBox(color: Colors.black12),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Colors.black12,
        child: Center(
            child: Icon(Icons.image_not_supported_outlined,
                size: 20, color: Colors.black38)),
      ),
    );

void _viewImage(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Rangée horizontale (glisser gauche ↔ droite).
Widget _hList({
  required double height,
  required int count,
  required IndexedWidgetBuilder builder,
  double gap = 12,
}) {
  return SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(width: gap),
      itemBuilder: builder,
    ),
  );
}

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
            const SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
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
                  label: const Text('Réessayer / Retry'),
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

class _BusinessSite extends ConsumerStatefulWidget {
  const _BusinessSite({required this.bundle});

  final BusinessBundle bundle;

  @override
  ConsumerState<_BusinessSite> createState() => _BusinessSiteState();
}

class _BusinessSiteState extends ConsumerState<_BusinessSite> {
  String _lang = 'fr';
  final ScrollController _scroll = ScrollController();
  bool _collapsed = false;

  BusinessBundle get bundle => widget.bundle;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final c = _scroll.hasClients && _scroll.offset > 300;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<String> _heroImages() {
    final out = <String>[];
    final cover = bundle.business.coverUrl;
    if (cover != null && cover.isNotEmpty) out.add(cover);
    final g = bundle.sectionOfType(BusinessSectionType.gallery);
    final c = g?.content;
    if (c is GalleryContent) {
      for (final i in c.images) {
        if (i.url.isNotEmpty && !out.contains(i.url)) out.add(i.url);
      }
    }
    return out.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final sections = bundle.visibleSections;

    final extras = ref
        .watch(businessExtrasProvider(bundle.business.id))
        .maybeWhen(data: (d) => d, orElse: () => <BizExtra>[]);
    final visibleExtras = extras
        .where((e) => e.visible && e.hasContent)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final main =
        sections.where((s) => s.type != BusinessSectionType.contact).toList();
    final contact =
        sections.where((s) => s.type == BusinessSectionType.contact).toList();

    final blocks = <Widget>[
      for (final s in main) _SectionRenderer(section: s),
      for (final e in visibleExtras) _ExtraSection(extra: e),
      for (final s in contact) _SectionRenderer(section: s),
    ];

    return _LangScope(
      code: _lang,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openContactSheet,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(_t(_lang, 'contact')),
        ),
        body: ScrollConfiguration(
          behavior: const _DragScrollBehavior(),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              // ── HERO : carrousel + overlay + nom + slogan + CTAs ──
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                stretch: true,
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                title: AnimatedOpacity(
                  opacity: _collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    bundle.business.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _lang = _lang == 'fr' ? 'en' : 'fr'),
                    child: Tooltip(
                      message: _t(_lang, 'lang_tip'),
                      child: Text(
                        _lang == 'fr' ? 'EN' : 'FR',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _t(_lang, 'copy_id'),
                    icon: const Icon(Icons.content_copy),
                    onPressed: _copyId,
                  ),
                  IconButton(
                    tooltip: _t(_lang, 'qr'),
                    icon: const Icon(Icons.qr_code_2),
                    onPressed: _showQr,
                  ),
                  IconButton(
                    tooltip: _t(_lang, 'share'),
                    icon: const Icon(Icons.share),
                    onPressed: _share,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: _HeroCover(
                    bundle: bundle,
                    images: _heroImages(),
                    onContact: _openContactSheet,
                    onShare: _share,
                  ),
                ),
              ),

              // ── Carte identité chevauchante + compteurs ──
              SliverToBoxAdapter(child: _IdentityCard(bundle: bundle)),

              // ── Bandeau infos ──
              SliverToBoxAdapter(child: _InfoStrip(business: bundle.business)),

              // ── Sections ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: RevealOnScroll(
                        style: theme.animationStyle,
                        staggerIndex: i,
                        child: blocks[i],
                      ),
                    ),
                    childCount: blocks.length,
                  ),
                ),
              ),

              // ── Footer de marque ──
              SliverToBoxAdapter(child: _Footer(bundle: bundle)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: bundle.business.thixId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${_t(_lang, 'copied')}${bundle.business.thixId}')),
    );
  }

  void _share() {
    final url = '$kThixPublicBaseUrl/b/${bundle.business.thixId}';
    Share.share(
      '${_t(_lang, 'share_msg').replaceAll('{name}', bundle.business.name)}\n'
      '$url\nID : ${bundle.business.thixId}',
    );
  }

  void _showQr() {
    final scheme = Theme.of(context).colorScheme;
    final lang = _lang;
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
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t(lang, 'close')),
          ),
        ],
      ),
    );
  }

  void _openContactSheet() {
    final lang = _lang;
    final section = bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent
        ? (section!.content as ContactContent).channels
        : const <ContactChannel>[];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: channels.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_t(lang, 'no_channel')),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_t(lang, 'contact_prefix')} ${bundle.business.name}',
                      style: Theme.of(sheetCtx)
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
// HERO : carrousel qui défile + contenu bas-gauche
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.bundle,
    required this.images,
    required this.onContact,
    required this.onShare,
  });

  final BusinessBundle bundle;
  final List<String> images;
  final VoidCallback onContact;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;

    return Stack(
      fit: StackFit.expand,
      children: [
        _HeroCarousel(images: images, colors: theme.heroGradient),
        // Voile bas pour lisibilité
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 34,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(_tr(context, 'verified'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              _SlideIn(
                duration: Duration(
                    milliseconds:
                        (650 * theme.animationStyle.durationScale).round()),
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
                      label: Text(_tr(context, 'contact_us')),
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
                      label: Text(_tr(context, 'share')),
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

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.images, required this.colors});
  final List<String> images;
  final List<Color> colors;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pc = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pc.hasClients) return;
        final next = (_index + 1) % widget.images.length;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.colors.length >= 2
              ? widget.colors
              : [Theme.of(context).colorScheme.primary, Colors.black87],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imgs.isEmpty)
          gradient
        else
          PageView.builder(
            controller: _pc,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: imgs[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => gradient,
              errorWidget: (_, __, ___) => gradient,
            ),
          ),
        const IgnorePointer(
          child: ColoredBox(color: Color(0x59000000)),
        ),
        if (imgs.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < imgs.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
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
                      backgroundImage:
                          b.logoUrl != null ? NetworkImage(b.logoUrl!) : null,
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
                        label: _tr(context, 'years'),
                        compact: false,
                        duration: Duration(
                            milliseconds: (1200 * style.durationScale).round()),
                      ),
                    if (b.employees != null && b.employees! > 0)
                      AnimatedCounter(
                        value: b.employees!,
                        label: _tr(context, 'staff'),
                        compact: false,
                        duration: Duration(
                            milliseconds: (1200 * style.durationScale).round()),
                      ),
                    AnimatedCounter(
                      value: bundle.stats?.views ?? 0,
                      label: _tr(context, 'visits'),
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
        (Icons.event_rounded,
            '${_tr(context, 'since')} ${business.sinceYear}'),
      if (business.employees != null)
        (Icons.groups_rounded,
            '${business.employees} ${_tr(context, 'staff')}'),
      if (business.website != null) (Icons.language_rounded, business.website!),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
// RENDERER DE SECTIONS STANDARD
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
            _tt(context, title),
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

Card _card(BuildContext context,
    {required Widget child, Clip clip = Clip.none}) {
  final theme = Theme.of(context);
  final radius = theme.extension<BusinessThemeExt>()?.radius ??
      BorderRadius.circular(24);
  return Card(
    margin: EdgeInsets.zero,
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
              height: 190,
              width: double.infinity,
              child: GestureDetector(
                onTap: () => _viewImage(context, content.imageUrl!),
                child: _img(content.imageUrl!),
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
                    style:
                        theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SERVICES (rangée glissante, photo OU icône) ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;

  @override
  Widget build(BuildContext context) {
    if (content.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        _hList(
          height: 240,
          count: content.items.length,
          builder: (_, i) {
            final s = content.items[i];
            final hasImg = s.imageUrl != null && s.imageUrl!.isNotEmpty;
            return SizedBox(
              width: 210,
              child: _card(
                context,
                clip: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImg)
                      SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: _img(s.imageUrl!),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 14, left: 12),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
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
                            ] else
                              const Spacer(),
                            if (s.price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      scheme.tertiary.withValues(alpha: 0.15),
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
            );
          },
        ),
      ],
    );
  }
}

// ── PRODUITS (rangée glissante, photos) ──
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
        _hList(
          height: 240,
          count: content.items.length,
          builder: (_, i) {
            final p = content.items[i];
            return SizedBox(
              width: 180,
              child: InkWell(
                onTap: () => _openUrl(p.url),
                child: _card(
                  context,
                  clip: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: p.imageUrl == null || p.imageUrl!.isEmpty
                            ? const ColoredBox(color: Colors.black12)
                            : _img(p.imageUrl!),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
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
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── RÉALISATIONS / GALERIE ──
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
        _hList(
          height: 200,
          count: content.images.length,
          builder: (_, i) {
            final img = content.images[i];
            return GestureDetector(
              onTap: () => _viewImage(context, img.url),
              child: SizedBox(
                width: 280,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _img(img.url),
                      if (img.caption != null && img.caption!.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding:
                                const EdgeInsets.fromLTRB(12, 18, 12, 10),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
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
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── ÉQUIPE ──
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
        _hList(
          height: 160,
          gap: 14,
          count: content.members.length,
          builder: (_, i) {
            final m = content.members[i];
            return SizedBox(
              width: 112,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage:
                          m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
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
      ],
    );
  }
}

// ── ACTUALITÉS (rangée glissante) ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;

  @override
  Widget build(BuildContext context) {
    if (content.posts.isEmpty) return const SizedBox.shrink();
    final lang = _LangScope.of(context);
    final fmt = DateFormat.yMMMd(lang == 'fr' ? 'fr_FR' : 'en_US');
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        _hList(
          height: 340,
          count: content.posts.length,
          builder: (_, i) {
            final p = content.posts[i];
            final hasImg = p.imageUrl != null && p.imageUrl!.isNotEmpty;
            return SizedBox(
              width: 290,
              child: _card(
                context,
                clip: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImg)
                      Stack(
                        children: [
                          SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: _img(p.imageUrl!)),
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.publishedAt != null && !hasImg)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(fmt.format(p.publishedAt!),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600)),
                              ),
                            Text(p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15)),
                            if (p.excerpt != null) ...[
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(p.excerpt!,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium),
                              ),
                            ] else
                              const Spacer(),
                            if (p.url != null && p.url!.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _openUrl(p.url),
                                  child: Text(_tr(context, 'read_more')),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── TÉMOIGNAGES (rangée glissante) ──
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
        _hList(
          height: 210,
          count: content.items.length,
          builder: (_, idx) {
            final t = content.items[idx];
            return SizedBox(
              width: 300,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color: scheme.onSurfaceVariant)),
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
            );
          },
        ),
      ],
    );
  }
}

// ── CONTACT ──
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
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
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
// 10 RUBRIQUES AVANCÉES (rangées glissantes, photos + vidéos)
// ─────────────────────────────────────────────────────────────────────────────

class _ExtraSection extends StatelessWidget {
  const _ExtraSection({required this.extra});
  final BizExtra extra;

  @override
  Widget build(BuildContext context) {
    final spec = kBizKindByKey[extra.kind];
    if (spec == null) return const SizedBox.shrink();
    final lang = _LangScope.of(context);
    final items = extra.items
        .where((i) => (i['title'] ?? '').trim().isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final custom = extra.title?.trim() ?? '';
    final title = custom.isNotEmpty ? custom : (lang == 'en' ? spec.en : spec.fr);

    late final Widget list;
    switch (spec.layout) {
      case BizLayout.logo:
        list = _hList(
          height: 136,
          count: items.length,
          builder: (_, i) => _LogoCard(item: items[i]),
        );
        break;
      case BizLayout.steps:
        list = _hList(
          height: 250,
          count: items.length,
          builder: (_, i) => _StepCard(item: items[i], number: i + 1),
        );
        break;
      case BizLayout.standard:
        list = _hList(
          height: 350,
          count: items.length,
          builder: (_, i) => _StdCard(item: items[i], kind: spec.key),
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, title),
        list,
      ],
    );
  }
}

String _v(Map<String, String> m, String k) => (m[k] ?? '').trim();

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item});
  final Map<String, String> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final sub = _v(item, 'subtitle');
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: _v(item, 'link').isEmpty ? null : () => _openUrl(item['link']),
        child: _card(
          context,
          clip: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: img.isEmpty
                      ? Icon(Icons.business_rounded,
                          size: 36, color: scheme.primary)
                      : _img(img, fit: BoxFit.contain),
                ),
                const SizedBox(height: 6),
                Text(_v(item, 'title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12)),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.item, required this.number});
  final Map<String, String> item;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    return SizedBox(
      width: 260,
      child: _card(
        context,
        clip: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img.isNotEmpty)
              SizedBox(
                  height: 100, width: double.infinity, child: _img(img)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.primary,
                          child: Text('$number',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_v(item, 'title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(_v(item, 'text'),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
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

class _StdCard extends StatelessWidget {
  const _StdCard({required this.item, required this.kind});
  final Map<String, String> item;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final video = _v(item, 'video');
    final sub = _v(item, 'subtitle');
    final meta = _v(item, 'meta');
    final text = _v(item, 'text');
    final link = _v(item, 'link');
    final isVideoKind = kind == 'videos';
    final isPricing = kind == 'pricing';

    final ctaLabel = kind == 'careers'
        ? _tr(context, 'apply')
        : _tr(context, 'learn_more');

    return SizedBox(
      width: 260,
      child: _card(
        context,
        clip: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Média : photo ou vidéo ──
            SizedBox(
              height: 140,
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  if (video.isNotEmpty) {
                    _openUrl(video);
                  } else if (img.isNotEmpty) {
                    _viewImage(context, img);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (img.isNotEmpty)
                      _img(img)
                    else
                      ColoredBox(
                        color: scheme.primary.withValues(alpha: 0.10),
                        child: Icon(
                            video.isNotEmpty
                                ? Icons.movie_creation_outlined
                                : kBizKindByKey[kind]?.icon ??
                                    Icons.image_outlined,
                            size: 36,
                            color: scheme.primary),
                      ),
                    if (video.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 30),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_v(item, 'title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                      ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: isPricing ? 14 : 11,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.primary)),
                        ),
                      ),
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(text,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ] else
                      const Spacer(),
                    if (link.isNotEmpty || (isVideoKind && video.isNotEmpty))
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              _openUrl(link.isNotEmpty ? link : video),
                          child: Text(
                              link.isEmpty && isVideoKind
                                  ? _tr(context, 'watch')
                                  : ctaLabel),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER DE MARQUE
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
            '${_tr(context, 'rights')}',
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
                _tr(context, 'powered'),
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
// Animations natives
// ─────────────────────────────────────────────────────────────────────────────

class _FadeIn extends StatefulWidget {
  const _FadeIn(
      {required this.child,
      required this.duration,
      this.delay = Duration.zero});
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

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
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
        position:
            Tween<Offset>(begin: Offset(0, widget.beginY), end: Offset.zero)
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
  BusinessThemeExt copyWith(
          {BusinessAnimationStyle? style, BorderRadius? radius}) =>
      BusinessThemeExt(
        style: style ?? this.style,
        radius: radius ?? this.radius,
      );

  @override
  BusinessThemeExt lerp(BusinessThemeExt? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
