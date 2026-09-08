/// THIX RETROUVE — Enterprise Glass Design (Production)
/// ✅ Glassmorphism subtil : surfaces blanches translucides, palette réduite
/// ✅ Actions compactes icône + libellé (plus de grandes cartes)
/// ✅ Objets en grille carrée 2 colonnes (photo-first, lisibilité maximale)
/// ✅ i18n + sanitization + Semantics + HapticFeedback + logs
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:async';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/nav.dart';

import 'models/objet_model.dart';
import 'providers/objet_providers.dart';

// ============================================================================
// DESIGN TOKENS (Glass Enterprise)
// ============================================================================

const double _kGlassSurface = 0.05;   // opacité surface
const double _kGlassSurfaceHi = 0.08; // opacité haut du dégradé
const double _kGlassBorder = 0.09;    // opacité bordure
const double _kRadiusLg = 20.0;
const double _kRadiusMd = 16.0;
const double _kRadiusSm = 12.0;

const int _kMaxVisibleObjects = 8;
const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);

// ============================================================================
// SANITIZER
// ============================================================================

class _RetrouveSanitizer {
  _RetrouveSanitizer._();

  static String sanitizeText(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static String? sanitizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url.trim();
  }
}

// ============================================================================
// GLASS CARD (surface réutilisable, sans blur coûteux)
// ============================================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = _kRadiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: _kGlassSurfaceHi),
            Colors.white.withValues(alpha: _kGlassSurface),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: _kGlassBorder),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ============================================================================
// SCREEN
// ============================================================================

class ThixRetrouveScreen extends ConsumerStatefulWidget {
  const ThixRetrouveScreen({super.key});

  @override
  ConsumerState<ThixRetrouveScreen> createState() => _ThixRetrouveScreenState();
}

