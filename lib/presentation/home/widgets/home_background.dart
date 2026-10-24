// lib/presentation/home/widgets/home_background.dart
import 'package:flutter/material.dart';
import 'home_theme.dart';

/// Fond ambiant ultra-light : dégradé + halos statiques uniquement.
/// (vagues animées et grille de points retirées → rendu plus corporate)
class HomeSoftBackground extends StatelessWidget {
  const HomeSoftBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          children: [
            // Dégradé de base : blanc → brume bleutée → blanc
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, HomeTheme.skyMist, Colors.white],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // Halos très doux (statiques)
            Positioned(top: -120, right: -80, child: _halo(HomeTheme.sky.withOpacity(0.14), 360)),
            Positioned(top: 360, left: -140, child: _halo(HomeTheme.sky.withOpacity(0.07), 380)),
            Positioned(bottom: -140, right: -100, child: _halo(HomeTheme.skyDeep.withOpacity(0.05), 400)),
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
