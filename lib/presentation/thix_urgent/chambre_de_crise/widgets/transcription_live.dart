// lib/presentation/thix_urgent/chambre_de_crise/widgets/transcription_live.dart
import 'package:flutter/material.dart';

class TranscriptionLive extends StatelessWidget {
  const TranscriptionLive({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1D24), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.closed_caption_rounded, color: Colors.white54, size: 12), SizedBox(width: 6), Text('📝 Transcription live (Whisper)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))]),
        SizedBox(height: 8),
        Text('"Au secours... il y a eu un accident ici à côté du marché... j\'ai besoin d\'aide..."', style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic, height: 1.4)),
        SizedBox(height: 6),
        Text('• Traduction auto FR / Fon • Sauvegardée dans THIX CHAT', style: TextStyle(color: Colors.white24, fontSize: 8)),
      ]),
    );
  }
}
