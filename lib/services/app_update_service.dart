// lib/services/app_update_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Détecte une nouvelle version sur le Play Store et lance la mise à jour.
/// Fonctionne uniquement sur Android, pour une app installée depuis le Play Store.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _kLastPromptKey = 'app_update_last_prompt_ms';
  static const Duration _kPromptInterval = Duration(hours: 24);

  /// true quand une mise à jour est disponible (écouté par le header).
  final ValueNotifier<bool> updateAvailable = ValueNotifier<bool>(false);

  AppUpdateInfo? _info;
  Future<void>? _checkFuture;
  bool _sessionPromptHandled = false;

  String installedVersion = '';
  String installedBuild = '';

  int? get storeVersionCode => _info?.availableVersionCode;

  // ── DÉTECTION (une seule fois par session) ──
  Future<void> checkForUpdate() => _checkFuture ??= _doCheck();

  Future<void> _doCheck() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      installedVersion = pkg.version;
      installedBuild = pkg.buildNumber;

      if (kIsWeb || !Platform.isAndroid) return;

      final info = await InAppUpdate.checkForUpdate();
      _info = info;

      var available = info.updateAvailability == UpdateAvailability.updateAvailable;

      // Sécurité : compare le versionCode du Play Store avec celui installé.
      final storeCode = info.availableVersionCode;
      final installedCode = int.tryParse(installedBuild);
      if (available && storeCode != null && installedCode != null && storeCode <= installedCode) {
        available = false;
      }

      updateAvailable.value = available;
    } catch (e) {
      // Normal en debug / hors Play Store / sans réseau.
      debugPrint('[AppUpdate] ⚠️ Check failed (non-critical): $e');
      updateAvailable.value = false;
    }
  }

  // ── RAPPEL : le panneau s'affiche au maximum 1 fois / 24 h ──
  Future<bool> shouldPromptNow() async {
    // Verrou synchrone : évite un double affichage si le header est reconstruit.
    if (_sessionPromptHandled) return false;
    _sessionPromptHandled = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastPromptKey);
      if (last == null) return true;
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed >= _kPromptInterval.inMilliseconds;
    } catch (_) {
      return true;
    }
  }

  Future<void> markPromptedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastPromptKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[AppUpdate] ⚠️ markPromptedNow failed: $e');
    }
  }

  // ── LANCEMENT DE LA MISE À JOUR ──
  Future<void> startUpdate() async {
    final info = _info;
    try {
      if (info != null && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (info != null && info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
        return;
      }
    } catch (e) {
      debugPrint('[AppUpdate] ⚠️ In-app update failed, opening Play Store: $e');
    }
    await openStore();
  }

  Future<void> openStore() async {
    try {
      final pkg = (await PackageInfo.fromPlatform()).packageName;
      final market = Uri.parse('market://details?id=$pkg');
      final web = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
      final ok = await launchUrl(market, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdate] ❌ openStore failed: $e');
    }
  }
}
