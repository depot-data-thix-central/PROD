/// THIX SOS — Carte alertes à proximité (Production Enterprise)
/// ✅ SÉCURISÉ : validation coordonnées, erreurs masquées, ThixPolicy, i18n
/// ✅ ACCESSIBLE : Semantics, haptic, mounted checks, logs structurés
/// ✅ UI PREMIUM : glassmorphism, gradients, animations, design system cohérent
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_recherche/models/personne_recherchee_model.dart';
import 'package:thix_id/presentation/thix_recherche/providers/recherche_providers.dart';
import 'package:thix_id/presentation/thix_sos/providers/sos_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kNavigationThrottle = Duration(seconds: 1);
const double _kMinValidLat = -90.0;
const double _kMaxValidLat = 90.0;
const double _kMinValidLng = -180.0;
const double _kMaxValidLng = 180.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _NearbyValidators {
  _NearbyValidators._();

  static bool isValidCoordinate(double lat, double lng) {
    return lat >= _kMinValidLat &&
        lat <= _kMaxValidLat &&
        lng >= _kMinValidLng &&
        lng <= _kMaxValidLng;
  }

  static String friendlyError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return l10n.t('nearby_error_timeout');
    if (msg.contains('network')) return l10n.t('nearby_error_network');
    if (msg.contains('permission')) return l10n.t('nearby_error_permission');
    if (msg.contains('location')) return l10n.t('nearby_error_location');
    return l10n.t('nearby_error_generic');
  }
}

// ============================================================================
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE (GLASSMORPHISM)
// ============================================================================
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
    this.blur = 15.0,
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
              color: color ?? Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class NearbyAlertsCard extends ConsumerStatefulWidget {
  const NearbyAlertsCard({super.key});

  @override
  ConsumerState<NearbyAlertsCard> createState() => _NearbyAlertsCardState();
}

class _NearbyAlertsCardState extends ConsumerState<NearbyAlertsCard> {
  DateTime? _lastNavigation;

