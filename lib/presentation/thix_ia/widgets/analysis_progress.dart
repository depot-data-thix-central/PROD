// lib/presentation/thix_ia/widgets/analysis_progress.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_analysis.dart';
import '../core/extensions/analysis_extensions.dart';

class AnalysisProgress extends StatelessWidget {
  const AnalysisProgress({super.key, required this.analysis, this.onCancel, this.onRetry});

  final ProjectAnalysis analysis;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: analysis.isFailed? ThixPolicy.danger.withOpacity(0.3) : ThixPolicy.border),
        boxShadow: ThixPolicy.shadowCard(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: analysis.type.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(analysis.type.icon, color: analysis.type.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(analysis.type.label, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: analysis.status == AnalysisStatus.completed? ThixPolicy.success.withOpacity(0.12) : ThixPolicy.info.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(analysis.status.name.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: analysis.status == AnalysisStatus.completed? ThixPolicy.success : ThixPolicy.info, fontWeight: ThixPolicy.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${analysis.progress}%', style: ThixPolicy.titleStyle.copyWith(color: analysis.type.color)), Text('${(analysis.confidence * 100).toInt()}% confiance', style: ThixPolicy.captionStyle)]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: analysis.progress / 100, minHeight: 6, backgroundColor: ThixPolicy.surfaceStrong, valueColor: AlwaysStoppedAnimation(analysis.isFailed? ThixPolicy.danger : analysis.type.color))),
          const SizedBox(height: 12),
          Row(
            children: [
              _Step(label: 'Collecte', done: analysis.progress >= 25),
              _Divider(),
              _Step(label: 'Vérif', done: analysis.progress >= 50),
              _Divider(),
              _Step(label: 'Analyse', done: analysis.progress >= 75),
              _Divider(),
              _Step(label: 'Rapport', done: analysis.progress >= 100),
            ],
          ),
          if (analysis.isRunning)...[
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: analysis.type.color)),
              const SizedBox(width: 8),
              Text(_statusText, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
              const Spacer(),
              if (onCancel!= null) GestureDetector(onTap: onCancel, child: Text('Annuler', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.semiBold))),
            ]),
          ],
          if (analysis.isFailed && onRetry!= null)...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onRetry, icon: Icon(Icons.refresh_rounded, size: 16, color: ThixPolicy.danger), label: Text('Relancer', style: TextStyle(color: ThixPolicy.danger)), style: OutlinedButton.styleFrom(side: BorderSide(color: ThixPolicy.danger.withOpacity(0.3))))),
          ],
        ],
      ),
    );
  }

  String get _statusText {
    if (analysis.progress < 25) return 'Initialisation moteurs IA...';
    if (analysis.progress < 50) return 'Collecte sources officielles...';
    if (analysis.progress < 75) return 'Vérification croisée...';
    return 'Génération rapport...';
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done});
  final String label;
  final bool done;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 18, height: 18, decoration: BoxDecoration(color: done? ThixPolicy.success : ThixPolicy.surfaceStrong, shape: BoxShape.circle, border: Border.all(color: done? ThixPolicy.success : ThixPolicy.border)), child: done? Icon(Icons.check_rounded, size: 10, color: Colors.white) : null),
      const SizedBox(width: 4),
      Text(label, style: ThixPolicy.microStyle.copyWith(color: done? ThixPolicy.success : ThixPolicy.textMuted)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 12, height: 1, margin: EdgeInsets.symmetric(horizontal: 2), color: ThixPolicy.border);
}
