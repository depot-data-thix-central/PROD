// lib/presentation/home/widgets/home_hub_brand.dart
//
// Logo THIX HUB + "Your Hub, Your Universe" + tagline + swoosh.
// Les couleurs suivent les réglages (couleur principale / accent).
import 'package:flutter/material.dart';

import 'package:thix_id/l10n/app_localizations.dart';

import 'home_hub_settings.dart';
import 'home_theme.dart';

class HubBrand extends StatelessWidget {
  final Color primary;
  final Color accent;
  const HubBrand({super.key, required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Color.lerp(primary, Colors.black, 0.35)!;
    final glow = [
      Shadow(color: Colors.white.withOpacity(0.85), blurRadius: 10),
    ];

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HubLogoMark(size: 56, primary: primary, accent: accent),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'THIX ',
                        style: TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: 'HUB',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.0,
                    letterSpacing: -0.8,
                    shadows: glow,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hubTr(l10n, 'hub_slogan', 'Your Hub, Your Universe'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: HomeTheme.ink,
                    shadows: glow,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          hubTr(l10n, 'hub_tagline', 'Connect. Create. Share. Grow!'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: dark,
            shadows: glow,
          ),
        ),
        const SizedBox(height: 4),
        CustomPaint(size: const Size(150, 10), painter: _SwooshPainter(accent)),
      ],
    );
  }
}

class HubLogoMark extends StatelessWidget {
  final double size;
  final Color primary;
  final Color accent;
  const HubLogoMark({
    super.key,
    required this.size,
    required this.primary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(primary: primary, accent: accent),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color primary;
  final Color accent;
  _LogoPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    Offset o(double x, double y) => Offset(x * s, y * s);

    Path poly(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    final rect = Offset.zero & size;
    final bluePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(primary, Colors.white, 0.18)!,
          Color.lerp(primary, Colors.black, 0.25)!,
        ],
      ).createShader(rect);
    final yellowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(accent, Colors.white, 0.25)!, accent],
      ).createShader(rect);

    Paint stroke(Paint base) => Paint()
      ..shader = base.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..strokeJoin = StrokeJoin.round;

    // Aile jaune
    final wing = poly([o(4, 50), o(34, 44), o(30, 70), o(10, 80)]);
    canvas.drawPath(wing, yellowPaint);
    canvas.drawPath(wing, stroke(yellowPaint));

    // Barre du T
    final bar = poly([o(22, 14), o(94, 6), o(88, 34), o(16, 42)]);
    canvas.drawPath(bar, bluePaint);
    canvas.drawPath(bar, stroke(bluePaint));

    // Pied du T
    final stem = poly([o(44, 38), o(70, 35), o(60, 94), o(40, 96)]);
    canvas.drawPath(stem, bluePaint);
    canvas.drawPath(stem, stroke(bluePaint));
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.primary != primary || old.accent != accent;
}

class _SwooshPainter extends CustomPainter {
  final Color color;
  _SwooshPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w, h * 0.30)
      ..quadraticBezierTo(w * 0.5, h * 0.55, 0, h * 0.85)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SwooshPainter old) => old.color != color;
}
