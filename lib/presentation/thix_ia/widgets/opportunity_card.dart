// lib/presentation/thix_ia/widgets/opportunity_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import 'source_badge.dart';

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.title, required this.description, this.impact = 'medium', this.source});

  final String title;
  final String description;
  final String impact; // low, medium, high
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
              Icon(Icons.trending_up_rounded, size: 16, color: _color),
              SizedBox(width: 6),
              Text('OPPORTUNITÉ • IMPACT ${impact.toUpperCase()}', style: ThixPolicy.microStyle.copyWith(color: _color, fontWeight: ThixPolicy.bold)),
              Spacer(),
              if (source!= null) SourceBadge(source: source!, type: 'official'),
            ]),
          ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
              SizedBox(height: 6),
              Text(description, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lightbulb_rounded, size: 12, color: _color), SizedBox(width: 4), Text('Action : Intégrer au Go-to-Market', style: ThixPolicy.microStyle.copyWith(color: _color, fontWeight: ThixPolicy.semiBold))]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (impact) {
      case 'low': return ThixPolicy.textSecondary;
      case 'medium': return ThixPolicy.info;
      case 'high': return ThixPolicy.success;
      default: return ThixPolicy.success;
    }
  }
}
