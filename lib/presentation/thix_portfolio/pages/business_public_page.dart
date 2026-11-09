// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE INSTITUTIONNELLE
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 3.1.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ NOUVEAUTÉS v3.1 :
//    • Section "Nos Réalisations" (Projets terminés avec photos/vidéos)
//    • Section "Projets en Cours" (Avec barre de progression et %)
//    • Section "Nos Partenaires" (Logos/Noms défilants)
//    • Bilingue FR/EN intégré
//    • Hero Banner interactif (Cover + Galerie)
//    • Toutes les rubriques défilent horizontalement
//    • 100 % compatible avec le Theme Studio
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui';

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
import '../widgets/reveal_on_scroll.dart';

const String kThixPublicBaseUrl = 'https://thixid.com';

// ─────────────────────────────────────────────────────────────────────────────
// MODÈLES TEMPORAIRES POUR LES NOUVELLES SECTIONS (À LIER À SUPABASE PLUS TARD)
// ─────────────────────────────────────────────────────────────────────────────
class MockProject {
  final String title;
  final String imageUrl;
  final double progress; // 0.0 à 1.0
  final String status;

  MockProject({required this.title, required this.imageUrl, required this.progress, required this.status});
}

class MockPartner {
  final String name;
  final String? logoUrl;

  MockPartner({required this.name, this.logoUrl});
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADUCTIONS FR / EN INTÉGRÉES
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  final bool isFr;
  _T(this.isFr);

