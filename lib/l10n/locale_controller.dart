// lib/l10n/locale_controller.dart
//
// ============================================================================
// LOCALE CONTROLLER — Production Enterprise
// ============================================================================
//
// Controller pour gérer la locale active de l'application THIX.
//
// Fonctionnalités :
//   - Persistance de la locale sélectionnée (SharedPreferences)
//   - Support de la locale système (fallback intelligent)
//   - 8 langues alignées avec app_localizations.dart
//   - Détection RTL pour ar/hébreu (futur)
//   - Validation robuste des locales (regex)
//   - Protection contre les race conditions
//   - Logs structurés pour debug
//   - Intégration Riverpod (provider global)
//
// Langues supportées :
//   - fr (Français) — défaut
//   - en (English)
//   - es (Español)
//   - pt (Português)
//   - ln (Lingála)       — RDC
//   - sw (Kiswahili)     — RDC
//   - kg (Kikongo)       — RDC
//   - lu (Tshiluba)      — RDC
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

/// Clé SharedPreferences pour stocker la locale sélectionnée.
const String _kLocaleKey = 'app_locale_code';

/// Clé pour "utiliser locale système" (valeur spéciale).
const String _kSystemLocaleValue = 'SYSTEM';

/// Code de langue par défaut si aucune locale n'est configurée.
const String _kDefaultLocaleCode = 'fr';

/// Regex de validation d'un code de langue (2-3 lettres minuscules).
final RegExp _kLocaleCodeRegex = RegExp(r'^[a-z]{2,3}$');

// ============================================================================
// LANGUAGE METADATA
// ============================================================================

/// Métadonnées pour chaque langue supportée.
class LanguageInfo {
  final String code;
  final String nativeName;
  final String englishName;
  final String? flag;
  final bool isRTL;

  const LanguageInfo({
    required this.code,
    required this.nativeName,
    required this.englishName,
    this.flag,
    this.isRTL = false,
  });
}

/// Informations sur toutes les langues supportées.
/// ⚠️ DOIT être synchronisé avec app_localizations.dart
const Map<String, LanguageInfo> kSupportedLanguages = {
  'fr': LanguageInfo(
    code: 'fr',
    nativeName: 'Français',
    englishName: 'French',
    flag: '🇫🇷',
  ),
  'en': LanguageInfo(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
    flag: '🇬🇧',
  ),
  'es': LanguageInfo(
    code: 'es',
    nativeName: 'Español',
    englishName: 'Spanish',
    flag: '🇪🇸',
  ),
  'pt': LanguageInfo(
    code: 'pt',
    nativeName: 'Português',
    englishName: 'Portuguese',
    flag: '🇵🇹',
  ),
  'ln': LanguageInfo(
    code: 'ln',
    nativeName: 'Lingála',
    englishName: 'Lingala',
    flag: '🇨🇩',
  ),
  'sw': LanguageInfo(
    code: 'sw',
    nativeName: 'Kiswahili',
    englishName: 'Swahili',
    flag: '🇨🇩',
  ),
  'kg': LanguageInfo(
    code: 'kg',
    nativeName: 'Kikongo',
    englishName: 'Kikongo',
    flag: '🇨🇩',
  ),
  'lu': LanguageInfo(
    code: 'lu',
    nativeName: 'Tshiluba',
    englishName: 'Tshiluba',
    flag: '🇨🇩',
  ),
};

// ============================================================================
// LOCALE CONTROLLER
// ============================================================================

/// Controller pour gérer la locale active de l'application.
///
/// **Cycle de vie** :
/// 1. `init()` : Charge la locale persistée ou utilise la locale système
/// 2. `setLocale()` : Change la locale et la persiste
/// 3. `setSystem()` : Revient à la locale système (valeur spéciale)
///
/// **Locales supportées** : Voir `kSupportedLanguages`
class LocaleController extends ChangeNotifier {
  /// Locales supportées par l'application (ordre = priorité de fallback).
  static List<Locale> get supportedLocales =>
      kSupportedLanguages.keys.map((code) => Locale(code)).toList();

