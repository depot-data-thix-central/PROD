/// Mes Recherches Page (Production Enterprise)
/// ✅ ThixPolicy + i18n 8 langues + sanitization + go_router
/// ✅ Skeleton loader + PullToRefresh + Semantics + HapticFeedback
/// ✅ Logs structurés + I18nService.relativeTime() + RepaintBoundary
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
// CONSTANTS
// ============================================================================

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
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: ThixPolicy.textMain, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
        ),
        title: Text(
          l10n.t('searches_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textMuted,
          indicatorColor: ThixPolicy.primary,
          labelStyle: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.bold,
          ),
          tabs: [
            Tab(text: l10n.t('searches_tab_lost')),
            Tab(text: l10n.t('searches_tab_found')),
            Tab(text: l10n.t('searches_tab_recovered')),
          ],
        ),
      ),
      body: mesObjetsAsync.when(
        data: (objets) {
          final perdus = objets.where((o) => o.statut == StatutObjet.perdu).toList();
          final trouves = objets.where((o) => o.statut == StatutObjet.trouve).toList();
          final recuperes = objets.where((o) => o.statut == StatutObjet.recupere).toList();

          debugPrint('[MesRecherches] ✓ Loaded: ${perdus.length} perdus, '
              '${trouves.length} trouvés, ${recuperes.length} récupérés');

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(
                context,
                l10n,
                perdus,
                emptyMessage: l10n.t('searches_empty_lost'),
              ),
              _buildList(
                context,
                l10n,
                trouves,
                emptyMessage: l10n.t('searches_empty_found'),
              ),
              _buildList(
                context,
                l10n,
                recuperes,
                emptyMessage: l10n.t('searches_empty_recovered'),
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
      backgroundColor: ThixPolicy.card,
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
  // OBJECT CARD
  // ========================================================================

  Widget _buildObjectCard(
    BuildContext context,
    AppLocalizations l10n,
    ObjetModel obj,
  ) {
    final isRecovered = obj.statut == StatutObjet.recupere;
    final statusColor = isRecovered ? ThixPolicy.success : ThixPolicy.warning;
    final i18n = I18nService.of(context);

    // ✅ Sanitization
    final safeTitle = _SearchSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation = _SearchSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);
    final safeDescription = _SearchSanitizer.sanitize(obj.description, maxLength: 500);
    final safeReward = _SearchSanitizer.sanitize(obj.recompense ?? '', maxLength: 50);
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
            context.push('/retrouve/object/${obj.id}');
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Icon/Thumbnail ──
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                  child: Icon(
                    _iconForCategory(obj.categorie),
                    size: 26,
                    color: ThixPolicy.textMuted,
                  ),
                ),
                const SizedBox(width: 12),

                // ── Content ──
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
                      const SizedBox(height: 2),
                      Text(
                        '${obj.statutLabel} • ${i18n.relativeTime(obj.date)}',
                        style: ThixPolicy.captionStyle
                            .copyWith(color: ThixPolicy.textMuted),
                      ),
                    ],
                  ),
                ),

                // ── Status Badge ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRecovered
                        ? l10n.t('searches_status_recovered')
                        : l10n.t('searches_status_searching'),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: ThixPolicy.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('searches_empty_hint'),
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.textMuted.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            l10n.t('searches_load_error'),
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: l10n.t('common_retry'),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.invalidate(mesObjetsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.textMain,
              ),
            ),
          ),
        ],
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
          opacity: 0.35 + 0.3 * _ctrl.value,
          child: Container(
            height: 76,
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
