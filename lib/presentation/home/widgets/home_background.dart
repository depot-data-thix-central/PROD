// lib/presentation/home/widgets/home_background.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSoftBackground extends StatelessWidget {
  const HomeSoftBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // RepaintBoundary est excellent pour les fonds statiques floutés (optimisation des performances)
      child: RepaintBoundary(
        child: Container(
          // Fond Corporate ultra-propre et neutre
          color: const Color(0xFFF7F8FA), 
          child: Stack(
            children: [
              // Orbe Supérieur Droit (Bleu principal très doux)
              Positioned(
                top: -150,
                right: -100,
                child: _AmbientOrb(
                  size: 450,
                  color: ThixPolicy.primary.withValues(alpha: 0.06),
                ),
              ),
              // Orbe Central Gauche (Bleu profond / Indigo)
              Positioned(
                top: 250,
                left: -150,
                child: _AmbientOrb(
                  size: 380,
                  color: ThixPolicy.primaryDeep.withValues(alpha: 0.04),
                ),
              ),
              // Orbe Inférieur Droit (Touche infinitésimale de Gold Premium)
              Positioned(
                bottom: -100,
                right: -50,
                child: _AmbientOrb(
                  size: 300,
                  color: ThixPolicy.gold.withValues(alpha: 0.02),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crée un halo de lumière diffuse parfait pour les fonds Glassmorphism
class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // ImageFiltered applique le flou directement sur le widget lui-même (contrairement au BackdropFilter)
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
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
