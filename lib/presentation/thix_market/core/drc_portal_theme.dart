// lib/presentation/thix_market/core/drc_portal_theme.dart
// ============================================================================
// DRC PRODUCTS PORTAL — Design tokens (couleurs du drapeau de la RDC)
// ============================================================================
import 'package:flutter/material.dart';

const Color kDrcBlue = Color(0xFF007FFF); // bleu ciel du drapeau
const Color kDrcBlueDeep = Color(0xFF0B3D91);
const Color kDrcNavy = Color(0xFF071F52);
const Color kDrcRed = Color(0xFFCE1021);
const Color kDrcYellow = Color(0xFFF7D618);

const Color kDrcInk = Color(0xFF0E1B2E);
const Color kDrcSub = Color(0xFF5A6B84);
const Color kDrcMuted = Color(0xFF93A1B5);
const Color kDrcLine = Color(0xFFE3E9F2);
const Color kDrcBg = Color(0xFFF4F7FC);
const Color kDrcSoft = Color(0xFFE8F0FE);

/// Barre verticale tricolore (bleu / jaune / rouge) pour les titres de section.
class DrcTricolorBar extends StatelessWidget {
  final double width;
  final double height;
  const DrcTricolorBar({super.key, this.width = 4, this.height = 18});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: width,
        height: height,
        child: const Column(
          children: [
            Expanded(flex: 5, child: ColoredBox(color: kDrcBlue, child: SizedBox.expand())),
            Expanded(flex: 2, child: ColoredBox(color: kDrcYellow, child: SizedBox.expand())),
            Expanded(flex: 3, child: ColoredBox(color: kDrcRed, child: SizedBox.expand())),
          ],
        ),
      ),
    );
  }
}

/// Filet horizontal tricolore (bleu / jaune / rouge / jaune).
class DrcTricolorStripe extends StatelessWidget {
  final double? width;
  final double height;
  const DrcTricolorStripe({super.key, this.width, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        width: width,
        height: height,
        child: const Row(
          children: [
            Expanded(flex: 5, child: ColoredBox(color: kDrcBlue, child: SizedBox.expand())),
            Expanded(flex: 1, child: ColoredBox(color: kDrcYellow, child: SizedBox.expand())),
            Expanded(flex: 2, child: ColoredBox(color: kDrcRed, child: SizedBox.expand())),
            Expanded(flex: 1, child: ColoredBox(color: kDrcYellow, child: SizedBox.expand())),
          ],
        ),
      ),
    );
  }
}
