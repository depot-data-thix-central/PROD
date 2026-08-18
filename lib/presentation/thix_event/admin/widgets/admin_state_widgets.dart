// lib/presentation/thix_event/admin/widgets/admin_state_widgets.dart
import 'package:flutter/material.dart';

class AdminEmptyWidget extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const AdminEmptyWidget({super.key, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFEFF5FF), shape: BoxShape.circle), child: const Icon(Icons.inbox, size: 36, color: Color(0xFF7386A8))),
      const SizedBox(height: 12),
      const Text('Aucune donnée', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0A1F44))),
      const SizedBox(height: 4),
      const Text('Tire vers le bas pour rafraîchir', style: TextStyle(fontSize: 11, color: Color(0xFF7386A8))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () => onRefresh(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A1F44)), child: const Text('Rafraîchir', style: TextStyle(color: Colors.white))),
    ]));
  }
}

class AdminErrorWidget extends StatelessWidget {
  final String message; final Future<void> Function() onRetry;
  const AdminErrorWidget({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () => onRetry(), child: const Text('Réessayer')),
    ])));
  }
}

class AdminShimmerList extends StatelessWidget {
  const AdminShimmerList({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemCount: 6, itemBuilder: (_,__)=> Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), height: 80, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16))));
  }
}
