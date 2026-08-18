import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HangupButton extends StatelessWidget {
  final VoidCallback onHangup;
  final String? tooltip;
  final bool isEnabled;
  final double size;
  final bool requireConfirm;

  const HangupButton({
    super.key,
    required this.onHangup,
    this.tooltip,
    this.isEnabled = true,
    this.size = 56,
    this.requireConfirm = false,
  });

  Future<void> _handleTap(BuildContext context) async {
    if(!isEnabled) return;
    HapticFeedback.heavyImpact();
    if(requireConfirm){
      final ok = await showDialog<bool>(
        context: context,
        builder: (_)=> AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Terminer l\'appel ?', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text('Cette action mettra fin à l\'appel en cours.'),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD81E2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: ()=> Navigator.pop(context, true),
              child: const Text('Raccrocher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if(ok!=true) return;
    }
    onHangup();
  }

  @override Widget build(BuildContext context){
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: tooltip?? 'Terminer l\'appel',
      child: Tooltip(
        message: tooltip?? 'Terminer l\'appel',
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: isEnabled? 1.0 : 0.9,
          child: SizedBox(
            width: size,
            height: size,
            child: FloatingActionButton(
              heroTag: 'hangup_btn',
              onPressed: isEnabled? ()=> _handleTap(context) : null,
              backgroundColor: isEnabled? const Color(0xFFE53935) : const Color(0xFFEF9A9A),
              foregroundColor: Colors.white,
              elevation: isEnabled? 6 : 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