  /// Locale active courante.
  Locale _locale = const Locale(_kDefaultLocaleCode);

  /// Indique si on utilise la locale système (préférence = SYSTEM).
  bool _useSystem = true;

  /// Flag pour prévenir les appels concurrents.
  bool _isUpdating = false;

  /// Getter pour la locale active.
  Locale get locale => _locale;

  /// Getter : est-ce qu'on utilise la locale système ?
  bool get useSystem => _useSystem;

  /// Informations sur la langue active.
  LanguageInfo? get currentLanguageInfo =>
      kSupportedLanguages[_locale.languageCode];

  /// La langue active est-elle RTL ?
  bool get isRTL => currentLanguageInfo?.isRTL ?? false;

  /// TextDirection pour la langue active.
  TextDirection get textDirection =>
      isRTL ? TextDirection.rtl : TextDirection.ltr;

  // ─── INITIALIZATION ─────────────────────────────────────────────────

  /// Initialise le controller en chargeant la locale persistée.
  ///
  /// **Logique** :
  /// 1. Tente de charger la locale depuis SharedPreferences
  /// 2. Si valeur = SYSTEM → utilise la locale système
  /// 3. Si code valide et supporté → l'utilise
  /// 4. Sinon → utilise la locale par défaut (fr)
  Future<void> init() async {
    debugPrint('[LocaleController] 🚀 Initializing...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getString(_kLocaleKey);

      // Cas 1 : Valeur spéciale "SYSTEM"
      if (storedValue == _kSystemLocaleValue) {
        _useSystem = true;
        _locale = _resolveSystemOrDefault();
        debugPrint('[LocaleController] ✓ Using system locale: '
            '${_locale.languageCode}');
        notifyListeners();
        return;
      }

      // Cas 2 : Code de langue persisté valide
      if (storedValue != null && _isValidCode(storedValue)) {
        _useSystem = false;
        _locale = Locale(storedValue);
        debugPrint('[LocaleController] ✓ Loaded persisted locale: $storedValue');
        notifyListeners();
        return;
      }

      // Cas 3 : Première utilisation → utiliser locale système
      _useSystem = true;
      _locale = _resolveSystemOrDefault();
      debugPrint('[LocaleController] ✓ First launch, using: '
          '${_locale.languageCode}');
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleController] ❌ Init failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      _useSystem = false;
      _locale = const Locale(_kDefaultLocaleCode);
      notifyListeners();
    }
  }

  // ─── SET LOCALE ─────────────────────────────────────────────────────

  /// Change la locale active et la persiste.
  ///
  /// Returns `true` si la locale a été changée, `false` sinon.
  Future<bool> setLocale(Locale locale) async {
    final code = locale.languageCode;

    // Validation : code valide et supporté ?
    if (!_isValidCode(code) || !isSupported(code)) {
      debugPrint('[LocaleController] ⚠️ Unsupported locale: $code');
      return false;
    }

    // Validation : déjà active ?
    if (!_useSystem && _locale.languageCode == code) {
      debugPrint('[LocaleController] ℹ️ Locale already active: $code');
      return false;
    }

    // Protection : race condition
    if (_isUpdating) {
      debugPrint('[LocaleController] ⚠️ Already updating, ignoring setLocale');
      return false;
    }

    _isUpdating = true;
    try {
      debugPrint('[LocaleController] 🔄 Setting locale: $code');

      // Mise à jour en mémoire
      _useSystem = false;
      _locale = Locale(code);
      notifyListeners();

      // Persistance
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, code);

      debugPrint('[LocaleController] ✓ Locale persisted: $code');
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

  /// Revient à la locale système.
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

      // Persistance de la valeur spéciale
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, _kSystemLocaleValue);

      // Résolution
      final newLocale = _resolveSystemOrDefault();
      final changed = _locale.languageCode != newLocale.languageCode ||
          !_useSystem;

      _useSystem = true;
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

  // ─── REFRESH SYSTEM LOCALE ──────────────────────────────────────────

  /// Rafraîchit la locale active si on utilise la locale système.
  ///
  /// À appeler quand `WidgetsBindingObserver.didChangeLocales` est invoqué.
  void refreshSystemLocale(List<Locale> locales) {
    if (!_useSystem) return;

    final newLocale = _resolveFromLocalesList(locales);
    if (newLocale.languageCode != _locale.languageCode) {
      debugPrint('[LocaleController] 🔄 System locale changed: '
          '${newLocale.languageCode}');
      _locale = newLocale;
      notifyListeners();
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Vérifie si un code de langue est supporté.
  static bool isSupported(String code) {
    if (!_isValidCode(code)) return false;
    return kSupportedLanguages.containsKey(code);
  }

  /// Valide le format d'un code de langue (2-3 lettres minuscules).
  static bool _isValidCode(String code) {
    if (code.isEmpty || code.length > 3) return false;
    return _kLocaleCodeRegex.hasMatch(code);
  }

  /// Retourne la liste des codes de langues supportés.
  static List<String> get supportedLanguageCodes =>
      kSupportedLanguages.keys.toList();

  /// Récupère les informations d'une langue.
  static LanguageInfo? getLanguageInfo(String code) =>
      kSupportedLanguages[code];

  /// Résout la locale à utiliser depuis une liste de locales (système).
  Locale _resolveFromLocalesList(List<Locale> locales) {
    for (final loc in locales) {
      if (_isValidCode(loc.languageCode) && isSupported(loc.languageCode)) {
        return Locale(loc.languageCode);
      }
    }
    return const Locale(_kDefaultLocaleCode);
  }

  /// Résout la locale système ou retourne la défaut.
  Locale _resolveSystemOrDefault() {
    try {
      final platformLocales = PlatformDispatcher.instance.locales;
      if (platformLocales.isNotEmpty) {
        return _resolveFromLocalesList(platformLocales);
      }
    } catch (e) {
      debugPrint('[LocaleController] ⚠️ Failed to get system locales: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
    return const Locale(_kDefaultLocaleCode);
  }

  /// Retourne la locale système si supportée, sinon la locale par défaut.
  Locale getSystemOrDefault() => _resolveSystemOrDefault();

  /// Réinitialise complètement le controller (pour tests).
  @visibleForTesting
  Future<void> reset() async {
    debugPrint('[LocaleController] 🔄 Resetting...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocaleKey);
      _useSystem = true;
      _locale = const Locale(_kDefaultLocaleCode);
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleController] ❌ Reset failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  @override
  void dispose() {
    debugPrint('[LocaleController] 👋 Disposed');
    super.dispose();
  }
}

// ============================================================================
// RIVERPOD PROVIDER
// ============================================================================

/// Provider global pour le LocaleController.
///
/// **Usage** :
/// ```dart
/// // Dans main()
/// final controller = LocaleController();
/// await controller.init();
///
/// runApp(
///   ProviderScope(
///     overrides: [
///       localeControllerProvider.overrideWithValue(controller),
///     ],
///     child: const MyApp(),
///   ),
/// );
///
/// // Dans un widget
/// final controller = ref.watch(localeControllerProvider);
/// Text(controller.currentLanguageInfo?.nativeName ?? '');
/// ```
final localeControllerProvider = Provider<LocaleController>((ref) {
  throw UnimplementedError(
    'localeControllerProvider must be overridden in main() '
    'after calling LocaleController.init()',
  );
});

/// Provider dérivé pour écouter uniquement la locale active (rebuild widgets).
final currentLocaleProvider = Provider<Locale>((ref) {
  final controller = ref.watch(localeControllerProvider);
  // Écoute les changements via ChangeNotifier
  ref.listen<LocaleController>(
    localeControllerProvider,
    (_, __) {},
  );
  return controller.locale;
});

/// Provider pour savoir si la locale actuelle est RTL.
final isRTLProvider = Provider<bool>((ref) {
  return ref.watch(localeControllerProvider).isRTL;
});

/// Provider pour la liste des langues disponibles (avec métadonnées).
final availableLanguagesProvider = Provider<List<LanguageInfo>>((ref) {
  return kSupportedLanguages.values.toList();
});
