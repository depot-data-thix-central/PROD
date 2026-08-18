// lib/presentation/thix_urgent/widgets/central/emergency_timer_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';

class EmergencyTimerWidget extends StatefulWidget {
  final bool isActive;
  const EmergencyTimerWidget({super.key, required this.isActive});

  @override
  State<EmergencyTimerWidget> createState() => _EmergencyTimerWidgetState();
}

class _EmergencyTimerWidgetState extends State<EmergencyTimerWidget> {
  int _sec = 0;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant EmergencyTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _start();
    if (!widget.isActive && oldWidget.isActive) _stop();
  }

  void _start() {
    _sec = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sec++);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _sec = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox(height: 22);
    
    final m = (_sec ~/ 60).toString().padLeft(2, '0');
    final s = (_sec % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$m:$s • EN DIRECT - THIX CHAT', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
