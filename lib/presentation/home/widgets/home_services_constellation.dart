// lib/presentation/home/widgets/home_services_constellation.dart
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxTitleLength = 20;
const double _kStageHeight = ThixPolicy.constellationStageHeight;
const double _kHubRadius = ThixPolicy.constellationHubRadius;
const double _kNodeContainerWidth = 52.0;
const double _kNodeTextSize = 8.5;
const double _kNodeCircleSize = 44.0;
const double _kNodeIconSize = 19.0;
const double _kHubShrink = 0.85;

// ============================================================================
// DATA MODEL
// ============================================================================
class _ServiceNodeData {
  final String key;
  final IconData icon;
  final String title;
  final int? badge;
  final Color color;

  const _ServiceNodeData({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    this.badge,
  });
}

// ============================================================================
// MAIN WIDGET
// ============================================================================
class HomeServicesConstellation extends StatefulWidget {
  final SectionBadgeCounts counts;
  final void Function(String key) onServiceTap;
  final VoidCallback onHomeTap;
  final VoidCallback onMiniAppsTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final String? avatarUrl;

  const HomeServicesConstellation({
    super.key,
    required this.counts,
    required this.onServiceTap,
    required this.onHomeTap,
    required this.onMiniAppsTap,
    required this.onDocumentsTap,
    required this.onProfileTap,
    required this.onScanTap,
    this.avatarUrl,
  });

  @override
  State<HomeServicesConstellation> createState() =>
      _HomeServicesConstellationState();
}

class _HomeServicesConstellationState extends State<HomeServicesConstellation> {
  static const Color _colorCorporate = ThixPolicy.primaryDeep;
  static const Color _colorPrimary = ThixPolicy.primary;
  static const Color _colorMoney = ThixPolicy.gold;
  static const Color _colorHealth = ThixPolicy.danger;
  static const Color _colorMarket = ThixPolicy.domainMarket;
  static const Color _colorNetwork = ThixPolicy.domainNetwork;
  static const Color _colorLearning = ThixPolicy.domainLearning;
  static const Color _colorEvent = ThixPolicy.warning;

  @override
  void initState() {
    super.initState();
    debugPrint('[Constellation] 🌐 Initialized');
  }

  @override
  void dispose() {
    debugPrint('[Constellation] 👋 Disposed');
    super.dispose();
  }

  List<_ServiceNodeData> _getGroupedNodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      // Orbite interne (4 nœuds)
      _ServiceNodeData(
        key: 'thixMoney',
        icon: Icons.account_balance_wallet_rounded,
        title: l10n.t('serviceMoney'),
        badge: c.money,
        color: _colorMoney,
      ),
      _ServiceNodeData(
        key: 'thixMedia',
        icon: Icons.video_collection_rounded,
        title: 'TDIA',
        badge: c.media,
        color: _colorNetwork,
      ),
      _ServiceNodeData(
        key: 'monPays',
        icon: Icons.flag_rounded,
        title: l10n.t('serviceMonPays'),
        badge: c.monPays,
        color: _colorCorporate,
      ),
      _ServiceNodeData(
        key: 'thixInfo',
        icon: Icons.newspaper_rounded,
        title: 'THIX MEDIA',
        badge: c.info,
        color: _colorPrimary,
      ),

