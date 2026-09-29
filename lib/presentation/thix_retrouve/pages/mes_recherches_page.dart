/// Mes Recherches Page (Production Enterprise)
/// ✅ FIX 1 : thème clair unifié (fond #F7F9FC) — cohérent RETROUVE/Detail
/// ✅ FIX 2 : _tr() fallbacks → plus jamais de clé l10n brute
/// ✅ FIX 3 : navigation corrigée → pushNamed('thixRetrouveDetail', extra: …)
///    (l'ancienne route '/retrouve/object/{id}' n'existe pas = écran 404)
/// ✅ FIX 4 : vignettes PHOTOS réelles (CachedNetworkImage) + transfert
///    imageUrl/reward/contact vers la page de détail
/// ✅ Skeleton loader + PullToRefresh + Semantics + HapticFeedback + throttle
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';

import '../models/objet_model.dart';
import '../providers/objet_providers.dart';

// ============================================================================
// DESIGN TOKENS (Light Premium — identiques RETROUVE / Detail)
// ============================================================================

const Color _kBg = Color(0xFFF7F9FC);
const Color _kSurface = Color(0xFFFFFFFF);
const Color _kTextMain = Color(0xFF12233D);
const Color _kTextSec = Color(0xFF5A6B84);
const Color _kTextMuted = Color(0xFF93A1B5);
const Color _kBorder = Color(0xFFE5EAF1);
const Color _kSkeleton = Color(0xFFE8EDF3);
const Color _kGold = Color(0xFFE0A400);
const Color _kGoldDeep = Color(0xFFB07F00);

