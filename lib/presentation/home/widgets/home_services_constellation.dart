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

  bool _menuExpanded = false;
  Timer? _collapseTimer;

  static const double _stageHeight = ThixPolicy.constellationStageHeight;
  static const double _hubRadius = ThixPolicy.constellationHubRadius;
  static const double _hubMenuRadius = ThixPolicy.constellationHubMenuRadius;
  static const double _hubMenuNodeSize = ThixPolicy.constellationHubMenuNodeSize;

  // Constantes de géométrie affinées pour un look plus "propre"
  static const double _nodeContainerWidth = 56.0;
  static const double _nodeTextSize = 9.0;

  // Palette par catégorie — chaque service retrouve sa propre couleur.
  // Le CERCLE reste mono (blanc) ; seule l'icône est teintée.
  static const Color _colorMedia = Color(0xFF7C3AED); // violet — TDIA
  static const Color _colorInfo = Color(0xFF2D6CDF); // bleu — THIX MEDIA
  static const Color _colorEvents = Color(0xFFE0703C); // orange — Événements
  static const Color _colorMoney = Color(0xFF1F9D6F); // vert — Thix Money
  static const Color _colorMarket = Color(0xFFE0A23C); // ambre — THIX Market
  static const Color _colorReservation = Color(0xFF0FA3A3); // teal — Réservation
  static const Color _colorJobs = Color(0xFF2E9E5B); // vert — Emplois
  static const Color _colorFormations = Color(0xFF2D6CDF); // bleu — Formations
  static const Color _colorOpportunities = Color(0xFFE3B23C); // or — Opportunités
  static const Color _colorNetwork = Color(0xFF5B4FDB); // indigo — Thix Pro
  static const Color _colorHealth = Color(0xFFE0453C); // rouge — THIX Santé
  static const Color _colorCountry = Color(0xFF123B7A); // navy — Mon Pays

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
  /// Chaque nœud porte désormais sa propre couleur d'icône.
  List<_ServiceNodeData> _getGroupedNodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      // --- CATÉGORIE 1 : Contenu & Médias ---
      _ServiceNodeData(key: 'thixMedia', icon: Icons.play_circle_filled, title: 'TDIA', badge: c.media, color: _colorMedia),
      _ServiceNodeData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', badge: c.info, color: _colorInfo),
      _ServiceNodeData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), badge: c.events, color: _colorEvents),

      // --- CATÉGORIE 2 : Économie & Transactions ---
      _ServiceNodeData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), badge: c.money, color: _colorMoney),
      _ServiceNodeData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), badge: c.market, color: _colorMarket),
      _ServiceNodeData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), badge: c.reservation, color: _colorReservation),

      // --- CATÉGORIE 3 : Carrière, Éducation & Réseau ---
      _ServiceNodeData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), badge: c.jobs, color: _colorJobs),
      _ServiceNodeData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), badge: c.formations, color: _colorFormations),
      _ServiceNodeData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), badge: c.opportunities, color: _colorOpportunities),
      _ServiceNodeData(key: 'reseauPro', icon: Icons.groups_rounded, title: 'Thix Pro', badge: c.network, color: _colorNetwork),

      // --- CATÉGORIE 4 : Vie Pratique & Gouvernement ---
      _ServiceNodeData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), badge: c.health, color: _colorHealth),
      _ServiceNodeData(key: 'monPays', icon: Icons.flag, title: l10n.t('serviceMonPays'), badge: c.monPays, color: _colorCountry),
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

            final nodeCount = nodes.length;
            final positions = <Offset>[];

            // Calcul de la géométrie de la constellation
            for (var i = 0; i < nodeCount; i++) {
              final angle = -90.0 + (i * (360.0 / nodeCount));
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
                    // Arrière plan lumineux central — teinte or/ivoire, plus de violet
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
                              colors: [ThixPolicy.gold.withValues(alpha: 0.10), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Lignes de connexion — effet "petite tranchée" mono-couleur
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RadialBranchesPainter(
                          center: center,
                          nodeOffsets: positions,
                          shineProgress: _shineController.value,
                        ),
                      ),
                    ),
                    // Nœuds de services (Orbite) — icône colorée, cercle mono
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
                    // Hub Central — Avatar utilisateur
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
                              width: _hubRadius * 2,
                              height: _hubRadius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [ThixPolicy.gold, ThixPolicy.primaryDeep],
                                ),
                                boxShadow: [
                                  BoxShadow(color: ThixPolicy.gold.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1),
                                  BoxShadow(color: ThixPolicy.primaryDeep.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                                ],
                                border: Border.all(color: Colors.white, width: 2.4),
                              ),
                              alignment: Alignment.center,
                              child: _menuExpanded
                                  ? const Icon(Icons.close_rounded, color: Colors.white, size: 26)
                                  : ClipOval(
                                      child: (widget.avatarUrl != null && widget.avatarUrl!.trim().isNotEmpty)
                                          ? Image.network(
                                              widget.avatarUrl!.trim(),
                                              fit: BoxFit.cover,
                                              width: _hubRadius * 2 - 6,
                                              height: _hubRadius * 2 - 6,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                                            )
                                          : const Icon(Icons.person_rounded, color: Colors.white, size: 26),
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
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.primaryDeep.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: ThixPolicy.primaryDeep),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Peint les branches reliant le hub aux nœuds de service.
/// Rendu "petite tranchée" : mono-couleur (blanc), un léger ombrage
/// sous le trait pour donner un effet gravé/creusé plutôt qu'un
/// dégradé coloré. Les étincelles qui voyagent le long des branches
/// restent visibles et lumineuses (halo + reflet en croix).
class _RadialBranchesPainter extends CustomPainter {
  final Offset center;
  final List<Offset> nodeOffsets;
  final double shineProgress;

