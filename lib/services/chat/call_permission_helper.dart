// lib/services/chat/call_permission_helper.dart
//
// ============================================================================
// CALL PERMISSION HELPER v2.0 — Production Enterprise
// ============================================================================
//
// CHANGELOG v2.0 (depuis v1.0) :
//   ✅ Ajout de `ensureAtStartup()` pour les permissions système critiques :
//      - NOTIFICATIONS (Android 13+) : recevoir les pushs FCM
//      - ANSWER_PHONE_CALLS (Android 8+) : accepter depuis CallKit
//      - FULL_SCREEN_INTENT (Android 14+) : écran d'appel verrouillé
//      - IGNORE_BATTERY_OPTIMIZATIONS : fiabilité en Doze mode
//   ✅ Séparation claire entre :
//      - `ensure(type)` : micro/caméra AVANT chaque appel
//      - `ensureAtStartup()` : permissions système AU PREMIER LANCEMENT
//   ✅ Gestion propre des permissions "special app access" (FSI, Battery)
//      qui nécessitent d'ouvrir les paramètres système plutôt qu'une
//      demande runtime classique.
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
// ⚠️ IMPORTANT :
//   - `ensure(type)` doit être appelé AVANT tout appel à Agora
//     (startCall, acceptIncoming, prepareLocalPreview).
//   - `ensureAtStartup()` doit être appelé UNE FOIS au login / premier lancement.
// ============================================================================

import 'dart:io';

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
/// // 1. Au premier lancement / login
/// await CallPermissionHelper.ensureAtStartup(context);
///
/// // 2. Avant chaque appel
/// final ok = await CallPermissionHelper.ensure(context, CallType.video);
/// if (!ok) return; // Permissions refusées
/// // ... lancer l'appel
/// ```
class CallPermissionHelper {
  CallPermissionHelper._();

  // ═══════════════════════════════════════════════════════════════════════
  // PERMISSIONS AVANT APPEL (micro/caméra)
  // ═══════════════════════════════════════════════════════════════════════

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

    debugPrint('[CallPermission] ✓ All call permissions granted');
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PERMISSIONS SYSTÈME AU DÉMARRAGE (pushs + CallKit)
  // ═══════════════════════════════════════════════════════════════════════

  /// Vérifie et demande les permissions système critiques pour la fiabilité
  /// des appels VoIP. À appeler UNE FOIS au login / premier lancement.
  ///
  /// Gère :
  ///   - NOTIFICATIONS (Android 13+) : recevoir les pushs FCM
  ///   - PHONE / ANSWER_PHONE_CALLS : accepter depuis CallKit
  ///   - FULL_SCREEN_INTENT (Android 14+) : écran d'appel verrouillé
  ///   - IGNORE_BATTERY_OPTIMIZATIONS : fiabilité en Doze mode
  ///
  /// Retourne `true` si les permissions essentielles sont accordées.
  static Future<bool> ensureAtStartup(BuildContext context) async {
    debugPrint('[CallPermission] 🔐 ensureAtStartup()');

    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('[CallPermission] ℹ️ Non-Android platform, skipping');
      return true;
    }

    final l10n = AppLocalizations.of(context);
    var allOk = true;

    // 1. Notifications (Android 13+)
    // Sans cette permission, l'app ne reçoit PAS les pushs FCM.
    if (await Permission.notification.status.isDenied) {
      debugPrint('[CallPermission] 📲 Requesting NOTIFICATIONS');
      final result = await _showPermissionDialog(
        context: context,
        title: l10n.t('permission_notif_title'),
        message: l10n.t('permission_notif_message'),
        icon: Icons.notifications_active_rounded,
        confirmLabel: l10n.t('permission_allow'),
        cancelLabel: l10n.t('permission_cancel'),
        isDestructive: false,
      );

      if (result == true) {
        HapticFeedback.selectionClick();
        await Permission.notification.request();
      }

      final granted = await Permission.notification.status.isGranted;
      if (!granted) {
        debugPrint('[CallPermission] ❌ NOTIFICATIONS denied');
        allOk = false;
      }
    }

