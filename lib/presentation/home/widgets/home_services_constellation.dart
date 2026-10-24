// lib/presentation/home/widgets/home_services_constellation.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// THIX ID CENTRAL — "THIX HUB" · Roue orbitale radiale
// Rupture totale : ni colonnes, ni grilles, ni barres.
// Les 12 services gravitent sur un anneau rotatif (drag + snap + haptiques).
// API publique IDENTIQUE à l'ancien widget → drop-in.
//
// ÉVOLutions :
//  • Header : overline "THIX HUB" (titre "Services" supprimé).
//  • Services suspendus (reservation / sante / wallet) → "Bientôt à disposition".
//  • Thix Media devient "Thidia" (icône smart_display).
//  • Badges intelligents : pulse adaptatif selon criticité de la section.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ── CONSTANTES ──────────────────────────────────────────────────────────────
const int _kCount = 12;
const double _kStep = pi * 2 / _kCount;
const double _kNodeSize = 46.0;
const double _kHubSize = 122.0;
const int _kMaxBadgeDisplay = 99;

/// 🔒 Services temporairement suspendus → message "Bientôt à disposition".
const Set<String> _kSuspended = {'thixSante', 'thixMoney'};

/// Durées d'animation des badges
const Duration _kBadgePulseDuration = Duration(milliseconds: 900);
const Duration _kHubPulseDuration = Duration(milliseconds: 1400);

String _tr(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.trim().isEmpty || v == key) ? fallback : v;
}

double _angDist(double a, double b) {
  var d = (a - b) % (2 * pi);
  if (d > pi) d -= 2 * pi;
  if (d < -pi) d += 2 * pi;
  return d.abs();
}

// ── DATA MODEL ──────────────────────────────────────────────────────────────
class _ServiceNodeData {
  final String key;
  final IconData icon;
  final String label;
  final int? badge;
  final Color color;
  final ThixSection section;
  final bool pulseBadge; // Badge animé si section critique

  const _ServiceNodeData({
    required this.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.section,
    this.badge,
    this.pulseBadge = false,
  });
}

// ── WIDGET PUBLIC (API inchangée) ───────────────────────────────────────────
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

