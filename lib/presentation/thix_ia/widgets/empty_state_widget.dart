// lib/presentation/thix_ia/widgets/empty_state_widget.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

/// ============================================================================
/// EMPTY STATE WIDGET - Réutilisable, premium, avec actions
/// ============================================================================

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceStrong,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Icon(icon, size: 36, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: ThixPolicy.s20),
            Text(title, style: ThixPolicy.h3Style, textAlign: TextAlign.center),
            const SizedBox(height: ThixPolicy.s8),
            Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5), textAlign: TextAlign.center),
            if (actionLabel!= null && onAction!= null)...[
              const SizedBox(height: ThixPolicy.s24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                    elevation: 0,
                  ),
                  child: Text(actionLabel!, style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.semiBold)),
                ),
              ),
            ],
            if (secondaryActionLabel!= null && onSecondaryAction!= null)...[
              const SizedBox(height: ThixPolicy.s10),
              TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary))),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyProjects extends StatelessWidget {
  const EmptyProjects({super.key, this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Aucun projet',
      subtitle: 'Transformez votre idée en business solide avec THIX IA. Créez votre premier projet en 10 secondes.',
      actionLabel: 'Créer mon premier projet',
      onAction: onCreate,
    );
  }
}

class EmptyAnalyses extends StatelessWidget {
  const EmptyAnalyses({super.key, this.onStart});
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.analytics_outlined,
      title: 'Aucune analyse',
      subtitle: 'Lancez votre première analyse IA : marché, concurrence, réglementation ou modèle financier.',
      actionLabel: 'Lancer une analyse',
      onAction: onStart,
    );
  }
}

class EmptyFacts extends StatelessWidget {
  const EmptyFacts({super.key});
  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.fact_check_outlined,
      title: 'Aucun fait vérifié',
      subtitle: 'Les faits sourcés apparaîtront ici après vos analyses. Chaque fait est vérifiable avec source officielle.',
    );
  }
}
