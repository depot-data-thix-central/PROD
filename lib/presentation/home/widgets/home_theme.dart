// lib/presentation/home/widgets/home_theme.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Palette Home : blanc + bleu ciel. Une seule couleur d'accent.
class HomeTheme {
  HomeTheme._();

  static const Color sky = Color(0xFF4DA8E8);
  static const Color skyDeep = Color(0xFF2B7BC4);
  static const Color skySoft = Color(0xFFEAF4FC);
  static const Color skyMist = Color(0xFFF4F9FE);
  static const Color ink = Color(0xFF12304D);
  static const Color inkSoft = Color(0xFF5B7287);
  static const Color line = Color(0xFFDCEAF6);
  static const Color alert = Color(0xFFE5484D);

  static List<BoxShadow> softShadow([double opacity = 0.08]) => [
        BoxShadow(
          color: skyDeep.withOpacity(opacity),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Carte « verre dépoli ». [blur] = 0 → transparence simple (plus léger).
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;
  final bool shadow;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.blur = 0,
    this.opacity = 0.78,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
        boxShadow: shadow ? HomeTheme.softShadow() : null,
      ),
      child: child,
    );
    if (blur <= 0) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: box,
      ),
    );
  }
}