class _ThixRetrouveScreenState extends ConsumerState<ThixRetrouveScreen> {
  DateTime? _lastTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objetsAsync = ref.watch(objetsRecentsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          _buildBackgroundGlow(),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(l10n),

                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      debugPrint('[Retrouve] 🔄 Refresh');
                      ref.invalidate(objetsRecentsProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHero(l10n),
                          const SizedBox(height: 20),
                          _buildActionRow(context, l10n),
                          const SizedBox(height: 10),
                          _buildMapShortcut(context, l10n),
                          const SizedBox(height: 28),
                          _buildSectionHeader(context, l10n),
                          const SizedBox(height: 12),
                          _buildObjetsGrid(context, l10n, objetsAsync),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom nav flottante (seul élément avec vrai blur)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _buildBottomNav(context, l10n),
          ),
        ],
      ),
    );
  }

  // ── Fond : halo unique très discret ─────────────────────────
  Widget _buildBackgroundGlow() {
    return Positioned(
      top: -120,
      right: -100,
      child: IgnorePointer(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ThixPolicy.primary.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header minimal ──────────────────────────────────────────
  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.t('common_menu'),
            child: IconButton(
              icon: Icon(Icons.menu_rounded,
                  color: ThixPolicy.textMuted, size: 22),
              onPressed: () {},
            ),
          ),
          Expanded(
            child: Text(
              'THIX CENTRAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThixPolicy.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('common_notifications'),
            child: IconButton(
              icon: Icon(Icons.notifications_none_rounded,
                  color: ThixPolicy.textMuted, size: 22),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero compact ────────────────────────────────────────────
  Widget _buildHero(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'THIX ',
                style: TextStyle(
                  color: ThixPolicy.textMain,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: l10n.t('retrouve_brand_suffix'),
                style: TextStyle(
                  color: ThixPolicy.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('retrouve_tagline'),
          style: TextStyle(color: ThixPolicy.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  // ── Actions Perdu / Trouvé — COMPACTES, icône + libellé court ──
  Widget _buildActionRow(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactAction(
            tint: ThixPolicy.domainOpportunity,
            icon: Icons.search_off_rounded,
            label: l10n.t('retrouve_lost_title'),
            onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactAction(
            tint: ThixPolicy.success,
            icon: Icons.inventory_2_rounded,
            label: l10n.t('retrouve_found_title'),
            onTap: () => _navigateToDeclare(context, StatutObjet.trouve),
          ),
        ),
      ],
    );
  }

  // Action compacte : icône dans un badge + libellé sur une ligne.
  // Ne prend qu'une hauteur réduite — plus de sous-titre, plus de grande carte.
  Widget _buildCompactAction({
    required Color tint,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kRadiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: _kGlassSurfaceHi),
                  Colors.white.withValues(alpha: _kGlassSurface),
                ],
              ),
              borderRadius: BorderRadius.circular(_kRadiusSm),
              border: Border.all(
                color: Colors.white.withValues(alpha: _kGlassBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: tint, size: 16),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Raccourci carte — compact, icône seule + texte court ─────
  Widget _buildMapShortcut(BuildContext context, AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('retrouve_map_title'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _throttledTap(
            () => context.pushNamed('thixRetrouveCarte'),
          ),
          borderRadius: BorderRadius.circular(_kRadiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: _kGlassSurfaceHi),
                  Colors.white.withValues(alpha: _kGlassSurface),
                ],
              ),
              borderRadius: BorderRadius.circular(_kRadiusSm),
              border: Border.all(
                color: Colors.white.withValues(alpha: _kGlassBorder),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.map_outlined,
                      color: ThixPolicy.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('retrouve_map_title'),
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: ThixPolicy.textMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header de section ───────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.t('retrouve_recent_objects'),
          style: TextStyle(
            color: ThixPolicy.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('common_see_all'),
          child: GestureDetector(
            onTap: () => _throttledTap(
              () => context.pushNamed('thixRetrouveMesRecherches'),
            ),
            child: Text(
              l10n.t('common_see_all'),
              style: TextStyle(
                color: ThixPolicy.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Grille objets — 2 colonnes, cartes carrées, photo-first ──
  Widget _buildObjetsGrid(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<ObjetModel>> objetsAsync,
  ) {
    return objetsAsync.when(
      data: (objets) {
        if (objets.isEmpty) return _buildEmptyState(l10n);
        final visible = objets.take(_kMaxVisibleObjects).toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, i) =>
              _buildObjectCard(context, l10n, visible[i]),
        );
      },
      loading: () => const _SkeletonGrid(),
      error: (err, stack) => _buildErrorState(l10n, err),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return _GlassCard(
      radius: _kRadiusLg,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 40, color: ThixPolicy.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              l10n.t('retrouve_empty_title'),
              style: TextStyle(color: ThixPolicy.textMain, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('retrouve_empty_subtitle'),
              style: TextStyle(color: ThixPolicy.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, Object err) {
    debugPrint('[Retrouve] ❌ Error: $err');
    return _GlassCard(
      radius: _kRadiusLg,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 32, color: ThixPolicy.textMuted),
            const SizedBox(height: 10),
            Text(
              l10n.t('retrouve_load_error'),
              style: TextStyle(color: ThixPolicy.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(objetsRecentsProvider),
              child: Text(
                l10n.t('common_retry'),
                style: TextStyle(
                  color: ThixPolicy.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CARTE OBJET CARRÉE — photo en haut (60%), infos compactes en bas ──
  Widget _buildObjectCard(
    BuildContext context,
    AppLocalizations l10n,
    ObjetModel obj,
  ) {
    final isLost = obj.statut == StatutObjet.perdu;
    final statusColor =
        isLost ? ThixPolicy.domainOpportunity : ThixPolicy.success;
    final i18n = I18nService.of(context);

    final safeTitle =
        _RetrouveSanitizer.sanitizeText(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation = _RetrouveSanitizer.sanitizeText(obj.lieu,
        maxLength: _kMaxLocationLength);
    final safeImageUrl = _RetrouveSanitizer.sanitizeImageUrl(obj.imageUrl);

    return Semantics(
      button: true,
      label: '$safeTitle. ${obj.statutLabel}. $safeLocation',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _throttledTap(() {
            HapticFeedback.selectionClick();
            context.pushNamed(
              'thixRetrouveDetail',
              extra: {
                'title': safeTitle,
                'status': obj.statutLabel,
                'location': safeLocation,
                'time': i18n.relativeTime(obj.date),
                'description': _RetrouveSanitizer.sanitizeText(
                    obj.description,
                    maxLength: 500),
                'imageUrl': safeImageUrl,
              },
            );
          }),
          borderRadius: BorderRadius.circular(_kRadiusMd),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: _kGlassSurfaceHi),
                  Colors.white.withValues(alpha: _kGlassSurface),
                ],
              ),
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: _kGlassBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Zone photo (occupe la majorité du carré) ──
                Expanded(
                  flex: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThumbnail(safeImageUrl),
                      // Pastille statut en overlay coin haut-gauche
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _statusPill(statusColor, obj.statutLabel),
                      ),
                      if (obj.hasRecompense)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: ThixPolicy.inkDeep.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: Semantics(
                              label: l10n.t('retrouve_has_reward'),
                              child: Icon(Icons.workspace_premium_rounded,
                                  color: ThixPolicy.warning, size: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Zone infos compactes ──
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          safeTitle,
                          style: TextStyle(
                            color: ThixPolicy.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (safeLocation.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 11, color: ThixPolicy.textMuted),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  safeLocation,
                                  style: TextStyle(
                                    color: ThixPolicy.textMuted,
                                    fontSize: 10.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        Text(
                          i18n.relativeTime(obj.date),
                          style: TextStyle(
                            color: ThixPolicy.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildThumbnail(String? imageUrl) {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: ThixPolicy.textMuted,
                  size: 28,
                ),
              ),
            )
          : Center(
              child: Icon(Icons.inventory_2_rounded,
                  color: ThixPolicy.textMuted, size: 28),
            ),
    );
  }

  Widget _statusPill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav glass (blur) ─────────────────────────────────
  Widget _buildBottomNav(BuildContext context, AppLocalizations l10n) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, l10n.t('nav_home'), false,
                    onTap: () {}),
                _navItem(Icons.manage_search_rounded,
                    l10n.t('nav_searches'), true,
                    onTap: () => _throttledTap(() => context
                        .pushNamed('thixRetrouveMesRecherches'))),
                // Bouton central
                Semantics(
                  button: true,
                  label: l10n.t('retrouve_add_action'),
                  child: GestureDetector(
                    onTap: () => _showAddModal(context, l10n),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ThixPolicy.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                _navItem(Icons.chat_bubble_outline_rounded,
                    l10n.t('nav_messages'), false,
                    onTap: () =>
                        _throttledTap(() => context.pushNamed(AppRoutes.chat))),
                _navItem(Icons.person_outline_rounded,
                    l10n.t('nav_profile'), false,
                    onTap: () => _throttledTap(
                        () => context.pushNamed(AppRoutes.profile))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected,
      {required VoidCallback onTap}) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected
                      ? ThixPolicy.textMain
                      : ThixPolicy.textMuted,
                  size: 20),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? ThixPolicy.textMain
                      : ThixPolicy.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal d'ajout ───────────────────────────────────────────
  void _showAddModal(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: ThixPolicy.inkDeep.withValues(alpha: 0.7),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.t('retrouve_add_modal_title'),
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _modalAction(
                    sheetCtx,
                    tint: ThixPolicy.domainOpportunity,
                    icon: Icons.search_off_rounded,
                    label: l10n.t('retrouve_modal_lost'),
                    onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
                  ),
                  const SizedBox(height: 10),
                  _modalAction(
                    sheetCtx,
                    tint: ThixPolicy.success,
                    icon: Icons.inventory_2_rounded,
                    label: l10n.t('retrouve_modal_found'),
                    onTap: () => _navigateToDeclare(context, StatutObjet.trouve),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modalAction(
    BuildContext sheetCtx, {
    required Color tint,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(sheetCtx);
            onTap();
          },
          borderRadius: BorderRadius.circular(_kRadiusMd),
          child: _GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: tint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: ThixPolicy.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers logique ─────────────────────────────────────────
  Future<void> _navigateToDeclare(BuildContext context, StatutObjet type) async {
    _throttledTap(() async {
      HapticFeedback.lightImpact();
      if (!context.mounted) return;
      final routeName = type == StatutObjet.perdu
          ? 'thixRetrouveDeclarerPerdu'
          : 'thixRetrouveDeclarerTrouve';
      final result = await context.pushNamed<bool>(routeName);
      if (result == true && mounted) {
        ref.invalidate(objetsRecentsProvider);
      }
    });
  }

  void _throttledTap(FutureOr<void> Function() callback) {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) return;
    _lastTap = now;
    callback();
  }
}

// ============================================================================
// SKELETON — grille 2 colonnes, cohérente avec le layout final
// ============================================================================

class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: 0.4 + 0.3 * _ctrl.value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