      // Orbite externe (8 nœuds)
      _ServiceNodeData(
        key: 'evenements',
        icon: Icons.event_rounded,
        title: 'Thix Event',
        badge: c.events,
        color: _colorEvent,
      ),
      _ServiceNodeData(
        key: 'thixMarket',
        icon: Icons.storefront_rounded,
        title: l10n.t('serviceMarket'),
        badge: c.market,
        color: _colorMarket,
      ),
      _ServiceNodeData(
        key: 'reservation',
        icon: Icons.confirmation_number_rounded,
        title: l10n.t('serviceReservation'),
        badge: c.reservation,
        color: _colorPrimary,
      ),
      _ServiceNodeData(
        key: 'emplois',
        icon: Icons.work_rounded,
        title: l10n.t('serviceEmplois'),
        badge: c.jobs,
        color: _colorCorporate,
      ),
      _ServiceNodeData(
        key: 'formations',
        icon: Icons.school_rounded,
        title: l10n.t('serviceFormations'),
        badge: c.formations,
        color: _colorLearning,
      ),
      _ServiceNodeData(
        key: 'opportunites',
        icon: Icons.lightbulb_rounded,
        title: l10n.t('serviceOpportunites'),
        badge: c.opportunities,
        color: _colorMoney,
      ),
      _ServiceNodeData(
        key: 'reseauPro',
        icon: Icons.groups_rounded,
        title: 'Thix Pro',
        badge: c.network,
        color: _colorNetwork,
      ),
      _ServiceNodeData(
        key: 'thixSante',
        icon: Icons.local_hospital_rounded,
        title: l10n.t('serviceSante'),
        badge: c.health,
        color: _colorHealth,
      ),
    ];
  }

  Offset _polar(Offset center, double angleDeg, double radius) {
    final rad = angleDeg * math.pi / 180;
    return center + Offset(radius * math.cos(rad), radius * math.sin(rad));
  }

  void _handleProfileTap() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    debugPrint('[Constellation] 👤 Profile tap');
    widget.onProfileTap();
  }

  void _handleServiceTap(String key) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    debugPrint('[Constellation] 🔷 Service tap: $key');
    widget.onServiceTap(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = _getGroupedNodes(l10n);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        child: SizedBox(
          height: _kStageHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final center = Offset(w / 2, _kStageHeight / 2);
              final maxR = math.min(
                w / 2 - ThixPolicy.constellationOuterPadding,
                ThixPolicy.constellationMaxRadius,
              );
              final innerR = maxR * 0.58;

              final positions = <Offset>[];

              // 4 nœuds internes
              for (var i = 0; i < 4; i++) {
                final angle = -135.0 + (i * 90.0);
                positions.add(_polar(center, angle, innerR));
              }

              // 8 nœuds externes
              for (var i = 0; i < 8; i++) {
                final angle = -90.0 + (i * 45.0);
                positions.add(_polar(center, angle, maxR));
              }

              final hubVisualRadius = _kHubRadius * _kHubShrink;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Arrière-plan lumineux central (subtil)
                  Positioned(
                    left: center.dx - 130,
                    top: center.dy - 130,
                    child: IgnorePointer(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              ThixPolicy.primary.withOpacity(0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lignes de connexion (statiques, pas d'animation)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _RadialBranchesPainter(
                          center: center,
                          nodeOffsets: positions,
                        ),
                      ),
                    ),
                  ),

                  // Nœuds de services
                  for (var i = 0; i < nodes.length; i++)
                    Positioned(
                      left: positions[i].dx - (_kNodeContainerWidth / 2),
                      top: positions[i].dy - (_kNodeCircleSize / 2),
                      child: RepaintBoundary(
                        child: _ConstellationNode(
                          data: nodes[i],
                          width: _kNodeContainerWidth,
                          circleSize: _kNodeCircleSize,
                          iconSize: _kNodeIconSize,
                          textSize: _kNodeTextSize,
                          onTap: () => _handleServiceTap(nodes[i].key),
                        ),
                      ),
                    ),

                  // Hub central (profil)
                  Positioned(
                    left: center.dx - hubVisualRadius,
                    top: center.dy - hubVisualRadius,
                    child: RepaintBoundary(
                      child: _HubButton(
                        radius: hubVisualRadius,
                        avatarUrl: widget.avatarUrl,
                        onTap: _handleProfileTap,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PAINTER (Lignes statiques, pas d'animation)
// ============================================================================
class _RadialBranchesPainter extends CustomPainter {
  final Offset center;
  final List<Offset> nodeOffsets;

  _RadialBranchesPainter({
    required this.center,
    required this.nodeOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Octogone extérieur
    if (nodeOffsets.length == 12) {
      final perimeterPaint = Paint()
        ..color = ThixPolicy.border.withOpacity(0.6)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (var i = 4; i < 12; i++) {
        final start = nodeOffsets[i];
        final end = (i == 11) ? nodeOffsets[4] : nodeOffsets[i + 1];
        canvas.drawLine(start, end, perimeterPaint);
      }
    }

    // Branches radiales
    final trackPaint = Paint()
      ..color = ThixPolicy.border.withOpacity(0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final end in nodeOffsets) {
      canvas.drawLine(center, end, trackPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialBranchesPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.nodeOffsets != nodeOffsets;
  }
}

// ============================================================================
// HUB BUTTON (Profil)
// ============================================================================
class _HubButton extends StatelessWidget {
  final double radius;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _HubButton({
    required this.radius,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profil utilisateur',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: ThixPolicy.border, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3.5),
          child: ClipOval(
            child: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!.trim(),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.person_rounded,
                        color: ThixPolicy.primaryDeep,
                        size: 24,
                      ),
                    ),
                  )
                : Container(
                    color: ThixPolicy.primary.withOpacity(0.1),
                    child: const Icon(
                      Icons.person_rounded,
                      color: ThixPolicy.primaryDeep,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SERVICE NODE
// ============================================================================
class _ConstellationNode extends StatefulWidget {
  final _ServiceNodeData data;
  final double width;
  final double circleSize;
  final double iconSize;
  final double textSize;
  final VoidCallback onTap;

  const _ConstellationNode({
    required this.data,
    required this.width,
    required this.circleSize,
    required this.iconSize,
    required this.textSize,
    required this.onTap,
  });

  @override
  State<_ConstellationNode> createState() => _ConstellationNodeState();
}

class _ConstellationNodeState extends State<_ConstellationNode> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final sanitizedTitle =
        d.title.length > _kMaxTitleLength ? d.title.substring(0, _kMaxTitleLength) : d.title;

    return Semantics(
      button: true,
      label: sanitizedTitle,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            width: widget.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Cercle (pas de BackdropFilter, juste Container solide)
                    Container(
                      width: widget.circleSize,
                      height: widget.circleSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.border, width: 1.3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(d.icon, color: d.color, size: widget.iconSize),
                    ),

                    // Badge
                    if (d.badge != null && d.badge! > 0)
                      Positioned(
                        top: -3,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.2),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: ThixPolicy.danger.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${d.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  sanitizedTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.textSize,
                    fontWeight: FontWeight.w700,
                    color: ThixPolicy.textMain,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
