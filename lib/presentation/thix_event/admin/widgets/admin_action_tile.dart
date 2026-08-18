// lib/presentation/thix_event/admin/widgets/admin_action_tile.dart
import 'package:flutter/material.dart';

class AdminActionTile extends StatelessWidget {
  final String title; final String subtitle; final IconData icon; final VoidCallback onTap; final Color? color;
  const AdminActionTile({super.key, required this.title, required this.subtitle, required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7EEFC))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (color?? const Color(0xFF2D6CDF)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color?? const Color(0xFF2D6CDF))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF7386A8)))])),
          const Icon(Icons.chevron_right, color: Color(0xFF7386A8)),
        ]),
      ),
    );
  }
}
