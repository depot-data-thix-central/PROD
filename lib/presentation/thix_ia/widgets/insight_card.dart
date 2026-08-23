// lib/presentation/thix_ia/widgets/insight_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import 'confidence_indicator.dart';
import 'source_badge.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.title, required this.content, this.confidence = 0.75, this.type = 'insight', this.source});

  final String title;
  final String content;
  final double confidence;
  final String type;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowCard(opacity: 0.04)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(_icon, color: _color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          ConfidenceIndicator(value: confidence, size: 32, showLabel: false),
        ]),
        const SizedBox(height: 12),
        Text(content, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          SourceBadge(source: source?? type, type: 'official'),
          const Spacer(),
          Text('Source vérifiée', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
        ]),
      ]),
    );
  }

  Color get _color {
    switch (type) {
      case 'market': return ThixPolicy.info;
      case 'finance': return ThixPolicy.success;
      case 'strategy': return ThixPolicy.primary;
      case 'business': return ThixPolicy.primary;
      default: return ThixPolicy.primary;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'market': return Icons.trending_up_rounded;
      case 'finance': return Icons.calculate_rounded;
      case 'strategy': return Icons.rocket_launch_rounded;
      case 'business': return Icons.business_center_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }
}
