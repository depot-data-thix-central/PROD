// lib/presentation/thix_ia/widgets/ai_agent_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../core/extensions/analysis_extensions.dart';

class AiAgentCard extends StatelessWidget {
  const AiAgentCard({super.key, required this.type, required this.status, this.progress = 0, this.onTap});

  final String type; // market, legal, finance, strategy, design, research
  final String status; // idle, running, completed, failed
  final int progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    final icon = type.icon;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: status == 'running'? color.withOpacity(0.4) : ThixPolicy.border), boxShadow: ThixPolicy.shadowCard(opacity: status == 'running'? 0.12 : 0.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
            Spacer(),
            if (status == 'running') SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(color))) else Container(width: 8, height: 8, decoration: BoxDecoration(color: status == 'completed'? ThixPolicy.success : ThixPolicy.textMuted, shape: BoxShape.circle)),
          ]),
          SizedBox(height: 12),
          Text(type.label, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
          SizedBox(height: 2),
          Text(status == 'running'? '$progress% • En cours' : status.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: status == 'completed'? ThixPolicy.success : ThixPolicy.textMuted)),
          if (status == 'running')...[
            SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: progress / 100, minHeight: 3, backgroundColor: ThixPolicy.surfaceStrong, valueColor: AlwaysStoppedAnimation(color))),
          ],
        ]),
      ),
    );
  }
}
