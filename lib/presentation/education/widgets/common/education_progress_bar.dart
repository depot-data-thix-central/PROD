// lib/presentation/education/widgets/common/education_progress_bar.dart
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart'; // ✅ Import du design system

class EducationProgressBar extends StatelessWidget {
  final double progress; // 0.0 à 1.0
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final bool showLabel;
  final String? labelText;

  const EducationProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.backgroundColor,
    this.progressColor,
    this.showLabel = false,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    // S'assure que la valeur reste toujours entre 0.0 et 1.0
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isCompleted = clampedProgress >= 1.0;
    
    // Application des couleurs du Design System THIX
    final bgColor = backgroundColor ?? ThixPolicy.border;
    // La barre devient automatiquement verte si terminée (sauf si une couleur personnalisée est forcée)
    final pColor = progressColor ?? (isCompleted ? ThixPolicy.success : ThixPolicy.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                labelText ?? 'Progression',
                style: const TextStyle(
                  fontSize: 12,
                  color: ThixPolicy.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(clampedProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: pColor, // Le texte s'accorde à la couleur de la barre
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor: bgColor,
            color: pColor,
            minHeight: height,
          ),
        ),
      ],
    );
  }
}
