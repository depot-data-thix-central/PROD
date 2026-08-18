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
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7F9FF), ThixPolicy.surface],
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -220,
              right: -180,
              child: _SoftBlob(
                size: 420,
                colors: [Color(0x2A003BFF), Color(0x1400214F)],
              ),
            ),
            const Positioned(
              top: -120,
              left: -220,
              child: _SoftBlob(
                size: 360,
                colors: [Color(0x1F003BFF), Color(0x1200214F)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _SoftBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}
