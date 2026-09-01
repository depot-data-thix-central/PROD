// lib/l10n/locale_controller.dart
//
// ============================================================================
// LOCALE CONTROLLER — Production Enterprise
// ============================================================================
//
// Controller pour gérer la locale active de l'application.
//
// Fonctionnalités :
//   - Persistance de la locale sélectionnée (SharedPreferences)
//   - Support de la locale système (fallback intelligent)
//   - 8 langues supportées : fr, en, ar, zh, pt, ln, kg, sw
//   - Validation robuste des locales
//   - Protection contre les race conditions
//   - Logs structurés pour debug
//
// Usage :
//   ```dart
//   // Initialisation (dans main())
//   final localeController = LocaleController();
//   await localeController.init();
//
//   // Changement de langue
//   await localeController.setLocale(Locale('en'));
//
//   // Retour à la locale système
//   await localeController.setSystem();
//
//   // Vérification
//   if (LocaleController.isSupported('fr')) { ... }
//   ```
//
// Architecture :
//   - ChangeNotifier pour reactivity Flutter
//   - SharedPreferences pour persistance
//   - Fallback intelligent sur locale système
//   - Validation stricte des locales
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

/// Clé SharedPreferences pour stocker la locale sélectionnée.
const String _kLocaleKey = 'app_locale_code';

/// Code de langue par défaut si aucune locale n'est configurée.
const String _kDefaultLocaleCode = 'fr';

/// Durée maximum pour les opérations async (protection race condition).
const Duration _kAsyncTimeout = Duration(seconds: 5);

// ============================================================================
// LOCALE CONTROLLER
// ============================================================================

