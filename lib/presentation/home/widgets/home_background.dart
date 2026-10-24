// lib/presentation/home/widgets/home_background.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_theme.dart';

class HomeSoftBackground extends StatefulWidget {
  const HomeSoftBackground({super.key});

  @override
  State<HomeSoftBackground> createState() => _HomeSoftBackgroundState();
}

class _HomeSoftBackgroundState extends State<HomeSoftBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          children: [
            // 1. Dégradé de base : blanc → brume bleutée
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, HomeTheme.skyMist, Colors.white],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // 2. Halos très doux (statiques)
            Positioned(top: -120, right: -80, child: _halo(HomeTheme.sky.withOpacity(0.16), 360)),
            Positioned(top: 360, left: -140, child: _halo(HomeTheme.sky.withOpacity(0.08), 380)),
            Positioned(bottom: -140, right: -100, child: _halo(HomeTheme.skyDeep.withOpacity(0.05), 400)),
            // 3. Grille de points discrète
            const Positioned.fill(child: CustomPaint(painter: _DotsPainter())),
            // 4. Ondulation en haut (animée)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 300,
              child: CustomPaint(painter: _WavePainter(_controller)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _halo(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
        ),
      );
}

class _WavePainter extends CustomPainter {
  final Animation<double> anim;
  _WavePainter(this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 2 * math.pi;
    _layer(canvas, size, yBase: 150, amp: 16, freq: 1.2, phase: t, top: 0.30, bottom: 0.0);
    _layer(canvas, size, yBase: 130, amp: 20, freq: 0.9, phase: -t + 1.4, top: 0.22, bottom: 0.0);
    _layer(canvas, size, yBase: 105, amp: 14, freq: 1.6, phase: t * 1.0 + 3.0, top: 0.16, bottom: 0.0);
  }

  void _layer(Canvas canvas, Size size,
      {required double yBase,
      required double amp,
      required double freq,
      required double phase,
      required double top,
      required double bottom}) {
    final path = Path()..moveTo(0, 0);
    for (double x = 0; x <= size.width + 6; x += 6) {
      final y = yBase + math.sin(x / size.width * 2 * math.pi * freq + phase) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, 0)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [HomeTheme.sky.withOpacity(top), HomeTheme.sky.withOpacity(bottom + 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, yBase + amp));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => false;
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = HomeTheme.skyDeep.withOpacity(0.045)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final pts = <Offset>[];
    for (double x = 14; x < size.width; x += 32) {
      for (double y = 14; y < size.height; y += 32) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, pts, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
