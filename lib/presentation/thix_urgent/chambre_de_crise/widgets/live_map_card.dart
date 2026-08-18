// lib/presentation/thix_urgent/chambre_de_crise/widgets/live_map_card.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveMapCard extends StatelessWidget {
  final String criseId;
  const LiveMapCard({super.key, required this.criseId});

  @override
  Widget build(BuildContext context) {
    // Stream GPS paginé: 1 position/seconde max pour scale
    final stream = Supabase.instance.client.from('emergency_locations').stream(primaryKey: ['id']).eq('crise_id', criseId).order('created_at', ascending: false).limit(1);

    return Container(
      height: 180,
      decoration: BoxDecoration(color: const Color(0xFF1A1D24), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(color: const Color(0xFF252A33), child: const Center(child: Icon(Icons.map_rounded, size: 70, color: Colors.white10))),
            StreamBuilder(stream: stream, builder: (c, snap) => const Center(child: Icon(Icons.location_on, color: Colors.red, size: 42))),
            Positioned(top: 12, left: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text('Position en direct • 5s', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))),
            Positioned(bottom: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)), child: const Text('Cotonou, Bénin • 12m', style: TextStyle(color: Colors.white70, fontSize: 9)))),
          ],
        ),
      ),
    );
  }
}
