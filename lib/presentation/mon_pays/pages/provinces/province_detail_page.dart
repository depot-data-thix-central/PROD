// lib/presentation/mon_pays/pages/provinces/province_detail_page.dart
//
// ============================================================================
// 🏠 PAGE PRINCIPALE PROVINCE — Production v4.0
// ============================================================================
// Header glass + Bande raccourcis épinglée (pinned) + Sections fluides
// Multilingue (FR/LN/SW/TL/KG) + Accessibilité + Recherche globale
// ============================================================================

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../models/province.dart';
import '../../providers/provinces_provider.dart';

import 'widgets/province_shortcut_bar.dart';
import 'widgets/province_discovery_widgets.dart';
import 'widgets/province_authorities_widgets.dart';
import 'widgets/province_culture_widgets.dart';
import 'widgets/province_quiz_widget.dart';

// ════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════════════════
class ProvinceDetailPage extends ConsumerStatefulWidget {
  final String provinceId;
  const ProvinceDetailPage({required this.provinceId, super.key});

  @override
  ConsumerState<ProvinceDetailPage> createState() => _ProvinceDetailPageState();
}

class _ProvinceDetailPageState extends ConsumerState<ProvinceDetailPage> {
  final ScrollController _scroll = ScrollController();
  bool _showBackToTop = false;

  // Clés pour le scroll vers les sections via la bande raccourcis
  static const List<String> _sectionIds = [
    'actu', 'projets', 'services', 'citoyen', 'budget', 'docs', 'media',
    'carte', 'galerie', 'autorites', 'villes', 'tourisme', 'economie',
    'culture', 'quiz', 'urgences',
  ];

  late final Map<String, GlobalKey> _keys = {
    for (final id in _sectionIds) id: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.offset > 400;
    if (show != _showBackToTop) {
      setState(() => _showBackToTop = show);
    }
  }

  /// Scroll animé vers une section (utilisé par la bande raccourcis).
  void _goToSection(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.08, // laisse un peu d'espace sous la barre épinglée
      );
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _refresh() async {
    refreshAllProvinceProviders(ref, widget.provinceId);
  }

