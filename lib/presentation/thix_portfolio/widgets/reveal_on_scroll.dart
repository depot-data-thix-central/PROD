// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — WIDGET : RÉVÉLATION AU SCROLL
//  Fichier  : lib/presentation/thix_portfolio/widgets/reveal_on_scroll.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  Révèle son enfant (fade + slide/scale) la première fois qu'il entre
//  dans le viewport (> 15 % visible), puis reste stable (pas de rejeu).
//
//  • Durée & courbe pilotées par [BusinessAnimationStyle.durationScale/curve]
//  • Délai = [staggerIndex] × style.staggerMs  → effet cascade premium
//  • 6 directions : up, down, left, right, fade, scale
//  • Dépendance : visibility_detector (déjà ajoutée au pubspec)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/business_theme.dart';

enum RevealDirection { up, down, left, right, fade, scale }

class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({
    super.key,
    required this.child,
    this.style = BusinessAnimationStyle.elegant,
    this.direction = RevealDirection.up,
    this.staggerIndex = 0,
    this.distance = 0.12,
    this.visibleThreshold = 0.15,
  });

  final Widget child;
  final BusinessAnimationStyle style;
  final RevealDirection direction;

  /// Position dans la cascade (0 = immédiat, 1 = +staggerMs, …).
  final int staggerIndex;

  /// Amplitude du décalage (fraction d'écran, 0 → 1).
  final double distance;

  /// Seuil de visibilité déclenchant l'animation (0 → 1).
  final double visibleThreshold;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (650 * widget.style.durationScale).round(),
    ),
  );

  late Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: widget.style.curve,
  );

  bool _played = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    if (_played || !mounted) return;
    if (info.visibleFraction >= widget.visibleThreshold) {
      _played = true;
      _controller.forward();
    }
  }

  Offset get _beginOffset {
    switch (widget.direction) {
      case RevealDirection.up:
        return Offset(0, widget.distance);
      case RevealDirection.down:
        return Offset(0, -widget.distance);
      case RevealDirection.left:
        return Offset(widget.distance, 0);
      case RevealDirection.right:
        return Offset(-widget.distance, 0);
      case RevealDirection.fade:
      case RevealDirection.scale:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final delayed = widget.staggerIndex > 0
        ? DelayedAnimationWrapper(
            delay: Duration(
              milliseconds:
                  widget.staggerIndex * widget.style.staggerMs,
            ),
            controller: _controller,
            child: _buildAnimated(),
          )
        : _buildAnimated();

    return VisibilityDetector(
      key: ValueKey('thix-reveal-${widget.staggerIndex}-${hashCode}'),
      onVisibilityChanged: _onVisibility,
      child: delayed,
    );
  }

  Widget _buildAnimated() {
    switch (widget.direction) {
      case RevealDirection.scale:
        return FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(_curve),
            child: widget.child,
          ),
        );
      case RevealDirection.fade:
        return FadeTransition(opacity: _curve, child: widget.child);
      default:
        return FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(begin: _beginOffset, end: Offset.zero)
                .animate(_curve),
            child: widget.child,
          ),
        );
    }
  }
}

/// Applique un délai avant de lancer le controller partagé (cascade).
class DelayedAnimationWrapper extends StatefulWidget {
  const DelayedAnimationWrapper({
    super.key,
    required this.delay,
    required this.controller,
    required this.child,
  });

  final Duration delay;
  final AnimationController controller;
  final Widget child;

  @override
  State<DelayedAnimationWrapper> createState() =>
      _DelayedAnimationWrapperState();
}

class _DelayedAnimationWrapperState extends State<DelayedAnimationWrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Le controller parent est lancé par RevealOnScroll ; on retarde
    // simplement l'affichage de l'enfant jusqu'à échéance du délai.
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.shrink();
}