  String get contact => isFr ? 'Contacter' : 'Contact Us';
  String get about => isFr ? 'À propos' : 'About Us';
  String get services => isFr ? 'Nos Services' : 'Our Services';
  String get products => isFr ? 'Nos Produits' : 'Our Products';
  String get gallery => isFr ? 'Galerie & Réalisations' : 'Gallery & Portfolio';
  String get team => isFr ? 'Notre Équipe' : 'Our Team';
  String get testimonials => isFr ? 'Témoignages' : 'Testimonials';
  String get news => isFr ? 'Actualités & Blog' : 'News & Blog';
  String get partners => isFr ? 'Nos Partenaires' : 'Our Partners';
  String get faq => isFr ? 'Questions Fréquentes' : 'FAQ';
  String get stats => isFr ? 'Chiffres Clés' : 'Key Figures';
  String get achievements => isFr ? 'Nos Réalisations' : 'Our Achievements';
  String get ongoingProjects => isFr ? 'Projets en Cours' : 'Ongoing Projects';
  String get completed => isFr ? 'Terminé' : 'Completed';
  String get yearsExp => isFr ? "ans d'expérience" : 'years of experience';
  String get employees => isFr ? 'collaborateurs' : 'employees';
  String get views => isFr ? 'visites' : 'views';
  String get verified => isFr ? 'ENTREPRISE VÉRIFIÉE' : 'VERIFIED BUSINESS';
  String get readMore => isFr ? 'Lire plus' : 'Read more';
  String get noContact => isFr ? 'Aucun canal de contact.' : 'No contact channel.';
  String get share => isFr ? 'Partager' : 'Share';
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE RACINE
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
// SQUELETTE / ERREUR
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
                background: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 120, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white))),
                  const SizedBox(height: 16),
                  const SizedBox(height: 200, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white))),
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
  const _PublicNotFound({required this.thixId, this.invalid = false, this.onRetry});

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
              Icon(Icons.storefront_outlined, size: 84, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(invalid ? 'Identifiant invalide' : 'Entreprise introuvable',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (onRetry != null)
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SITE INSTITUTIONNEL
// ─────────────────────────────────────────────────────────────────────────────

class _BusinessSite extends StatefulWidget {
  const _BusinessSite({required this.bundle});
  final BusinessBundle bundle;

  @override
  State<_BusinessSite> createState() => _BusinessSiteState();
}

class _BusinessSiteState extends State<_BusinessSite> {
  bool _isFr = true;
  late _T _t;

  // Hero Carousel
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  List<String> _heroImages = [];

  @override
  void initState() {
    super.initState();
    _t = _T(_isFr);
    _setupHeroImages();
    _startAutoPlay();
  }

  void _setupHeroImages() {
    final b = widget.bundle.business;
    final gallery = widget.bundle.sectionOfType(BusinessSectionType.gallery)?.content as GalleryContent?;
    _heroImages = [
      if (b.coverUrl != null && b.coverUrl!.isNotEmpty) b.coverUrl!,
      if (gallery != null) ...gallery.images.map((e) => e.url),
      if (b.logoUrl != null && b.logoUrl!.isNotEmpty) b.logoUrl!,
    ];
    if (_heroImages.isEmpty) _heroImages.add(''); 
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && _heroImages.length > 1) {
        _currentPage = (_currentPage + 1) % _heroImages.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleLang() {
    setState(() {
      _isFr = !_isFr;
      _t = _T(_isFr);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final sections = widget.bundle.visibleSections;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          // 1. HERO BANNER DÉFILANT
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            actions: [
              TextButton.icon(
                onPressed: _toggleLang,
                icon: const Icon(Icons.language, color: Colors.white, size: 18),
                label: Text(_isFr ? 'EN' : 'FR', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              IconButton(tooltip: _t.share, icon: const Icon(Icons.share), onPressed: () => _share(context)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
              title: Text(widget.bundle.business.name, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              background: _HeroBanner(
                images: _heroImages,
                controller: _pageController,
                currentPage: _currentPage,
                bundle: widget.bundle,
                t: _t,
              ),
            ),
          ),

          // 2. CARTE IDENTITÉ
          SliverToBoxAdapter(child: _IdentityCard(bundle: widget.bundle)),

          // 3. STATS
          SliverToBoxAdapter(child: _StatsSection(bundle: widget.bundle, t: _t)),

          // 4. SECTIONS DYNAMIQUES (À PROPOS, SERVICES, PRODUITS, etc.)
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final section = sections[i];
                  return RevealOnScroll(
                    style: theme.animationStyle,
                    staggerIndex: i,
                    child: _SectionRenderer(section: section, t: _t),
                  );
                },
                childCount: sections.length,
              ),
            ),
          ),

          // 5. NOS RÉALISATIONS (MOCK DATA POUR L'INSTANT)
          SliverToBoxAdapter(
            child: _AchievementsSection(
              title: _t.achievements,
              items: [
                MockProject(title: 'Site web SONATHIX', imageUrl: 'https://picsum.photos/400/300?random=1', progress: 1.0, status: 'Terminé'),
                MockProject(title: 'App Mobile THIX', imageUrl: 'https://picsum.photos/400/300?random=2', progress: 1.0, status: 'Terminé'),
                MockProject(title: 'Data Center Kinshasa', imageUrl: 'https://picsum.photos/400/300?random=3', progress: 1.0, status: 'Terminé'),
              ],
              t: _t,
            ),
          ),

          // 6. PROJETS EN COURS (MOCK DATA POUR L'INSTANT)
          SliverToBoxAdapter(
            child: _OngoingProjectsSection(
              title: _t.ongoingProjects,
              items: [
                MockProject(title: 'Déploiement THIX Market', imageUrl: 'https://picsum.photos/400/300?random=4', progress: 0.75, status: 'En cours'),
                MockProject(title: 'Réseau Fibre Optique RDC', imageUrl: 'https://picsum.photos/400/300?random=5', progress: 0.40, status: 'En cours'),
                MockProject(title: 'Portail Gouvernemental', imageUrl: 'https://picsum.photos/400/300?random=6', progress: 0.90, status: 'En cours'),
              ],
              t: _t,
            ),
          ),

          // 7. NOS PARTENAIRES (MOCK DATA POUR L'INSTANT)
          SliverToBoxAdapter(
            child: _PartnersSection(
              title: _t.partners,
              items: [
                MockPartner(name: 'SONATHIX'),
                MockPartner(name: 'THIX HUB'),
                MockPartner(name: 'RDC DIGITAL'),
                MockPartner(name: 'AFRICA TECH'),
                MockPartner(name: 'KINSHASA CO'),
              ],
            ),
          ),

          // 8. FAQ
          SliverToBoxAdapter(child: _FaqSection(t: _t)),

          // 9. CTA & FOOTER
          SliverToBoxAdapter(child: _CtaSection(bundle: widget.bundle, t: _t)),
          SliverToBoxAdapter(child: _Footer(bundle: widget.bundle)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openContactSheet(context),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(_t.contact),
      ),
    );
  }

  void _share(BuildContext context) {
    final url = '$kThixPublicBaseUrl/b/${widget.bundle.business.thixId}';
    Share.share('Découvrez ${widget.bundle.business.name} sur THIX 🚀\n$url');
  }

  void _openContactSheet(BuildContext context) {
    final section = widget.bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent ? (section!.content as ContactContent).channels : const <ContactChannel>[];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: channels.isEmpty
              ? Text(_t.noContact)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${_t.contact} ${widget.bundle.business.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    for (final c in channels)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                          title: Text(c.label ?? c.type.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(c.value),
                          trailing: const Icon(Icons.open_in_new, size: 16),
                          onTap: () async {
                            final uri = c.launchUri;
                            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
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
// COMPOSANTS UI : HERO, IDENTITÉ, STATS
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentPage;
  final BusinessBundle bundle;
  final _T t;

  const _HeroBanner({required this.images, required this.controller, required this.currentPage, required this.bundle, required this.t});

  @override
  Widget build(BuildContext context) {
    final b = bundle.business;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: images.length,
          itemBuilder: (context, index) {
            final url = images[index];
            if (url.isEmpty) return Container(color: Theme.of(context).colorScheme.primary);
            return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
              stops: [0.3, 1.0],
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentPage == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 20,
          bottom: 70,
          child: b.verified
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(t.verified, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final BusinessBundle bundle;
  const _IdentityCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: theme.radius,
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: b.logoUrl != null ? NetworkImage(b.logoUrl!) : null,
                child: b.logoUrl == null ? Text(b.name[0].toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text([b.sector, b.city].whereType<String>().join(' • '), style: TextStyle(color: scheme.onSurfaceVariant)),
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

class _StatsSection extends StatelessWidget {
  final BusinessBundle bundle;
  final _T t;
  const _StatsSection({required this.bundle, required this.t});

  @override
  Widget build(BuildContext context) {
    final b = bundle.business;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (b.ageYears != null && b.ageYears! > 0) _statItem('${b.ageYears}+', t.yearsExp, scheme),
          if (b.employees != null && b.employees! > 0) _statItem('${b.employees}+', t.employees, scheme),
          _statItem('${bundle.stats?.views ?? 0}', t.views, scheme),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, ColorScheme scheme) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.primary)),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOUVELLES SECTIONS : RÉALISATIONS, PROJETS EN COURS, PARTENAIRES
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final String title;
  final List<MockProject> items;
  final _T t;

  const _AchievementsSection({required this.title, required this.items, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (ctx, i) {
              final project = items[i];
              return Container(
                width: 280,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: theme.extension<BusinessThemeExt>()?.radius ?? BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Stack(
                  children: [
                    CachedNetworkImage(imageUrl: project.imageUrl, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                              child: Text(t.completed, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
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

class _OngoingProjectsSection extends StatelessWidget {
  final String title;
  final List<MockProject> items;
  final _T t;

  const _OngoingProjectsSection({required this.title, required this.items, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (ctx, i) {
              final project = items[i];
              return Container(
                width: 280,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: theme.extension<BusinessThemeExt>()?.radius ?? BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    CachedNetworkImage(imageUrl: project.imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Progression', style: theme.textTheme.bodySmall),
                              Text('${(project.progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: project.progress,
                              minHeight: 8,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
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

class _PartnersSection extends StatelessWidget {
  final String title;
  final List<MockPartner> items;

  const _PartnersSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final partner = items[i];
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: Center(
                    child: partner.logoUrl != null
                        ? ClipOval(child: CachedNetworkImage(imageUrl: partner.logoUrl!, width: 80, height: 80, fit: BoxFit.cover))
                        : Text(partner.name.substring(0, 2), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: theme.colorScheme.primary)),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTIONS DYNAMIQUES DE LA BDD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionRenderer extends StatelessWidget {
  final BusinessSection section;
  final _T t;
  const _SectionRenderer({required this.section, required this.t});

  @override
  Widget build(BuildContext context) {
    final content = section.content;
    switch (section.type) {
      case BusinessSectionType.about:
        return _AboutSection(content: content as AboutContent);
      case BusinessSectionType.services:
        return _HorizontalListSection<ServiceItem>(
          title: (content as ServicesContent).title,
          items: content.items,
          height: 200,
          itemBuilder: (ctx, item) => _ServiceCard(item: item),
        );
      case BusinessSectionType.products:
        return _HorizontalListSection<ProductItem>(
          title: (content as ProductsContent).title,
          items: content.items,
          height: 240,
          itemBuilder: (ctx, item) => _ProductCard(item: item),
        );
      case BusinessSectionType.gallery:
        return _HorizontalListSection<GalleryImage>(
          title: (content as GalleryContent).title,
          items: content.images,
          height: 200,
          itemBuilder: (ctx, item) => _GalleryCard(item: item),
        );
      case BusinessSectionType.team:
        return _HorizontalListSection<TeamMember>(
          title: (content as TeamContent).title,
          items: content.members,
          height: 160,
          itemBuilder: (ctx, item) => _TeamCard(member: item),
        );
      case BusinessSectionType.contact:
        return _ContactSection(content: content as ContactContent, t: t);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _HorizontalListSection<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final double height;
  final Widget Function(BuildContext, T) itemBuilder;

  const _HorizontalListSection({required this.title, required this.items, required this.height, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (ctx, i) => itemBuilder(ctx, items[i]),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final AboutContent content;
  const _AboutSection({required this.content});

  @override
  Widget build(BuildContext context) {
    if (content.body.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final hasImage = content.imageUrl != null && content.imageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          if (hasImage) ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: content.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)),
          if (hasImage) const SizedBox(height: 16),
          Text(content.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceItem item;
  const _ServiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (item.imageUrl != null) CachedNetworkImage(imageUrl: item.imageUrl!, height: 100, width: double.infinity, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductItem item;
  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 180,
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (item.imageUrl != null) CachedNetworkImage(imageUrl: item.imageUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryImage item;
  const _GalleryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(imageUrl: item.url, fit: BoxFit.cover, width: 300),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final TeamMember member;
  const _TeamCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          CircleAvatar(radius: 40, backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null, child: member.photoUrl == null ? const Icon(Icons.person) : null),
          const SizedBox(height: 8),
          Text(member.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final ContactContent content;
  final _T t;
  const _ContactSection({required this.content, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          for (final c in content.channels)
            ListTile(
              leading: Icon(Icons.contact_phone, color: theme.colorScheme.primary),
              title: Text(c.label ?? c.type.name),
              subtitle: Text(c.value),
              onTap: () async {
                if (c.launchUri != null) await launchUrl(c.launchUri!);
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ, CTA ET FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  final _T t;
  const _FaqSection({required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.faq, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ExpansionTile(
            title: Text(t.isFr ? 'Comment nous contacter ?' : 'How to contact us?', style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [Padding(padding: const EdgeInsets.all(16), child: Text(t.isFr ? 'Utilisez les canaux ci-dessus.' : 'Use the channels above.'))],
          ),
        ],
      ),
    );
  }
}

class _CtaSection extends StatelessWidget {
  final BusinessBundle bundle;
  final _T t;
  const _CtaSection({required this.bundle, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.primary, theme.primary.withValues(alpha: 0.8)]), borderRadius: theme.radius),
      child: Column(
        children: [
          Text(t.isFr ? 'Prêt à collaborer ?' : 'Ready to collaborate?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: theme.primary), onPressed: () {}, child: Text(t.contact)),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final BusinessBundle bundle;
  const _Footer({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(bundle.theme.primary, Colors.black, 0.7)!;
    return Container(
      width: double.infinity,
      color: dark,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(bundle.business.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(bundle.business.thixId, style: TextStyle(color: bundle.theme.accent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Propulsé par THIX HUB', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSION THEME STUDIO
// ─────────────────────────────────────────────────────────────────────────────
class BusinessThemeExt extends ThemeExtension<BusinessThemeExt> {
  const BusinessThemeExt({required this.style, required this.radius});
  final BusinessAnimationStyle style;
  final BorderRadius radius;

  @override
  BusinessThemeExt copyWith({BusinessAnimationStyle? style, BorderRadius? radius}) =>
      BusinessThemeExt(style: style ?? this.style, radius: radius ?? this.radius);

  @override
  BusinessThemeExt lerp(BusinessThemeExt? other, double t) => t < 0.5 ? this : (other ?? this);
}