const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _SearchSanitizer {
  _SearchSanitizer._();

  static String sanitize(String? input, {required int maxLength}) {
    if (input == null || input.isEmpty) return '';
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
// CATEGORY ICON HELPER
// ============================================================================

IconData _iconForCategory(String? cat) {
  if (cat == null) return Icons.inventory_2_rounded;
  final normalized = cat.toLowerCase().trim();
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
    return Icons.description_rounded;
  }
  if (normalized.contains('audio') || normalized.contains('ecou')) {
    return Icons.headphones_rounded;
  }
  return Icons.inventory_2_rounded;
}

// ============================================================================
// PAGE
// ============================================================================

class MesRecherchesPage extends ConsumerStatefulWidget {
  const MesRecherchesPage({super.key});

  @override
  ConsumerState<MesRecherchesPage> createState() => _MesRecherchesPageState();
}

class _MesRecherchesPageState extends ConsumerState<MesRecherchesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _lastTap;

  /// 🛡️ Traduction sûre : fallback FR si clé absente (jamais de clé brute)
  String _tr(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    return (v == key || v.trim().isEmpty) ? fallback : v;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
        debugPrint('[MesRecherches] 📑 Tab changed: ${_tabController.index}');
      }
    });
    debugPrint('[MesRecherches] 🚀 Page initialized');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mesObjetsAsync = ref.watch(mesObjetsProvider);

    return Scaffold(
      // ✅ Fond CLAIR unifié
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: _tr(l10n, 'common_back', 'Retour'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kTextMain, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
        ),
        title: Text(
          _tr(l10n, 'searches_title', 'Mes recherches'),
          style: ThixPolicy.h3Style.copyWith(
            color: _kTextMain,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: _kTextMuted,
          indicatorColor: ThixPolicy.primary,
          dividerColor: _kBorder,
          labelStyle: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.bold,
          ),
          tabs: [
            Tab(text: _tr(l10n, 'searches_tab_lost', 'Perdus')),
            Tab(text: _tr(l10n, 'searches_tab_found', 'Trouvés')),
            Tab(text: _tr(l10n, 'searches_tab_recovered', 'Récupérés')),
          ],
        ),
      ),
      body: mesObjetsAsync.when(
        data: (objets) {
          final perdus =
              objets.where((o) => o.statut == StatutObjet.perdu).toList();
          final trouves =
              objets.where((o) => o.statut == StatutObjet.trouve).toList();
          final recuperes =
              objets.where((o) => o.statut == StatutObjet.recupere).toList();

          debugPrint('[MesRecherches] ✓ Loaded: ${perdus.length} perdus, '
              '${trouves.length} trouvés, ${recuperes.length} récupérés');

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(
                context,
                l10n,
                perdus,
                emptyMessage: _tr(l10n, 'searches_empty_lost',
                    'Aucun objet perdu déclaré'),
              ),
              _buildList(
                context,
                l10n,
                trouves,
                emptyMessage: _tr(l10n, 'searches_empty_found',
                    'Aucun objet trouvé déclaré'),
              ),
              _buildList(
                context,
                l10n,
                recuperes,
                emptyMessage: _tr(l10n, 'searches_empty_recovered',
                    'Aucun objet récupéré pour le moment'),
              ),
            ],
          );
        },
        loading: () => const _SkeletonLoader(),
        error: (e, _) => _buildErrorState(context, l10n, e),
      ),
    );
  }

  // ========================================================================
  // LIST BUILDER
  // ========================================================================

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<ObjetModel> items, {
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return _buildEmptyState(l10n, emptyMessage);
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: _kSurface,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        debugPrint('[MesRecherches] 🔄 Refresh triggered');
        ref.invalidate(mesObjetsProvider);
      },
      child: RepaintBoundary(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final obj = items[index];
            return _buildObjectCard(context, l10n, obj);
          },
        ),
      ),
    );
  }

  // ========================================================================
  // OBJECT CARD (avec PHOTO réelle)
  // ========================================================================

  Widget _buildObjectCard(
    BuildContext context,
    AppLocalizations l10n,
    ObjetModel obj,
  ) {
    final isRecovered = obj.statut == StatutObjet.recupere;
    final statusColor = isRecovered ? ThixPolicy.success : _kGoldDeep;
    final statusBg = isRecovered
        ? ThixPolicy.success.withValues(alpha: 0.12)
        : _kGold.withValues(alpha: 0.14);
    final i18n = I18nService.of(context);

    // ✅ Sanitization
    final safeTitle =
        _SearchSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation =
        _SearchSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);
    final safeDescription =
        _SearchSanitizer.sanitize(obj.description, maxLength: 500);
    final safeReward =
        _SearchSanitizer.sanitize(obj.recompense ?? '', maxLength: 50);
    final safeImageUrl = _SearchSanitizer.sanitizeImageUrl(obj.imageUrl);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: '${safeTitle}. ${obj.statutLabel}. ${safeLocation}',
        child: GestureDetector(
          onTap: () => _throttledTap(() {
            HapticFeedback.selectionClick();
            debugPrint('[MesRecherches] 📦 Object tapped: '
                '${safeTitle.substring(0, safeTitle.length.clamp(0, 20))}');
            // ✅ FIX ROUTE : route nommée existante + extra complet
            //    (l'ancien '/retrouve/object/{id}' n'existe pas → 404)
            context.pushNamed(
              'thixRetrouveDetail',
              extra: {
                'title': safeTitle,
                'status': obj.statutLabel,
                'location': safeLocation,
                'time': i18n.relativeTime(obj.date),
                'description': safeDescription,
                'reward': safeReward,
                'contact': obj.contactInfo ?? '',
                'imageUrl': safeImageUrl,
              },
            );
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: _kBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _kTextMain.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── ✅ Vignette PHOTO réelle (fallback icône catégorie) ──
                _Thumb(url: safeImageUrl, categorie: obj.categorie),
                const SizedBox(width: 12),

                // ── Content ─
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        style: ThixPolicy.bodyStyle.copyWith(
                          color: _kTextMain,
                          fontWeight: ThixPolicy.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${obj.statutLabel} • ${i18n.relativeTime(obj.date)}',
                        style: ThixPolicy.captionStyle
                            .copyWith(color: _kTextSec),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (safeLocation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          safeLocation,
                          style: ThixPolicy.captionStyle
                              .copyWith(color: _kTextMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Status Badge (texte contrasté) ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRecovered
                        ? _tr(l10n, 'searches_status_recovered', 'RÉCUPÉRÉ')
                        : _tr(l10n, 'searches_status_searching', 'EN RECHERCHE'),
                    style: ThixPolicy.captionStyle.copyWith(
                      color: statusColor,
                      fontWeight: ThixPolicy.bold,
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

  // ========================================================================
  // EMPTY STATE
  // ========================================================================

  Widget _buildEmptyState(AppLocalizations l10n, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: _kTextMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(
                color: _kTextSec,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _tr(l10n, 'searches_empty_hint',
                  'Vos déclarations apparaîtront ici.'),
              style: ThixPolicy.captionStyle.copyWith(
                color: _kTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // ERROR STATE
  // ========================================================================

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    debugPrint('[MesRecherches] ❌ Error: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: ThixPolicy.danger,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _tr(l10n, 'searches_load_error', 'Chargement impossible'),
              style: ThixPolicy.bodyStyle.copyWith(color: _kTextSec),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: _tr(l10n, 'common_retry', 'Réessayer'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.invalidate(mesObjetsProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_tr(l10n, 'common_retry', 'Réessayer')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // THROTTLE HELPER
  // ========================================================================

  void _throttledTap(VoidCallback callback) {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      debugPrint('[MesRecherches] ⏱️ Tap throttled');
      return;
    }
    _lastTap = now;
    callback();
  }
}

// ============================================================================
// VIGNETTE PHOTO (CachedNetworkImage + fallback icône)
// ============================================================================

class _Thumb extends StatelessWidget {
  final String? url;
  final String? categorie;

  const _Thumb({required this.url, required this.categorie});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              width: 52,
              height: 52,
              placeholder: (_, __) => const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) =>
                  Icon(_iconForCategory(categorie), size: 24, color: _kTextMuted),
            )
          : Icon(_iconForCategory(categorie), size: 24, color: _kTextMuted),
    );
  }
}

// ============================================================================
// SKELETON LOADER (clair)
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: 0.5 + 0.3 * _ctrl.value,
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: _kSkeleton,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: _kBorder),
            ),
          ),
        ),
      ),
    );
  }
}
