/// TdiaLogo (Production Enterprise)
/// 
/// Logo iconique TDIA : hexagone arrondi avec "Play-T" fusionné
/// Design premium enterprise, scalable, cohérent ThixPolicy
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class TdiaLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const TdiaLogo({super.key, this.size = 26, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(),
        if (showWordmark) ...[
          SizedBox(width: size * 0.3),
          Text(
            'TDIA',
            style: TextStyle(
              color: ThixPolicy.textMain,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.72,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIcon() {
    return Semantics(
      label: 'TDIA',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThixPolicy.primary,
              ThixPolicy.primary.withValues(alpha: 0.75),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: ThixPolicy.primary.withValues(alpha: 0.35),
              blurRadius: size * 0.3,
              offset: Offset(0, size * 0.1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Hexagone intérieur subtil
            Container(
              margin: EdgeInsets.all(size * 0.08),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
            ),
            // Play-T fusionné
            Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: size * 0.62,
              shadows: const [
                Shadow(color: Color(0x33000000), blurRadius: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
