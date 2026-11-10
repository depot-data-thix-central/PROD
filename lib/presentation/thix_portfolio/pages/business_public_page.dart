// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « GLASS PREMIUM »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 4.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v4.0 — Refonte design 100 % (glassmorphism / verre dépoli) :
//    • Fond ambiant (dégradé + halos flous) dérivé du BusinessTheme
//    • Barre du haut flottante en verre (opaque au scroll)
//    • Hero plein écran : carrousel auto + stats en verre flou
//    • Chips de navigation vers les rubriques
//    • Toutes les rubriques en cartes de verre, glissement gauche ↔ droite
//      (tactile + souris) + flèches
//    • Dock flottant en verre (Contacter / QR / Partager)
//    • FR / EN, 10 rubriques avancées (business_extras) conservés
//    • Images : Image.network + repli <img> (corrige les images grises web)
//    • 100 % des couleurs via BusinessTheme (Studio inchangé)
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
import '../widgets/reveal_on_scroll.dart';

const String kThixPublicBaseUrl = 'https://thixid.com';
const double _kMaxW = 1120;

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
    'read_more': 'Lire plus',
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
    'top': 'Haut de page',
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
    'read_more': 'Read more',
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
    'top': 'Back to top',
  },
};

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

String _fmtDate(String lang, DateTime d) {
  try {
    return DateFormat.yMMMd(lang == 'fr' ? 'fr_FR' : 'en_US').format(d);
  } catch (_) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

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

BorderRadius _radius(BuildContext c) =>
    Theme.of(c).extension<BusinessThemeExt>()?.radius ??
    BorderRadius.circular(24);

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 22, color: Colors.black38),
        ),
      );
}

/// Image réseau robuste (repli <img> HTML sur le web → évite les erreurs CORS).
Widget _img(String url, {BoxFit fit = BoxFit.cover, Widget? fallback}) {
  return ColoredBox(
    color: Colors.black.withValues(alpha: 0.05),
    child: Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      frameBuilder: (c, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 450),
              child: child,
            ),
      errorBuilder: (_, __, ___) => fallback ?? const _ImgFallback(),
    ),
  );
}

void _viewImage(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              ),
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

class _Tap extends StatelessWidget {
  const _Tap({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _Wrap extends StatelessWidget {
  const _Wrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxW),
          child: child,
        ),
      );
}

/// Apparition (fondu + montée) sans contrôleur.
class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.delay = 0, this.dy = 26});
  final Widget child;
  final int delay;
  final double dy;

  @override
  Widget build(BuildContext context) {
    final total = 750 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, ch) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: ch),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS — verre dépoli
