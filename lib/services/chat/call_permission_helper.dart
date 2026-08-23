// lib/services/chat/call_permission_helper.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/chat/call_status.dart';

/// Vérifie/demande les permissions AVANT de lancer le pipeline Agora,
/// avec explication préalable (même règle App Store/Play Store que pour
/// le live). Retourne true si l'appel peut démarrer.
class CallPermissionHelper {
  static Future<bool> ensure(BuildContext context, CallType type) async {
    final micOk = await _ensureOne(
      context: context,
      permission: Permission.microphone,
      title: 'Accès au microphone',
      message: "THIX ID a besoin du microphone pour votre appel.",
      icon: Icons.mic_rounded,
    );
    if (!micOk) return false;

    if (type == CallType.video) {
      final camOk = await _ensureOne(
        context: context,
        permission: Permission.camera,
        title: 'Accès à la caméra',
        message: "THIX ID a besoin de la caméra pour votre appel vidéo.",
        icon: Icons.videocam_rounded,
      );
      if (!camOk) return false;
    }
    return true;
  }

  static Future<bool> _ensureOne({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      final open = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16294D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(icon, color: const Color(0xFF2D6CDF), size: 30),
          title: Text(title, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: Text(
            "$message\n\nCette permission a été refusée précédemment. Activez-la dans les réglages pour continuer.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFAEB9D4), fontSize: 13.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: Color(0xFFAEB9D4))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A1F44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ouvrir les réglages', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (open == true) await openAppSettings();
      return false;
    }

    if (!context.mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16294D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(icon, color: const Color(0xFF2D6CDF), size: 30),
        title: Text(title, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFAEB9D4), fontSize: 13.5, height: 1.4)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFFAEB9D4))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A1F44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Autoriser', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (accepted != true) return false;

    final result = await permission.request();
    return result.isGranted;
  }
}
