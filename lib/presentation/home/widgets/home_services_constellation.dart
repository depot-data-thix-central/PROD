// lib/presentation/home/widgets/home_services_constellation.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

/// Définition immuable des données d'un nœud de service.
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
  State<HomeServicesConstellation> createState() => _HomeServicesConstellationState();
}

class _HomeServicesConstellationState extends State<HomeServicesConstellation> with TickerProviderStateMixin {
  late final AnimationController _shineController;
  late final AnimationController _pulseController;

  static const double _stageHeight = ThixPolicy.constellationStageHeight;
  static const double _hubRadius = ThixPolicy.constellationHubRadius;

  // Constantes de géométrie réduites pour un look plus compact
  static const double _nodeContainerWidth = 52.0; // Réduit (était 60)
  static const double _nodeTextSize = 8.5; // Réduit (était 9.5)
  static const double _nodeCircleSize = 44.0; // Taille visuelle réduite du cercle du nœud
  static const double _nodeIconSize = 19.0; // Icône réduite en conséquence
  static const double _hubShrink = 0.85; // Facteur de réduction du hub central

  // ✅ PALETTE DIFFÉRENCIÉE : chaque service a sa propre teinte pour mieux le distinguer,
  // tout en restant dans le nuancier THIX existant (pas de nouvelle couleur inventée).
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
    _shineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Génère la liste des nœuds séparés en 2 orbites, chacun avec sa propre couleur
  List<_ServiceNodeData> _getGroupedNodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      // --- ORBITE INTERNE (4 nœuds) ---
      _ServiceNodeData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), badge: c.money, color: _colorMoney),
      // TDIA : icône fil vidéo / réseau social au lieu du simple bouton "play"
      _ServiceNodeData(key: 'thixMedia', icon: Icons.video_collection_rounded, title: 'TDIA', badge: c.media, color: _colorNetwork),
      _ServiceNodeData(key: 'monPays', icon: Icons.flag, title: l10n.t('serviceMonPays'), badge: c.monPays, color: _colorCorporate),
      _ServiceNodeData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', badge: c.info, color: _colorPrimary),

      // --- ORBITE EXTERNE (8 nœuds formant l'octogone) ---
      // Événements renommé en "Thix Event"
      _ServiceNodeData(key: 'evenements', icon: Icons.event_rounded, title: 'Thix Event', badge: c.events, color: _colorEvent),
      _ServiceNodeData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), badge: c.market, color: _colorMarket),
      _ServiceNodeData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), badge: c.reservation, color: _colorPrimary),
      _ServiceNodeData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), badge: c.jobs, color: _colorCorporate),
      _ServiceNodeData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), badge: c.formations, color: _colorLearning),
      _ServiceNodeData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), badge: c.opportunities, color: _colorMoney),
      _ServiceNodeData(key: 'reseauPro', icon: Icons.groups_rounded, title: 'Thix Pro', badge: c.network, color: _colorNetwork),
      _ServiceNodeData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), badge: c.health, color: _colorHealth),
    ];
  }

  Offset _polar(Offset center, double angleDeg, double radius) {
    final rad = angleDeg * math.pi / 180;
    return center + Offset(radius * math.cos(rad), radius * math.sin(rad));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = _getGroupedNodes(l10n);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: SizedBox(
        height: _stageHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final center = Offset(w / 2, _stageHeight / 2);
            final maxR = math.min(
              w / 2 - ThixPolicy.constellationOuterPadding,
              ThixPolicy.constellationMaxRadius,
            );
            final innerR = maxR * 0.58; 

            final positions = <Offset>[];

            // 1. Calcul des 4 Nœuds Internes
            for (var i = 0; i < 4; i++) {
              final angle = -135.0 + (i * 90.0); 
              positions.add(_polar(center, angle, innerR));
            }

            // 2. Calcul des 8 Nœuds Externes
            for (var i = 0; i < 8; i++) {
              final angle = -90.0 + (i * 45.0); 
              positions.add(_polar(center, angle, maxR));
            }

            final hubVisualRadius = _hubRadius * _hubShrink;

            return AnimatedBuilder(
              animation: Listenable.merge([_shineController, _pulseController]),
              builder: (context, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Arrière plan lumineux central (très subtil)
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
                              colors: [ThixPolicy.primary.withOpacity(0.08), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Lignes de connexion Corporate (Fines et translucides)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CorporateRadialBranchesPainter(
                          center: center,
                          nodeOffsets: positions,
                          shineProgress: _shineController.value,
                        ),
                      ),
                    ),

                    // Nœuds de services (Glassmorphism)
                    for (var i = 0; i < nodes.length; i++)
                      Positioned(
                        left: positions[i].dx - (_nodeContainerWidth / 2),
                        top: positions[i].dy - (_nodeCircleSize / 2),
                        child: _ConstellationNode(
                          data: nodes[i],
                          width: _nodeContainerWidth,
                          circleSize: _nodeCircleSize,
                          iconSize: _nodeIconSize,
                          textSize: _nodeTextSize,
                          onTap: () => widget.onServiceTap(nodes[i].key),
                        ),
                      ),

                    // Hub Central (Bouton Profil direct - Glassmorphism), réduit
                    Positioned(
                      left: center.dx - hubVisualRadius,
                      top: center.dy - hubVisualRadius,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onProfileTap(); // ✅ DIRECTEMENT AU PROFIL
                        },
                        child: Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.04),
                          child: Container(
                            width: hubVisualRadius * 2,
                            height: hubVisualRadius * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.6),
                                  ),
                                  padding: const EdgeInsets.all(3.5),
                                  child: ClipOval(
                                    child: (widget.avatarUrl != null && widget.avatarUrl!.trim().isNotEmpty)
                                        ? Image.network(
                                            widget.avatarUrl!.trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: ThixPolicy.primaryDeep, size: 24),
                                          )
                                        : Container(
                                            color: ThixPolicy.primary.withOpacity(0.1),
                                            child: const Icon(Icons.person_rounded, color: ThixPolicy.primaryDeep, size: 24),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Peint les branches avec un style très "Corporate" et "Premium" (Fines lignes translucides)
class _CorporateRadialBranchesPainter extends CustomPainter {
  final Offset center;
  final List<Offset> nodeOffsets;
  final double shineProgress;

  _CorporateRadialBranchesPainter({
    required this.center,
    required this.nodeOffsets,
    required this.shineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // TRACER L'OCTOGONE EXTÉRIEUR (Très fin et translucide)
    if (nodeOffsets.length == 12) {
      final perimeterPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (var i = 4; i < 12; i++) {
        final start = nodeOffsets[i];
        final end = (i == 11) ? nodeOffsets[4] : nodeOffsets[i + 1]; 
        canvas.drawLine(start, end, perimeterPaint);
      }
    }

    // TRACER LES BRANCHES RADIALES 
    for (var i = 0; i < nodeOffsets.length; i++) {
      final end = nodeOffsets[i];

      // Ligne très propre
      final trackPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center, end, trackPaint);

      // Étincelle voyageuse (Animation très subtile)
      final phase = i / nodeOffsets.length;
      final t = (shineProgress + phase) % 1.0;
      final shinePos = Offset.lerp(center, end, t)!;

      // Halo élégant blanc/doré
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.9), ThixPolicy.gold.withOpacity(0.2), Colors.transparent],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: shinePos, radius: 8));
      canvas.drawCircle(shinePos, 8, haloPaint);

      // Cœur de l'étincelle
      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(shinePos, 1.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CorporateRadialBranchesPainter oldDelegate) {
    return oldDelegate.shineProgress != shineProgress || oldDelegate.nodeOffsets != nodeOffsets;
  }
}

/// Nœud de service en style Glassmorphism Corporate
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

class _ConstellationNodeState extends State<_ConstellationNode> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final size = widget.circleSize;
    final iconSize = widget.iconSize;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        HapticFeedback.lightImpact();
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: widget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cercle Glassmorphism, teinté légèrement selon la couleur du service
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(d.color.withOpacity(0.06), Colors.white.withOpacity(0.65)),
                          shape: BoxShape.circle,
                          border: Border.all(color: d.color.withOpacity(0.35), width: 1.1),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(d.icon, color: d.color, size: iconSize),
                      ),
                    ),
                  ),
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
                          boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          '${d.badge}',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                d.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.textSize,
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain, // Texte foncé corporate
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