// ─────────────────────────────────────────────────────────────────────────────

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius,
    this.padding,
    this.blur = 22,
    this.tint,
    this.alpha,
    this.shadow = true,
  });

  final Widget child;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? tint;
  final double? alpha;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = radius ?? _radius(context);
    final base = tint ?? Colors.white;
    final a = alpha ?? (dark ? 0.08 : 0.60);

    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.22 : 0.05),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: (a + 0.16).clamp(0.0, 1.0)),
                  base.withValues(alpha: a),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.14 : 0.75),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    this.color,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = _Tap(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon,
            size: size * 0.5,
            color: color ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.big = false});
  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: big ? 5 : 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: big ? 14 : 11.5,
          fontWeight: FontWeight.w900,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.radius,
    this.ring,
  });

  final String? url;
  final String name;
  final double radius;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = radius * 2;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fb = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(initial,
            style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w900,
                color: scheme.onPrimaryContainer)),
      ),
    );
    final has = url != null && url!.isNotEmpty;
    return Container(
      padding: ring != null ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: ring != null
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ring!, width: 2),
            )
          : null,
      child: ClipOval(
        child: SizedBox(
          width: d,
          height: d,
          child: has ? _img(url!, fallback: fb) : fb,
        ),
      ),
    );
  }
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
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        );
    return Scaffold(
      body: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(height: 520, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [block(80), block(220), block(160)]),
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
// SITE
// ─────────────────────────────────────────────────────────────────────────────

class _Blk {
  const _Blk(this.id, this.label, this.child);
  final String id;
  final String label;
  final Widget child;
}

bool _isEmpty(BusinessSectionContent c) => switch (c) {
      AboutContent() => c.body.trim().isEmpty,
      ServicesContent() => c.items.isEmpty,
      ProductsContent() => c.items.isEmpty,
      GalleryContent() => c.images.isEmpty,
      TeamContent() => c.members.isEmpty,
      NewsContent() => c.posts.isEmpty,
      TestimonialsContent() => c.items.isEmpty,
      ContactContent() => c.channels.isEmpty,
    };

String _titleOf(BusinessSectionContent c) => switch (c) {
      AboutContent() => c.title,
      ServicesContent() => c.title,
      ProductsContent() => c.title,
      GalleryContent() => c.title,
      TeamContent() => c.title,
      NewsContent() => c.title,
      TestimonialsContent() => c.title,
      ContactContent() => c.title,
    };

class _BusinessSite extends ConsumerStatefulWidget {
  const _BusinessSite({required this.bundle});

  final BusinessBundle bundle;

  @override
  ConsumerState<_BusinessSite> createState() => _BusinessSiteState();
}

class _BusinessSiteState extends ConsumerState<_BusinessSite> {
  String _lang = 'fr';
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier<bool>(false);
  final Map<String, GlobalKey> _keys = {};

  BusinessBundle get bundle => widget.bundle;

  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.hasClients && _scroll.offset > 380;
      if (s != _scrolled.value) _scrolled.value = s;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrolled.dispose();
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
    final n = bundle.sectionOfType(BusinessSectionType.news)?.content;
    if (n is NewsContent) {
      for (final p in n.posts) {
        final u = p.imageUrl;
        if (u != null && u.isNotEmpty && !out.contains(u)) out.add(u);
      }
    }
    return out.take(6).toList();
  }

  String _label(String title) =>
      _lang == 'en' ? (_titlesEn[title.trim()] ?? title) : title;

  void _goTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final sections = bundle.visibleSections;

    final extras = ref
        .watch(businessExtrasProvider(bundle.business.id))
        .maybeWhen(data: (d) => d, orElse: () => <BizExtra>[]);
    final visibleExtras = extras.where((e) => e.visible && e.hasContent).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final main = sections
        .where((s) =>
            s.type != BusinessSectionType.contact && !_isEmpty(s.content))
        .toList();
    final contact = sections
        .where((s) =>
            s.type == BusinessSectionType.contact && !_isEmpty(s.content))
        .toList();

    final blocks = <_Blk>[
      for (final s in main)
        _Blk('s-${s.id}', _label(_titleOf(s.content)),
            _SectionRenderer(section: s)),
      for (final e in visibleExtras)
        if (kBizKindByKey[e.kind] != null)
          _Blk(
            'x-${e.kind}',
            (e.title?.trim().isNotEmpty ?? false)
                ? e.title!.trim()
                : (_lang == 'en'
                    ? kBizKindByKey[e.kind]!.en
                    : kBizKindByKey[e.kind]!.fr),
            _ExtraSection(extra: e),
          ),
      for (final s in contact)
        _Blk('s-${s.id}', _label(_titleOf(s.content)),
            _SectionRenderer(section: s)),
    ];

    return _LangScope(
      code: _lang,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: ScrollConfiguration(
          behavior: const _DragScrollBehavior(),
          child: Stack(
            children: [
              Positioned.fill(child: _Ambient(bundle: bundle)),
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: _Hero(
                      bundle: bundle,
                      images: _heroImages(),
                      onContact: _openContactSheet,
                      onShare: _share,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Wrap(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 22, 0, 0),
                        child: _InfoStrip(business: bundle.business),
                      ),
                    ),
                  ),
                  if (blocks.length > 1)
                    SliverToBoxAdapter(
                      child: _Wrap(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _NavChips(
                            labels: [for (final b in blocks) b.label],
                            onTap: (i) => _goTo(blocks[i].id),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 34)),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        for (final b in blocks)
                          KeyedSubtree(
                            key: _key(b.id),
                            child: _Wrap(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 40),
                                child: RevealOnScroll(
                                  style: theme.animationStyle,
                                  staggerIndex: 0,
                                  child: b.child,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Footer(
                      bundle: bundle,
                      onTop: () => _scroll.animateTo(0,
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutCubic),
                    ),
                  ),
                ],
              ),

              // ── Barre du haut flottante ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _Wrap(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _scrolled,
                        builder: (_, s, __) => _TopBar(
                          bundle: bundle,
                          solid: s,
                          lang: _lang,
                          onLang: () => setState(
                              () => _lang = _lang == 'fr' ? 'en' : 'fr'),
                          onCopy: _copyId,
                          onQr: _showQr,
                          onShare: _share,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Dock flottant ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Center(
                      child: _Dock(
                        label: _t(_lang, 'contact'),
                        onContact: _openContactSheet,
                        onQr: _showQr,
                        onShare: _share,
                      ),
                    ),
                  ),
                ),
              ),
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
        behavior: SnackBarBehavior.floating,
        content: Text('${_t(_lang, 'copied')}${bundle.business.thixId}'),
      ),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _Glass(
            radius: BorderRadius.circular(30),
            blur: 30,
            alpha: 0.86,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final c in channels)
                                _ContactTile(channel: c),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fond ambiant (dégradé + halos flous)
