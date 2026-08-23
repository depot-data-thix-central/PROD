// lib/presentation/thix_ia/widgets/thix_ia_empty.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

class ThixIaEmpty extends StatelessWidget {
  const ThixIaEmpty({super.key, required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction, this.illustration});

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? illustration;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
              child: Icon(icon, size: 40, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text(title, style: ThixPolicy.h3Style, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null)...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Spécialisations pour respecter l'arbo
class EmptyProjects extends StatelessWidget {
  const EmptyProjects({super.key, this.onCreate});
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) => ThixIaEmpty(icon: Icons.folder_open_rounded, title: 'Aucun projet THX', subtitle: 'Créez votre premier projet. THIX IA génère automatiquement THX-BIZ-..., mémoire et analyses.', actionLabel: 'Créer projet avec THIX IA', onAction: onCreate);
}

class EmptyAnalyses extends StatelessWidget {
  const EmptyAnalyses({super.key, this.onStart});
  final VoidCallback? onStart;
  @override
  Widget build(BuildContext context) => ThixIaEmpty(icon: Icons.analytics_outlined, title: 'Aucune analyse', subtitle: 'Lancez étude marché, légal, finance, stratégie. Sources officielles RDC + Banque Mondiale.', actionLabel: 'Lancer analyse', onAction: onStart);
}

class EmptyFacts extends StatelessWidget {
  const EmptyFacts({super.key});
  @override
  Widget build(BuildContext context) => ThixIaEmpty(icon: Icons.verified_outlined, title: 'Aucun fait vérifié', subtitle: 'Importez des documents ou lancez une recherche pour alimenter la mémoire projet avec faits sourcés.');
}
