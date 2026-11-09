// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE (LE SITE DE L'ENTREPRISE)
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.4 — Novembre 2026 (CORRIGÉ CI v3)
// ════════════════════════════════════════════════════════════════════════════
//
//  Corrections CI v3 :
//    • extensions: [ext] au lieu de Map (Flutter 3.47 attend un Iterable)
//    • Typewriter natif au lieu de AnimatedTextKit (non dans pubspec)
//    • Toutes les animations sont NATIVES Flutter
// ════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
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
        // ✅ FIX CI v3 : extensions attend un Iterable (liste), pas un Map
        return Theme(
          data: bundle.theme.toThemeData().copyWith(
                extensions: [ext],
              ),
          child: _BusinessSite(bundle: bundle),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton de chargement
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
                background: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(
                      height: 220,
                      child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white))),
                  const SizedBox(height: 16),
                  const SizedBox(
                      height: 24,
                      child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white))),
                  const SizedBox(height: 16),
                  const SizedBox(
                      height: 140,
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

// ─────────────────────────────────────────────────────────────────────────────
// Page introuvable / ID invalide
// ─────────────────────────────────────────────────────────────────────────────

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
// Le site (scroll principal)
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
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
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
              background: ParallaxCover(
                colors: theme.heroGradient,
                imageUrl: bundle.business.coverUrl,
                factor: theme.animationStyle.parallax,
                height: 340,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _HeroIdentity(bundle: bundle),
          ),

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
      builder: (_) => Theme(
        data: Theme.of(context),
        child: AlertDialog(
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
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
      builder: (_) => Theme(
        data: Theme.of(context),
        child: SafeArea(
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
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  IconData _channelIcon(ContactChannelType type) {
    switch (type) {
      case ContactChannelType.phone:    return Icons.phone;
      case ContactChannelType.email:    return Icons.mail_outline;
      case ContactChannelType.whatsapp: return Icons.chat;
      case ContactChannelType.website:  return Icons.language;
      case ContactChannelType.address:  return Icons.place_outlined;
      case ContactChannelType.map:      return Icons.map_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero : logo + nom + badge + slogan + compteurs
// ─────────────────────────────────────────────────────────────────────────────

class _HeroIdentity extends StatelessWidget {
  const _HeroIdentity({required this.bundle});
  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;
    final style = theme.animationStyle;

    final counters = <Widget>[
      if (b.ageYears != null && b.ageYears! > 0)
        AnimatedCounter(
          value: b.ageYears!,
          label: 'ans d\'expérience',
          compact: false,
          duration: Duration(milliseconds: (1200 * style.durationScale).round()),
        ),
      if (b.employees != null && b.employees! > 0)
        AnimatedCounter(
          value: b.employees!,
          label: 'collaborateurs',
          compact: false,
          duration: Duration(milliseconds: (1200 * style.durationScale).round()),
        ),
      AnimatedCounter(
        value: bundle.stats?.views ?? 0,
        label: 'visites',
        duration: Duration(milliseconds: (1400 * style.durationScale).round()),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          _logo(context),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _SlideIn(
                  duration: Duration(milliseconds: (600 * style.durationScale).round()),
                  delay: Duration(milliseconds: (200 * style.durationScale).round()),
                  beginY: 0.35,
                  child: Text(
                    b.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (b.verified)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _PulseIcon(
                    icon: Icons.verified,
                    color: const Color(0xFF22C55E),
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (b.sector != null || b.city != null)
            _FadeIn(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 300),
              child: Text(
                [b.sector, b.city].whereType<String>().join(' • '),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 10),
          // ✅ FIX CI v3 : Typewriter NATIF (pas de package animated_text_kit)
          if (b.claim != null && b.claim!.trim().isNotEmpty)
            DefaultTextStyle(
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              child: _Typewriter(
                text: b.claim!,
                speed: Duration(milliseconds: (35 * style.durationScale).round()),
              ),
            ),
          const SizedBox(height: 22),
          if (counters.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final c in counters) Expanded(child: c),
              ],
            ),
        ],
      ),
    );
  }

  Widget _logo(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final style = theme.animationStyle;

    Widget logo = CircleAvatar(
      radius: 52,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: bundle.business.logoUrl != null
          ? NetworkImage(bundle.business.logoUrl!)
          : null,
      child: bundle.business.logoUrl == null
          ? Text(
              bundle.business.name.isNotEmpty
                  ? bundle.business.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: scheme.onPrimaryContainer,
              ),
            )
          : null,
    );

    logo = _ScaleFadeIn(
      duration: Duration(milliseconds: (700 * style.durationScale).round()),
      beginScale: 0.4,
      child: logo,
    );

    if (style.glow) {
      logo = _GlowWrapper(
        color: scheme.primary,
        blurRadius: 26,
        child: logo,
      );
    }
    return logo;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typewriter NATIF (remplace AnimatedTextKit non présent dans pubspec)
// ─────────────────────────────────────────────────────────────────────────────

class _Typewriter extends StatefulWidget {
  const _Typewriter({required this.text, required this.speed});
  final String text;
  final Duration speed;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int _charIndex = 0;
  bool _cursorVisible = true;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final timer = _typeChar();
    });
  }

  Future<void> _typeChar() async {
    while (_charIndex < widget.text.length && mounted) {
      await Future.delayed(widget.speed);
      if (!mounted) return;
      setState(() => _charIndex++);
    }
    // Curseur clignotant après la fin
    if (mounted) {
      _blinkCursor();
    }
  }

  void _blinkCursor() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _cursorVisible = !_cursorVisible);
      _blinkCursor();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayed = widget.text.substring(0, _charIndex);
    return Text(
      '$displayed${_cursorVisible ? '│' : ' '}',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets d'animation NATIFS (remplacent .animate() de flutter_animate)
// ─────────────────────────────────────────────────────────────────────────────

class _FadeIn extends StatefulWidget {
  const _FadeIn({
    required this.child,
    required this.duration,
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted && !_started) {
        _started = true;
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted && !_started) {
        _started = true;
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.beginY),
          end: Offset.zero,
        ).animate(_curve),
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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

class _PulseIcon extends StatefulWidget {
  const _PulseIcon({
    required this.icon,
    required this.color,
    this.size = 24,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.18);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}

class _GlowWrapper extends StatefulWidget {
  const _GlowWrapper({
    required this.child,
    required this.color,
    this.blurRadius = 26,
  });
  final Widget child;
  final Color color;
  final double blurRadius;

  @override
  State<_GlowWrapper> createState() => _GlowWrapperState();
}

class _GlowWrapperState extends State<_GlowWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.3 + (_controller.value * 0.4);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: opacity),
                blurRadius: widget.blurRadius,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rendu des sections
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
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Card _card(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  final radius = theme.extension<BusinessThemeExt>()?.radius ??
      BorderRadius.circular(24);
  return Card(
    elevation: 0,
    color: theme.colorScheme.surfaceContainerLow,
    shape: RoundedRectangleBorder(borderRadius: radius),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;

  @override
  Widget build(BuildContext context) {
    if (content.body.trim().isEmpty) return const SizedBox.shrink();
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, content.title),
          if (content.tagline != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                content.tagline!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          Text(content.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in content.items)
              SizedBox(
                width: 160,
                child: _card(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.bolt, color: scheme.primary),
                      const SizedBox(height: 8),
                      Text(s.title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (s.description != null) ...[
                        const SizedBox(height: 4),
                        Text(s.description!,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (s.price != null) ...[
                        const SizedBox(height: 8),
                        Chip(label: Text(s.price!)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;

  @override
  Widget build(BuildContext context) {
    if (content.items.isEmpty) return const SizedBox.shrink();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                    ),
                    const SizedBox(height: 8),
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (p.price != null)
                      Text(p.price!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          )),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;

  @override
  Widget build(BuildContext context) {
    if (content.images.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).extension<BusinessThemeExt>()?.style ??
        BusinessAnimationStyle.elegant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        CarouselSlider(
          options: CarouselOptions(
            height: 200,
            viewportFraction: 0.85,
            enlargeCenterPage: true,
            autoPlay: style != BusinessAnimationStyle.minimal,
            autoPlayInterval: const Duration(seconds: 4),
          ),
          items: [
            for (final img in content.images)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: img.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Colors.black12),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Colors.black12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final m = content.members[i];
              return SizedBox(
                width: 120,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: m.photoUrl != null
                          ? NetworkImage(m.photoUrl!)
                          : null,
                      child: m.photoUrl == null
                          ? Text(m.name.isNotEmpty
                              ? m.name[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (m.role != null)
                      Text(m.role!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
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

class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;

  @override
  Widget build(BuildContext context) {
    if (content.posts.isEmpty) return const SizedBox.shrink();
    final fmt = DateFormat.yMMMd('fr_FR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        for (final p in content.posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.publishedAt != null)
                    Text(fmt.format(p.publishedAt!),
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(p.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (p.excerpt != null) ...[
                    const SizedBox(height: 4),
                    Text(p.excerpt!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

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
          height: 170,
          child: PageView(
            children: [
              for (final t in content.items)
                _card(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote, color: scheme.primary),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(t.quote,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Row(
                        children: [
                          if (t.rating != null)
                            for (var i = 0; i < 5; i++)
                              Icon(
                                i < t.rating! ? Icons.star : Icons.star_border,
                                size: 16,
                                color: scheme.tertiary,
                              ),
                          const Spacer(),
                          if (t.author != null)
                            Text('— ${t.author}',
                                style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.content});
  final ContactContent content;

  @override
  Widget build(BuildContext context) {
    if (content.channels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in content.channels)
              ActionChip(
                avatar: const Icon(Icons.link, size: 16),
                label: Text(c.label ?? c.value),
                onPressed: () async {
                  final uri = c.launchUri;
                  if (uri != null) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer THIX
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.bundle});
  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          SelectableText(
            bundle.business.thixId,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Site généré par THIX Portfolio Business',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} ${bundle.business.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension Theme
// ─────────────────────────────────────────────────────────────────────────────

class BusinessThemeExt extends ThemeExtension<BusinessThemeExt> {
  const BusinessThemeExt({required this.style, required this.radius});
  final BusinessAnimationStyle style;
  final BorderRadius radius;

  @override
  BusinessThemeExt copyWith({
    BusinessAnimationStyle? style,
    BorderRadius? radius,
  }) =>
      BusinessThemeExt(
        style: style ?? this.style,
        radius: radius ?? this.radius,
      );

  @override
  BusinessThemeExt lerp(BusinessThemeExt? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