// ─────────────────────────────────────────────────────────────────────────────

class _Ambient extends StatelessWidget {
  const _Ambient({required this.bundle});
  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = bundle.theme;

    Widget blob(Color c, double size) => IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0)],
              ),
            ),
          ),
        );

    return LayoutBuilder(
      builder: (_, cs) => Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                      t.primary.withValues(alpha: 0.09), scheme.surface),
                  scheme.surface,
                  Color.alphaBlend(
                      t.accent.withValues(alpha: 0.07), scheme.surface),
                ],
              ),
            ),
          ),
          Positioned(
              top: cs.maxHeight * 0.10,
              right: -cs.maxWidth * 0.15,
              child: blob(t.accent, 460)),
          Positioned(
              top: cs.maxHeight * 0.38,
              left: -cs.maxWidth * 0.18,
              child: blob(t.primary, 520)),
          Positioned(
              bottom: -cs.maxHeight * 0.05,
              right: cs.maxWidth * 0.05,
              child: blob(t.primary, 420)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre du haut
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.bundle,
    required this.solid,
    required this.lang,
    required this.onLang,
    required this.onCopy,
    required this.onQr,
    required this.onShare,
  });

  final BusinessBundle bundle;
  final bool solid;
  final String lang;
  final VoidCallback onLang;
  final VoidCallback onCopy;
  final VoidCallback onQr;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = solid ? scheme.onSurface : Colors.white;
    final b = bundle.business;

    return _Glass(
      radius: BorderRadius.circular(28),
      blur: 24,
      tint: solid ? scheme.surface : Colors.white,
      alpha: solid ? 0.74 : 0.14,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            _RoundBtn(
              icon: Icons.arrow_back_rounded,
              color: fg,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedOpacity(
              opacity: solid ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Row(
                children: [
                  _Avatar(url: b.logoUrl, name: b.name, radius: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tooltip(
            message: _t(lang, 'lang_tip'),
            child: TextButton(
              onPressed: onLang,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                lang == 'fr' ? 'EN' : 'FR',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
            ),
          ),
          _RoundBtn(
              icon: Icons.content_copy_rounded,
              color: fg,
              tooltip: _t(lang, 'copy_id'),
              onTap: onCopy),
          _RoundBtn(
              icon: Icons.qr_code_2_rounded,
              color: fg,
              tooltip: _t(lang, 'qr'),
              onTap: onQr),
          _RoundBtn(
              icon: Icons.ios_share_rounded,
              color: fg,
              tooltip: _t(lang, 'share'),
              onTap: onShare),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dock flottant
// ─────────────────────────────────────────────────────────────────────────────

class _Dock extends StatelessWidget {
  const _Dock({
    required this.label,
    required this.onContact,
    required this.onQr,
    required this.onShare,
  });

  final String label;
  final VoidCallback onContact;
  final VoidCallback onQr;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Glass(
      radius: BorderRadius.circular(40),
      blur: 26,
      tint: scheme.surface,
      alpha: 0.72,
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: onContact,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
          ),
          const SizedBox(width: 4),
          _RoundBtn(icon: Icons.qr_code_2_rounded, onTap: onQr, size: 46),
          _RoundBtn(icon: Icons.ios_share_rounded, onTap: onShare, size: 46),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({
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
    final size = MediaQuery.sizeOf(context);
    final height = math.min(math.max(680.0, size.height * 0.92), 880.0);
    final narrow = size.width < 600;

    final stats = <(int, String)>[
      if (b.ageYears != null && b.ageYears! > 0)
        (b.ageYears!, _tr(context, 'years')),
      if (b.employees != null && b.employees! > 0)
        (b.employees!, _tr(context, 'staff')),
      if ((bundle.stats?.views ?? 0) > 0)
        (bundle.stats!.views, _tr(context, 'visits')),
    ];

    final meta = [b.sector, b.city]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .join('  •  ');

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroCarousel(images: images, colors: theme.heroGradient),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.32, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Color.lerp(theme.primary, Colors.black, 0.75)!
                        .withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxW),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Rise(
                        child: Row(
                          children: [
                            _Avatar(
                              url: b.logoUrl,
                              name: b.name,
                              radius: narrow ? 30 : 38,
                              ring: theme.accent,
                            ),
                            if (b.verified) ...[
                              const SizedBox(width: 12),
                              _Glass(
                                radius: BorderRadius.circular(20),
                                blur: 16,
                                tint: const Color(0xFF22C55E),
                                alpha: 0.38,
                                shadow: false,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_rounded,
                                        size: 15, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      _tr(context, 'verified'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Rise(
                        delay: 120,
                        child: Text(
                          b.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: narrow ? 40 : 66,
                            height: 1.03,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.6,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 18),
                            ],
                          ),
                        ),
                      ),
                      if (b.claim != null && b.claim!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _Rise(
                            delay: 240,
                            child: Text(
                              b.claim!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.94),
                                fontSize: narrow ? 16 : 21,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (meta.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _Rise(
                            delay: 300,
                            child: Text(
                              meta,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _Rise(
                        delay: 380,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: onContact,
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18),
                              label: Text(_tr(context, 'contact_us'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.primary,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 26, vertical: 17),
                              ),
                            ),
                            _Tap(
                              onTap: onShare,
                              child: _Glass(
                                radius: BorderRadius.circular(40),
                                blur: 18,
                                alpha: 0.16,
                                shadow: false,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.ios_share_rounded,
                                        size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      _tr(context, 'share'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stats.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _Rise(
                          delay: 500,
                          child: _Glass(
                            radius: BorderRadius.circular(26),
                            blur: 26,
                            alpha: 0.14,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              children: [
                                for (var i = 0; i < stats.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                        width: 1,
                                        height: 36,
                                        color: Colors.white24),
                                  Expanded(
                                    child: _Stat(
                                        value: stats[i].$1,
                                        label: stats[i].$2),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _compact(v.round()),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_pc.hasClients) return;
        final next = (_index + 1) % widget.images.length;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 900),
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
        gradient,
        if (imgs.isNotEmpty)
          PageView.builder(
            controller: _pc,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _img(imgs[i], fallback: const SizedBox()),
          ),
        if (imgs.length > 1)
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < imgs.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      width: 6,
                      height: i == _index ? 24 : 6,
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Bandeau infos + navigation
// ─────────────────────────────────────────────────────────────────────────────

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <(IconData, String, VoidCallback?)>[
      if (business.sector != null)
        (Icons.category_rounded, business.sector!, null),
      if (business.city != null) (Icons.place_rounded, business.city!, null),
      if (business.sinceYear != null)
        (
          Icons.event_rounded,
          '${_tr(context, 'since')} ${business.sinceYear}',
          null
        ),
      if (business.employees != null)
        (
          Icons.groups_rounded,
          '${business.employees} ${_tr(context, 'staff')}',
          null
        ),
      if (business.website != null)
        (
          Icons.language_rounded,
          business.website!,
          () => _openUrl(business.website)
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _Tap(
          onTap: chips[i].$3,
          child: _Glass(
            radius: BorderRadius.circular(26),
            blur: 16,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chips[i].$1, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Text(chips[i].$2,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavChips extends StatelessWidget {
  const _NavChips({required this.labels, required this.onTap});
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _Tap(
          onTap: () => onTap(i),
          child: _Glass(
            radius: BorderRadius.circular(26),
            blur: 16,
            tint: scheme.primary,
            alpha: 0.12,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              labels[i],
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: scheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// En-têtes + section horizontale
// ─────────────────────────────────────────────────────────────────────────────

Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Container(
          width: 5,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scheme.primary, scheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _tt(context, title),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: -0.6),
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

class _HSection extends StatefulWidget {
  const _HSection({
    required this.title,
    required this.height,
    required this.count,
    required this.builder,
    this.gap = 14,
  });

  final String title;
  final double height;
  final int count;
  final IndexedWidgetBuilder builder;
  final double gap;

  @override
  State<_HSection> createState() => _HSectionState();
}

class _HSectionState extends State<_HSection> {
  final ScrollController _c = ScrollController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go(int dir) {
    if (!_c.hasClients) return;
    final w = _c.position.viewportDimension * 0.8;
    final t = (_c.offset + dir * w).clamp(0.0, _c.position.maxScrollExtent);
    _c.animateTo(t,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final arrows = widget.count > 1
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Glass(
                radius: BorderRadius.circular(20),
                blur: 14,
                shadow: false,
                child: _RoundBtn(
                    icon: Icons.chevron_left_rounded,
                    size: 38,
                    onTap: () => _go(-1)),
              ),
              const SizedBox(width: 8),
              _Glass(
                radius: BorderRadius.circular(20),
                blur: 14,
                shadow: false,
                child: _RoundBtn(
                    icon: Icons.chevron_right_rounded,
                    size: 38,
                    onTap: () => _go(1)),
              ),
            ],
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, widget.title, trailing: arrows),
        SizedBox(
          height: widget.height + 20,
          child: ListView.separated(
            controller: _c,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: widget.count,
            separatorBuilder: (_, __) => SizedBox(width: widget.gap),
            itemBuilder: widget.builder,
          ),
        ),
      ],
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

// ── À PROPOS ──
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = content.imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    final text = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, content.title),
          if (content.tagline != null && content.tagline!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _Pill(content.tagline!, big: true),
            ),
          Text(content.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
        ],
      ),
    );

    return _Glass(
      child: LayoutBuilder(
        builder: (context, cs) {
          if (!hasImage) return text;
          final wide = cs.maxWidth > 760;
          final image = _Tap(
            onTap: () => _viewImage(context, url),
            child: _img(url),
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 230, width: double.infinity, child: image),
                text,
              ],
            );
          }
          final imgW = cs.maxWidth * 5 / 11;
          return Stack(
            children: [
              Row(
                children: [
                  SizedBox(width: imgW),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 340),
                      child: text,
                    ),
                  ),
                ],
              ),
              Positioned(
                  left: 0, top: 0, bottom: 0, width: imgW, child: image),
            ],
          );
        },
      ),
    );
  }
}

// ── SERVICES ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _HSection(
      title: content.title,
      height: 290,
      count: content.items.length,
      builder: (_, i) {
        final s = content.items[i];
        final hasImg = s.imageUrl != null && s.imageUrl!.isNotEmpty;
        return SizedBox(
          width: 250,
          child: _Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImg)
                  SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: _img(s.imageUrl!))
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          scheme.primary.withValues(alpha: 0.22),
                          scheme.tertiary.withValues(alpha: 0.16),
                        ]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bolt_rounded,
                          color: scheme.primary, size: 26),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 6),
                        if (s.description != null)
                          Expanded(
                            child: Text(s.description!,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(height: 1.45)),
                          )
                        else
                          const Spacer(),
                        if (s.price != null && s.price!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _Pill(s.price!),
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
    );
  }
}

// ── PRODUITS ──
class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;

  @override
  Widget build(BuildContext context) {
    return _HSection(
      title: content.title,
      height: 300,
      count: content.items.length,
      builder: (_, i) {
        final p = content.items[i];
        return SizedBox(
          width: 220,
          child: _Tap(
            onTap: (p.url != null && p.url!.isNotEmpty)
                ? () => _openUrl(p.url)
                : null,
            child: _Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: (p.imageUrl == null || p.imageUrl!.isEmpty)
                          ? const _ImgFallback()
                          : _img(p.imageUrl!),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 14.5)),
                        if (p.price != null && p.price!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _Pill(p.price!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── GALERIE ──
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;

  @override
  Widget build(BuildContext context) {
    return _HSection(
      title: content.title,
      height: 220,
      count: content.images.length,
      builder: (_, i) {
        final img = content.images[i];
        return SizedBox(
          width: 330,
          child: _Tap(
            onTap: () => _viewImage(context, img.url),
            child: _Glass(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _img(img.url),
                  if (img.caption != null && img.caption!.isNotEmpty)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: _Glass(
                        radius: BorderRadius.circular(16),
                        blur: 16,
                        tint: Colors.black,
                        alpha: 0.30,
                        shadow: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(img.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── ÉQUIPE ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 210,
      count: content.members.length,
      builder: (_, i) {
        final m = content.members[i];
        return SizedBox(
          width: 170,
          child: _Glass(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Avatar(
                    url: m.photoUrl,
                    name: m.name,
                    radius: 42,
                    ring: scheme.primary),
                const SizedBox(height: 12),
                Text(m.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
                if (m.role != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(m.role!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── ACTUALITÉS ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;

  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return _HSection(
      title: content.title,
      height: 370,
      count: content.posts.length,
      builder: (_, i) {
        final p = content.posts[i];
        final hasImg = p.imageUrl != null && p.imageUrl!.isNotEmpty;
        return SizedBox(
          width: 320,
          child: _Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImg)
                  Stack(
                    children: [
                      SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: _img(p.imageUrl!)),
                      if (p.publishedAt != null)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _Glass(
                            radius: BorderRadius.circular(12),
                            blur: 14,
                            tint: scheme.primary,
                            alpha: 0.55,
                            shadow: false,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Text(_fmtDate(lang, p.publishedAt!),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.publishedAt != null && !hasImg)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(_fmtDate(lang, p.publishedAt!),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700)),
                          ),
                        Text(p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 6),
                        if (p.excerpt != null)
                          Expanded(
                            child: Text(p.excerpt!,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(height: 1.5)),
                          )
                        else
                          const Spacer(),
                        if (p.url != null && p.url!.isNotEmpty)
                          _Tap(
                            onTap: () => _openUrl(p.url),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_tr(context, 'read_more'),
                                      style: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: scheme.primary),
                                ],
                              ),
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
    );
  }
}

// ── TÉMOIGNAGES ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 230,
      count: content.items.length,
      builder: (_, idx) {
        final t = content.items[idx];
        return SizedBox(
          width: 350,
          child: _Glass(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    color: scheme.primary, size: 34),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(t.quote,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.55)),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.author != null)
                            Text(t.author!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13)),
                          if (t.role != null)
                            Text(t.role!,
                                style: TextStyle(
                                    fontSize: 11,
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
                              size: 16,
                              color: scheme.tertiary,
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── CONTACT ──
IconData _contactIcon(ContactChannelType type) {
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.channel});
  final ContactChannel channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = channel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final uri = c.launchUri;
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_contactIcon(c.type),
                    size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.label ?? c.type.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(c.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.content});
  final ContactContent content;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, content.title),
          for (final c in content.channels) _ContactTile(channel: c),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10 RUBRIQUES AVANCÉES (photos + vidéos)
// ─────────────────────────────────────────────────────────────────────────────

String _v(Map<String, String> m, String k) => (m[k] ?? '').trim();

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
    final title =
        custom.isNotEmpty ? custom : (lang == 'en' ? spec.en : spec.fr);

    switch (spec.layout) {
      case BizLayout.logo:
        return _HSection(
          title: title,
          height: 150,
          count: items.length,
          builder: (_, i) => _LogoCard(item: items[i]),
        );
      case BizLayout.steps:
        return _HSection(
          title: title,
          height: 270,
          count: items.length,
          builder: (_, i) => _StepCard(item: items[i], number: i + 1),
        );
      case BizLayout.standard:
        return _HSection(
          title: title,
          height: 380,
          count: items.length,
          builder: (_, i) => _StdCard(item: items[i], kind: spec.key),
        );
    }
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item});
  final Map<String, String> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final sub = _v(item, 'subtitle');
    final link = _v(item, 'link');
    return SizedBox(
      width: 170,
      child: _Tap(
        onTap: link.isEmpty ? null : () => _openUrl(link),
        child: _Glass(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Expanded(
                child: img.isEmpty
                    ? Icon(Icons.business_rounded,
                        size: 40, color: scheme.primary)
                    : _img(img, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              Text(_v(item, 'title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 12.5)),
              if (sub.isNotEmpty)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
            ],
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
      width: 280,
      child: _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img.isNotEmpty)
              SizedBox(height: 110, width: double.infinity, child: _img(img)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [scheme.primary, scheme.tertiary]),
                            shape: BoxShape.circle,
                          ),
                          child: Text('$number',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_v(item, 'title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(_v(item, 'text'),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(height: 1.5)),
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

    final ctaLabel =
        kind == 'careers' ? _tr(context, 'apply') : _tr(context, 'learn_more');

    return SizedBox(
      width: 280,
      child: _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: _Tap(
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
                            size: 38,
                            color: scheme.primary),
                      ),
                    if (video.isNotEmpty)
                      Center(
                        child: _Glass(
                          radius: BorderRadius.circular(40),
                          blur: 14,
                          tint: Colors.black,
                          alpha: 0.35,
                          shadow: false,
                          padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_v(item, 'title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                      ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _Pill(meta, big: isPricing),
                      ),
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(text,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.45)),
                      ),
                    ] else
                      const Spacer(),
                    if (link.isNotEmpty || (isVideoKind && video.isNotEmpty))
                      _Tap(
                        onTap: () => _openUrl(link.isNotEmpty ? link : video),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  link.isEmpty && isVideoKind
                                      ? _tr(context, 'watch')
                                      : ctaLabel,
                                  style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: scheme.primary),
                            ],
                          ),
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
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.bundle, required this.onTop});
  final BusinessBundle bundle;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final d1 = Color.lerp(theme.primary, Colors.black, 0.60)!;
    final d2 = Color.lerp(theme.primary, Colors.black, 0.84)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [d1, d2],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 120),
      child: _Wrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(url: b.logoUrl, name: b.name, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      if (b.claim != null)
                        Text(b.claim!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12)),
                    ],
                  ),
                ),
                _Tap(
                  onTap: onTop,
                  child: _Glass(
                    radius: BorderRadius.circular(26),
                    blur: 14,
                    alpha: 0.12,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_tr(context, 'top'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),
            SelectableText(
              b.thixId,
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '© ${DateTime.now().year} ${b.name}. ${_tr(context, 'rights')}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.65)),
                const SizedBox(width: 6),
                Text(
                  _tr(context, 'powered'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12),
                ),
              ],
            ),
          ],
        ),
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
