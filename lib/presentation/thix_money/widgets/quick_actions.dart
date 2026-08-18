// lib/presentation/thix_money/widgets/quick_actions.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});
  @override
  Widget build(BuildContext context) {
    final actions = [
      {'icon': Icons.send_rounded, 'label': 'Envoyer', 'route': '/thix-money/send', 'color': const Color(0xFF1A3FFF)},
      {'icon': Icons.add_circle_rounded, 'label': 'Recharger', 'route': '/thix-money/recharge', 'color': const Color(0xFF00C853)},
      {'icon': Icons.qr_code_scanner_rounded, 'label': 'Scanner', 'route': '/thix-money/scanner', 'color': const Color(0xFF651FFF)},
      {'icon': Icons.local_atm_rounded, 'label': 'Retrait', 'route': '/thix-money/retrait', 'color': const Color(0xFFFF6D00)},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(a['route'] as String),
            child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(a['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F1D5E))),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
