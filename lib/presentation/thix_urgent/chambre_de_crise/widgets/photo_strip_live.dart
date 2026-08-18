// lib/presentation/thix_urgent/chambre_de_crise/widgets/photo_strip_live.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoStripLive extends StatelessWidget {
  const PhotoStripLive({super.key});
  @override
  Widget build(BuildContext context) {
    // Pagination: seulement 20 dernières photos pour scale
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1D24), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📸 Photos fantômes (auto 8s) • Cloud', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('emergency_photos').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(20),
            builder: (c, snap) {
              final photos = snap.data ?? [];
              if (photos.isEmpty) return ListView.separated(scrollDirection: Axis.horizontal, itemCount: 5, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => Container(width: 64, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.image, color: Colors.white24, size: 20)));
              return ListView.separated(scrollDirection: Axis.horizontal, itemCount: photos.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(photos[i]['url'], width: 64, height: 64, fit: BoxFit.cover)));
            },
          ),
        ),
      ]),
    );
  }
}
