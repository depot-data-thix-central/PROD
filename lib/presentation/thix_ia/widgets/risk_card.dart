// lib/presentation/thix_ia/widgets/risk_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import 'source_badge.dart';

class RiskCard extends StatelessWidget {
  const RiskCard({super.key, required this.title, required this.content, this.level = 'medium', this.source});

  final String title;
  final String content;
  final String level; // low, medium, high, critical
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: _color.withOpacity(0.3)), boxShadow: ThixPolicy.shadowCard(opacity: 0.04)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: BorderRadius.only(topLeft: Radius.circular(ThixPolicy.rMd), topRight: Radius.circular(ThixPolicy.rMd))),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: _color),
              SizedBox(width: 6),
              Text('RISQUE • ${level.toUpperCase()}', style: ThixPolicy.microStyle.copyWith(color: _color, fontWeight: ThixPolicy.bold)),
              Spacer(),
              if (source!= null) SourceBadge(source: source!, type: 'official'),
            ]),
          ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
              SizedBox(height: 6),
              Text(content, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.shield_outlined, size: 12, color: ThixPolicy.textMuted),
                SizedBox(width: 4),
                Expanded(child: Text('Mitigation recommandée : consulter sources officielles', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (level) {
      case 'low': return ThixPolicy.success;
      case 'medium': return ThixPolicy.warning;
      case 'high': return ThixPolicy.danger;
      case 'critical': return ThixPolicy.danger;
      default: return ThixPolicy.warning;
    }
  }
}
