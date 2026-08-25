// lib/presentation/home/widgets/home_background.dart
import 'dart:math' as math;
import 'dart:ui'; // Requis pour PointMode
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSoftBackground extends StatefulWidget {
  const HomeSoftBackground({super.key});

  @override
  State<HomeSoftBackground> createState() => _HomeSoftBackgroundState();
}

class _HomeSoftBackgroundState extends State<HomeSoftBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<_NodeSeed> _nodeSeeds;

  @override
  void initState() {
    super.initState();
    // Animation ralentie (35 secondes) pour une fluidité "corporate" et apaisante
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 35))
      ..repeat();

    // Graines stables pour les particules/nœuds (générées une seule fois)
    final rnd = math.Random(42);
    _nodeSeeds = List.generate(15, (i) { // Réduction légère du nombre de nœuds pour plus d'épure
      return _NodeSeed(
        baseX: rnd.nextDouble(),
        baseY: rnd.nextDouble(),
        radius: 40.0 + rnd.nextDouble() * 120.0,
        speed: 0.2 + rnd.nextDouble() * 0.5,
        phase: rnd.nextDouble() * 2 * math.pi,
        dotRadius: 1.2 + rnd.nextDouble() * 1.5,
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

            // Orb 1 : Halo très clair (Haut gauche)
            final x1 = size.width * 0.2 + math.cos(t) * 150.0;
            final y1 = size.height * 0.15 + math.sin(t) * 100.0;

            // Orb 2 : Reflet Blanc pur (Centre droit)
            final x2 = size.width * 0.85 + math.sin(t * 1.2) * 120.0;
            final y2 = size.height * 0.35 + math.cos(t * 0.8) * 150.0;

            // Orb 3 : Subtil Bleu Institutionnel (Bas gauche)
            final x3 = size.width * 0.15 + math.cos(t * 1.5) * 180.0;
            final y3 = size.height * 0.85 + math.sin(t) * 120.0;

            // Orb 4 : Reflet Blanc (Bas droit)
            final x4 = size.width * 0.7 + math.sin(t * 0.6) * 100.0;
            final y4 = size.height * 0.75 + math.cos(t * 0.9) * 110.0;

            return Stack(
              children: [
                // 1. Fond de base (Ultra clair et propre)
                Positioned.fill(
                  child: Container(color: ThixPolicy.surfaceSoft),
                ),

                // 2. Les orbes lumineux (Blanc dominant et Bleu très diaphane)
                _buildPerformanceOrb(x1, y1, 700, ThixPolicy.primary.withOpacity(0.04)),
                _buildPerformanceOrb(x2, y2, 800, Colors.white.withOpacity(0.6)),
                _buildPerformanceOrb(x3, y3, 650, ThixPolicy.primaryDeep.withOpacity(0.03)),
                _buildPerformanceOrb(x4, y4, 600, Colors.white.withOpacity(0.5)),

                // 3. La Texture Nette par-dessus (Grille Tech + ondes très diffuses)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PremiumVisualTexturePainter(),
                  ),
                ),

                // 4. NŒUDS FLOTTANTS — Réseau d'entreprise
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FloatingNodesPainter(seeds: _nodeSeeds, t: t, size: size),
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

/// Graine stable décrivant la trajectoire d'un nœud flottant
class _NodeSeed {
  final double baseX; 
  final double baseY;
  final double radius; 
  final double speed; 
  final double phase; 
  final double dotRadius; 

  const _NodeSeed({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.dotRadius,
  });
}

/// Peintre : petits nœuds qui dérivent doucement et se relient par de fines lignes
class _FloatingNodesPainter extends CustomPainter {
  final List<_NodeSeed> seeds;
  final double t;
  final Size size;

  _FloatingNodesPainter({required this.seeds, required this.t, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Teintes très discrètes pour ne pas surcharger l'œil
    final dotPaint = Paint()..color = ThixPolicy.primary.withOpacity(0.08);
    final linePaint = Paint()
      ..color = ThixPolicy.primaryDeep.withOpacity(0.03)
      ..strokeWidth = 1.0;

    final positions = <Offset>[];

    for (final s in seeds) {
      final cx = s.baseX * canvasSize.width;
      final cy = s.baseY * canvasSize.height;
      final angle = t * s.speed + s.phase;
      final ox = cx + math.cos(angle) * s.radius;
      final oy = cy + math.sin(angle) * s.radius;
      final pos = Offset(ox, oy);
      positions.add(pos);
      canvas.drawCircle(pos, s.dotRadius, dotPaint);
    }

    // Relie les nœuds proches entre eux
    const double linkDistance = 140.0;
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final d = (positions[i] - positions[j]).distance;
        if (d < linkDistance) {
          // Atténuation dynamique de la ligne en fonction de la distance
          final opacity = (1.0 - (d / linkDistance)) * 0.04;
          linePaint.color = ThixPolicy.primaryDeep.withOpacity(opacity);
          canvas.drawLine(positions[i], positions[j], linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingNodesPainter oldDelegate) => true;
}

/// Peintre personnalisé pour dessiner la grille tech fine
class _PremiumVisualTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ─── GRILLE DE POINTS (Style Fintech minimaliste) ───
    final dotPaint = Paint()
      ..color = ThixPolicy.inkDeep.withOpacity(0.025) // Gris très subtil
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    const double spacing = 40.0; // Espacement élargi pour aérer le design

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        points.add(Offset(x, y));
      }
    }
    
    // Dessine tous les points en une seule opération ultra-rapide
    canvas.drawPoints(PointMode.points, points, dotPaint);

    // ─── ONDES ABSTRAITES très subtiles (Filigrane) ───
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    wavePaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        ThixPolicy.primary.withOpacity(0.0),
        ThixPolicy.primary.withOpacity(0.06), // Transparence drastiquement réduite
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
