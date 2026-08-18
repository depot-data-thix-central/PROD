// lib/presentation/thix_sante/sante/widgets/countdown_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
class CountdownWidget extends StatefulWidget {
  final DateTime dpa; const CountdownWidget({super.key, required this.dpa});
  @override State<CountdownWidget> createState()=> _CountdownWidgetState();
}
class _CountdownWidgetState extends State<CountdownWidget> {
  late Timer _timer; Duration _remaining = Duration.zero;
  @override void initState(){ super.initState(); _remaining = widget.dpa.difference(DateTime.now()); _timer = Timer.periodic(const Duration(seconds:1), (_){ if(mounted) setState(()=> _remaining = widget.dpa.difference(DateTime.now())); }); }
  @override void dispose(){ _timer.cancel(); super.dispose(); }
  @override Widget build(BuildContext context){
    if(_remaining.isNegative) return const Text('Bébé est là!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900));
    final months = _remaining.inDays ~/30; final weeks = (_remaining.inDays %30) ~/7; final days = (_remaining.inDays %30) %7;
    return Semantics(label: 'Temps restant', child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: Text('$months mois $weeks semaines $days jours ${ _remaining.inHours %24}h ${ _remaining.inMinutes %60}m', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:14))));
  }
}
