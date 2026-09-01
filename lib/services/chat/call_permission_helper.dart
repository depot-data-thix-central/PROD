// lib/services/chat/call_permission_helper.dart
//
// ============================================================================
// CALL PERMISSION HELPER — Production Enterprise
// ============================================================================
//
// Helper de vérification/demande de permissions micro/caméra avant un appel.
//
// Architecture :
//   - Explication préalable avant demande système (conformité App Store / Play Store)
//   - Détection "permanently denied" avec redirection vers réglages OS
//   - Widget AlertDialog extrait (DRY) avec ThixPolicy
//   - Support Web (permission_handler a un comportement différent)
//
// Sécurité & UX :
//   - i18n complète (8+ clés)
//   - Semantics VoiceOver sur tous les éléments
//   - HapticFeedback sur actions
//   - mounted checks après tous les awaits
//   - Logs structurés [CallPermission]
//
// ⚠️ IMPORTANT : Ce helper doit être appelé AVANT tout appel à Agora
//    (startCall, acceptIncoming, prepareLocalPreview).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kDialogIconSize = 30.0;
const double _kDialogBorderRadius = 20.0;
const double _kButtonBorderRadius = 12.0;
const double _kContentFontSize = 13.5;
const double _kContentLineHeight = 1.4;

// ============================================================================
// CALL PERMISSION HELPER
// ============================================================================

/// Helper de vérification/demande de permissions micro/caméra.
///
/// **Usage** :
/// ```dart
/// final ok = await CallPermissionHelper.ensure(context, CallType.video);
/// if (!ok) return; // Permissions refusées
/// // ... lancer l'appel
/// ```
///
/// **Flux** :
///   1. Vérifie le statut actuel de la permission
///   2. Si granted → retourne `true` immédiatement
///   3. Si permanently denied → dialogue explicatif + redirection réglages OS
///   4. Sinon → dialogue explicatif + demande système
///
/// Retourne `true` si la permission est accordée, `false` sinon.
class CallPermissionHelper {
  CallPermissionHelper._();

  /// Vérifie et demande les permissions nécessaires selon le type d'appel.
  ///
  /// [context] : BuildContext pour afficher les dialogues.
  /// [type] : Type d'appel (audio = micro seul, vidéo = micro + caméra).
  ///
  /// Retourne `true` si toutes les permissions requises sont accordées.
  static Future<bool> ensure(BuildContext context, CallType type) async {
    debugPrint('[CallPermission] 🔐 ensure(type=${type.name})');

    // Sur Web, les permissions sont gérées par le navigateur directement
    if (kIsWeb) {
      debugPrint('[CallPermission] ℹ️ Web platform, skipping permission check');
      return true;
    }

    final l10n = AppLocalizations.of(context);

    // 1. Microphone (toujours requis)
    final micOk = await _ensureOne(
      context: context,
      permission: Permission.microphone,
      title: l10n.t('permission_mic_title'),
      message: l10n.t('permission_mic_message'),
      deniedMessage: l10n.t('permission_denied_message'),
      icon: Icons.mic_rounded,
      permissionLabel: 'microphone',
    );

    if (!micOk) {
      debugPrint('[CallPermission] ❌ Microphone permission denied');
      return false;
    }

    // 2. Caméra (uniquement si appel vidéo)
    if (type == CallType.video) {
      final camOk = await _ensureOne(
        context: context,
        permission: Permission.camera,
        title: l10n.t('permission_cam_title'),
        message: l10n.t('permission_cam_message'),
        deniedMessage: l10n.t('permission_denied_message'),
        icon: Icons.videocam_rounded,
        permissionLabel: 'camera',
      );

      if (!camOk) {
        debugPrint('[CallPermission] ❌ Camera permission denied');
        return false;
      }
    }

    debugPrint('[CallPermission] ✓ All permissions granted');
    return true;
  }

  /// Vérifie/demande une permission spécifique avec dialogue explicatif.
  static Future<bool> _ensureOne({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
    required String deniedMessage,
    required IconData icon,
    required String permissionLabel,
  }) async {
    final status = await permission.status;

    // Déjà accordée
    if (status.isGranted) {
      debugPrint('[CallPermission] ✓ $permissionLabel already granted');
      return true;
    }

    debugPrint('[CallPermission] ℹ️ $permissionLabel status: $status');

    // Permanently denied → dialogue explicatif + redirection réglages
    if (status.isPermanentlyDenied) {
      return await _handlePermanentlyDenied(
        context: context,
        title: title,
        message: message,
        deniedMessage: deniedMessage,
        icon: icon,
        permissionLabel: permissionLabel,
      );
    }

    // Denied ou non-déterminé → dialogue explicatif + demande système
    return await _handleRequestPermission(
      context: context,
      permission: permission,
      title: title,
      message: message,
      icon: icon,
      permissionLabel: permissionLabel,
    );
  }

