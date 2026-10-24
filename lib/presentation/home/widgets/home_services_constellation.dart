// lib/presentation/home/widgets/home_services_constellation.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// THIX HUB — Roue orbitale (v3 « Pro Premium »)
//
// DESIGN :
//   • Palette corporate unifiée : blanc + bleu profond + or (signature THIX).
//   • Nœuds blancs premium, bordure or sur le focus (cohérence Apple/iOS).
//   • Hub central : dégradé bleu profond → or + reflet subtil + pulse adaptatif.
//   • Nameplate glassmorphism sous la roue (BackdropFilter).
//   • Badges or uniformes avec pulse sur sections critiques.
//   • Services suspendus : cadenas doré discret + snackbar premium.
//
// API publique IDENTIQUE aux v1/v2 → drop-in.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';

// ── CONSTANTES ──────────────────────────────────────────────────────────────
const int _kCount = 12;
const double _kStep = pi * 2 / _kCount;
const double _kNodeSize = 48.0;
const double _kHubSize = 124.0;
const int _kMaxBadgeDisplay = 99;

/// Services temporairement suspendus.
const Set<String> _kSuspended = {'thixSante', 'thixMoney'};

/// Durées d'animation
const Duration _kBadgePulseDuration = Duration(milliseconds: 1100);
const Duration _kHubPulseDuration = Duration(milliseconds: 1500);
const Duration _kOrbitAnimDuration = Duration(milliseconds: 420);

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
  final ThixSection section;
  final bool pulseBadge;
  final bool suspended;

  const _ServiceNodeData({
    required this.key,
    required this.icon,
    required this.label,
    required this.section,
    this.badge,
    this.pulseBadge = false,
    this.suspended = false,
  });
}