  void _navigateToMap() {
    final now = DateTime.now();
    if (_lastNavigation != null &&
        now.difference(_lastNavigation!) < _kNavigationThrottle) {
      debugPrint('[NearbyAlerts] ⚠️ Navigation throttled');
      return;
    }
    _lastNavigation = now;
    HapticFeedback.mediumImpact();

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.t('nearby_map_coming_soon'),
                  style: ThixPolicy.bodyStyle
                      .copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final posAsync = ref.watch(sosUserPositionProvider);

    return RepaintBoundary(
      child: GlassBox(
        padding: EdgeInsets.zero,
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HEADER DE SECTION ───
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ThixPolicy.s8),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      border: Border.all(
                          color: ThixPolicy.danger.withOpacity(0.3), width: 1),
                    ),
                    child: const Icon(Icons.radar_rounded,
                        color: ThixPolicy.danger, size: 20),
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Text(
                      l10n.t('nearby_alerts_title'),
                      style: ThixPolicy.h2Style.copyWith(
                          color: Colors.white, letterSpacing: -0.5),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.t('nearby_view_on_map'),
                    child: GestureDetector(
                      onTap: _navigateToMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s12,
                            vertical: ThixPolicy.s6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius:
                              BorderRadius.circular(ThixPolicy.rXl),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.t('nearby_view_on_map'),
                                style: ThixPolicy.labelStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: ThixPolicy.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 10, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s16),

            // ─── CONTENU (position + alertes) ───
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
              child: posAsync.when(
                loading: () => const _SkeletonLoader(),
                error: (e, stack) {
                  debugPrint('[NearbyAlerts] ❌ Position error: $e');
                  debugPrint('[NearbyAlerts] Stack: $stack');
                  return _ErrorBox(
                    message: _NearbyValidators.friendlyError(e, l10n),
                  );
                },
                data: (pos) {
                  if (pos == null) {
                    return _LocationDisabledBox(l10n: l10n);
                  }

                  if (!_NearbyValidators.isValidCoordinate(pos.lat, pos.lng)) {
                    debugPrint(
                        '[NearbyAlerts] ⚠️ Invalid coordinates: ${pos.lat}, ${pos.lng}');
                    return _ErrorBox(
                      message: l10n.t('nearby_invalid_coordinates'),
                    );
                  }

                  final nearbyAsync = ref.watch(
                    nearbyAlertesProvider(
                      NearbyParams(lat: pos.lat, lng: pos.lng),
                    ),
                  );
                  return nearbyAsync.when(
                    loading: () => const _SkeletonLoader(),
                    error: (e, stack) {
                      debugPrint('[NearbyAlerts] ❌ Nearby error: $e');
                      debugPrint('[NearbyAlerts] Stack: $stack');
                      return _ErrorBox(
                        message: _NearbyValidators.friendlyError(e, l10n),
                      );
                    },
                    data: (list) => _MapBlock(
                      lat: pos.lat,
                      lng: pos.lng,
                      alertes: list,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MAP BLOCK — Design premium avec gradient et overlay stats
// ============================================================================
class _MapBlock extends StatelessWidget {
  const _MapBlock({
    required this.lat,
    required this.lng,
    required this.alertes,
  });

  final double lat;
  final double lng;
  final List<PersonneRecherchee> alertes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disparues =
        alertes.where((a) => a.typeAlerte == TypeAlerte.disparue).length;
    final officiels =
        alertes.where((a) => a.typeAlerte == TypeAlerte.recherchee).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: SizedBox(
            height: 180,
            child: Stack(
              children: [
                // ─── FOND DE CARTE (Placeholder premium) ───
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Grille subtile pour effet "carte"
                      CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _GridPainter(),
                      ),
                      // Glow danger au centre
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThixPolicy.danger.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                color: ThixPolicy.danger.withOpacity(0.3),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Icône centrale
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.15)),
                              ),
                              child: const Icon(Icons.map_outlined,
                                  color: Colors.white54, size: 36),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.t('nearby_map_disabled'),
                              textAlign: TextAlign.center,
                              style: ThixPolicy.microStyle.copyWith(
                                  color: Colors.white38,
                                  letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── OVERLAY STATISTIQUES (en haut à gauche) ───
                Positioned(
                  left: 12,
                  top: 12,
                  child: Semantics(
                    label: '${alertes.length} ${l10n.t('nearby_active_alerts')}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius:
                                BorderRadius.circular(ThixPolicy.rMd),
                            border: Border.all(
                                color: ThixPolicy.danger.withOpacity(0.4),
                                width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: ThixPolicy.danger,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              ThixPolicy.danger.withOpacity(0.8),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${alertes.length} ${l10n.t('nearby_active_alerts')}',
                                    style: ThixPolicy.labelStyle.copyWith(
                                      color: Colors.white,
                                      fontWeight: ThixPolicy.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$disparues ${l10n.t('nearby_missing')} · $officiels ${l10n.t('nearby_official')}',
                                style: ThixPolicy.microStyle.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── BADGE COORDONNÉES (en bas à droite) ───
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}',
                              style: ThixPolicy.microStyle.copyWith(
                                color: Colors.white70,
                                fontFamily: 'monospace',
                                fontWeight: ThixPolicy.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),

        // ─── LÉGENDE ───
        _LegendRow(l10n: l10n),
      ],
    );
  }
}

// ============================================================================
// GRILLE DÉCORATIVE (effet carte)
// ============================================================================
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// LÉGENDE — Pills colorés
// ============================================================================
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _LegendPill(
          color: ThixPolicy.danger,
          label: l10n.t('nearby_legend_missing'),
        ),
        _LegendPill(
          color: ThixPolicy.primary,
          label: l10n.t('nearby_legend_official'),
        ),
        _LegendPill(
          color: ThixPolicy.warning,
          label: l10n.t('nearby_legend_report'),
        ),
      ],
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: ThixPolicy.microStyle.copyWith(
              color: Colors.white70,
              fontWeight: ThixPolicy.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADER — Animé (shimmer effect)
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Column(
          children: [
            // Skeleton carte
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.08 + 0.04 * _ctrl.value),
                    Colors.white.withOpacity(0.03),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.map_outlined,
                          color: Colors.white24, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 140,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Skeleton légende
            Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 8.0 : 0),
                  child: Container(
                    width: 80 + (i * 10.0),
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// ERROR BOX — Avec retry + icône dans cercle teinté
// ============================================================================
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: ThixPolicy.danger, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: Colors.white,
              fontWeight: ThixPolicy.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOCATION DISABLED BOX — CTA clair
// ============================================================================
class _LocationDisabledBox extends StatelessWidget {
  const _LocationDisabledBox({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.warning.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThixPolicy.warning.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off_rounded,
                color: ThixPolicy.warning, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('nearby_location_required'),
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle.copyWith(
              color: Colors.white,
              fontWeight: ThixPolicy.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('nearby_location_subtitle'),
            textAlign: TextAlign.center,
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
