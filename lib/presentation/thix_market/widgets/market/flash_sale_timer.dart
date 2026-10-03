import 'dart:async';
import 'package:flutter/material.dart';

class FlashSaleTimer extends StatefulWidget {
  final DateTime endTime;
  const FlashSaleTimer({super.key, required this.endTime});
  @override 
  State<FlashSaleTimer> createState() => _FlashSaleTimerState();
}

class _FlashSaleTimerState extends State<FlashSaleTimer> {
  late Timer _timer; 
  late Duration _remaining;

  @override 
  void initState() { 
    super.initState(); 
    _remaining = widget.endTime.difference(DateTime.now()); 
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { 
      if (!mounted) return; 
      setState(() => _remaining = widget.endTime.difference(DateTime.now())); 
    }); 
  }

  @override 
  void dispose() { 
    _timer.cancel(); 
    super.dispose(); 
  }

  @override 
  Widget build(BuildContext context) {
    final safe = _remaining.isNegative ? Duration.zero : _remaining;
    
    final days = safe.inDays;
    final hours = (safe.inHours % 24).toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');

    // Affichage conditionnel selon la durée (> 24h)
    final String timeText = days > 0 
        ? '${days}j ${hours}h ${minutes}m ${seconds}s'
        : '$hours:$minutes:$seconds';

    // Couleur rouge bordeaux (0xFF800020)
    const burgundyColor = Color(0xFF800020);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Taille réduite
      decoration: BoxDecoration(
        color: burgundyColor.withValues(alpha: 0.12), 
        borderRadius: BorderRadius.circular(8),
      ), 
      child: Text(
        timeText, 
        style: const TextStyle(
          color: burgundyColor, 
          fontWeight: FontWeight.w700,
          fontSize: 11, // Taille de police ajustée
        ),
      ),
    );
  }
}
