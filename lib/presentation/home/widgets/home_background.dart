// lib/presentation/home/widgets/home_background.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kAnimationDurationSeconds = 25;
const int _kFingerprintCount = 9;
const double _kGridSpacing = 35.0;
const double _kFingerprintMinOpacity = 0.05;
const double _kFingerprintMaxOpacity = 0.14;

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomeSoftBackground extends StatefulWidget {
  const HomeSoftBackground({super.key});

  @override
  State<HomeSoftBackground> createState() => _HomeSoftBackgroundState();
}

class _HomeSoftBackgroundState extends State<HomeSoftBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late final List<_FingerprintSeed> _fpSeeds;
  bool _isAppVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[HomeBackground] 🎨 Initialized');

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _kAnimationDurationSeconds),
    )..repeat();

    // Graines stables pour empreintes (seed fixe pour reproductibilité)
    final rnd = math.Random(42);
    _fpSeeds = List.generate(_kFingerprintCount, (i) {
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    debugPrint('[HomeBackground] 👋 Disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppVisible = state == AppLifecycleState.resumed;
    if (_isAppVisible) {
      _controller.repeat();
      debugPrint('[HomeBackground] ▶️ Animation resumed');
    } else {
      _controller.stop();
      debugPrint('[HomeBackground] ⏸️ Animation paused (background)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;
            final orbPositions = _calculateOrbPositions(size, t);

            return Stack(
              children: [
                // 1. Fond de base
                Positioned.fill(
                  child: Container(color: ThixPolicy.card),
                ),

                // 2. Orbes lumineux (sans BackdropFilter = 50x plus rapide)
                _PerformanceOrb(
                  left: orbPositions[0].dx,
                  top: orbPositions[0].dy,
                  size: 600,
                  color: ThixPolicy.primary.withOpacity(0.08),
                ),
                _PerformanceOrb(
                  left: orbPositions[1].dx,
                  top: orbPositions[1].dy,
                  size: 500,
                  color: ThixPolicy.gold.withOpacity(0.06),
                ),
                _PerformanceOrb(
                  left: orbPositions[2].dx,
                  top: orbPositions[2].dy,
                  size: 650,
                  color: ThixPolicy.primary.withOpacity(0.07),
                ),
                _PerformanceOrb(
                  left: orbPositions[3].dx,
                  top: orbPositions[3].dy,
                  size: 450,
                  color: ThixPolicy.gold.withOpacity(0.05),
                ),

                // 3. Voile blanc (simule glassmorphism sans blur GPU)
                Positioned.fill(
                  child: Container(color: Colors.white.withOpacity(0.75)),
                ),

                // 4. Texture visuelle (grille + ondes)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PremiumVisualTexturePainter(),
                  ),
                ),

                // 5. Empreintes flottantes
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FloatingFingerprintsPainter(
                      seeds: _fpSeeds,
                      t: t,
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

  /// Calcule les positions des 4 orbes en fonction du temps
  List<Offset> _calculateOrbPositions(Size size, double t) {
    return [
      // Orb 1 : cercle en haut à gauche
      Offset(
        size.width * 0.2 + math.cos(t) * 120.0,
        size.height * 0.1 + math.sin(t) * 80.0,
      ),
      // Orb 2 : ellipse au centre droit
      Offset(
        size.width * 0.8 + math.sin(t * 1.3) * 150.0,
        size.height * 0.3 + math.cos(t * 0.8) * 120.0,
      ),
      // Orb 3 : arc en bas à gauche
      Offset(
        size.width * 0.1 + math.cos(t * 1.5) * 150.0,
        size.height * 0.8 + math.sin(t) * 100.0,
      ),
      // Orb 4 : accent additionnel
      Offset(
        size.width * 0.6 + math.sin(t * 0.6) * 100.0,
        size.height * 0.7 + math.cos(t * 0.9) * 90.0,
      ),
    ];
  }
}

// ============================================================================
// PERFORMANCE ORB (Sans BackdropFilter)
// ============================================================================
class _PerformanceOrb extends StatelessWidget {
  final double left;
  final double top;
  final double size;
  final Color color;

  const _PerformanceOrb({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - (size / 2),
      top: top - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FINGERPRINT SEED
// ============================================================================
class _FingerprintSeed {
  final double baseX;
  final double baseY;
  final double radius;
  final double speed;
  final double phase;
  final double size;
  final double pulsePhase;

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

// ============================================================================
// FLOATING FINGERPRINTS PAINTER
// ============================================================================
class _FloatingFingerprintsPainter extends CustomPainter {
  final List<_FingerprintSeed> seeds;
  final double t;

  _FloatingFingerprintsPainter({
    required this.seeds,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final s in seeds) {
      final cx = s.baseX * canvasSize.width;
      final cy = s.baseY * canvasSize.height;
      final angle = t * s.speed + s.phase;
      final ox = cx + math.cos(angle) * s.radius;
      final oy = cy + math.sin(angle) * s.radius;

      // Pulse d'opacité entre min et max
      final pulse = (math.sin(t * 0.8 + s.pulsePhase) + 1) / 2;
      final opacity = _kFingerprintMinOpacity +
          pulse * (_kFingerprintMaxOpacity - _kFingerprintMinOpacity);

      _paintFingerprintGlyph(
        canvas,
        Offset(ox, oy),
        s.size,
        ThixPolicy.primary.withOpacity(opacity),
      );
    }
  }

  void _paintFingerprintGlyph(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.09
      ..strokeCap = StrokeCap.round;

    const rings = 4;
    for (var i = 0; i < rings; i++) {
      final r = size * (0.3 + i * 0.18);
      final rect = Rect.fromCircle(center: center, radius: r);
      final startAngle = -math.pi / 2 - (i * 0.35);
      final sweepAngle = math.pi * 1.3 - (i * 0.12);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingFingerprintsPainter oldDelegate) {
    // Redraw seulement si le temps a changé
    return oldDelegate.t != t;
  }
}

// ============================================================================
// PREMIUM VISUAL TEXTURE PAINTER
// ============================================================================
class _PremiumVisualTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Grille de points
    final dotPaint = Paint()
      ..color = ThixPolicy.primary.withOpacity(0.025)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    for (double x = 0; x < size.width; x += _kGridSpacing) {
      for (double y = 0; y < size.height; y += _kGridSpacing) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, dotPaint);

    // Ondes abstraites
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

    final path1 = Path()
      ..moveTo(0, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.05,
        size.width,
        size.height * 0.25,
      );
    canvas.drawPath(path1, wavePaint);

    final path2 = Path()
      ..moveTo(0, size.height * 0.35)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.50,
        size.width * 0.7,
        size.height * 0.25,
        size.width,
        size.height * 0.45,
      );
    canvas.drawPath(path2, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
