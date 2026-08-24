// lib/presentation/home/widgets/home_background.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSoftBackground extends StatefulWidget {
  const HomeSoftBackground({super.key});

  @override
  State<HomeSoftBackground> createState() => _HomeSoftBackgroundState();
}

class _HomeSoftBackgroundState extends State<HomeSoftBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animation très lente (25 secondes pour un tour complet) pour un effet relaxant
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 25))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary( // Optimisation des performances
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // "t" va de 0.0 à 2*PI au fil de l'animation
            final t = _controller.value * 2 * math.pi;

            // Orb 1 : Bleu THIX (Bouge en cercle en haut à gauche)
            final x1 = -100.0 + math.cos(t) * 120.0;
            final y1 = -50.0 + math.sin(t) * 80.0;

            // Orb 2 : Or (Bouge en huit/ellipse au centre droit)
            final x2 = size.width - 250.0 + math.sin(t * 1.3) * 150.0;
            final y2 = size.height * 0.3 + math.cos(t * 0.8) * 120.0;

            // Orb 3 : Indigo THIX (Bouge en arc en bas à gauche)
            final x3 = -50.0 + math.cos(t * 1.5) * 150.0;
            final y3 = size.height - 200.0 + math.sin(t) * 100.0;

            return Stack(
              children: [
                // 1. Fond de base (Gris/Bleu très pâle et propre)
                Positioned.fill(
                  child: Container(color: const Color(0xFFF4F7FB)),
                ),

                // 2. Les orbes de couleur pure qui se déplacent
                Positioned(
                  left: x1, top: y1,
                  child: _MovingBlob(size: 450, color: ThixPolicy.primary.withOpacity(0.4)),
                ),
                Positioned(
                  left: x2, top: y2,
                  child: _MovingBlob(size: 400, color: ThixPolicy.gold.withOpacity(0.25)),
                ),
                Positioned(
                  left: x3, top: y3,
                  child: _MovingBlob(size: 500, color: ThixPolicy.primaryDeep.withOpacity(0.35)),
                ),

                // 3. LE FLOU MAGIQUE (Mélange les couleurs en un nuage liquide)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), // Flou extrême
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // 4. La Texture Nette par-dessus le flou (Grille Tech)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PremiumVisualTexturePainter(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Simple cercle de couleur (le flou est géré globalement par le BackdropFilter)
class _MovingBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _MovingBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// Peintre personnalisé pour dessiner la grille tech fine
class _PremiumVisualTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ─── GRILLE DE POINTS (Style Fintech) ───
    final dotPaint = Paint()
      ..color = ThixPolicy.primaryDeep.withOpacity(0.04)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    const double spacing = 35.0; // Espacement de la grille

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        points.add(Offset(x, y));
      }
    }
    
    // Dessine tous les points en une seule opération ultra-rapide
    canvas.drawPoints(PointMode.points, points, dotPaint);

    // ─── ONDES ABSTRAITES très subtiles ───
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    wavePaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        ThixPolicy.primary.withOpacity(0.0),
        ThixPolicy.primary.withOpacity(0.12),
        ThixPolicy.primary.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path1 = Path();
    path1.moveTo(0, size.height * 0.15);
    path1.quadraticBezierTo(
      size.width * 0.4, size.height * 0.05,
      size.width, size.height * 0.25,
    );
    canvas.drawPath(path1, wavePaint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.35);
    path2.cubicTo(
      size.width * 0.3, size.height * 0.50,
      size.width * 0.7, size.height * 0.25,
      size.width, size.height * 0.45,
    );
    canvas.drawPath(path2, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
