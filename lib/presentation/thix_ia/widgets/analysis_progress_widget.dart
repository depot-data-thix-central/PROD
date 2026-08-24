// lib/presentation/thix_ia/widgets/analysis_progress_widget.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_analysis.dart';
import '../core/extensions/analysis_extensions.dart';
import '../pages/analysis_report_page.dart'; // NOUVEL IMPORT

/// ============================================================================
/// ANALYSIS PROGRESS WIDGET - Progression réelle basée sur livrables §19
/// Pas de pourcentage arbitraire
/// ============================================================================

class AnalysisProgressWidget extends StatelessWidget {
  const AnalysisProgressWidget({super.key, required this.analysis, this.onCancel, this.onRetry});

  final ProjectAnalysis analysis;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Rend la carte cliquable avec GestureDetector
    return GestureDetector(
      onTap: analysis.isCompleted
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalysisReportPage(analysis: analysis),
                ),
              );
            }
          : null,
      // Ajout d'une MouseRegion pour changer le curseur sur Web/Desktop
      child: MouseRegion(
        cursor: analysis.isCompleted ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            // On met la bordure en vert discret si c'est terminé pour appuyer l'état de succès
            border: Border.all(
              color: analysis.status == AnalysisStatus.failed
                  ? ThixPolicy.danger.withOpacity(0.3)
                  : (analysis.isCompleted ? ThixPolicy.success.withOpacity(0.5) : ThixPolicy.border),
            ),
            boxShadow: ThixPolicy.shadowCard(opacity: 0.06),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(ThixPolicy.s16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.85)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: analysis.type.color.withOpacity(0.12), 
                            borderRadius: BorderRadius.circular(ThixPolicy.rMd)
                          ),
                          child: Icon(analysis.type.icon, color: analysis.type.color, size: 22),
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(analysis.type.label, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                              const SizedBox(height: 2),
                              Text(analysis.title ?? analysis.type.label, style: ThixPolicy.captionStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        _StatusBadge(status: analysis.status),
                        // NOUVEAU : Ajout d'une flèche pour indiquer la navigation possible
                        if (analysis.isCompleted) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: ThixPolicy.s16),
                    // Progression avec étapes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${analysis.progress}%', style: ThixPolicy.titleStyle.copyWith(color: analysis.type.color)),
                        Text(analysis.confidence > 0 ? 'Confiance ${(analysis.confidence * 100).toInt()}%' : '', style: ThixPolicy.captionStyle),
                      ],
                    ),
                    const SizedBox(height: ThixPolicy.s8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: analysis.progress / 100,
                        minHeight: 6,
                        backgroundColor: ThixPolicy.surfaceStrong,
                        valueColor: AlwaysStoppedAnimation(
                          analysis.status == AnalysisStatus.failed ? ThixPolicy.danger : analysis.type.color
                        ),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    // Étapes déduites du progress
                    _Steps(progress: analysis.progress, status: analysis.status),
                    
                    if (analysis.status == AnalysisStatus.running || analysis.status == AnalysisStatus.queued) ...[
                      const SizedBox(height: ThixPolicy.s12),
                      Row(
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(analysis.type.color))),
                          const SizedBox(width: 8),
                          Text(_statusText, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
                          const Spacer(),
                          if (onCancel != null)
                            GestureDetector(onTap: onCancel, child: Text('Annuler', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.semiBold))),
                        ],
                      ),
                    ],
                    if (analysis.status == AnalysisStatus.failed && onRetry != null) ...[
                      const SizedBox(height: ThixPolicy.s12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: Icon(Icons.refresh_rounded, size: 16, color: ThixPolicy.danger),
                          label: Text('Relancer', style: TextStyle(color: ThixPolicy.danger)),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: ThixPolicy.danger.withOpacity(0.3))),
                        ),
                      ),
                    ],
                    // NOUVEAU : Appel à l'action pour inciter le clic une fois terminé
                    if (analysis.isCompleted) ...[
                      const SizedBox(height: ThixPolicy.s16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: ThixPolicy.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        ),
                        child: Center(
                          child: Text(
                            'Voir le rapport détaillé',
                            style: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.success,
                              fontWeight: ThixPolicy.semiBold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusText {
    if (analysis.progress < 20) return 'Initialisation des moteurs IA...';
    if (analysis.progress < 50) return 'Collecte des sources officielles...';
    if (analysis.progress < 80) return 'Analyse et vérification des faits...';
    if (analysis.progress < 100) return 'Génération du rapport...';
    return 'Finalisation...';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AnalysisStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case AnalysisStatus.queued: color = ThixPolicy.textMuted; label = 'En file'; break;
      case AnalysisStatus.running: color = ThixPolicy.info; label = 'En cours'; break;
      case AnalysisStatus.completed: color = ThixPolicy.success; label = 'Terminé'; break;
      case AnalysisStatus.failed: color = ThixPolicy.danger; label = 'Échoué'; break;
      case AnalysisStatus.cancelled: color = ThixPolicy.textMuted; label = 'Annulé'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
      child: Text(label, style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: ThixPolicy.bold)),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.progress, required this.status});
  final int progress;
  final AnalysisStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = ['Collecte', 'Vérification', 'Analyse', 'Rapport'];
    final thresholds = [25, 50, 75, 100];

    return Row(
      children: List.generate(steps.length, (i) {
        final done = progress >= thresholds[i];
        final current = progress >= (i > 0 ? thresholds[i - 1] : 0) && progress < thresholds[i] && status == AnalysisStatus.running;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: done ? ThixPolicy.success : current ? ThixPolicy.info.withOpacity(0.15) : ThixPolicy.surfaceStrong,
                  shape: BoxShape.circle,
                  border: Border.all(color: done ? ThixPolicy.success : current ? ThixPolicy.info : ThixPolicy.border),
                ),
                child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : current ? Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(steps[i], style: ThixPolicy.microStyle.copyWith(color: done ? ThixPolicy.success : ThixPolicy.textMuted, fontWeight: done ? ThixPolicy.semiBold : ThixPolicy.regular))),
              if (i < steps.length - 1) Container(height: 1, width: 12, color: ThixPolicy.border),
            ],
          ),
        );
      }),
    );
  }
}