  Future<void> _shareProvince(Province p) async {
    final text = '''
🏛️ ${p.name} — République Démocratique du Congo

📍 Chef-lieu : ${p.capital}
👥 Population : ${p.population != null ? fmtNum(p.population!) : 'N/A'} hab
🗺️ Superficie : ${p.area != null ? '${fmtNum(p.area!)} km²' : 'N/A'}
${p.motto != null && p.motto!.isNotEmpty ? '✨ Devise : ${p.motto}' : ''}

🔗 Découvrez plus sur THIX ID
''';
    await Share.share(text);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final a11y = ref.watch(accessibilityProvider);
    final provinceAsync = ref.watch(provinceWithAllRelationsProvider(widget.provinceId));

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(a11y.textScale),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: Stack(
          children: [
            // ─── FOND DÉGRADÉ + HALOS DÉCORATIFS ───
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF0F4F8),
                      Color(0xFFE8EEF5),
                      Color(0xFFF8FAFC),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -90,
                      right: -90,
                      child: _decorativeHalo(ThixPolicy.primary, 280),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -60,
                      child: _decorativeHalo(ThixPolicy.gold, 200),
                    ),
                  ],
                ),
              ),
            ),

            // ─── CONTENU PRINCIPAL ───
            provinceAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ThixPolicy.primary),
              ),
              error: (e, _) => _buildErrorState(e),
              data: (province) => RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // ─── 1. HEADER GLASS ───
                    _buildHeader(province),

                    // ─── 2. BANDE RACCOURCIS ÉPINGLÉE ───
                    SliverPersistentHeader(
                      pinned: true,
                      floating: false,
                      delegate: _ShortcutBarDelegate(
                        child: ProvinceShortcutBar(onTap: _goToSection),
                      ),
                    ),

                    // ─── 3. HAUT DE PAGE (langue + accessibilité + identité) ───
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildTopActions(),
                          const SizedBox(height: 16),
                          _buildIdentityCard(province),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),

                    // ─── 4. SECTIONS DÉCOUVERTE ───
                    SliverToBoxAdapter(
                      key: _keys['actu'],
                      child: ProvinceNewsSection(
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['projets'],
                      child: ProvinceProjectsSection(
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['services'],
                      child: ProvinceServicesSection(
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['citoyen'],
                      child: ProvinceEngagementSection(
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['budget'],
                      child: Column(
                        children: [
                          ProvinceBudgetSection(
                            provinceId: widget.provinceId,
                            lang: lang,
                          ),
                          ProvinceDemographicsSection(
                            provinceId: widget.provinceId,
                            lang: lang,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['docs'],
                      child: ProvinceDocumentsSection(
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['media'],
                      child: ProvinceMediaSection(
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['carte'],
                      child: ProvinceMapCard(
                        province: province,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['galerie'],
                      child: ProvinceGallerySection(
                        province: province,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['autorites'],
                      child: ProvinceAuthoritiesSection(
                        province: province,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['villes'],
                      child: Column(
                        children: [
                          ProvinceCitiesSection(
                            province: province,
                            lang: lang,
                          ),
                          ProvinceDivisionsSection(
                            province: province,
                            lang: lang,
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['tourisme'],
                      child: ProvinceTourismSection(
                        province: province,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['economie'],
                      child: ProvinceEconomySection(
                        province: province,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['culture'],
                      child: ProvinceCultureSection(
                        province: province,
                        provinceId: widget.provinceId,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['quiz'],
                      child: ProvinceQuizSection(
                        provinceId: widget.provinceId,
                        provinceName: province.name,
                        lang: lang,
                      ),
                    ),
                    SliverToBoxAdapter(
                      key: _keys['urgences'],
                      child: ProvinceEmergencySection(
                        province: province,
                        lang: lang,
                      ),
                    ),
                    // Identité visuelle (pas de raccourci, fin de page)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                        child: ProvinceVisualIdentitySection(province: province),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── BOUTON RETOUR EN HAUT ───
            if (_showBackToTop)
              Positioned(
                right: 20,
                bottom: 30,
                child: _BackToTopButton(
                  onTap: () {
                    _scroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HALO DÉCORATIF (arrières-plans)
  // ════════════════════════════════════════════════════════════════════════
  Widget _decorativeHalo(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.08), Colors.transparent],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: ThixPolicy.danger,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Impossible de charger les données de la province.',
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HEADER (SliverAppBar avec image de couverture)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(Province province) {
    final isFav = ref.watch(favoriteProvincesProvider).contains(province.id);
    final coverUrl = province.coverImageUrl ?? '';
    final hasCover = coverUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _glassIconButton(
          Icons.arrow_back_rounded,
          () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        _glassIconButton(Icons.search_rounded, _openSearch),
        _glassIconButton(Icons.share_rounded, () => _shareProvince(province)),
        _glassIconButton(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          () {
            ref.read(favoriteProvincesProvider.notifier).toggle(province.id);
            HapticFeedback.lightImpact();
          },
          color: isFav ? ThixPolicy.danger : Colors.white,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 18, right: 20),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(
                province.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.h3Style.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black45),
                  ],
                ),
              ),
            ),
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de couverture (ou gradient)
            hasCover
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: ThixPolicy.primary,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.location_city_rounded,
                        size: 120,
                        color: Colors.white24,
                      ),
                    ),
                  ),
            // Overlay dégradé sombre
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            // Badge code province
            Positioned(
              left: 20,
              bottom: 64,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: ThixPolicy.danger.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  province.code,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton glassmorphism pour l'AppBar.
  Widget _glassIconButton(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: Icon(icon, color: color, size: 20),
              onPressed: onTap,
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TOP ACTIONS (langue + accessibilité)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildTopActions() {
    final lang = ref.watch(languageProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Sélecteur de langue
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: _openLanguageSheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 8),
                  Text(
                    lang.name,
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.inkDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: ThixPolicy.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Accessibilité
          GlassCard(
            padding: const EdgeInsets.all(11),
            onTap: _openAccessibilitySheet,
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: ThixPolicy.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // CARTE D'IDENTITÉ
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildIdentityCard(Province p) {
    final hasCoat = (p.coatOfArmsUrl ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // ───  Blason + nom ───
            Row(
              children: [
                GestureDetector(
                  onTap: hasCoat
                      ? () => showGlassSheet(
                            context,
                            title: 'Blason — ${p.name}',
                            imageUrl: p.coatOfArmsUrl,
                            children: const [],
                          )
                      : null,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThixPolicy.primary.withOpacity(0.35),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThixPolicy.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasCoat
                          ? CachedNetworkImage(
                              imageUrl: p.coatOfArmsUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.shield_rounded,
                                color: ThixPolicy.primary,
                              ),
                            )
                          : const Icon(
                              Icons.shield_rounded,
                              color: ThixPolicy.primary,
                              size: 36,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: ThixPolicy.h2Style.copyWith(
                          color: ThixPolicy.inkDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ThixPolicy.danger.withOpacity(0.15),
                                  ThixPolicy.danger.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: ThixPolicy.danger.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              p.code,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: ThixPolicy.danger,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Région ${p.region}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ThixPolicy.captionStyle.copyWith(
                                color: ThixPolicy.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((p.motto ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '« ${p.motto} »',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ───  Stats ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _identityStat(
                  Icons.location_city_rounded,
                  ThixPolicy.primary,
                  'Capitale',
                  p.capital,
                ),
                _identityStat(
                  Icons.groups_rounded,
                  const Color(0xFF43A047),
                  'Population',
                  p.population != null ? fmtNum(p.population!) : 'N/A',
                ),
                _identityStat(
                  Icons.map_rounded,
                  const Color(0xFFFB8C00),
                  'Superficie',
                  p.area != null ? '${fmtNum(p.area!)} km²' : 'N/A',
                ),
                if (p.territoriesCount != null)
                  _identityStat(
                    Icons.format_list_numbered_rounded,
                    const Color(0xFF8E24AA),
                    'Territoires',
                    '${p.territoriesCount}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityStat(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Flexible(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.16), color.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.inkDeep,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SHEETS (langue / accessibilité / recherche)
  // ════════════════════════════════════════════════════════════════════════

  void _openLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThixPolicy.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choisir la langue',
                  style: ThixPolicy.h3Style.copyWith(
                    color: ThixPolicy.inkDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                ...NationalLanguage.values.map((l) {
                  final isCurrent = ref.read(languageProvider) == l;
                  return InkWell(
                    onTap: () {
                      ref.read(languageProvider.notifier).state = l;
                      Navigator.pop(context);
                      HapticFeedback.selectionClick();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? ThixPolicy.primary.withOpacity(0.1)
                            : ThixPolicy.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent ? ThixPolicy.primary : ThixPolicy.border,
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(l.flag, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.name,
                                  style: ThixPolicy.labelStyle.copyWith(
                                    color: ThixPolicy.inkDeep,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  l.code.toUpperCase(),
                                  style: ThixPolicy.captionStyle.copyWith(
                                    color: ThixPolicy.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: ThixPolicy.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAccessibilitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(accessibilityProvider);
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.98),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ThixPolicy.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.accessibility_new_rounded,
                          color: ThixPolicy.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Accessibilité',
                          style: ThixPolicy.h3Style.copyWith(
                            color: ThixPolicy.inkDeep,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Taille du texte
                    Text(
                      'Taille du texte',
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: TextStyle(
                            fontSize: 12,
                            color: ThixPolicy.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: s.textScale,
                            min: 0.8,
                            max: 1.5,
                            divisions: 7,
                            activeColor: ThixPolicy.primary,
                            inactiveColor: ThixPolicy.primary.withOpacity(0.2),
                            onChanged: (v) {
                              ref.read(accessibilityProvider.notifier).state =
                                  s.copyWith(textScale: v);
                            },
                          ),
                        ),
                        Text(
                          'A',
                          style: TextStyle(
                            fontSize: 22,
                            color: ThixPolicy.textSecondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Contraste élevé
                    SwitchListTile(
                      title: Text(
                        'Contraste élevé',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: ThixPolicy.inkDeep,
                        ),
                      ),
                      subtitle: Text(
                        'Améliore la lisibilité',
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                      value: s.highContrast,
                      activeColor: ThixPolicy.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        ref.read(accessibilityProvider.notifier).state =
                            s.copyWith(highContrast: v);
                      },
                    ),
                    // Mode audio
                    SwitchListTile(
                      title: Text(
                        'Mode audio',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: ThixPolicy.inkDeep,
                        ),
                      ),
                      subtitle: Text(
                        'Lecture vocale du contenu',
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                      value: s.audioMode,
                      activeColor: ThixPolicy.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        ref.read(accessibilityProvider.notifier).state =
                            s.copyWith(audioMode: v);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSearch() {
    showGlassSheet(
      context,
      title: 'Rechercher dans la province',
      icon: Icons.search_rounded,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final notifier =
                ref.read(provinceSearchDebouncedProvider(widget.provinceId).notifier);
            final results =
                ref.watch(provinceSearchDebouncedProvider(widget.provinceId));
            return Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: notifier.search,
                  decoration: InputDecoration(
                    hintText: 'Ville, projet, actualité, service…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: ThixPolicy.primary,
                    ),
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Commencez à taper pour rechercher',
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.textMuted,
                      ),
                    ),
                  )
                else
                  ...results.map((r) {
                    final source = r['_source']?.toString() ?? '';
                    final label = (r['name'] ?? r['title'] ?? '').toString();
                    final target = {
                      'news': 'actu',
                      'project': 'projets',
                      'service': 'services',
                      'city': 'villes',
                    }[source] ?? 'actu';
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _goToSection(target);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ThixPolicy.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                source,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: ThixPolicy.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ThixPolicy.captionStyle.copyWith(
                                  color: ThixPolicy.inkDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: ThixPolicy.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DELEGATE : BANDE RACCOURCIS ÉPINGLÉE
// ════════════════════════════════════════════════════════════════════════
class _ShortcutBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _ShortcutBarDelegate({required this.child});

  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _ShortcutBarDelegate oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════════════
// BOUTON RETOUR EN HAUT
// ════════════════════════════════════════════════════════════════════════
class _BackToTopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToTopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: ThixPolicy.primary.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ThixPolicy.primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
