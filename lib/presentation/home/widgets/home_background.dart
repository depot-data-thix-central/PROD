// lib/presentation/home/widgets/home_background.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSoftBackground extends StatelessWidget {
  const HomeSoftBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          children: [
            // 1. Fond de base (Dégradé très doux Blanc -> Gris/Bleu pâle)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFF0F4F8), // Un bleu-gris très premium
                    ],
                  ),
                ),
              ),
            ),

            // 2. Texture Visuelle (Grille de points & Vagues abstraites)
            Positioned.fill(
              child: CustomPaint(
                painter: _PremiumVisualTexturePainter(),
              ),
            ),

            // 3. Éclairage / Orbes (Plus intenses pour faire ressortir le Glassmorphism)
            
            // Orbe Supérieur Droit (Bleu principal THIX)
            Positioned(
              top: -150,
              right: -150,
              child: _AmbientOrb(
                size: 500,
                color: ThixPolicy.primary.withOpacity(0.18), 
              ),
            ),

            // Orbe Central Gauche (Gold - pour le contraste)
            Positioned(
              top: 250,
              left: -200,
              child: _AmbientOrb(
                size: 450,
                color: ThixPolicy.gold.withOpacity(0.12),
              ),
            ),

            // Orbe Inférieur Droit (Indigo profond pour asseoir le design)
            Positioned(
              bottom: -150,
              right: -100,
              child: _AmbientOrb(
                size: 550,
                color: ThixPolicy.primaryDeep.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crée un halo de lumière diffuse
class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

/// Peintre personnalisé pour dessiner la grille tech et les ondes
class _PremiumVisualTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ─── 1. GRILLE DE POINTS (Style Fintech / Dashboard) ───
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


    // ─── 2. ONDES ABSTRAITES (Flux de données) ───
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dégradé pour que les lignes se fondent doucement aux extrémités
    wavePaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        ThixPolicy.primary.withOpacity(0.0),
        ThixPolicy.primary.withOpacity(0.15),
        ThixPolicy.primary.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Onde 1 (Haute)
    final path1 = Path();
    path1.moveTo(0, size.height * 0.15);
    path1.quadraticBezierTo(
      size.width * 0.4, size.height * 0.05,
      size.width, size.height * 0.25,
    );
    canvas.drawPath(path1, wavePaint);

    // Onde 2 (Milieu)
    final path2 = Path();
    path2.moveTo(0, size.height * 0.35);
    path2.cubicTo(
      size.width * 0.3, size.height * 0.50,
      size.width * 0.7, size.height * 0.25,
      size.width, size.height * 0.45,
    );
    canvas.drawPath(path2, wavePaint);

    // Onde 3 (Basse)
    final path3 = Path();
    path3.moveTo(0, size.height * 0.65);
    path3.quadraticBezierTo(
      size.width * 0.6, size.height * 0.85,
      size.width, size.height * 0.55,
    );
    canvas.drawPath(path3, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
