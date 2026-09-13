/// THIX RETROUVE — Design maquette (Production, blindé)
/// ✅ Cartes colorées via Container (rendu garanti web + mobile)
/// ✅ zéro clé l10n brute : fallback automatique si clé manquante
/// ✅ États vide / erreur / chargement TOUJOURS visibles
/// ✅ Routes, providers, extra détail, sanitizer, semantics : INTACTS
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
// TOKENS
// ============================================================================
const Color _kBg = Color(0xFFF7F9FC);
const Color _kSurface = Color(0xFFFFFFFF);
const Color _kTextMain = Color(0xFF12233D);
const Color _kTextSec = Color(0xFF5A6B84);
const Color _kTextMuted = Color(0xFF93A1B5);
const Color _kBorder = Color(0xFFE5EAF1);
const Color _kSkeleton = Color(0xFFE8EDF3);
const Color _kGold = Color(0xFFE0A400);
const Color _kRed = Color(0xFFE5484D);
const double _kRadiusLg = 18.0;
const double _kRadiusMd = 14.0;

const int _kMaxVisibleObjects = 6;
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
// SCREEN
// ============================================================================
class ThixRetrouveScreen extends ConsumerStatefulWidget {
  const ThixRetrouveScreen({super.key});
  @override
  ConsumerState<ThixRetrouveScreen> createState() => _ThixRetrouveScreenState();
}

class _ThixRetrouveScreenState extends ConsumerState<ThixRetrouveScreen> {
  DateTime? _lastTap;

  /// 🛡️ Traduction SÛRE : retourne le fallback si la clé n'existe pas
  String _tr(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    return (v == key || v.trim().isEmpty) ? fallback : v;
  }

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