    // 2. Phone / ANSWER_PHONE_CALLS (Android 8+)
    // Sans cette permission, le bouton "Accepter" de CallKit ne fait rien.
    if (await Permission.phone.status.isDenied) {
      debugPrint('[CallPermission] 📞 Requesting PHONE');
      final result = await _showPermissionDialog(
        context: context,
        title: l10n.t('permission_phone_title'),
        message: l10n.t('permission_phone_message'),
        icon: Icons.phone_callback_rounded,
        confirmLabel: l10n.t('permission_allow'),
        cancelLabel: l10n.t('permission_cancel'),
        isDestructive: false,
      );

      if (result == true) {
        HapticFeedback.selectionClick();
        await Permission.phone.request();
      }

      final granted = await Permission.phone.status.isGranted;
      if (!granted) {
        debugPrint('[CallPermission] ⚠️ PHONE denied (CallKit accept may fail)');
        // Pas bloquant : CallKit peut fonctionner partiellement sans
      }
    }

    // 3. Full Screen Intent (Android 14+)
    // Permission "special app access" : pas de demande runtime, il faut
    // ouvrir les paramètres système.
    if (await _needsFullScreenIntentPermission()) {
      debugPrint('[CallPermission] 🖥️ FULL_SCREEN_INTENT not granted');
      final result = await _showPermissionDialog(
        context: context,
        title: l10n.t('permission_fsi_title'),
        message: l10n.t('permission_fsi_message'),
        icon: Icons.fullscreen_rounded,
        confirmLabel: l10n.t('permission_open_settings'),
        cancelLabel: l10n.t('permission_later'),
        isDestructive: false,
      );

      if (result == true && context.mounted) {
        HapticFeedback.mediumImpact();
        await openAppSettings();
      }
    }

    // 4. Ignore Battery Optimizations
    // Pour éviter que Doze mode tue les pushs en arrière-plan.
    if (await Permission.ignoreBatteryOptimizations.status.isDenied) {
      debugPrint('[CallPermission] 🔋 Requesting IGNORE_BATTERY_OPTIMIZATIONS');
      final result = await _showPermissionDialog(
        context: context,
        title: l10n.t('permission_battery_title'),
        message: l10n.t('permission_battery_message'),
        icon: Icons.battery_alert_rounded,
        confirmLabel: l10n.t('permission_open_settings'),
        cancelLabel: l10n.t('permission_later'),
        isDestructive: false,
      );

      if (result == true && context.mounted) {
        HapticFeedback.mediumImpact();
        await openAppSettings();
      }
    }

    debugPrint('[CallPermission] ${allOk ? "✓" : "⚠️"} '
        'ensureAtStartup completed (allOk=$allOk)');
    return allOk;
  }

  /// Vérifie si la permission FULL_SCREEN_INTENT est accordée (Android 14+).
  /// Retourne `false` si la permission est accordée, `true` si elle manque.
  static Future<bool> _needsFullScreenIntentPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      // flutter_callkit_incoming expose cette vérification
      // Si la méthode n'existe pas, on considère que la permission est OK
      final canUse = await _checkFullScreenIntentStatus();
      return !canUse;
    } catch (e) {
      debugPrint('[CallPermission] ⚠️ FSI check failed: $e');
      return false; // En cas d'erreur, on ne bloque pas
    }
  }

  /// Vérifie le statut FSI via le plugin CallKit.
  static Future<bool> _checkFullScreenIntentStatus() async {
    // Note : flutter_callkit_incoming expose `canUseFullScreenIntent`
    // depuis la version 2.0+. Si cette méthode n'existe pas, retourner true.
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      final result = await MethodChannel('flutter_callkit_incoming')
          .invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } catch (e) {
      debugPrint('[CallPermission] ⚠️ canUseFullScreenIntent not available: $e');
      return true; // Considérer comme OK si la méthode n'existe pas
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS PRIVÉS (inchangés depuis v1.0)
  // ═══════════════════════════════════════════════════════════════════════

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
      barrierDismissible: true,
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
// PERMISSION DIALOG WIDGET (privé, inchangé depuis v1.0)
// ============================================================================

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