// ── WIDGET PUBLIC ───────────────────────────────────────────────────────────
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
  double _angle = -pi / 2 - (7 * _kStep);
  double _radius = 140;
  int _focus = 7;
  bool _interacted = false;

  late final AnimationController _ctrl;
  Animation<double>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kOrbitAnimDuration);
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

  void _step(int dir) => _animateTo(((_angle / _kStep).round() + dir) * _kStep);

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
          backgroundColor: ThixPolicy.inkDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: ThixPolicy.gold, size: 18),
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

  List<_ServiceNodeData> _nodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _ServiceNodeData(
        key: 'thixMoney',
        icon: Icons.account_balance_wallet_rounded,
        label: 'Thix ${l10n.t('svc_money')}',
        badge: c.money,
        section: ThixSection.money,
        pulseBadge: true,
        suspended: true,
      ),
      _ServiceNodeData(
        key: 'thixMarket',
        icon: Icons.storefront_rounded,
        label: 'Thix ${l10n.t('svc_market')}',
        badge: c.market,
        section: ThixSection.market,
        pulseBadge: true,
      ),
      _ServiceNodeData(
        key: 'thixMedia',
        icon: Icons.smart_display_rounded,
        label: 'Thidia',
        badge: c.media,
        section: ThixSection.media,
      ),
      _ServiceNodeData(
        key: 'reservation',
        icon: Icons.confirmation_number_rounded,
        label: 'Thix ${l10n.t('svc_booking')}',
        badge: c.reservation,
        section: ThixSection.reservation,
      ),
      _ServiceNodeData(
        key: 'emplois',
        icon: Icons.work_rounded,
        label: 'Thix ${l10n.t('svc_jobs')}',
        badge: c.jobs,
        section: ThixSection.jobs,
      ),
      _ServiceNodeData(
        key: 'formations',
        icon: Icons.school_rounded,
        label: 'Thix ${l10n.t('svc_learning')}',
        badge: c.formations,
        section: ThixSection.formations,
      ),
      _ServiceNodeData(
        key: 'opportunites',
        icon: Icons.lightbulb_rounded,
        label: 'Thix ${l10n.t('svc_opps')}',
        badge: c.opportunities,
        section: ThixSection.opportunities,
      ),
      _ServiceNodeData(
        key: 'reseauPro',
        icon: Icons.groups_rounded,
        label: 'Thix ${l10n.t('svc_pro')}',
        badge: c.network,
        section: ThixSection.network,
        pulseBadge: true,
      ),
      _ServiceNodeData(
        key: 'monPays',
        icon: Icons.flag_rounded,
        label: 'Thix ${l10n.t('svc_country')}',
        badge: c.monPays,
        section: ThixSection.monPays,
      ),
      _ServiceNodeData(
        key: 'thixInfo',
        icon: Icons.newspaper_rounded,
        label: 'Thix ${l10n.t('svc_news')}',
        badge: c.info,
        section: ThixSection.info,
      ),
      _ServiceNodeData(
        key: 'evenements',
        icon: Icons.event_rounded,
        label: 'Thix ${l10n.t('svc_event')}',
        badge: c.events,
        section: ThixSection.events,
      ),
      _ServiceNodeData(
        key: 'thixSante',
        icon: Icons.local_hospital_rounded,
        label: 'Thix ${l10n.t('svc_health')}',
        badge: c.health,
        section: ThixSection.health,
        pulseBadge: true,
        suspended: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = _nodes(l10n);
    final focused = nodes[_focus];

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth.clamp(280.0, 380.0);
            final center = size / 2;
            _radius = center - 34;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OrbitHeader(
                  avatarUrl: widget.avatarUrl,
                  onTap: _handleProfileTap,
                ),
                const SizedBox(height: 14),
                Semantics(
                  container: true,
                  label: '${focused.label}, ${_focus + 1} / $_kCount',
                  customSemanticsActions: {
                    const CustomSemanticsAction(label: 'Service suivant'):
                        () => _step(1),
                    const CustomSemanticsAction(label: 'Service précédent'):
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
                const SizedBox(height: 14),
                _NamePlate(label: focused.label, suspended: focused.suspended),
                const SizedBox(height: 12),
                _OrbitDots(index: _focus),
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

// ── NŒUD ORBITAL ────────────────────────────────────────────────────────────
class _OrbitNode extends StatelessWidget {
  final _ServiceNodeData node;
  final bool active;
  const _OrbitNode({required this.node, required this.active});

  @override
  Widget build(BuildContext context) {
    final showBadge = !node.suspended && node.badge != null && node.badge! > 0;
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
              color: active ? ThixPolicy.gold : ThixPolicy.border,
              width: active ? 2.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (active ? ThixPolicy.gold : ThixPolicy.inkDeep)
                    .withOpacity(active ? 0.22 : 0.08),
                blurRadius: active ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            node.icon,
            color: node.suspended
                ? ThixPolicy.textMuted
                : (active ? ThixPolicy.inkDeep : ThixPolicy.primaryDeep),
            size: 21,
          ),
        ),
        if (node.suspended)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ThixPolicy.inkDeep,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: const Icon(Icons.lock_rounded, size: 7, color: ThixPolicy.gold),
            ),
          ),
        if (showBadge)
          Positioned(
            top: -4,
            right: -4,
            child: _SmartBadge(count: node.badge!, pulse: node.pulseBadge),
          ),
      ],
    );
  }
}

// ── HUB CENTRAL ─────────────────────────────────────────────────────────────
class _OrbitHub extends StatelessWidget {
  final _ServiceNodeData node;
  final double size;
  final VoidCallback onTap;
  const _OrbitHub({required this.node, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBadge = !node.suspended && node.badge != null && node.badge! > 0;

    return Semantics(
      button: true,
      label: 'Ouvrir ${node.label}',
      child: GestureDetector(
        onTap: onTap,
        child: _HubPulseWrapper(
          active: hasBadge && node.pulseBadge,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C4A75), ThixPolicy.primaryDeep, ThixPolicy.gold],
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: ThixPolicy.inkDeep.withOpacity(0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: ThixPolicy.gold.withOpacity(0.18),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Reflet supérieur (effet 3D premium)
                Positioned(
                  top: 10,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.35),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(node.icon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          node.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _SmartBadge(
                      count: node.badge!,
                      pulse: node.pulseBadge,
                      large: true,
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

// ── WRAPPER PULSE POUR LE HUB ───────────────────────────────────────────────
class _HubPulseWrapper extends StatefulWidget {
  final Widget child;
  final bool active;
  const _HubPulseWrapper({required this.child, required this.active});

  @override
  State<_HubPulseWrapper> createState() => _HubPulseWrapperState();
}

class _HubPulseWrapperState extends State<_HubPulseWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: _kHubPulseDuration);
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _HubPulseWrapper old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final v = _anim.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ThixPolicy.gold.withOpacity(0.25 * v),
                      blurRadius: 28 * v,
                      spreadRadius: 4 * v,
                    ),
                  ],
                ),
              ),
            ),
            Transform.scale(scale: 1.0 + 0.03 * v, child: child),
          ],
        );
      },
      child: widget.child,
    );
  }
}

