// lib/presentation/thix_urgent/widgets/central/breathing_red_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BreathingRedButton extends StatelessWidget {
  final bool isActive;
  final AnimationController pulseController;
  final VoidCallback onLongPress;

  const BreathingRedButton({
    super.key,
    required this.isActive,
    required this.pulseController,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        onLongPress();
      },
      onTap: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (c, child) {
          final scale = 1.0 + (pulseController.value * (isActive ? 0.18 : 0.07));
          return Transform.scale(scale: scale, child: child);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Effet radar scalable (3 cercles seulement pour perf)
            for (int i = 1; i <= 3; i++)
              Container(
                width: 180 + i * 30,
                height: 180 + i * 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF2D2D).withOpacity(0.22 / i),
                    width: 1.5,
                  ),
                ),
              ),
            // Bouton principal
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF2D2D),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D2D).withOpacity(0.6),
                    blurRadius: isActive ? 45 : 22,
                    spreadRadius: isActive ? 8 : 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, size: 64, color: Colors.white),
                  if (isActive)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
