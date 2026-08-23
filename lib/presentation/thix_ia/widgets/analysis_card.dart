// lib/presentation/thix_ia/widgets/analysis_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_analysis.dart';
import '../core/extensions/analysis_extensions.dart';
import 'confidence_indicator.dart';

class AnalysisCard extends StatelessWidget {
  const AnalysisCard({super.key, required this.analysis, this.onTap});
  final ProjectAnalysis analysis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: analysis.isFailed? ThixPolicy.danger.withOpacity(0.3) : ThixPolicy.border), boxShadow: ThixPolicy.shadowCard(opacity: 0.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: analysis.type.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(analysis.type.icon, color: analysis.type.color, size: 20)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(analysis.type.label, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)), Text(analysis.title?? 'Analyse ${analysis.type.label}', style: ThixPolicy.captionStyle, maxLines: 1, overflow: TextOverflow.ellipsis)])),
            ConfidenceIndicator(value: analysis.confidence),
          ]),
          if (analysis.summary!= null && analysis.summary!.isNotEmpty)...[
            SizedBox(height: 12),
            Text(analysis.summary!, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          SizedBox(height: 12),
          Row(children: [
            _Badge(label: analysis.status.name.toUpperCase(), color: analysis.status == AnalysisStatus.completed? ThixPolicy.success : analysis.status == AnalysisStatus.failed? ThixPolicy.danger : ThixPolicy.info),
            Spacer(),
            Text(analysis.progress> 0? '${analysis.progress}%' : '', style: ThixPolicy.captionStyle),
            SizedBox(width: 8),
            Text(analysis.createdAt!= null? '${analysis.createdAt!.day}/${analysis.createdAt!.month}' : '', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
          ]),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(label, style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: ThixPolicy.bold, fontSize: 9)));
  }
}
