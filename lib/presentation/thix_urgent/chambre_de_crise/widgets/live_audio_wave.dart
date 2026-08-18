// lib/presentation/thix_urgent/chambre_de_crise/widgets/live_audio_wave.dart
import 'package:flutter/material.dart';
import 'dart:math';

class LiveAudioWave extends StatefulWidget {
  const LiveAudioWave({super.key});
  @override
  State<LiveAudioWave> createState() => _LiveAudioWaveState();
}

class _LiveAudioWaveState extends State<LiveAudioWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A1D24), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.mic_rounded, color: Colors.red, size: 14), SizedBox(width: 6), Text('🎙️ Audio en direct • Micro victime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))]),
        const SizedBox(height: 12),
        AnimatedBuilder(animation: _controller, builder: (_, __) => Row(children: List.generate(24, (i) { final h = 8 + Random().nextDouble() * 28; return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), height: h, decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.7 + Random().nextDouble() * 0.3), borderRadius: BorderRadius.circular(4)))); }))),
        const SizedBox(height: 8),
        const Text('Agora RTC • Chiffré • Latence < 500ms', style: TextStyle(color: Colors.white24, fontSize: 8)),
      ]),
    );
  }
}