// ── PEINTRE ORBITAL ─────────────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double radius;
  final double hubRadius;
  _OrbitPainter({required this.radius, required this.hubRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Lueur centrale subtile
    canvas.drawCircle(
      c,
      radius + 18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            ThixPolicy.gold.withOpacity(0.10),
            ThixPolicy.primaryDeep.withOpacity(0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius + 18)),
    );

    // Anneau orbital pointillé (style blueprint technique)
    final orbit = Rect.fromCircle(center: c, radius: radius);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = ThixPolicy.border.withOpacity(0.7);
    for (double a = 0; a < 2 * pi; a += 0.12) {
      canvas.drawArc(orbit, a, 0.04, false, dash);
    }

    // Anneau intérieur plus fin
    final inner = Rect.fromCircle(center: c, radius: hubRadius + 18);
    final innerDash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = ThixPolicy.border.withOpacity(0.4);
    for (double a = 0; a < 2 * pi; a += 0.16) {
      canvas.drawArc(inner, a, 0.05, false, innerDash);
    }

    // Repère de focus (arc doré en haut)
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = ThixPolicy.gold.withOpacity(0.55);
    canvas.drawArc(orbit, -pi / 2 - 0.42, 0.84, false, highlight);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.radius != radius || old.hubRadius != hubRadius;
}

// ── NAMEPLATE GLASSMORPHISM ─────────────────────────────────────────────────
class _NamePlate extends StatelessWidget {
  final String label;
  final bool suspended;
  const _NamePlate({required this.label, required this.suspended});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: ClipRRect(
        key: ValueKey(label),
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ThixPolicy.gold.withOpacity(0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: ThixPolicy.inkDeep.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: suspended ? ThixPolicy.textMuted : ThixPolicy.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                if (suspended) ...[
                  const Icon(Icons.lock_rounded, size: 11, color: ThixPolicy.textMuted),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ThixPolicy.inkDeep,
                    letterSpacing: 0.4,
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

// ── DOTS DE FOCALISATION ────────────────────────────────────────────────────
class _OrbitDots extends StatelessWidget {
  final int index;
  const _OrbitDots({required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _kCount; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            width: i == index ? 20 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == index ? ThixPolicy.gold : ThixPolicy.border,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ],
      ],
    );
  }
}

// ── SMART BADGE (or uniforme + pulse sur sections critiques) ────────────────
class _SmartBadge extends StatefulWidget {
  final int count;
  final bool pulse;
  final bool large;
  const _SmartBadge({required this.count, this.pulse = false, this.large = false});

  @override
  State<_SmartBadge> createState() => _SmartBadgeState();
}

class _SmartBadgeState extends State<_SmartBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: _kBadgePulseDuration);
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SmartBadge old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.large ? 20.0 : 17.0;
    final text = widget.count > _kMaxBadgeDisplay ? '$_kMaxBadgeDisplay+' : '${widget.count}';
    final badge = Container(
      constraints: BoxConstraints(minWidth: min, minHeight: min),
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
      decoration: BoxDecoration(
        color: ThixPolicy.gold,
        borderRadius: BorderRadius.circular(min),
        border: Border.all(color: Colors.white, width: widget.large ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.gold.withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: ThixPolicy.inkDeep,
          fontSize: widget.large ? 9.5 : 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (!widget.pulse) return badge;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + 0.14 * _anim.value,
        child: child,
      ),
      child: badge,
    );
  }
}

// ── HEADER « THIX HUB » + AVATAR ────────────────────────────────────────────
class _OrbitHeader extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;
  const _OrbitHeader({required this.onTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Signature visuelle : point or + barre fine
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: ThixPolicy.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 18,
            height: 1.5,
            decoration: BoxDecoration(
              color: ThixPolicy.gold.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'THIX HUB',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 3.5,
              fontWeight: FontWeight.w900,
              color: ThixPolicy.primaryDeep,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Profil utilisateur',
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [ThixPolicy.gold, ThixPolicy.primaryDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThixPolicy.inkDeep.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: ThixPolicy.primaryDeep,
                              size: 22,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: ThixPolicy.primaryDeep,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