/// Controller pour gérer la locale active de l'application.
///
/// **Cycle de vie** :
/// 1. `init()` : Charge la locale persistée ou utilise la locale système
/// 2. `setLocale()` : Change la locale et la persiste
/// 3. `setSystem()` : Revient à la locale système (supprime la préférence)
///
/// **Locales supportées** :
/// - `fr` (Français) — défaut
/// - `en` (English)
/// - `ar` (العربية) — RTL
/// - `zh` (中文)
/// - `pt` (Português)
/// - `ln` (Lingála)
/// - `kg` (Kikongo)
/// - `sw` (Kiswahili)
class LocaleController extends ChangeNotifier {
  /// Locales supportées par l'application.
  ///
  /// L'ordre définit la priorité de fallback :
  /// 1. Locale sélectionnée par l'utilisateur
  /// 2. Locale système (si supportée)
  /// 3. Français (défaut)
  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
    Locale('zh'),
    Locale('pt'),
    Locale('ln'),
    Locale('kg'),
    Locale('sw'),
  ];

  /// Locale active courante.
  Locale _locale = const Locale(_kDefaultLocaleCode);

  /// Flag pour prévenir les appels concurrents.
  bool _isUpdating = false;

  /// Getter pour la locale active.
  Locale get locale => _locale;

  // ─── INITIALIZATION ─────────────────────────────────────────────────

  /// Initialise le controller en chargeant la locale persistée.
  ///
  /// **Logique** :
  /// 1. Tente de charger la locale depuis SharedPreferences
  /// 2. Si valide et supportée → l'utilise
  /// 3. Sinon → utilise la locale système (si supportée)
  /// 4. Sinon → utilise la locale par défaut (fr)
  ///
  /// **Usage** :
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   final controller = LocaleController();
  ///   await controller.init();
  ///   runApp(MyApp(localeController: controller));
  /// }
  /// ```
  Future<void> init() async {
    debugPrint('[LocaleController] 🚀 Initializing...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCode = prefs.getString(_kLocaleKey);

      // Cas 1 : Locale persistée valide
      if (storedCode != null && isSupported(storedCode)) {
        _locale = Locale(storedCode);
        debugPrint('[LocaleController] ✓ Loaded persisted locale: $storedCode');
        notifyListeners();
        return;
      }

      // Cas 2 : Locale système (si supportée)
      final systemLocale = _getSystemLocale();
      if (systemLocale != null && _isLocaleSupported(systemLocale)) {
        _locale = systemLocale;
        debugPrint('[LocaleController] ✓ Using system locale: ${systemLocale.languageCode}');
        notifyListeners();
        return;
      }

      // Cas 3 : Fallback défaut
      _locale = const Locale(_kDefaultLocaleCode);
      debugPrint('[LocaleController] ✓ Using default locale: $_kDefaultLocaleCode');
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleController] ❌ Init failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      _locale = const Locale(_kDefaultLocaleCode);
      notifyListeners();
    }
  }

  // ─── SET LOCALE ─────────────────────────────────────────────────────

  /// Change la locale active et la persiste.
  ///
  /// **Validation** :
  /// - Vérifie que la locale est supportée
  /// - Ignore si identique à la locale actuelle
  /// - Protection contre les appels concurrents
  ///
  /// **Usage** :
  /// ```dart
  /// await controller.setLocale(Locale('en'));
  /// ```
  ///
  /// Returns `true` si la locale a été changée, `false` sinon.
  Future<bool> setLocale(Locale locale) async {
    // Validation : locale supportée ?
    if (!_isLocaleSupported(locale)) {
      debugPrint('[LocaleController] ⚠️ Unsupported locale: ${locale.languageCode}');
      return false;
    }

    // Validation : déjà active ?
    if (_locale.languageCode == locale.languageCode) {
      debugPrint('[LocaleController] ℹ️ Locale already active: ${locale.languageCode}');
      return false;
    }

    // Protection : race condition
    if (_isUpdating) {
      debugPrint('[LocaleController] ⚠️ Already updating, ignoring setLocale');
      return false;
    }

    _isUpdating = true;
    try {
      debugPrint('[LocaleController] 🔄 Setting locale: ${locale.languageCode}');

      // Mise à jour en mémoire
      _locale = locale;
      notifyListeners();

      // Persistance
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, locale.languageCode);

      debugPrint('[LocaleController] ✓ Locale persisted: ${locale.languageCode}');
      return true;
    } catch (e) {
      debugPrint('[LocaleController] ❌ setLocale failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  // ─── SET SYSTEM ─────────────────────────────────────────────────────

  /// Revient à la locale système (supprime la préférence persistée).
  ///
  /// **Logique** :
  /// 1. Supprime la locale persistée de SharedPreferences
  /// 2. Récupère la locale système
  /// 3. Si supportée → l'utilise
  /// 4. Sinon → utilise la locale par défaut (fr)
  ///
  /// **Usage** :
  /// ```dart
  /// await controller.setSystem();
  /// ```
  ///
  /// Returns `true` si la locale a été changée, `false` sinon.
  Future<bool> setSystem() async {
    // Protection : race condition
    if (_isUpdating) {
      debugPrint('[LocaleController] ⚠️ Already updating, ignoring setSystem');
      return false;
    }

    _isUpdating = true;
    try {
      debugPrint('[LocaleController] 🔄 Reverting to system locale');

      // Suppression de la préférence
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocaleKey);

      // Récupération de la locale système
      final systemLocale = _getSystemLocale();
      final newLocale = (systemLocale != null && _isLocaleSupported(systemLocale))
          ? systemLocale
          : const Locale(_kDefaultLocaleCode);

      // Mise à jour
      final changed = _locale.languageCode != newLocale.languageCode;
      _locale = newLocale;
      notifyListeners();

      debugPrint('[LocaleController] ✓ System locale: ${newLocale.languageCode}');
      return changed;
    } catch (e) {
      debugPrint('[LocaleController] ❌ setSystem failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Vérifie si un code de langue est supporté.
  ///
  /// **Usage** :
  /// ```dart
  /// if (LocaleController.isSupported('fr')) { ... }
  /// ```
  static bool isSupported(String code) {
    if (code.isEmpty) return false;
    return supportedLocales.any((l) => l.languageCode == code);
  }

  /// Retourne la liste des codes de langues supportés.
  static List<String> get supportedLanguageCodes =>
      supportedLocales.map((l) => l.languageCode).toList();

  /// Vérifie si une locale est dans la liste des locales supportées.
  bool _isLocaleSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  /// Récupère la locale système de manière sûre.
  ///
  /// Retourne `null` si impossible de la récupérer.
  Locale? _getSystemLocale() {
    try {
      // Plateforme Flutter
      final platformLocale = PlatformDispatcher.instance.locale;
      if (platformLocale.languageCode.isNotEmpty) {
        return platformLocale;
      }
    } catch (e) {
      debugPrint('[LocaleController] ⚠️ Failed to get system locale: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
    return null;
  }

  /// Retourne la locale système si supportée, sinon la locale par défaut.
  ///
  /// **Usage** :
  /// ```dart
  /// final locale = controller.getSystemOrDefault();
  /// ```
  Locale getSystemOrDefault() {
    final systemLocale = _getSystemLocale();
    if (systemLocale != null && _isLocaleSupported(systemLocale)) {
      return systemLocale;
    }
    return const Locale(_kDefaultLocaleCode);
  }

  /// Réinitialise complètement le controller (pour tests).
  ///
  /// ⚠️ **Usage interne uniquement** (tests unitaires).
  @visibleForTesting
  Future<void> reset() async {
    debugPrint('[LocaleController] 🔄 Resetting...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocaleKey);
      _locale = const Locale(_kDefaultLocaleCode);
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleController] ❌ Reset failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }
}
