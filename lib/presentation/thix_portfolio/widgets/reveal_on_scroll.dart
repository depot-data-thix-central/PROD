// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — WIDGET : RÉVÉLATION AU SCROLL
//  Fichier  : lib/presentation/thix_portfolio/widgets/reveal_on_scroll.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.2 — Novembre 2026 (CORRIGÉ CI)
// ════════════════════════════════════════════════════════════════════════════
//
//  Corrections CI :
//    • Suppression de la dépendance `visibility_detector` (non installée)
//    • Approche 100 % native : écoute du ScrollController parent
//      pour détecter quand le widget entre dans le viewport.
//    • Fallback : si aucun Scrollable parent, animation immédiate au build.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  final int staggerIndex;
  final double distance;
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
  ScrollPosition? _position;
  final GlobalKey _widgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Démarre immédiatement si pas de scrollable parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attach();
      if (!_played && mounted) {
        _checkVisibility();
      }
    });
  }

  void _attach() {
    _detach();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != null) {
      _position = pos;
      _position!.addListener(_checkVisibility);
    } else {
      // Pas de scrollable parent → animation immédiate
      _play();
    }
  }

  void _detach() {
    _position?.removeListener(_checkVisibility);
    _position = null;
  }

  void _checkVisibility() {
    if (_played || !mounted) return;
    final renderBox = _widgetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final widgetOffset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final widgetHeight = renderBox.size.height;

    // Le widget est-il visible à >= threshold % de sa hauteur ?
    final visibleTop = widgetOffset.dy.clamp(0.0, screenHeight.toDouble());
    final visibleBottom = (widgetOffset.dy + widgetHeight).clamp(0.0, screenHeight.toDouble());
    final visibleHeight = visibleBottom - visibleTop;
    final visibleFraction = visibleHeight / widgetHeight;

    if (visibleFraction >= widget.visibleThreshold) {
      _play();
    }
  }

  void _play() {
    if (_played) return;
    _played = true;
    // Applique le délai stagger
    Future.delayed(
      Duration(milliseconds: widget.staggerIndex * widget.style.staggerMs),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _detach();
    _controller.dispose();
    super.dispose();
  }

  Offset get _beginOffset {
    switch (widget.direction) {
      case RevealDirection.up:    return Offset(0, widget.distance);
      case RevealDirection.down:  return Offset(0, -widget.distance);
      case RevealDirection.left:  return Offset(widget.distance, 0);
      case RevealDirection.right: return Offset(-widget.distance, 0);
      case RevealDirection.fade:
      case RevealDirection.scale: return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget animated;
    switch (widget.direction) {
      case RevealDirection.scale:
        animated = FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(_curve),
            child: widget.child,
          ),
        );
      case RevealDirection.fade:
        animated = FadeTransition(opacity: _curve, child: widget.child);
      default:
        animated = FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(begin: _beginOffset, end: Offset.zero)
                .animate(_curve),
            child: widget.child,
          ),
        );
    }

    return Container(key: _widgetKey, child: animated);
  }
}