  /// Gère le cas "permanently denied" : explique + propose d'ouvrir les réglages OS.
  static Future<bool> _handlePermanentlyDenied({
    required BuildContext context,
    required String title,
    required String message,
    required String deniedMessage,
    required IconData icon,
    required String permissionLabel,
  }) async {
    if (!context.mounted) return false;

    final l10n = AppLocalizations.of(context);
    debugPrint('[CallPermission] ⚠️ $permissionLabel permanently denied');

    final openSettings = await _showPermissionDialog(
      context: context,
      title: title,
      message: '$message\n\n$deniedMessage',
      icon: icon,
      confirmLabel: l10n.t('permission_open_settings'),
      cancelLabel: l10n.t('permission_cancel'),
      isDestructive: true,
    );

    if (openSettings == true) {
      debugPrint('[CallPermission] 🔧 Opening app settings');
      HapticFeedback.mediumImpact();
      await openAppSettings();

      // Attendre que l'utilisateur revienne dans l'app
      // et revérifier le statut
      if (!context.mounted) return false;
      await Future.delayed(const Duration(milliseconds: 300));

      final newStatus = await Permission.values
          .firstWhere((p) => p.value == permission.value)
          .status;
      return newStatus.isGranted;
    }

    return false;
  }

  /// Gère la demande initiale : dialogue explicatif + appel système.
  static Future<bool> _handleRequestPermission({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
    required IconData icon,
    required String permissionLabel,
  }) async {
    if (!context.mounted) return false;

    final l10n = AppLocalizations.of(context);
    debugPrint('[CallPermission] 🙋 Requesting $permissionLabel');

    final accepted = await _showPermissionDialog(
      context: context,
      title: title,
      message: message,
      icon: icon,
      confirmLabel: l10n.t('permission_allow'),
      cancelLabel: l10n.t('permission_cancel'),
      isDestructive: false,
    );

    if (accepted != true) {
      debugPrint('[CallPermission] ❌ User cancelled $permissionLabel dialog');
      return false;
    }

    HapticFeedback.selectionClick();

    final result = await permission.request();
    final granted = result.isGranted;

    debugPrint('[CallPermission] ${granted ? "✓" : "❌"} '
        '$permissionLabel system request: $result');

    return granted;
  }

  // ── WIDGET PRIVÉ : DIALOGUE DE PERMISSION ─────────────────────────────

  /// Affiche un dialogue de permission stylisé ThixPolicy avec Semantics.
  ///
  /// Retourne `true` si l'utilisateur confirme, `false` sinon.
  static Future<bool?> _showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required String confirmLabel,
    required String cancelLabel,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true, // UX : permet de fermer en tapant en dehors
      barrierColor: Colors.black54,
      builder: (ctx) => _PermissionDialog(
        title: title,
        message: message,
        icon: icon,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }
}

// ============================================================================
// PERMISSION DIALOG WIDGET (privé)
// ============================================================================

/// Dialogue de permission avec design ThixPolicy et accessibilité complète.
class _PermissionDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const _PermissionDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      dialog: true,
      label: '$title. $message',
      child: AlertDialog(
        backgroundColor: ThixPolicy.primaryDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kDialogBorderRadius),
        ),
        icon: Icon(
          icon,
          color: ThixPolicy.primary,
          size: _kDialogIconSize,
        ),
        title: Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: ThixPolicy.titleStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: ThixPolicy.bodyStyle.copyWith(
            color: ThixPolicy.textOnDark.withOpacity(0.75),
            fontSize: _kContentFontSize,
            height: _kContentLineHeight,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Semantics(
            button: true,
            label: cancelLabel,
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, false);
              },
              child: Text(
                cancelLabel,
                style: TextStyle(
                  color: ThixPolicy.textOnDark.withOpacity(0.75),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: confirmLabel,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDestructive
                    ? ThixPolicy.gold
                    : Colors.white,
                foregroundColor: ThixPolicy.primaryDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
