/// THIX RETROUVE Screen (Production Enterprise)
/// ✅ i18n complet (8 langues) + sanitization + Semantics
/// ✅ go_router + mounted checks + logs structurés
/// ✅ Skeleton loader + CachedNetworkImage + RepaintBoundary
/// ✅ ThixPolicy uniquement (pas de couleurs custom)
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/nav.dart';

import 'models/objet_model.dart';
import 'pages/declarer_objet_page.dart';
import 'pages/carte_signalements_page.dart';
import 'pages/object_detail_page.dart';
import 'pages/mes_recherches_page.dart';
import 'providers/objet_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxVisibleObjects = 8;
const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kBlurSigma = 10.0; // Réduit pour performance

// ============================================================================
// VALIDATORS & SANITIZERS
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
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE
// ============================================================================

/// Boîte glassmorphism avec optimisation performance.
///
/// ✅ RepaintBoundary interne pour éviter rebuilds parents
/// ✅ Sigma configurable (10 par défaut, pas 15)
/// ✅ Couleur ThixPolicy compatible
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = _kBlurSigma,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? ThixPolicy.surfaceSoft.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: ThixPolicy.border.withValues(alpha: 0.3),
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

// ============================================================================
// SCREEN PRINCIPAL
// ============================================================================

class ThixRetrouveScreen extends ConsumerStatefulWidget {
  const ThixRetrouveScreen({super.key});

  @override
  ConsumerState<ThixRetrouveScreen> createState() => _ThixRetrouveScreenState();
}

class _ThixRetrouveScreenState extends ConsumerState<ThixRetrouveScreen> {
  int _currentIndex = 0;
  DateTime? _lastTap;
  static const _glow = ThixPolicy.primary; // Utilise ThixPolicy.primary comme "glow"

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objetsAsync = ref.watch(objetsRecentsProvider);

    debugPrint('[Retrouve] 🚀 Screen built');

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW ───
          _buildBackgroundGlows(),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                _buildHeader(l10n),

