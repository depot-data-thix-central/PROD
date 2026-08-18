// lib/presentation/thix_event/admin/widgets/admin_stat_card.dart
import 'package:flutter/material.dart';

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool isLoading;

  const AdminStatCard({super.key, required this.label, required this.value, required this.icon, this.color, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    // Const constructor + pas de setState interne = 0 rebuild inutile
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EEFC)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: isLoading? _shimmer() : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (color?? const Color(0xFF2D6CDF)).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color?? const Color(0xFF2D6CDF))),
          const Icon(Icons.trending_up, size: 14, color: Color(0xFF4CAF50)),
        ]),
        const Spacer(),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0A1F44))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF7386A8), fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _shimmer() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(height: 34, width: 34, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
    const SizedBox(height: 20),
    Container(height: 18, width: 60, color: Colors.grey[200]),
    const SizedBox(height: 6),
    Container(height: 10, width: 80, color: Colors.grey[200]),
  ]);
}
