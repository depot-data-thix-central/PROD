import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class DomainCategoryBar extends StatelessWidget {
  final String activeDomain;
  const DomainCategoryBar({super.key, required this.activeDomain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: ThixPolicy.s14, horizontal: ThixPolicy.s8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _Cat(icon: Icons.flight_rounded, label: 'Vols', color: ThixPolicy.domainLearning, active: activeDomain == 'flights'),
        _Cat(icon: Icons.king_bed_rounded, label: 'Hôtels', color: ThixPolicy.domainNetwork, active: activeDomain == 'hotels'),
        _Cat(icon: Icons.directions_bus_filled_rounded, label: 'Bus', color: ThixPolicy.primary, active: activeDomain == 'bus'),
        _Cat(icon: Icons.local_taxi_rounded, label: 'Taxis', color: ThixPolicy.domainOpportunity, active: activeDomain == 'taxi'),
        _Cat(icon: Icons.more_horiz_rounded, label: 'Plus', color: ThixPolicy.textSecondary, isMore: true),
      ]),
    );
  }
}

class _Cat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool isMore;
  const _Cat({required this.icon, required this.label, required this.color, this.active = false, this.isMore = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: ThixPolicy.constellationNodeSize, height: ThixPolicy.constellationNodeSize, decoration: BoxDecoration(color: active ? color.withOpacity(0.1) : (isMore ? ThixPolicy.surface : Colors.white), borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? color : (isMore ? Colors.transparent : ThixPolicy.border))), child: Icon(icon, size: ThixPolicy.constellationNodeIconSize, color: active || isMore ? color : ThixPolicy.primaryDeep)),
    SizedBox(height: ThixPolicy.s6),
    Text(label, style: TextStyle(fontSize: 10.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? color : ThixPolicy.textMain)),
  ]);
}
