//lib/services/ota_update_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX ID — Service OTA (Over-The-Air) via Shorebird.
///
/// Canal 1 : patchs du code Dart livrés en quelques heures, sans Play Store
///           ni réinstallation d'APK (appliqués au prochain lancement).
/// Canal 2 : [AppUpdateService] (existant, inchangé) garde la main sur les
///           releases natives : plugins, assets, Kotlin, upgrade Flutter.
///
/// Philosophie (identique à AppUpdateService) :
/// - singleton, ValueNotifier, jamais bloquant pour le démarrage ;
/// - `auto_update: true` (shorebird.yaml) télécharge déjà en fond ; ce
///   service ajoute l'UX : patch prêt → proposer le redémarrage (throttle
///   24 h), n° de patch affiché dans les réglages ;
/// - silencieux et inoffensif en debug, build non-Shorebird ou hors réseau.
/// ═══════════════════════════════════════════════════════════════════════
class OtaUpdateService {
  OtaUpdateService._();
  static final OtaUpdateService instance = OtaUpdateService._();

  // ── Persistance du throttle de prompt (même pattern qu'AppUpdateService) ──
  static const String _kLastPromptKey = 'ota_restart_prompt_last_ms';
  static const Duration _promptThrottle = Duration(hours: 24);

  /// Canal de patch écouté par ce build.
  /// Défaut : `stable`. Builds de test internes :
  /// `--dart-define=SHOREBIRD_TRACK=staging` (à passer à la release ET au patch).
  static const String _trackName =
      String.fromEnvironment('SHOREBIRD_TRACK', defaultValue: 'stable');

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Un patch est disponible côté serveur (téléchargement à lancer/en cours).
  final ValueNotifier<bool> patchAvailable = ValueNotifier<bool>(false);

  /// Un patch est téléchargé → sera appliqué au PROCHAIN lancement.
  /// C'est ce notifier que le header écoute pour proposer « Redémarrer ».
  final ValueNotifier<bool> patchReadyToRestart = ValueNotifier<bool>(false);

  /// N° du patch actuellement actif (null = release nue). Pour les réglages.
  final ValueNotifier<int?> currentPatchNumber = ValueNotifier<int?>(null);

  /// N° du patch téléchargé en attente de redémarrage. Pour le sheet.
  final ValueNotifier<int?> nextPatchNumber = ValueNotifier<int?>(null);

  Future<void>? _sessionCheck;
  bool _downloading = false;

  String get trackName => _trackName;
  UpdateTrack get _track => UpdateTrack(_trackName);

  /// Shorebird ne cible que les builds release Android/iOS.
  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Vérifie + télécharge un patch. Une seule fois par session.
  /// À appeler en post-frame, SANS await bloquant (appels réseau lents).
  Future<void> checkAndDownload() => _sessionCheck ??= _run();

  /// Vérification manuelle (bouton « Vérifier les mises à jour » des réglages).
  /// Retourne true si un patch est prêt à être appliqué.
  Future<bool> checkNow() async {
    _sessionCheck = null;
    await checkAndDownload();
    return patchReadyToRestart.value;
  }

  Future<void> _run() async {
    if (!isSupportedPlatform) return;
    try {
      // `isAvailable` = false en debug / build `flutter build` (non-Shorebird).
      // On sort sans bruit : l'app fonctionne normalement, sans OTA.
      if (!_updater.isAvailable) {
        debugPrint('[OTA] Updater indisponible (build non-Shorebird ou debug).');
        return;
      }

      await refreshPatchInfo();

      final status = await _updater.checkForUpdate(track: _track);
      if (status == UpdateStatus.outdated) {
        patchAvailable.value = true;
        await _download();
      } else if (status == UpdateStatus.restartRequired) {
        // Patch déjà téléchargé lors d'un lancement précédent.
        await _markReady();
      }
      // upToDate / unavailable → rien à faire.
    } catch (e) {
      // Hors réseau, serveur injoignable… non critique, on réessaiera
      // au prochain lancement. Jamais d'impact sur le démarrage.
      debugPrint('[OTA] ⚠️ Vérification non critique : $e');
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    _downloading = true;
    try {
      await _updater.update(track: _track);
      await _markReady();
      debugPrint('[OTA] ✅ Patch téléchargé — appliqué au prochain lancement.');
    } on UpdateException catch (e) {
      debugPrint('[OTA] ⚠️ Échec du téléchargement : ${e.message}');
    } catch (e) {
      debugPrint('[OTA] ⚠️ Échec du téléchargement : $e');
    } finally {
      _downloading = false;
    }
  }

  Future<void> _markReady() async {
    try {
      final next = await _updater.readNextPatch();
      nextPatchNumber.value = next?.number;
    } catch (_) {
      // Le n° est cosmétique : son absence n'empêche pas le redémarrage.
    }
    patchAvailable.value = false;
    patchReadyToRestart.value = true;
  }

  /// Rafraîchit le n° de patch actif (affiché dans Réglages → À propos).
  Future<void> refreshPatchInfo() async {
    try {
      final current = await _updater.readCurrentPatch();
      currentPatchNumber.value = current?.number;
    } catch (e) {
      debugPrint('[OTA] ⚠️ Lecture du patch courant : $e');
    }
  }

  // ── Throttle du prompt « Redémarrer » (24 h, comme AppUpdateService) ──────

  /// true si un patch est prêt ET qu'on n'a pas déjà proposé il y a < 24 h.
  Future<bool> shouldPromptRestart() async {
    if (!patchReadyToRestart.value) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastPromptKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed >= _promptThrottle.inMilliseconds;
    } catch (_) {
      return true; // prefs indisponibles → on propose quand même.
    }
  }

  /// À appeler à l'ouverture du sheet (pas au clic sur un bouton).
  Future<void> markRestartPromptedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kLastPromptKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Non critique.
    }
  }

  /// Applique le patch en fermant l'app (Android). L'utilisateur relance,
  /// le patch démarre. Retourne false si la fermeture n'est pas possible
  /// (iOS : Apple déconseille la fermeture programmée → l'utilisateur
  /// ferme et relance manuellement, le patch s'applique pareil).
  Future<bool> restartToApply() async {
    if (!patchReadyToRestart.value) return false;
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
      return true;
    }
    return false;
  }
}