  _RadialBranchesPainter({
    required this.center,
    required this.nodeOffsets,
    required this.shineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < nodeOffsets.length; i++) {
      final end = nodeOffsets[i];

      // ── Effet "tranchée" : ombre fine creusée sous le trait ──
      final groovePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center + const Offset(0, 1.1), end + const Offset(0, 1.1), groovePaint);

      // ── Trait principal — blanc mono-couleur ──
      final trackPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center, end, trackPaint);

      // ── Fin liseré intérieur clair pour accentuer le relief gravé ──
      final innerHighlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center - const Offset(0, 0.5), end - const Offset(0, 0.5), innerHighlight);

      // ── Étincelle voyageuse — beaucoup plus visible ──
      final phase = i / nodeOffsets.length;
      final t = (shineProgress + phase) % 1.0;
      final shinePos = Offset.lerp(center, end, t)!;

      // traînée de particules
      for (var trail = 1; trail <= 5; trail++) {
        final trailT = t - (trail * 0.028);
        if (trailT < 0) continue;
        final trailPos = Offset.lerp(center, end, trailT)!;
        final alpha = (0.40 - trail * 0.07).clamp(0.0, 0.40);
        final trailPaint = Paint()..color = ThixPolicy.gold.withValues(alpha: alpha);
        canvas.drawCircle(trailPos, 3.0 - (trail * 0.35), trailPaint);
      }

      // halo large et lumineux
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.95), ThixPolicy.gold.withValues(alpha: 0.35), Colors.transparent],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: shinePos, radius: 11));
      canvas.drawCircle(shinePos, 11, haloPaint);

      // reflet en croix (glint) — rend l'étincelle bien plus visible
      final glintPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(shinePos - const Offset(5, 0), shinePos + const Offset(5, 0), glintPaint);
      canvas.drawLine(shinePos - const Offset(0, 5), shinePos + const Offset(0, 5), glintPaint);

      // cœur de l'étincelle
      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(shinePos, 2.3, corePaint);
      final coreGoldPaint = Paint()..color = ThixPolicy.gold;
      canvas.drawCircle(shinePos, 1.0, coreGoldPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialBranchesPainter oldDelegate) {
    return oldDelegate.shineProgress != shineProgress || oldDelegate.nodeOffsets != nodeOffsets;
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
          width: widget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cercle MONO-couleur — blanc, bordure et ombre neutres.
                  // Seule l'icône à l'intérieur porte la couleur du service.
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.border, width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x14123B7A), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(d.icon, color: d.color, size: iconSize),
                  ),
                  if (d.badge != null && d.badge! > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          '${d.badge}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
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