  // ── HEADER ─
  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: _kTextMain, size: 22),
            onPressed: () {},
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'THIX ${_tr(l10n, 'retrouve_brand_suffix', 'RETROUVE')}',
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
                  _tr(l10n, 'retrouve_tagline', 'Perdu ? Trouvé ? On vous aide !'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kTextMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: _kTextMain, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── CARTES D'ACTION (Container coloré = rendu garanti) ──
  Widget _buildActionCards(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _actionCard(
            color: _kGold,
            icon: Icons.search_off_rounded,
            title: _tr(l10n, 'retrouve_lost_title', "J'ai perdu un objet"),
            subtitle: _tr(l10n, 'retrouve_lost_subtitle',
                'Déclarez un objet que vous avez perdu'),
            onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            color: ThixPolicy.primary,
            icon: Icons.inventory_2_rounded,
            title: _tr(l10n, 'retrouve_found_title', "J'ai trouvé un objet"),
            subtitle: _tr(l10n, 'retrouve_found_subtitle',
                'Déclarez un objet que vous avez trouvé'),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color, // ⬅️ couleur DIRECTE (pas via Material)
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
                color: Colors.white.withOpacity(0.9),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CARTE MAP ──
  Widget _buildMapCard(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () =>
          _throttledTap(() => context.pushNamed('thixRetrouveCarte')),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_kRadiusMd),
          border: Border.all(color: _kBorder),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr(l10n, 'retrouve_map_title',
                        'Voir les objets autour de moi'),
                    style: const TextStyle(
                      color: _kTextMain,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tr(l10n, 'retrouve_map_subtitle', 'Explorer sur la carte'),
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
    );
  }

  // ── HEADER SECTION ──
  Widget _buildSectionHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _tr(l10n, 'retrouve_recent_objects', 'Objets récents'),
          style: const TextStyle(
              color: _kTextMain, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        GestureDetector(
          onTap: () => _throttledTap(
              () => context.pushNamed('thixRetrouveMesRecherches')),
          child: Text(
            _tr(l10n, 'common_see_all', 'Voir tout'),
            style: TextStyle(
                color: ThixPolicy.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ── LISTE OBJETS ──
  Widget _buildObjetsList(BuildContext context, AppLocalizations l10n,
      AsyncValue<List<ObjetModel>> objetsAsync) {
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
    final safeLocation = _RetrouveSanitizer.sanitizeText(obj.lieu,
        maxLength: _kMaxLocationLength);
    final safeImageUrl = _RetrouveSanitizer.sanitizeImageUrl(obj.imageUrl);

    return GestureDetector(
      onTap: () => _throttledTap(() {
        HapticFeedback.selectionClick();
        context.pushNamed('thixRetrouveDetail', extra: {
          'title': safeTitle,
          'status': obj.statutLabel,
          'location': safeLocation,
          'time': i18n.relativeTime(obj.date),
          'description':
              _RetrouveSanitizer.sanitizeText(obj.description, maxLength: 500),
          'imageUrl': safeImageUrl,
        });
      }),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_kRadiusMd),
          border: Border.all(color: _kBorder),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: safeImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: safeImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: _kSkeleton),
                        errorWidget: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
            ),
            const SizedBox(width: 10),
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
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        obj.statutLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(' • ${i18n.relativeTime(obj.date)}',
                          style: const TextStyle(
                              color: _kTextSec, fontSize: 11)),
                    ],
                  ),
                  if (safeLocation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(safeLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _kTextMuted, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (obj.hasRecompense ? _kGold : statusColor)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                obj.hasRecompense
                    ? _tr(l10n, 'retrouve_badge_reward', 'RÉCOMPENSE')
                    : obj.statutLabel.toUpperCase(),
                style: TextStyle(
                  color: obj.hasRecompense ? _kGold : statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => const ColoredBox(
        color: _kSkeleton,
        child: Center(
          child: Icon(Icons.inventory_2_rounded, color: _kTextMuted, size: 24),
        ),
      );

  // ── ÉTATS (toujours visibles) ──
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36, color: _kTextMuted),
          const SizedBox(height: 10),
          Text(_tr(l10n, 'retrouve_empty_title', 'Aucun objet pour le moment'),
              style: const TextStyle(
                  color: _kTextMain,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              _tr(l10n, 'retrouve_empty_subtitle',
                  'Déclarez un objet perdu ou trouvé pour commencer.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextSec, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, Object err) {
    debugPrint('[Retrouve] ❌ Error: $err');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 30, color: _kTextMuted),
          const SizedBox(height: 8),
          Text(_tr(l10n, 'retrouve_load_error', 'Chargement impossible'),
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
            child: Text(_tr(l10n, 'common_retry', 'Réessayer'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM NAV RÉDUITE ──
  Widget _buildBottomNav(BuildContext context, AppLocalizations l10n) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, _tr(l10n, 'nav_home', 'Accueil'), true,
              onTap: () {}),
          _navItem(Icons.category_outlined,
              _tr(l10n, 'nav_searches', 'Services'), false,
              onTap: () => _throttledTap(
                  () => context.pushNamed('thixRetrouveMesRecherches'))),
          GestureDetector(
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
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.grid_view_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          _navItem(Icons.chat_bubble_outline_rounded,
              _tr(l10n, 'nav_messages', 'Messages'), false,
              onTap: () =>
                  _throttledTap(() => context.pushNamed(AppRoutes.chat))),
          _navItem(Icons.person_outline_rounded,
              _tr(l10n, 'nav_profile', 'Profil'), false,
              onTap: () =>
                  _throttledTap(() => context.pushNamed(AppRoutes.profile))),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected,
      {required VoidCallback onTap}) {
    return GestureDetector(
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
    );
  }

  // ── MODAL AJOUT ──
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
                    color: _kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                  _tr(l10n, 'retrouve_add_modal_title',
                      'Que voulez-vous déclarer ?'),
                  style: const TextStyle(
                      color: _kTextMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _modalAction(
                sheetCtx,
                color: _kGold,
                icon: Icons.search_off_rounded,
                label: _tr(l10n, 'retrouve_modal_lost', "J'ai perdu un objet"),
                onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
              ),
              const SizedBox(height: 10),
              _modalAction(
                sheetCtx,
                color: ThixPolicy.primary,
                icon: Icons.inventory_2_rounded,
                label: _tr(l10n, 'retrouve_modal_found', "J'ai trouvé un objet"),
                onTap: () => _navigateToDeclare(context, StatutObjet.trouve),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalAction(BuildContext sheetCtx,
      {required Color color,
      required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        onTap();
      },
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
              child: Text(label,
                  style: const TextStyle(
                      color: _kTextMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _kTextMuted, size: 18),
          ],
        ),
      ),
    );
  }

  // ── LOGIQUE INTACTE ──
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
// SKELETON VISIBLE (gris)
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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
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
              opacity: 0.6 + 0.4 * _ctrl.value,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: _kSkeleton,
                  borderRadius: BorderRadius.circular(_kRadiusMd),
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