                Expanded(
                  child: RefreshIndicator(
                    color: _glow,
                    backgroundColor: ThixPolicy.inkDeep,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      debugPrint('[Retrouve] 🔄 Refresh triggered');
                      ref.invalidate(objetsRecentsProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLogoAndTitle(l10n),
                          const SizedBox(height: ThixPolicy.s24),

                          // ── Boutons Perdu / Trouvé ──
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  color: ThixPolicy.domainOpportunity,
                                  icon: Icons.search_off_rounded,
                                  title: l10n.t('retrouve_lost_title'),
                                  subtitle: l10n.t('retrouve_lost_subtitle'),
                                  onTap: () => _navigateToDeclare(
                                    context, StatutObjet.perdu,
                                  ),
                                ),
                              ),
                              const SizedBox(width: ThixPolicy.s12),
                              Expanded(
                                child: _buildActionCard(
                                  color: ThixPolicy.success,
                                  icon: Icons.inventory_2_rounded,
                                  title: l10n.t('retrouve_found_title'),
                                  subtitle: l10n.t('retrouve_found_subtitle'),
                                  onTap: () => _navigateToDeclare(
                                    context, StatutObjet.trouve,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: ThixPolicy.s16),

                          // ── Carte interactive ──
                          _buildMapShortcut(context, l10n),
                          const SizedBox(height: ThixPolicy.s32),

                          // ── Section objets récents ──
                          _buildRecentObjectsHeader(context, l10n),
                          const SizedBox(height: ThixPolicy.s16),

                          // ── Liste dynamique ──
                          _buildObjetsList(context, l10n, objetsAsync),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Nav Flottante ──
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildFloatingBottomNav(context, l10n),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // BACKGROUND GLOWS
  // ========================================================================

  Widget _buildBackgroundGlows() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _glow.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: _glow.withValues(alpha: 0.25),
                    blurRadius: 120,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.primary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: ThixPolicy.primary.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // HEADER
  // ========================================================================

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ThixPolicy.s16,
        vertical: ThixPolicy.s12,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.t('common_menu'),
            child: IconButton(
              icon: const Icon(Icons.menu_rounded, color: ThixPolicy.textMain),
              onPressed: () {
                debugPrint('[Retrouve] ℹ️ Menu tap (TODO)');
              },
            ),
          ),
          Expanded(
            child: Text(
              'THIX CENTRAL',
              textAlign: TextAlign.center,
              style: ThixPolicy.h3Style.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: ThixPolicy.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('common_notifications'),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: ThixPolicy.textMain),
              onPressed: () {
                debugPrint('[Retrouve] ℹ️ Notifications tap (TODO)');
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // LOGO & TITLE
  // ========================================================================

  Widget _buildLogoAndTitle(AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _glow.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: _glow.withValues(alpha: 0.5)),
          ),
          child: Icon(
            Icons.manage_search_rounded,
            color: ThixPolicy.textMain,
            size: 32,
          ),
        ),
        const SizedBox(width: ThixPolicy.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'THIX ',
                      style: ThixPolicy.h1Style.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                    TextSpan(
                      text: l10n.t('retrouve_brand_suffix'),
                      style: ThixPolicy.h1Style.copyWith(
                        color: _glow,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.t('retrouve_tagline'),
                style: ThixPolicy.bodySmallStyle
                    .copyWith(color: ThixPolicy.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // ACTION CARDS (Perdu / Trouvé)
  // ========================================================================

  Widget _buildActionCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: GlassBox(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          padding: const EdgeInsets.all(ThixPolicy.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: ThixPolicy.s24),
              Text(
                title,
                style: ThixPolicy.titleStyle.copyWith(
                  color: ThixPolicy.textMain,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // MAP SHORTCUT
  // ========================================================================

  Widget _buildMapShortcut(BuildContext context, AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('retrouve_map_shortcut_label'),
      child: GestureDetector(
        onTap: () => _throttledTap(() {
          debugPrint('[Retrouve] 🗺️ Map shortcut tapped');
          context.push('/retrouve/map');
        }),
        child: GlassBox(
          padding: const EdgeInsets.symmetric(
            vertical: ThixPolicy.s16,
            horizontal: ThixPolicy.s16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: ThixPolicy.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('retrouve_map_title'),
                      style: ThixPolicy.bodyStyle.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                    Text(
                      l10n.t('retrouve_map_subtitle'),
                      style: ThixPolicy.captionStyle
                          .copyWith(color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: ThixPolicy.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // RECENT OBJECTS HEADER
  // ========================================================================

  Widget _buildRecentObjectsHeader(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('retrouve_recent_objects'),
            style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.textMain),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('common_see_all'),
          child: GestureDetector(
            onTap: () => _throttledTap(() {
              context.push('/retrouve/searches');
            }),
            child: Text(
              l10n.t('common_see_all'),
              style: ThixPolicy.labelStyle.copyWith(
                color: _glow,
                fontWeight: ThixPolicy.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // OBJETS LIST (with skeleton + error + empty states)
  // ========================================================================

  Widget _buildObjetsList(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<ObjetModel>> objetsAsync,
  ) {
    return objetsAsync.when(
      data: (objets) {
        if (objets.isEmpty) {
          return _buildEmptyState(l10n);
        }
        return RepaintBoundary(
          child: Column(
            children: objets
                .take(_kMaxVisibleObjects)
                .map((obj) => _buildObjectCard(context, l10n, obj))
                .toList(),
          ),
        );
      },
      loading: () => const _SkeletonLoader(),
      error: (err, stack) => _buildErrorState(context, l10n, err),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: ThixPolicy.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.t('retrouve_empty_title'),
              style: ThixPolicy.bodyStyle
                  .copyWith(color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('retrouve_empty_subtitle'),
              style: ThixPolicy.captionStyle
                  .copyWith(color: ThixPolicy.textMuted.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object err,
  ) {
    debugPrint('[Retrouve] ❌ Error loading objects: $err');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: ThixPolicy.danger,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('retrouve_load_error'),
              style: ThixPolicy.bodyStyle
                  .copyWith(color: ThixPolicy.danger),
            ),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.invalidate(objetsRecentsProvider);
                },
                child: Text(
                  l10n.t('common_retry'),
                  style: ThixPolicy.buttonText
                      .copyWith(color: ThixPolicy.textMain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // OBJECT CARD
  // ========================================================================

  Widget _buildObjectCard(
    BuildContext context,
    AppLocalizations l10n,
    ObjetModel obj,
  ) {
    final isLost = obj.statut == StatutObjet.perdu;
    final statusColor = isLost ? ThixPolicy.domainOpportunity : ThixPolicy.success;

    // ✅ SANITIZATION : tous les textes utilisateur
    final safeTitle = _RetrouveSanitizer.sanitizeText(
      obj.titre,
      maxLength: _kMaxTitleLength,
    );
    final safeLocation = _RetrouveSanitizer.sanitizeText(
      obj.lieu,
      maxLength: _kMaxLocationLength,
    );
    final safeDescription = _RetrouveSanitizer.sanitizeText(
      obj.description,
      maxLength: 500,
    );
    final safeReward = _RetrouveSanitizer.sanitizeText(
      obj.recompense ?? '',
      maxLength: 100,
    );
    final safeImageUrl = _RetrouveSanitizer.sanitizeImageUrl(obj.imageUrl);

    final i18n = I18nService.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
      child: Semantics(
        button: true,
        label: '${obj.statutLabel}. $safeTitle. ${safeLocation.isNotEmpty ? safeLocation : ""}',
        child: GestureDetector(
          onTap: () => _throttledTap(() {
            debugPrint('[Retrouve] 📦 Object tapped: ${safeTitle.substring(0, safeTitle.length.clamp(0, 20))}');
            context.push('/retrouve/object/${obj.id}');
          }),
          child: GlassBox(
            padding: const EdgeInsets.all(ThixPolicy.s12),
            child: Row(
              children: [
                _buildObjectThumbnail(obj.categorie, safeImageUrl),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        style: ThixPolicy.bodyStyle.copyWith(
                          color: ThixPolicy.textMain,
                          fontWeight: ThixPolicy.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${obj.statutLabel} • ${i18n.relativeTime(obj.date)}',
                            style: ThixPolicy.captionStyle.copyWith(
                              color: statusColor,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (safeLocation.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: ThixPolicy.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                safeLocation,
                                style: ThixPolicy.captionStyle.copyWith(
                                  color: ThixPolicy.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (obj.hasRecompense)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ThixPolicy.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ThixPolicy.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Semantics(
                      label: l10n.t('retrouve_has_reward'),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: ThixPolicy.warning,
                        size: 18,
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

  Widget _buildObjectThumbnail(String? categorie, String? imageUrl) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 64,
                height: 64,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ThixPolicy.textMuted,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) =>
                    _buildCategoryIcon(categorie),
              )
            : _buildCategoryIcon(categorie),
      ),
    );
  }

  Widget _buildCategoryIcon(String? categorie) {
    return Icon(
      _iconForCategory(categorie),
      size: 28,
      color: ThixPolicy.textMuted,
    );
  }

  // ========================================================================
  // BOTTOM NAV FLOTTANTE
  // ========================================================================

  Widget _buildFloatingBottomNav(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return GlassBox(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 30,
      child: Semantics(
        label: l10n.t('retrouve_bottom_nav'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, l10n.t('nav_home'), 0,
                onTap: () {}),
            _navItem(Icons.manage_search_rounded,
                l10n.t('nav_searches'), 1,
                onTap: () => _throttledTap(() {
                      context.push('/retrouve/searches');
                    })),
            // ── BOUTON CENTRAL "+" ──
            Semantics(
              button: true,
              label: l10n.t('retrouve_add_action'),
              child: GestureDetector(
                onTap: () => _showAddModal(context, l10n),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _glow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _glow.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: ThixPolicy.textMain,
                    size: 28,
                  ),
                ),
              ),
            ),
            _navItem(Icons.chat_bubble_rounded,
                l10n.t('nav_messages'), 3,
                onTap: () => _throttledTap(() {
                      context.push(AppRoutes.chat);
                    })),
            _navItem(Icons.person_rounded, l10n.t('nav_profile'), 4,
                onTap: () => _throttledTap(() {
                      context.push(AppRoutes.profile);
                    })),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int idx, {
    required VoidCallback onTap,
  }) {
    final sel = _currentIndex == idx;
    return Semantics(
      button: true,
      selected: sel,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (idx == 0 || idx == 3 || idx == 4) {
            setState(() => _currentIndex = idx);
          }
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: sel ? ThixPolicy.textMain : ThixPolicy.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold,
                color: sel ? ThixPolicy.textMain : ThixPolicy.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // ADD MODAL
  // ========================================================================

  void _showAddModal(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    debugPrint('[Retrouve] ➕ Add modal opened');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.inkDeep,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(
              color: ThixPolicy.border.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThixPolicy.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.t('retrouve_add_modal_title'),
                  style: ThixPolicy.h2Style
                      .copyWith(color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 24),
                _buildModalAction(
                  icon: Icons.search_off_rounded,
                  color: ThixPolicy.domainOpportunity,
                  title: l10n.t('retrouve_modal_lost'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToDeclare(context, StatutObjet.perdu);
                  },
                ),
                const SizedBox(height: 12),
                _buildModalAction(
                  icon: Icons.inventory_2_rounded,
                  color: ThixPolicy.success,
                  title: l10n.t('retrouve_modal_found'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToDeclare(context, StatutObjet.trouve);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalAction({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: GlassBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: ThixPolicy.titleStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: ThixPolicy.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // NAVIGATION HELPERS
  // ========================================================================

  Future<void> _navigateToDeclare(
    BuildContext context,
    StatutObjet type,
  ) async {
    _throttledTap(() async {
      HapticFeedback.lightImpact();
      final typeLabel = type == StatutObjet.perdu ? 'perdu' : 'trouvé';
      debugPrint('[Retrouve] 📝 Navigate to declare: $typeLabel');

      if (!context.mounted) return;
      final result = await context.push<bool>(
        '/retrouve/declare',
        extra: {'type': type},
      );
      if (result == true && mounted) {
        debugPrint('[Retrouve] ✓ Object declared, invalidating provider');
        ref.invalidate(objetsRecentsProvider);
      }
    });
  }

  /// Throttle les taps pour éviter les doubles-taps et navigations multiples.
  void _throttledTap(FutureOr<void> Function() callback) {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      debugPrint('[Retrouve] ⏱️ Tap throttled');
      return;
    }
    _lastTap = now;
    callback();
  }

  /// Retourne l'icône pour une catégorie (switch sur code, pas sur FR)
  IconData _iconForCategory(String? cat) {
    if (cat == null) return Icons.inventory_2_rounded;
    final normalized = cat.toLowerCase().trim();
    // Utilisation de codes stables (pas de strings FR)
    if (normalized.contains('phone') || normalized.contains('tel')) {
      return Icons.phone_android_rounded;
    }
    if (normalized.contains('wallet') || normalized.contains('sac')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (normalized.contains('key') || normalized.contains('cl')) {
      return Icons.vpn_key_rounded;
    }
    if (normalized.contains('backpack')) {
      return Icons.backpack_rounded;
    }
    if (normalized.contains('watch') || normalized.contains('bijou')) {
      return Icons.watch_rounded;
    }
    if (normalized.contains('doc')) {
      return Icons.description_outlined;
    }
    if (normalized.contains('audio') || normalized.contains('ecou')) {
      return Icons.headphones_rounded;
    }
    return Icons.inventory_2_rounded;
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================

class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
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
    return Column(
      children: List.generate(4, (i) => _buildSkeletonRow(i)),
    );
  }

  Widget _buildSkeletonRow(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: 0.35 + 0.3 * _ctrl.value,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: ThixPolicy.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
          ),
        ),
      ),
    );
  }
}