class _HomeServicesConstellationState extends State<HomeServicesConstellation>
    with SingleTickerProviderStateMixin {
  static const Color _colorCorporate = ThixPolicy.primaryDeep;
  static const Color _colorPrimary = ThixPolicy.primary;
  static const Color _colorMoney = ThixPolicy.gold;
  static const Color _colorHealth = ThixPolicy.danger;
  static const Color _colorMarket = ThixPolicy.domainMarket;
  static const Color _colorNetwork = ThixPolicy.domainNetwork;
  static const Color _colorLearning = ThixPolicy.domainLearning;
  static const Color _colorEvent = ThixPolicy.warning;

  double _angle = -pi / 2 - (7 * _kStep);
  double _radius = 140;
  int _focus = 7;
  bool _interacted = false;

  late final AnimationController _ctrl;
  Animation<double>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _ctrl.addListener(_onTick);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTick() {
    final a = _anim;
    if (a == null) return;
    setState(() => _angle = a.value);
    _syncFocus();
  }

  void _syncFocus() {
    final f = _computeFocus();
    if (f != _focus) {
      setState(() => _focus = f);
      HapticFeedback.selectionClick();
    }
  }

  int _computeFocus() {
    int best = 0;
    double bestD = double.infinity;
    for (int i = 0; i < _kCount; i++) {
      final d = _angDist(_base(i) + _angle, -pi / 2);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  double _base(int i) => i * _kStep;

  void _animateTo(double target) {
    _ctrl.stop();
    double t = target;
    while (t - _angle > pi) t -= 2 * pi;
    while (t - _angle < -pi) t += 2 * pi;
    _anim = Tween<double>(begin: _angle, end: t).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward(from: 0);
  }

  void _markInteracted() {
    if (!_interacted) setState(() => _interacted = true);
  }

  // ── GESTES ──
  void _onDragStart(DragStartDetails _) {
    _ctrl.stop();
    _markInteracted();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _angle += d.delta.dx / _radius);
    _syncFocus();
  }

  void _onDragEnd(DragEndDetails d) {
    final vel = (d.velocity.pixelsPerSecond.dx / 1400).clamp(-1.2, 1.2);
    final projected = _angle + vel * _kStep;
    _animateTo((projected / _kStep).round() * _kStep);
  }

  void _focusOn(int i) {
    _markInteracted();
    _animateTo(-pi / 2 - _base(i));
  }

  void _step(int dir) {
    _animateTo(((_angle / _kStep).round() + dir) * _kStep);
  }

  // ── OUVERTURE / SUSPENSION ──
  void _open(String key) {
    HapticFeedback.lightImpact();
    if (_kSuspended.contains(key)) {
      _showSoon();
      return;
    }
    widget.onServiceTap(key);
  }

  void _showSoon() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: ThixPolicy.primaryDeep,
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tr(l10n, 'soon_available', 'Bientôt à disposition'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _handleProfileTap() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    widget.onProfileTap();
  }

  /// ✅ Les 12 services avec leur section et flag pulse
  List<_ServiceNodeData> _nodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _ServiceNodeData(
        key: 'thixMoney',
        icon: Icons.account_balance_wallet_rounded,
        label: 'Thix ${l10n.t('svc_money')}',
        badge: c.money,
        color: _colorMoney,
        section: ThixSection.money,
        pulseBadge: true, // 💰 Transactions = urgence financière
      ),
      _ServiceNodeData(
        key: 'thixMarket',
        icon: Icons.storefront_rounded,
        label: 'Thix ${l10n.t('svc_market')}',
        badge: c.market,
        color: _colorMarket,
        section: ThixSection.market,
        pulseBadge: true, // 🛒 Commandes = action requise
      ),
      _ServiceNodeData(
        key: 'thixMedia',
        icon: Icons.smart_display_rounded,
        label: 'Thidia',
        badge: c.media,
        color: _colorNetwork,
        section: ThixSection.media,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'reservation',
        icon: Icons.confirmation_number_rounded,
        label: 'Thix ${l10n.t('svc_booking')}',
        badge: c.reservation,
        color: _colorPrimary,
        section: ThixSection.reservation,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'emplois',
        icon: Icons.work_rounded,
        label: 'Thix ${l10n.t('svc_jobs')}',
        badge: c.jobs,
        color: _colorCorporate,
        section: ThixSection.jobs,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'formations',
        icon: Icons.school_rounded,
        label: 'Thix ${l10n.t('svc_learning')}',
        badge: c.formations,
        color: _colorLearning,
        section: ThixSection.formations,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'opportunites',
        icon: Icons.lightbulb_rounded,
        label: 'Thix ${l10n.t('svc_opps')}',
        badge: c.opportunities,
        color: _colorMoney,
        section: ThixSection.opportunities,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'reseauPro',
        icon: Icons.groups_rounded,
        label: 'Thix ${l10n.t('svc_pro')}',
        badge: c.network,
        color: _colorNetwork,
        section: ThixSection.network,
        pulseBadge: true, // 👥 Interactions sociales = engagement
      ),
      _ServiceNodeData(
        key: 'monPays',
        icon: Icons.flag_rounded,
        label: 'Thix ${l10n.t('svc_country')}',
        badge: c.monPays,
        color: _colorCorporate,
        section: ThixSection.monPays,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'thixInfo',
        icon: Icons.newspaper_rounded,
        label: 'Thix ${l10n.t('svc_news')}',
        badge: c.info,
        color: _colorPrimary,
        section: ThixSection.info,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'evenements',
        icon: Icons.event_rounded,
        label: 'Thix ${l10n.t('svc_event')}',
        badge: c.events,
        color: _colorEvent,
        section: ThixSection.events,
        pulseBadge: false,
      ),
      _ServiceNodeData(
        key: 'thixSante',
        icon: Icons.local_hospital_rounded,
        label: 'Thix ${l10n.t('svc_health')}',
        badge: c.health,
        color: _colorHealth,
        section: ThixSection.health,
        pulseBadge: true, // 🚨 Santé = CRITIQUE
      ),
    ];
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = _nodes(l10n);
    final focused = nodes[_focus];

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ThixPolicy.s16,
          vertical: ThixPolicy.s8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth.clamp(260.0, 372.0);
            final center = size / 2;
            _radius = center - 30;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OrbitHeader(
                  avatarUrl: widget.avatarUrl,
                  onTap: _handleProfileTap,
                ),
                const SizedBox(height: 6),

                // ── ROUE ORBITALE ──
                Semantics(
                  container: true,
                  label: '${focused.label}, ${_focus + 1} sur $_kCount',
                  customSemanticsActions: {
                    CustomSemanticsAction(label: 'Service suivant'):
                        () => _step(1),
                    CustomSemanticsAction(label: 'Service précédent'):
                        () => _step(-1),
                  },
                  child: GestureDetector(
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: Size(size, size),
                            painter: _OrbitPainter(
                              radius: _radius,
                              hubRadius: _kHubSize / 2,
                              accent: focused.color,
                            ),
                          ),
                          for (int i = 0; i < nodes.length; i++)
                            _buildNode(nodes[i], i, center),
                          Positioned(
                            left: center - _kHubSize / 2,
                            top: center - _kHubSize / 2,
                            child: _OrbitHub(
                              node: focused,
                              size: _kHubSize,
                              onTap: () => _open(focused.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── INDICATEUR DE FOCale ──
                _OrbitDots(index: _focus, color: focused.color),

                // ── HINT (disparaît après 1ère interaction) ──
                AnimatedOpacity(
                  opacity: _interacted ? 0 : 1,
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _tr(l10n, 'orbit_hint', 'Faites glisser pour explorer'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ThixPolicy.textMain.withOpacity(0.45),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNode(_ServiceNodeData node, int i, double center) {
    final a = _base(i) + _angle;
    final dx = center + cos(a) * _radius;
    final dy = center + sin(a) * _radius;
    final t = 1 - (_angDist(a, -pi / 2) / pi);
    final scale = 0.78 + 0.34 * t;
    final opacity = 0.45 + 0.55 * t;
    final active = i == _focus;

    return Positioned(
      left: dx - _kNodeSize / 2,
      top: dy - _kNodeSize / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () => active ? _open(node.key) : _focusOn(i),
            child: _OrbitNode(node: node, active: active),
          ),
        ),
      ),
    );
  }
}

// ── NUD ORBITAL ────────────────────────────────────────────────────────────
class _OrbitNode extends StatelessWidget {
  final _ServiceNodeData node;
  final bool active;
  const _OrbitNode({required this.node, required this.active});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _kNodeSize,
          height: _kNodeSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? node.color : ThixPolicy.border.withOpacity(0.8),
              width: active ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? node.color.withOpacity(0.25)
                    : Colors.black.withOpacity(0.06),
                blurRadius: active ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(node.icon, color: node.color, size: 20),
        ),
        // ✅ Badge intelligent avec pulse conditionnel
        if (node.badge != null && node.badge! > 0)
          Positioned(
            top: -3,
            right: -3,
            child: _SmartBadge(
              count: node.badge!,
              section: node.section,
              color: node.color,
              pulse: node.pulseBadge,
            ),
          ),
      ],
    );
  }
}

