import 'dart:async';
import 'package:flutter/material.dart';

class FlashSaleTimer extends StatefulWidget {
  final DateTime endTime;
  const FlashSaleTimer({super.key, required this.endTime});
  @override State<FlashSaleTimer> createState()=> _FlashSaleTimerState();
}

class _FlashSaleTimerState extends State<FlashSaleTimer> {
  late Timer _timer; late Duration _remaining;
  @override void initState(){ super.initState(); _remaining=widget.endTime.difference(DateTime.now()); _timer=Timer.periodic(const Duration(seconds:1), (_){ if(!mounted) return; setState(()=> _remaining=widget.endTime.difference(DateTime.now())); }); }
  @override void dispose(){ _timer.cancel(); super.dispose(); }
  @override Widget build(BuildContext context){
    final safe=_remaining.isNegative? Duration.zero : _remaining;
    final h=safe.inHours.toString().padLeft(2,'0');
    final m=(safe.inMinutes%60).toString().padLeft(2,'0');
    final s=(safe.inSeconds%60).toString().padLeft(2,'0');
    return Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: const Color(0xFFE5592F).withValues(alpha:0.12), borderRadius: BorderRadius.circular(16)), child: Text('$h:$m:$s', style: const TextStyle(color: Color(0xFFE5592F), fontWeight: FontWeight.w700)));
  }
}
