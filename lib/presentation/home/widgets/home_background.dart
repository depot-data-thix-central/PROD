// lib/presentation/home/widgets/home_background.dart
import 'dart:math' as math;
import 'dart:ui'; // Requis pour ImageFilter (glassmorphism)
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSoftBackground extends StatefulWidget {
  const HomeSoftBackground({super.key});

  @override
  State<HomeSoftBackground> createState() => _HomeSoftBackgroundState();
}

class _HomeSoftBackgroundState extends State<HomeSoftBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<_FingerprintSeed> _fpSeeds;

  @override
  void initState() {
    super.initState();
    // Animation très lente (25 secondes pour un tour complet) pour un effet relaxant
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 25))
      ..repeat();

    // Graines stables pour les empreintes digitales flottantes (générées une seule fois)
    final rnd = math.Random(42);
    _fpSeeds = List.generate(9, (i) {
      return _FingerprintSeed(
        baseX: rnd.nextDouble(),
        baseY: rnd.nextDouble(),
        radius: 35.0 + rnd.nextDouble() * 80.0,
        speed: 0.3 + rnd.nextDouble() * 0.6,
        phase: rnd.nextDouble() * 2 * math.pi,
        size: 16.0 + rnd.nextDouble() * 18.0,
        pulsePhase: rnd.nextDouble() * 2 * math.pi,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🌟 HELPER HAUTE PERFORMANCE : Utilise un RadialGradient elliptique au lieu d'un Flou GPU
  Widget _buildPerformanceOrb(double left, double top, double size, Color color) {
    return Positioned(
      left: left - (size / 2),
      top: top - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color, 
              color.withOpacity(0.0) // Se fond de manière invisible dans le décor
            ],
            stops: const [0.0, 1.0], // Dégradé ultra doux du centre vers les bords
          ),
        ),
      ),
    );
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

            // Orb 1 : Bleu THIX clair (Bouge en cercle en haut à gauche)
            final x1 = size.width * 0.2 + math.cos(t) * 120.0;
            final y1 = size.height * 0.1 + math.sin(t) * 80.0;

            // Orb 2 : Or très doux (Bouge en huit/ellipse au centre droit)
            final x2 = size.width * 0.8 + math.sin(t * 1.3) * 150.0;
            final y2 = size.height * 0.3 + math.cos(t * 0.8) * 120.0;

            // Orb 3 : Bleu clair (Bouge en arc en bas à gauche)
            final x3 = size.width * 0.1 + math.cos(t * 1.5) * 150.0;
            final y3 = size.height * 0.8 + math.sin(t) * 100.0;

            // Orb 4 : Accent additionnel très léger
            final x4 = size.width * 0.6 + math.sin(t * 0.6) * 100.0;
            final y4 = size.height * 0.7 + math.cos(t * 0.9) * 90.0;

            return Stack(
              children: [
                // 1. Fond de base — blanc opaque
                Positioned.fill(
                  child: Container(color: Colors.white),
                ),

                // 2. Les orbes lumineux, très en retrait (opacités faibles) puisque
                // le fond doit rester majoritairement blanc opaque
                _buildPerformanceOrb(x1, y1, 600, ThixPolicy.primary.withOpacity(0.08)),
                _buildPerformanceOrb(x2, y2, 500, ThixPolicy.gold.withOpacity(0.06)),
                _buildPerformanceOrb(x3, y3, 650, ThixPolicy.primary.withOpacity(0.07)),
                _buildPerformanceOrb(x4, y4, 450, ThixPolicy.gold.withOpacity(0.05)),

                // 3. GLASSMORPHISM EXCESSIF — voile de verre dépoli très marqué
                // qui écrase les orbes en une brume blanche laiteuse
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.white.withOpacity(0.55)),
                  ),
                ),

                // 4. Seconde couche de verre, plus fine, pour renforcer l'effet
                // "glass on glass" sans revenir à des couleurs sombres
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(color: Colors.white.withOpacity(0.25)),
                  ),
                ),

                // 5. La Texture Nette par-dessus (Grille Tech + ondes) — tons très clairs
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PremiumVisualTexturePainter(),
                  ),
                ),

                // 6. EMPREINTES DIGITALES FLOTTANTES — écho discret de l'identité THIX ID,
                // dérivent lentement et pulsent doucement en opacité
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FloatingFingerprintsPainter(seeds: _fpSeeds, t: t, size: size),
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

/// Graine stable décrivant la trajectoire et le rythme d'une empreinte flottante
class _FingerprintSeed {
  final double baseX; // position de base normalisée (0..1)
  final double baseY;
  final double radius; // rayon du mouvement en pixels
  final double speed; // multiplicateur de vitesse
  final double phase; // déphasage initial du mouvement
  final double size; // taille de l'icône
  final double pulsePhase; // déphasage du pulse d'opacité

  const _FingerprintSeed({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.size,
    required this.pulsePhase,
  });
}

/// Peintre : petites empreintes digitales qui dérivent doucement et pulsent en opacité,
/// clin d'œil discret à l'identité THIX ID sans surcharger le fond.
class _FloatingFingerprintsPainter extends CustomPainter {
  final List<_FingerprintSeed> seeds;
  final double t;
  final Size size;

  _FloatingFingerprintsPainter({required this.seeds, required this.t, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final s in seeds) {
      final cx = s.baseX * canvasSize.width;
      final cy = s.baseY * canvasSize.height;
      final angle = t * s.speed + s.phase;
      final ox = cx + math.cos(angle) * s.radius;
      final oy = cy + math.sin(angle) * s.radius;

      // Pulse doux d'opacité entre 0.05 et 0.14 pour rester très discret
      final pulse = (math.sin(t * 0.8 + s.pulsePhase) + 1) / 2; // 0..1
      final opacity = 0.05 + pulse * 0.09;

      _paintFingerprintGlyph(canvas, Offset(ox, oy), s.size, ThixPolicy.primary.withOpacity(opacity));
    }
  }

  /// Dessine un petit glyphe d'empreinte digitale stylisé (arcs concentriques
  /// incomplets), en Canvas pur pour rester léger — pas besoin de police d'icônes.
  void _paintFingerprintGlyph(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.09
      ..strokeCap = StrokeCap.round;

    final rings = 4;
    for (var i = 0; i < rings; i++) {
      final r = size * (0.3 + i * 0.18);
      final rect = Rect.fromCircle(center: center, radius: r);
      // Arc incomplet (comme une crête d'empreinte), angle et ouverture variés par anneau
      final startAngle = -math.pi / 2 - (i * 0.35);
      final sweepAngle = math.pi * 1.3 - (i * 0.12);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingFingerprintsPainter oldDelegate) => true;
}

/// Peintre personnalisé pour dessiner la grille tech fine — version très claire
class _PremiumVisualTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ─── GRILLE DE POINTS (Style Fintech), quasi invisible ───
    final dotPaint = Paint()
      ..color = ThixPolicy.primary.withOpacity(0.025)
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

    // ─── ONDES ABSTRAITES très subtiles, tons très clairs ───
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    wavePaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        ThixPolicy.primary.withOpacity(0.0),
        ThixPolicy.primary.withOpacity(0.06),
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