// ── HUB CENTRAL CONTEXTUEL ──────────────────────────────────────────────────
class _OrbitHub extends StatelessWidget {
  final _ServiceNodeData node;
  final double size;
  final VoidCallback onTap;

  const _OrbitHub({
    required this.node,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = node.badge != null && node.badge! > 0;

    return Semantics(
      button: true,
      label: 'Ouvrir ${node.label}',
      child: GestureDetector(
        onTap: onTap,
        child: _HubPulseWrapper(
          active: hasBadge && node.pulseBadge,
          color: node.color,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [node.color, ThixPolicy.primaryDeep],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: node.color.withOpacity(0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(node.icon, color: Colors.white, size: 27),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          node.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ Badge du hub central avec pulse
                if (hasBadge)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _SmartBadge(
                      count: node.badge!,
                      section: node.section,
                      color: node.color,
                      pulse: node.pulseBadge,
                      size: _SmartBadgeSize.large,
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

// ── WRAPPER PULSE POUR LE HUB ────────────────────────────────────────────────
class _HubPulseWrapper extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color color;

  const _HubPulseWrapper({
    required this.child,
    required this.active,
    required this.color,
  });

  @override
  State<_HubPulseWrapper> createState() => _HubPulseWrapperState();
}

class _HubPulseWrapperState extends State<_HubPulseWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController? _ctrl;
  late Animation<double>? _anim;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _ctrl = AnimationController(
        vsync: this,
        duration: _kHubPulseDuration,
      )..repeat(reverse: true);
      _anim = Tween<double>(begin: 1.0, end: 1.05)
          .animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeInOut));
    } else {
      _ctrl = null;
      _anim = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _anim == null) return widget.child;

    return AnimatedBuilder(
      animation: _anim!,
      builder: (_, __) => Transform.scale(
        scale: _anim!.value,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Halo pulsant derrière le hub
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3 * _anim!.value),
                      blurRadius: 30 * _anim!.value,
                      spreadRadius: 2 * _anim!.value,
                    ),
                  ],
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// ── PEINTRE DÉCORATIF ────────────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double radius;
  final double hubRadius;
  final Color accent;

  _OrbitPainter({
    required this.radius,
    required this.hubRadius,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ThixPolicy.border.withOpacity(0.9);

    final orbit = Rect.fromCircle(center: c, radius: radius);
    for (double a = 0; a < 2 * pi; a += 0.09) {
      canvas.drawArc(orbit, a, 0.045, false, dash);
    }

    final hl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = accent.withOpacity(0.45);
    canvas.drawArc(orbit, -pi / 2 - 0.42, 0.84, false, hl);

    final inner = Rect.fromCircle(center: c, radius: hubRadius + 14);
    final dashLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = ThixPolicy.border.withOpacity(0.45);
    for (double a = 0; a < 2 * pi; a += 0.14) {
      canvas.drawArc(inner, a, 0.05, false, dashLight);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.radius != radius || old.accent != accent;
}

// ── POINTS DE FOCale ────────────────────────────────────────────────────────
class _OrbitDots extends StatelessWidget {
  final int index;
  final Color color;
  const _OrbitDots({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _kCount; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: i == index ? 16 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == index ? color : ThixPolicy.border,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ],
      ],
    );
  }
}

// ── SMART BADGE ──────────────────────────────────────────────────────────────
/// Badge intelligent avec :
/// - Limite 99+ pour les compteurs élevés
/// - Pulse adaptatif selon criticité de la section
/// - Couleur adaptative (pas toujours danger)
enum _SmartBadgeSize { small, large }

class _SmartBadge extends StatefulWidget {
  final int count;
  final ThixSection section;
  final Color color;
  final bool pulse;
  final _SmartBadgeSize size;

  const _SmartBadge({
    required this.count,
    required this.section,
    required this.color,
    this.pulse = false,
    this.size = _SmartBadgeSize.small,
  });

  @override
  State<_SmartBadge> createState() => _SmartBadgeState();
}

class _SmartBadgeState extends State<_SmartBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController? _pulseCtrl;
  late Animation<double>? _pulseAnim;

  /// Couleur adaptative selon la section
  Color get _badgeColor {
    switch (widget.section) {
      case ThixSection.health:
        return ThixPolicy.danger; // 🚨 Rouge urgence
      case ThixSection.money:
        return ThixPolicy.gold; // 💰 Or finance
      case ThixSection.market:
        return ThixPolicy.warning; // 🛒 Orange action
      case ThixSection.messages:
        return ThixPolicy.primary; // 💬 Bleu communication
      default:
        return widget.color; // Couleur du service par défaut
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: _kBadgePulseDuration,
      )..repeat(reverse: true);
      _pulseAnim = Tween<double>(begin: 1.0, end: 1.2)
          .animate(CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut));
    } else {
      _pulseCtrl = null;
      _pulseAnim = null;
    }
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  String get _displayText {
    if (widget.count > _kMaxBadgeDisplay) return '$_kMaxBadgeDisplay+';
    return '${widget.count}';
  }

  double get _minSize => widget.size == _SmartBadgeSize.large ? 20 : 16;
  double get _fontSize => widget.size == _SmartBadgeSize.large ? 9 : 8;
  double get _borderWidth => widget.size == _SmartBadgeSize.large ? 2 : 1.5;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: _borderWidth),
        boxShadow: [
          BoxShadow(
            color: _badgeColor.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: BoxConstraints(minWidth: _minSize, minHeight: _minSize),
      child: Center(
        child: Text(
          _displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: _fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    if (widget.pulse && _pulseAnim != null) {
      return AnimatedBuilder(
        animation: _pulseAnim!,
        builder: (_, __) => Transform.scale(
          scale: _pulseAnim!.value,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

// ── HEADER COMPACT : "THIX HUB" + profil ─────────────────────────────────────
class _OrbitHeader extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _OrbitHeader({required this.onTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    return Row(
      children: [
        const Text(
          'THIX HUB',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w800,
            color: ThixPolicy.primary,
          ),
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: 'Profil utilisateur',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.gold,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: url.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
