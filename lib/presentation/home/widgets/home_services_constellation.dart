// lib/presentation/home/widgets/home_services_constellation.dart
import 'dart:async';
import 'dart:math' as math;
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
  final Color color;
  final int? badge;
  
  const _ServiceNodeData({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    this.badge,
  });
}

/// Définition immuable des données d'un élément du menu central (Hub).
class _HubMenuItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _HubMenuItemData({
    required this.icon,
    required this.label,
    required this.onTap,
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

  const HomeServicesConstellation({
    super.key,
    required this.counts,
    required this.onServiceTap,
    required this.onHomeTap,
    required this.onMiniAppsTap,
    required this.onDocumentsTap,
    required this.onProfileTap,
    required this.onScanTap,
  });

  @override
  State<HomeServicesConstellation> createState() => _HomeServicesConstellationState();
}

class _HomeServicesConstellationState extends State<HomeServicesConstellation> with TickerProviderStateMixin {
  late final AnimationController _shineController;
  late final AnimationController _pulseController;
  
  bool _menuExpanded = false;
  Timer? _collapseTimer;

  static const double _stageHeight = ThixPolicy.constellationStageHeight;
  static const double _hubRadius = ThixPolicy.constellationHubRadius;
  static const double _hubMenuRadius = ThixPolicy.constellationHubMenuRadius;
  static const double _hubMenuNodeSize = ThixPolicy.constellationHubMenuNodeSize;
  
  // Constantes de géométrie affinées pour un look plus "propre"
  static const double _nodeContainerWidth = 56.0; // Réduit de 70 à 56 pour limiter les chevauchements
  static const double _nodeTextSize = 9.0; // Réduit pour plus de clarté
  
  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shineController.dispose();
    _pulseController.dispose();
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _armAutoCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _menuExpanded = false);
    });
  }

  void _toggleHubMenu() {
    HapticFeedback.mediumImpact();
    setState(() => _menuExpanded = !_menuExpanded);
    if (_menuExpanded) {
      _armAutoCollapse();
    } else {
      _collapseTimer?.cancel();
    }
  }

  void _runHubItem(VoidCallback action) {
    _collapseTimer?.cancel();
    setState(() => _menuExpanded = false);
    action();
  }

  /// Génère la liste des nœuds **triés par catégories logiques**
  /// pour que les icônes similaires se suivent sur le cercle.
  List<_ServiceNodeData> _getGroupedNodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      // --- CATÉGORIE 1 : Contenu & Médias ---
      _ServiceNodeData(key: 'thixMedia', icon: Icons.play_circle_filled, title: 'TDIA', color: ThixPolicy.domainMedia, badge: c.media),
      _ServiceNodeData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', color: ThixPolicy.domainInfo, badge: c.info),
      _ServiceNodeData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), color: ThixPolicy.domainEvents, badge: c.events),
      
      // --- CATÉGORIE 2 : Économie & Transactions ---
      _ServiceNodeData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), color: ThixPolicy.domainMoney, badge: c.money),
      _ServiceNodeData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), color: ThixPolicy.domainMarket, badge: c.market),
      _ServiceNodeData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), color: ThixPolicy.domainReservation, badge: c.reservation),
      
      // --- CATÉGORIE 3 : Carrière, Éducation & Réseau ---
      _ServiceNodeData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), color: ThixPolicy.domainJobs, badge: c.jobs),
      _ServiceNodeData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), color: ThixPolicy.domainLearning, badge: c.formations),
      _ServiceNodeData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), color: ThixPolicy.domainOpportunity, badge: c.opportunities),
      // Remplacement ici : "Thix Pro" au lieu de la localisation par défaut
      _ServiceNodeData(key: 'reseauPro', icon: Icons.groups_rounded, title: 'Thix Pro', color: ThixPolicy.domainNetwork, badge: c.network),
      
      // --- CATÉGORIE 4 : Vie Pratique & Gouvernement ---
      _ServiceNodeData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), color: ThixPolicy.domainHealth, badge: c.health),
      _ServiceNodeData(key: 'monPays', icon: Icons.flag, title: l10n.t('serviceMonPays'), color: ThixPolicy.domainGov, badge: c.monPays),
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
    
    final hubItems = <_HubMenuItemData>[
      _HubMenuItemData(icon: Icons.home_filled, label: l10n.t('hub_home'), onTap: () => _runHubItem(widget.onHomeTap)),
      _HubMenuItemData(icon: Icons.apps_rounded, label: l10n.t('hub_mini_apps'), onTap: () => _runHubItem(widget.onMiniAppsTap)),
      _HubMenuItemData(icon: Icons.folder_rounded, label: l10n.t('hub_documents'), onTap: () => _runHubItem(widget.onDocumentsTap)),
      _HubMenuItemData(icon: Icons.person_outline_rounded, label: l10n.t('hub_profile'), onTap: () => _runHubItem(widget.onProfileTap)),
      _HubMenuItemData(icon: Icons.qr_code_scanner_rounded, label: l10n.t('hub_scan_qr'), onTap: () => _runHubItem(widget.onScanTap)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 15, color: ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.t('servicesTitle'),
                style: const TextStyle(color: ThixPolicy.textMain, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _stageHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final center = Offset(w / 2, _stageHeight / 2 - 6);
                final maxR = math.min(
                  w / 2 - ThixPolicy.constellationOuterPadding,
                  ThixPolicy.constellationMaxRadius,
                );
                
                final nodeCount = nodes.length;
                final positions = <Offset>[];
                
                // Calcul de la géométrie de la constellation
                for (var i = 0; i < nodeCount; i++) {
                  final angle = -90.0 + (i * (360.0 / nodeCount));
                  // Le rayon alterné permet de faire respirer les icônes adjacentes
                  final radius = i.isEven ? maxR : maxR * ThixPolicy.constellationInnerFactor;
                  positions.add(_polar(center, angle, radius));
                }
                
                final hubPositions = <Offset>[];
                for (var i = 0; i < hubItems.length; i++) {
                  final angle = -90.0 + (i * (360.0 / hubItems.length));
                  hubPositions.add(_polar(center, angle, _hubMenuRadius));
                }
                
                return AnimatedBuilder(
                  animation: Listenable.merge([_shineController, _pulseController]),
                  builder: (context, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Arrière plan lumineux central
                        Positioned(
                          left: center.dx - 130,
                          top: center.dy - 130,
                          child: IgnorePointer(
                            child: Container(
                              width: 260, height: 260,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [ThixPolicy.gold.withValues(alpha: 0.10), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Lignes de connexion (optimisées avec RepaintBoundary dans l'idéal)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RadialBranchesPainter(
                              center: center,
                              nodeOffsets: positions,
                              shineProgress: _shineController.value,
                            ),
                          ),
                        ),
                        // Nœuds de services (Orbite)
                        for (var i = 0; i < nodes.length; i++)
                          Positioned(
                            left: positions[i].dx - (_nodeContainerWidth / 2),
                            top: positions[i].dy - ThixPolicy.constellationNodeHalf,
                            child: _ConstellationNode(
                              data: nodes[i],
                              width: _nodeContainerWidth,
                              textSize: _nodeTextSize,
                              onTap: () => widget.onServiceTap(nodes[i].key),
                            ),
                          ),
                        // Satellites du Hub (Menu interne)
                        for (var i = 0; i < hubItems.length; i++)
                          Positioned(
                            left: hubPositions[i].dx - (_hubMenuNodeSize / 2),
                            top: hubPositions[i].dy - (_hubMenuNodeSize / 2),
                            child: _HubSatelliteButton(
                              visible: _menuExpanded,
                              order: i,
                              size: _hubMenuNodeSize,
                              icon: hubItems[i].icon,
                              label: hubItems[i].label,
                              onTap: hubItems[i].onTap,
                            ),
                          ),
                        // Hub Central (Bouton d'interaction)
                        Positioned(
                          left: center.dx - _hubRadius,
                          top: center.dy - _hubRadius,
                          child: GestureDetector(
                            onTap: _toggleHubMenu,
                            child: Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.05),
                              child: AnimatedRotation(
                                turns: _menuExpanded ? 0.125 : 0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: Container(
                                  width: _hubRadius * 2, height: _hubRadius * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [ThixPolicy.gold, ThixPolicy.premiumAccent],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: ThixPolicy.gold.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1),
                                      BoxShadow(color: ThixPolicy.premiumAccent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                                    ],
                                    border: Border.all(color: Colors.white, width: 2.4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(_menuExpanded ? Icons.close_rounded : Icons.grid_view_rounded, color: Colors.white, size: 26),
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
        ],
      ),
    );
  }
}

class _HubSatelliteButton extends StatelessWidget {
  final bool visible;
  final int order;
  final double size;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _HubSatelliteButton({
    required this.visible,
    required this.order,
    required this.size,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.4,
      duration: Duration(milliseconds: 180 + order * 30),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: Duration(milliseconds: 150 + order * 30),
        child: IgnorePointer(
          ignoring: !visible,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.premiumAccent.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: ThixPolicy.premiumAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialBranchesPainter extends CustomPainter {
  final Offset center;
  final List<Offset> nodeOffsets;
  final double shineProgress;
  
  // Paint mis en cache pour optimiser les FPS (Standard Entreprise)
  final Paint _trailPaint = Paint();
  final Paint _coreShinePaint = Paint()..color = Colors.white;

  _RadialBranchesPainter({
    required this.center, 
    required this.nodeOffsets, 
    required this.shineProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < nodeOffsets.length; i++) {
      final end = nodeOffsets[i];
      
      // Ligne de base
      final basePaint = Paint()
        ..shader = LinearGradient(
          colors: [ThixPolicy.gold.withValues(alpha: 0.38), ThixPolicy.premiumAccent.withValues(alpha: 0.30)]
        ).createShader(Rect.fromPoints(center, end))
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
        
      canvas.drawLine(center, end, basePaint);
      
      // Animation lumineuse (Shine)
      final phase = i / nodeOffsets.length;
      final t = (shineProgress + phase) % 1.0;
      final shinePos = Offset.lerp(center, end, t)!;
      
      for (var trail = 1; trail <= 4; trail++) {
        final trailT = t - (trail * 0.03);
        if (trailT < 0) continue;
        final trailPos = Offset.lerp(center, end, trailT)!;
        final alpha = (0.28 - trail * 0.06).clamp(0.0, 0.28);
        
        _trailPaint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(trailPos, 2.4 - (trail * 0.3), _trailPaint);
      }
      
      // Halo lumineux
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.85), ThixPolicy.gold.withValues(alpha: 0.0)]
        ).createShader(Rect.fromCircle(center: shinePos, radius: 7));
        
      canvas.drawCircle(shinePos, 7, haloPaint);
      canvas.drawCircle(shinePos, 2.0, _coreShinePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _RadialBranchesPainter oldDelegate) {
    return oldDelegate.shineProgress != shineProgress || 
           oldDelegate.nodeOffsets != nodeOffsets;
  }
}

class _ConstellationNode extends StatefulWidget {
  final _ServiceNodeData data;
  final double width;
  final double textSize;
  final VoidCallback onTap;
  
  const _ConstellationNode({
    required this.data, 
    required this.width,
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
    final size = ThixPolicy.constellationNodeSize;
    final iconSize = ThixPolicy.constellationNodeIconSize;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: widget.width, // Largeur stricte pour éviter les conflits
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: d.color.withValues(alpha: 0.35), width: 1.2),
                      boxShadow: [BoxShadow(color: d.color.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: Icon(d.icon, color: d.color, size: iconSize),
                  ),
                  if (d.badge != null && d.badge! > 0)
                    Positioned(
                      top: -4, right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          '${d.badge}', 
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Texte optimisé : taille réduite, condensé et avec ellipsis
              Text(
                d.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.textSize, 
                  fontWeight: FontWeight.w700, 
                  color: ThixPolicy.textMain, 
                  height: 1.1,
                  letterSpacing: -0.2, // Rend le texte plus compact
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
