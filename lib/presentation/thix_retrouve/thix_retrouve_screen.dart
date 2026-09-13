/// THIX RETROUVE — Design fidèle à la maquette (Production)
/// ✅ Header : THIX RETROUVE + petit commentaire (hero du bas supprimé)
/// ✅ Cartes d'action colorées (or / bleu) pleine largeur
/// ✅ Objets récents en LISTE (lignes compactes + badges)
/// ✅ Bottom nav RÉDUITE (hauteur compacte)
/// ✅ i18n + sanitization + Semantics + HapticFeedback + logs — NON CASSÉS
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/nav.dart';

import 'models/objet_model.dart';
import 'providers/objet_providers.dart';

// ============================================================================
// DESIGN TOKENS (Light — maquette)
// ============================================================================

const Color _kBg = Color(0xFFF7F9FC);
const Color _kSurface = Color(0xFFFFFFFF);
const Color _kTextMain = Color(0xFF12233D); // navy maquette
const Color _kTextSec = Color(0xFF5A6B84);
const Color _kTextMuted = Color(0xFF93A1B5);
const Color _kBorder = Color(0xFFE5EAF1);
const Color _kGold = Color(0xFFE0A400); // or maquette
const Color _kRed = Color(0xFFE5484D); // statut Perdu
const Color _kRadiusLg = 18.0;
const Color _kRadiusMd = 14.0;

const int _kMaxVisibleObjects = 6;
const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);

