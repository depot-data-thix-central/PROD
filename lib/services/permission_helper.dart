// lib/services/permission_helper.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralise la logique de demande de permissions en respectant
/// les règles Apple (App Store Review Guideline 5.1.1) et Google Play
/// (Permissions Policy) : on doit expliquer POURQUOI on demande la
/// permission AVANT d'afficher le système de dialog natif, sinon le
/// premier refus est souvent définitif et l'app est rejetée en review
/// si aucun contexte n'est donné.
class PermissionHelper {
  /// Affiche un dialog custom expliquant l'usage, puis déclenche la
  /// demande native si l'utilisateur accepte. Retourne true si accordé.
  static Future<bool> requestWithRationale({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final status = await permission.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      final open = await _showDialog(
        context: context,
        title: title,
        message:
            "$message\n\nVous avez précédemment refusé cette permission. Vous pouvez l'activer manuellement dans les réglages de votre téléphone.",
        icon: icon,
        confirmLabel: 'Ouvrir les réglages',
      );
      if (open == true) {
        await openAppSettings();
      }
      return false;
    }

    // Explication AVANT le prompt natif — étape obligatoire pour les
    // guidelines Apple/Google sur les permissions sensibles (caméra, micro).
    final accepted = await _showDialog(
      context: context,
      title: title,
      message: message,
      icon: icon,
      confirmLabel: 'Autoriser',
    );

    if (accepted != true) return false;

    final result = await permission.request();
    return result.isGranted;
  }

  static Future<bool?> _showDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16294D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D6CDF).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF2D6CDF), size: 30),
        ),
        title: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFAEB9D4), fontSize: 13.5, height: 1.4)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Pas maintenant', style: TextStyle(color: Color(0xFFAEB9D4))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A1F44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
