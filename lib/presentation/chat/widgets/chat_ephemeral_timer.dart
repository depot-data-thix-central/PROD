// lib/presentation/chat/widgets/chat_ephemeral_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ChatEphemeralTimer extends StatefulWidget {
  final int duration;
  final VoidCallback onExpired;

  const ChatEphemeralTimer({
    super.key,
    required this.duration,
    required this.onExpired,
  });

  @override
  State<ChatEphemeralTimer> createState() => _ChatEphemeralTimerState();
}

class _ChatEphemeralTimerState extends State<ChatEphemeralTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        timer.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 🌟 NOUVEAU : Formatage intelligent du temps (Heures, Minutes, Secondes)
  String get _formattedTime {
    if (_remaining < 60) return '${_remaining}s'; // Ex: 59s
    
    if (_remaining < 3600) {
      final m = _remaining ~/ 60;
      final s = _remaining % 60;
      if (s == 0) return '${m}m';
      return '${m}m ${s}s'; // Ex: 12m 30s
    }
    
    final h = _remaining ~/ 3600;
    final m = (_remaining % 3600) ~/ 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m.toString().padLeft(2, '0')}m'; // Ex: 3h 00m
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFF59E0B)),
        const SizedBox(width: 4),
        Text(
          _formattedTime,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}