// ============================================================================
// SANITIZER (inchangé)
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
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: RefreshIndicator(
                color: ThixPolicy.primary,
                backgroundColor: _kSurface,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  debugPrint('[Retrouve] 🔄 Refresh');
                  ref.invalidate(objetsRecentsProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _buildActionCards(context, l10n),
                    const SizedBox(height: 12),
                    _buildMapCard(context, l10n),
                    const SizedBox(height: 22),
                    _buildSectionHeader(context, l10n),
                    const SizedBox(height: 10),
                    _buildObjetsList(context, l10n, objetsAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, l10n),
    );
  }

  // ── HEADER : THIX RETROUVE + petit commentaire ────────────────
  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.t('common_menu'),
            child: IconButton(
              icon: const Icon(Icons.menu_rounded, color: _kTextMain, size: 22),
              onPressed: () {},
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'THIX ${l10n.t('retrouve_brand_suffix')}'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t('retrouve_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kTextMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('common_notifications'),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: _kTextMain, size: 22),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  // ── CARTES D'ACTION (or / bleu) — maquette ───────────────────
  Widget _buildActionCards(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _actionCard(
            color: _kGold,
            icon: Icons.search_off_rounded,
            title: l10n.t('retrouve_lost_title'),
            subtitle: l10n.t('retrouve_lost_subtitle'),
            onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            color: ThixPolicy.primary,
            icon: Icons.inventory_2_rounded,
            title: l10n.t('retrouve_found_title'),
            subtitle: l10n.t('retrouve_found_subtitle'),
            onTap: () => _navigateToDeclare(context, StatutObjet.trouve),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kRadiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadiusLg),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 34),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CARTE CARTE MAP ──────────────────────────────────────────
  Widget _buildMapCard(BuildContext context, AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('retrouve_map_title'),
      child: Material(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusMd),
        child: InkWell(
          onTap: () =>
              _throttledTap(() => context.pushNamed('thixRetrouveCarte')),
          borderRadius: BorderRadius.circular(_kRadiusMd),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('retrouve_map_title'),
                        style: const TextStyle(
                          color: _kTextMain,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.t('retrouve_map_subtitle'),
                        style: const TextStyle(color: _kTextSec, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_on_rounded,
                      color: ThixPolicy.primary, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER DE SECTION ───────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.t('retrouve_recent_objects'),
          style: const TextStyle(
            color: _kTextMain,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('common_see_all'),
          child: GestureDetector(
            onTap: () => _throttledTap(
                () => context.pushNamed('thixRetrouveMesRecherches')),
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

  // ── LISTE OBJETS (lignes, maquette) ─────────────────────────
  Widget _buildObjetsList(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<ObjetModel>> objetsAsync,
  ) {
    return objetsAsync.when(
      data: (objets) {
        if (objets.isEmpty) return _buildEmptyState(l10n);
        final visible = objets.take(_kMaxVisibleObjects).toList();
        return Column(
          children: [
            for (final o in visible) ...[
              _buildObjectRow(context, l10n, o),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
      loading: () => const _SkeletonList(),
      error: (err, stack) => _buildErrorState(l10n, err),
    );
  }

  Widget _buildObjectRow(
      BuildContext context, AppLocalizations l10n, ObjetModel obj) {
    final isLost = obj.statut == StatutObjet.perdu;
    final statusColor = isLost ? _kRed : ThixPolicy.success;
    final i18n = I18nService.of(context);

    final safeTitle =
        _RetrouveSanitizer.sanitizeText(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation =
        _RetrouveSanitizer.sanitizeText(obj.lieu, maxLength: _kMaxLocationLength);
    final safeImageUrl = _RetrouveSanitizer.sanitizeImageUrl(obj.imageUrl);

    return Semantics(
      button: true,
      label: '$safeTitle. ${obj.statutLabel}. $safeLocation',
      child: Material(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusMd),
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
                'description': _RetrouveSanitizer.sanitizeText(obj.description,
                    maxLength: 500),
                'imageUrl': safeImageUrl,
              },
            );
          }),
          borderRadius: BorderRadius.circular(_kRadiusMd),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                // Vignette
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: safeImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: safeImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: _kBg,
                                child: const Center(
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)))),
                            errorWidget: (_, __, ___) => _thumbPlaceholder(),
                          )
                        : _thumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: 10),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kTextMain,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            obj.statutLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ' • ${i18n.relativeTime(obj.date)}',
                            style: const TextStyle(
                                color: _kTextSec, fontSize: 11),
                          ),
                        ],
                      ),
                      if (safeLocation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          safeLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _kTextMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge droit : RÉCOMPENSE ou statut
                if (obj.hasRecompense)
                  _badge(l10n.t('retrouve_badge_reward'), _kGold)
                else
                  _badge(obj.statutLabel.toUpperCase(), statusColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        color: _kBg,
        child: const Icon(Icons.inventory_2_rounded,
            color: _kTextMuted, size: 24),
      );

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── ÉTATS VIDE / ERREUR ─────────────────────────────────────
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 36, color: _kTextMuted),
            const SizedBox(height: 10),
            Text(l10n.t('retrouve_empty_title'),
                style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l10n.t('retrouve_empty_subtitle'),
                style: const TextStyle(color: _kTextSec, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, Object err) {
    debugPrint('[Retrouve] ❌ Error: $err');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 30, color: _kTextMuted),
            const SizedBox(height: 8),
            Text(l10n.t('retrouve_load_error'),
                style: const TextStyle(color: _kTextSec, fontSize: 12.5)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => ref.invalidate(objetsRecentsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.t('common_retry'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM NAV RÉDUITE (maquette) ───────────────────────────
  Widget _buildBottomNav(BuildContext context, AppLocalizations l10n) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, l10n.t('nav_home'), true,
              onTap: () {}),
          _navItem(Icons.category_outlined, l10n.t('nav_searches'), false,
              onTap: () => _throttledTap(
                  () => context.pushNamed('thixRetrouveMesRecherches'))),
          // Bouton central or
          Semantics(
            button: true,
            label: l10n.t('retrouve_add_action'),
            child: GestureDetector(
              onTap: () => _showAddModal(context, l10n),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _kGold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kGold.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.grid_view_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
          _navItem(Icons.chat_bubble_outline_rounded,
              l10n.t('nav_messages'), false,
              onTap: () =>
                  _throttledTap(() => context.pushNamed(AppRoutes.chat))),
          _navItem(Icons.person_outline_rounded, l10n.t('nav_profile'), false,
              onTap: () =>
                  _throttledTap(() => context.pushNamed(AppRoutes.profile))),
        ],
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
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? ThixPolicy.primary : _kTextMuted, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? ThixPolicy.primary : _kTextMuted,
                  fontSize: 8.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

  // ── MODAL D'AJOUT (clair, compact) ──────────────────────────
  void _showAddModal(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('retrouve_add_modal_title'),
                style: const TextStyle(
                  color: _kTextMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _modalAction(
                sheetCtx,
                color: _kGold,
                icon: Icons.search_off_rounded,
                label: l10n.t('retrouve_modal_lost'),
                onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
              ),
              const SizedBox(height: 10),
              _modalAction(
                sheetCtx,
                color: ThixPolicy.primary,
                icon: Icons.inventory_2_rounded,
                label: l10n.t('retrouve_modal_found'),
                onTap: () => _navigateToDeclare(context, StatutObjet.trouve),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalAction(
    BuildContext sheetCtx, {
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(sheetCtx);
          onTap();
        },
        borderRadius: BorderRadius.circular(_kRadiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(_kRadiusMd),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _kTextMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS LOGIQUE (inchangés) ─────────────────────────────
  Future<void> _navigateToDeclare(
      BuildContext context, StatutObjet type) async {
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
// SKELETON — lignes (light)
// ============================================================================

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
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
      children: [
        for (int i = 0; i < 3; i++) ...[
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: 0.5 + 0.35 * _ctrl.value,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(color: _kBorder),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
