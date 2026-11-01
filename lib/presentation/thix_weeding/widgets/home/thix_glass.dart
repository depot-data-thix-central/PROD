// lib/presentation/thix_weeding/widgets/thix_glass.dart
// ============================================================================
// THIX WEDDING — VERRE DÉPOLI (glassmorphism) partagé
// ============================================================================
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class ThixGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity;
  final Color tint;
  final Color? borderColor;
  final VoidCallback? onTap;

  const ThixGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = 18,
    this.opacity = 0.42,
    this.tint = Colors.white,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3B8F).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withOpacity((opacity + 0.2).clamp(0.0, 1.0).toDouble()),
                  tint.withOpacity(opacity),
                ],
              ),
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.8),
                width: 1.1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (onTap == null) return glass;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: glass,
    );
  }
}

/// Fond doux (dégradé + halos colorés) pour que le verre dépoli ait quelque chose à flouter.
class ThixGlassBackdrop extends StatelessWidget {
  final Widget child;
  const ThixGlassBackdrop({super.key, required this.child});

  Widget _blob(double size, Color c) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8FAFD), Color(0xFFEEF3FA), Color(0xFFFFF8E9)],
              ),
            ),
          ),
        ),
        Positioned(top: -90, right: -70, child: _blob(280, const Color(0xFFD4AF37).withOpacity(0.30))),
        Positioned(top: 240, left: -110, child: _blob(300, const Color(0xFF0B3B8F).withOpacity(0.16))),
        Positioned(bottom: -110, right: -50, child: _blob(320, const Color(0xFFE31C4E).withOpacity(0.12))),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Fond de barre d'app en verre dépoli (à mettre dans flexibleSpace).
class ThixGlassBar extends StatelessWidget {
  const ThixGlassBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(color: Colors.white.withOpacity(0.55)),
      ),
    );
  }
}
