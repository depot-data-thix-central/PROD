/// THIX RETROUVE Screen (Production Enterprise)
/// Design épuré, compact, haute densité d'information
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
// CONSTANTS
// ============================================================================

const int _kMaxVisibleObjects = 8;
const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);

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
// WIDGETS DE STRUCTURE ENTREPRISE
// ============================================================================

/// Carte standardisée pour un look "Enterprise" : plat, bordure fine.
class EnterpriseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;

  const EnterpriseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? ThixPolicy.surfaceSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? ThixPolicy.border.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Boîte glassmorphism réservée aux éléments flottants (Bottom Nav)
class FloatingGlassBox extends StatelessWidget {
  final Widget child;

  const FloatingGlassBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: ThixPolicy.border.withValues(alpha: 0.15),
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
  static const _glow = ThixPolicy.primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objetsAsync = ref.watch(objetsRecentsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          _buildBackgroundGlows(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(l10n),

                Expanded(
                  child: RefreshIndicator(
                    color: _glow,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      ref.invalidate(objetsRecentsProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildTitleSection(l10n),
                          const SizedBox(height: 20),

                          // Actions ultra-compactes
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactActionCard(
                                  color: ThixPolicy.domainOpportunity,
                                  icon: Icons.search_off_rounded,
                                  title: l10n.t('retrouve_lost_title'),
                                  onTap: () => _navigateToDeclare(context, StatutObjet.perdu),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCompactActionCard(
                                  color: ThixPolicy.success,
                                  icon: Icons.inventory_2_rounded,
                                  title: l10n.t('retrouve_found_title'),
                                  onTap: () => _navigateToDeclare(context, StatutObjet.trouve),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildMapShortcut(context, l10n),
                          
                          const SizedBox(height: 28),
                          _buildRecentObjectsHeader(context, l10n),
                          const SizedBox(height: 12),

                          _buildObjetsList(context, l10n, objetsAsync),
                          const SizedBox(height: 100), // Espace pour la bottom nav
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Nav Flottante
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
  // BACKGROUND GLOWS (Adoucis)
  // ========================================================================

  Widget _buildBackgroundGlows() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _glow.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: _glow.withValues(alpha: 0.15),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: ThixPolicy.textMain),
            onPressed: () {},
          ),
          Expanded(
            child: Text(
              'THIX CENTRAL',
              textAlign: TextAlign.center,
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: ThixPolicy.bold,
                letterSpacing: 1.0,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // TITLE SECTION
  // ========================================================================

  Widget _buildTitleSection(AppLocalizations l10n) {
    return Column(
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
                  fontSize: 24,
                ),
              ),
              TextSpan(
                text: l10n.t('retrouve_brand_suffix'),
                style: ThixPolicy.h1Style.copyWith(
                  color: _glow,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('retrouve_tagline'),
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
        ),
      ],
    );
  }

  // ========================================================================
  // COMPACT ACTION CARDS
  // ========================================================================

  Widget _buildCompactActionCard({
    required Color color,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: EnterpriseCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        borderColor: color.withValues(alpha: 0.3),
        backgroundColor: color.withValues(alpha: 0.05),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.textMain,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // MAP SHORTCUT
  // ========================================================================

  Widget _buildMapShortcut(BuildContext context, AppLocalizations l10n) {
    return InkWell(
      onTap: () => _throttledTap(() => context.pushNamed('thixRetrouveCarte')),
      borderRadius: BorderRadius.circular(12),
      child: EnterpriseCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.map_outlined, color: ThixPolicy.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.t('retrouve_map_title'),
                style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // RECENT OBJECTS HEADER
  // ========================================================================

  Widget _buildRecentObjectsHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.t('retrouve_recent_objects'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontSize: 16,
          ),
        ),
        GestureDetector(
          onTap: () => _throttledTap(() => context.pushNamed('thixRetrouveMesRecherches')),
          child: Text(
            l10n.t('common_see_all'),
            style: ThixPolicy.labelStyle.copyWith(
              color: _glow,
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // OBJETS LIST
  // ========================================================================

  Widget _buildObjetsList(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<ObjetModel>> objetsAsync,
  ) {
    return objetsAsync.when(
      data: (objets) {
        if (objets.isEmpty) return _buildEmptyState(l10n);
        return Column(
          children: objets
              .take(_kMaxVisibleObjects)
              .map((obj) => _buildObjectCard(context, l10n, obj))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (err, stack) => _buildErrorState(context, l10n, err),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Text(
          l10n.t('retrouve_empty_title'),
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n, Object err) {
    return Center(
      child: TextButton(
        onPressed: () => ref.invalidate(objetsRecentsProvider),
        child: Text(l10n.t('common_retry')),
      ),
    );
  }

  // ========================================================================
  // ENTERPRISE OBJECT CARD
  // ========================================================================

  Widget _buildObjectCard(
    BuildContext context,
    AppLocalizations l10n,
    ObjetModel obj,
  ) {
    final isLost = obj.statut == StatutObjet.perdu;
    final statusColor = isLost ? ThixPolicy.domainOpportunity : ThixPolicy.success;
    final i18n = I18nService.of(context);

    final safeTitle = _RetrouveSanitizer.sanitizeText(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation = _RetrouveSanitizer.sanitizeText(obj.lieu, maxLength: _kMaxLocationLength);
    final safeImageUrl = _RetrouveSanitizer.sanitizeImageUrl(obj.imageUrl);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _throttledTap(() {
          context.pushNamed(
            'thixRetrouveDetail',
            extra: {
              'title': safeTitle,
              'status': obj.statutLabel,
              'location': safeLocation,
              'time': i18n.relativeTime(obj.date),
              'description': _RetrouveSanitizer.sanitizeText(obj.description, maxLength: 500),
              'imageUrl': safeImageUrl,
            },
          );
        }),
        borderRadius: BorderRadius.circular(10),
        child: EnterpriseCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _buildObjectThumbnail(obj.categorie, safeImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeTitle,
                      style: ThixPolicy.bodyStyle.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: ThixPolicy.semiBold,
                        fontSize: 14,
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
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${obj.statutLabel} • ${i18n.relativeTime(obj.date)}',
                          style: ThixPolicy.captionStyle.copyWith(
                            color: statusColor,
                            fontWeight: ThixPolicy.semiBold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (safeLocation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 12, color: ThixPolicy.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              safeLocation,
                              style: ThixPolicy.captionStyle.copyWith(
                                color: ThixPolicy.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (obj.hasRecompense)
                Icon(Icons.workspace_premium_rounded, color: ThixPolicy.warning, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectThumbnail(String? categorie, String? imageUrl) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                errorWidget: (_, __, ___) => Icon(Icons.inventory_2_rounded, color: ThixPolicy.textMuted, size: 24),
              )
            : Icon(Icons.inventory_2_rounded, color: ThixPolicy.textMuted, size: 24),
      ),
    );
  }

  // ========================================================================
  // BOTTOM NAV FLOTTANTE
  // ========================================================================

  Widget _buildFloatingBottomNav(BuildContext context, AppLocalizations l10n) {
    return FloatingGlassBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, l10n.t('nav_home'), 0, onTap: () {}),
          _navItem(Icons.manage_search_rounded, l10n.t('nav_searches'), 1,
              onTap: () => _throttledTap(() => context.pushNamed('thixRetrouveMesRecherches'))),
          
          // BOUTON CENTRAL "+"
          GestureDetector(
            onTap: () => _showAddModal(context, l10n),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _glow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _glow.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: ThixPolicy.inkDeep, size: 24),
            ),
          ),
          
          _navItem(Icons.chat_bubble_rounded, l10n.t('nav_messages'), 3,
              onTap: () => _throttledTap(() => context.pushNamed(AppRoutes.chat))),
          _navItem(Icons.person_rounded, l10n.t('nav_profile'), 4,
              onTap: () => _throttledTap(() => context.pushNamed(AppRoutes.profile))),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx, {required VoidCallback onTap}) {
    final sel = _currentIndex == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (idx == 0 || idx == 3 || idx == 4) setState(() => _currentIndex = idx);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: sel ? ThixPolicy.textMain : ThixPolicy.textMuted, size: 22),
          const SizedBox(height: 2),
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
    );
  }

  // ========================================================================
  // ADD MODAL
  // ========================================================================
  
  void _showAddModal(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 20),
              Text(
                l10n.t('retrouve_add_modal_title'),
                style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.textMain, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _navigateToDeclare(context, StatutObjet.perdu);
                },
                leading: CircleAvatar(backgroundColor: ThixPolicy.domainOpportunity.withValues(alpha: 0.1), child: Icon(Icons.search_off_rounded, color: ThixPolicy.domainOpportunity)),
                title: Text(l10n.t('retrouve_modal_lost'), style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.bold)),
                trailing: Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _navigateToDeclare(context, StatutObjet.trouve);
                },
                leading: CircleAvatar(backgroundColor: ThixPolicy.success.withValues(alpha: 0.1), child: Icon(Icons.inventory_2_rounded, color: ThixPolicy.success)),
                title: Text(l10n.t('retrouve_modal_found'), style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.bold)),
                trailing: Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // LOGIC HELPERS
  // ========================================================================

  Future<void> _navigateToDeclare(BuildContext context, StatutObjet type) async {
    _throttledTap(() async {
      HapticFeedback.lightImpact();
      if (!context.mounted) return;
      
      final routeName = type == StatutObjet.perdu ? 'thixRetrouveDeclarerPerdu' : 'thixRetrouveDeclarerTrouve';
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
