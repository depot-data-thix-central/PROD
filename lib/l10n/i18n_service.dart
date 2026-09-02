// lib/l10n/i18n_service.dart
//
// ============================================================================
// I18N SERVICE — Production Enterprise
// ============================================================================
//
// Service i18n avancé offrant des helpers de formatage date/heure/nombre
// en plus de [AppLocalizations].
//
// Langues supportées (8) — synchronisées avec app_localizations.dart :
//   fr, en, es, pt, ln, sw, kg, lu
//
// Architecture :
//   - Singleton partagé (cache des formats partagé entre instances)
//   - Wraps AppLocalizations avec formatage aware-locale
//   - Cache DateFormat/NumberFormat pour performance
//   - Validation robuste des inputs
//   - Logs structurés [I18nService]
//   - Fallback intelligent sur FR si clé manquante
//
// Usage :
//   ```dart
//   final svc = context.i18n;                        // extension
//   svc.t('home_premium_member')                   // Simple
//   svc.t('sos_pin_enter', args: ['4'])            // Paramétré
//   svc.plural('contact', 5)                       // Pluriel
//   svc.formatDate(DateTime.now())                 // Date locale-aware
//   svc.formatNumber(12345.6)                      // Nombre locale-aware
//   svc.relativeTime(pastDate)                     // "il y a 5 min"
//   svc.formatCurrency(1500)                       // "1 500 €" (FR)
//   ```
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';

// ============================================================================
// CONSTANTS & CONFIG MAPS
// ============================================================================

/// Maps language codes to intl locale strings for formatting.
///
/// Les langues nationales RDC (ln, kg, lu) utilisent les conventions FR
/// car intl ne fournit pas de data dédiée pour ces langues.
const Map<String, String> _intlLocaleMap = {
  'fr': 'fr_FR',
  'en': 'en_US',
  'es': 'es_ES',
  'pt': 'pt_PT',
  'sw': 'sw_TZ',
  'ln': 'fr_FR', // Lingála → French conventions
  'kg': 'fr_CD', // Kikongo → French Congo conventions
  'lu': 'fr_CD', // Tshiluba → French Congo conventions
};

/// Default date pattern per language.
const Map<String, String> _datePatternMap = {
  'en': 'MMM d, yyyy',
  'es': 'd \'de\' MMM \'de\' yyyy',
  'pt': 'd \'de\' MMM \'de\' yyyy',
  'default': 'd MMM yyyy',
};

/// Default datetime pattern per language.
const Map<String, String> _dateTimePatternMap = {
  'en': 'MMM d, yyyy h:mm a',
  'es': 'd \'de\' MMM \'de\' yyyy H:mm',
  'pt': 'd \'de\' MMM \'de\' yyyy H:mm',
  'default': 'd MMM yyyy H:mm',
};

/// Relative-time builtin strings per language (fallback si clé absente).
final Map<String, _RelativeTimeBuiltins> _relativeTimeBuiltins = {
  'fr': _RelativeTimeBuiltins(
    justNow: 'À l\'instant',
    minutes: (n) => 'il y a $n min${n > 1 ? 's' : ''}',
    hours: (n) => 'il y a $n heure${n > 1 ? 's' : ''}',
    days: (n) => 'il y a $n jour${n > 1 ? 's' : ''}',
    inTheFuture: 'dans un instant',
  ),
  'en': _RelativeTimeBuiltins(
    justNow: 'Just now',
    minutes: (n) => '$n min${n > 1 ? 's' : ''} ago',
    hours: (n) => '$n hour${n > 1 ? 's' : ''} ago',
    days: (n) => '$n day${n > 1 ? 's' : ''} ago',
    inTheFuture: 'Just now',
  ),
  'es': _RelativeTimeBuiltins(
    justNow: 'Ahora mismo',
    minutes: (n) => 'hace $n min',
    hours: (n) => 'hace $n hora${n > 1 ? 's' : ''}',
    days: (n) => 'hace $n día${n > 1 ? 's' : ''}',
    inTheFuture: 'en un momento',
  ),
  'pt': _RelativeTimeBuiltins(
    justNow: 'Agora',
    minutes: (n) => 'há $n min',
    hours: (n) => 'há $n hora${n > 1 ? 's' : ''}',
    days: (n) => 'há $n dia${n > 1 ? 's' : ''}',
    inTheFuture: 'em breve',
  ),
  'sw': _RelativeTimeBuiltins(
    justNow: 'Sasa hivi',
    minutes: (n) => 'dakika $n zilizopita',
    hours: (n) => 'saa $n zilizopita',
    days: (n) => 'siku $n zilizopita',
    inTheFuture: 'hivi karibuni',
  ),
  'ln': _RelativeTimeBuiltins(
    justNow: 'Sikawa',
    minutes: (n) => 'Miniti $n eleki',
    hours: (n) => 'Ngonga $n eleki',
    days: (n) => 'Mikolo $n eleki',
    inTheFuture: 'Kala mingi te',
  ),
  'kg': _RelativeTimeBuiltins(
    justNow: 'Ntangu yai',
    minutes: (n) => 'Miniti $n me luta',
    hours: (n) => 'Ngonga $n me luta',
    days: (n) => 'Bilumbu $n me luta',
    inTheFuture: 'Ntangu yai',
  ),
  'lu': _RelativeTimeBuiltins(
    justNow: 'Lelu',
    minutes: (n) => 'Minute $n iluta',
    hours: (n) => 'Ngonga $n iluta',
    days: (n) => 'Bikuva $n biluta',
    inTheFuture: 'Lelu',
  ),
};

/// Default currencies per language.
/// Note : LN, KG, LU utilisent tous CDF (Franc Congolais - RDC).
const Map<String, String> _defaultCurrencyMap = {
  'fr': 'EUR',
  'en': 'USD',
  'es': 'EUR',
  'pt': 'EUR',
  'sw': 'TZS',
  'ln': 'CDF',
  'kg': 'CDF',
  'lu': 'CDF',
  'default': 'EUR',
};

/// Limites de validation de dates raisonnables.
const int _kMinValidYear = 1850;
const int _kMaxValidYear = 2200;

// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Container pour les strings builtin relative-time d'une langue.
class _RelativeTimeBuiltins {
  final String justNow;
  final String Function(int n) minutes;
  final String Function(int n) hours;
  final String Function(int n) days;
  final String inTheFuture;

  const _RelativeTimeBuiltins({
    required this.justNow,
    required this.minutes,
    required this.hours,
    required this.days,
    required this.inTheFuture,
  });
}

/// Cache partagé pour [DateFormat] et [NumberFormat].
///
/// Singleton pour éviter de recréer les formatters coûteux.
class _FormatCache {
  _FormatCache._internal();
  static final _FormatCache _instance = _FormatCache._internal();
  factory _FormatCache() => _instance;

  final Map<String, DateFormat> _dateFormats = {};
  final Map<String, NumberFormat> _numberFormats = {};

  DateFormat dateFormat(String pattern, String locale) {
    final key = '$locale|$pattern';
    return _dateFormats[key] ??= DateFormat(pattern, locale);
  }

  NumberFormat numberFormat(String locale) {
    return _numberFormats['dec|$locale'] ??=
        NumberFormat.decimalPattern(locale);
  }

  NumberFormat compactFormat(String locale) {
    return _numberFormats['cmp|$locale'] ??=
        NumberFormat.compact(locale: locale);
  }

  NumberFormat currencyFormat(String locale, String symbol, int decimals) {
    final key = 'cur|$locale|$symbol|$decimals';
    return _numberFormats[key] ??= NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimals,
    );
  }

  /// Nettoyage du cache (pour tests).
  @visibleForTesting
  void clear() {
    _dateFormats.clear();
    _numberFormats.clear();
  }
}

// ============================================================================
// I18N SERVICE
// ============================================================================

/// Service i18n de haut niveau qui encapsule [AppLocalizations] et ajoute
/// le formatage date/heure/nombre aware-locale avec cache et validation.
class I18nService {
  final AppLocalizations _loc;
  final _FormatCache _cache = _FormatCache();

  I18nService._(this._loc);

  /// Crée un [I18nService] depuis le [AppLocalizations] le plus proche.
  ///
  /// ⚠️ Retourne `null` si aucun [AppLocalizations] trouvé dans l'arbre.
  static I18nService? tryOf(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (loc == null) {
      debugPrint('[I18nService] ⚠️ No AppLocalizations in widget tree');
      return null;
    }
    return I18nService._(loc);
  }

  /// Crée un [I18nService] depuis le [AppLocalizations] le plus proche.
  ///
  /// **Throws** si aucun [AppLocalizations] n'est trouvé.
  factory I18nService.of(BuildContext context) {
    final svc = tryOf(context);
    if (svc == null) {
      throw StateError(
        'I18nService.of() called with a context that does not contain '
        'AppLocalizations. Ensure Localizations delegate is set up.',
      );
    }
    return svc;
  }

  // ── Translation API ────────────────────────────────────────────────────────

  /// Traduction simple avec fallback : lang → fr → key.
  ///
  /// Supporte la substitution de paramètres `{0}`, `{1}`, ...
  ///
  /// ```dart
  /// svc.t('sos_pin_enter', args: ['4']) // "Entrez votre code à 4 chiffres"
  /// ```
  String t(String key, {List<String>? args}) {
    if (key.isEmpty) {
      debugPrint('[I18nService] ⚠️ t() called with empty key');
      return '';
    }
    return _loc.t(key, args: args);
  }

  /// Pluriel simple : utilise les suffixes `_zero`, `_one`, `_many`
  /// définis dans [AppLocalizations].
  ///
  /// ```dart
  /// svc.plural('contact', 0) // "Aucun contact"
  /// svc.plural('contact', 1) // "1 contact"
  /// svc.plural('contact', 5) // "5 contacts"
  /// ```
  String plural(String key, int count, {List<String>? args}) {
    if (key.isEmpty) {
      debugPrint('[I18nService] ⚠️ plural() called with empty key');
      return '';
    }
    return _loc.plural(key, count, args: args);
  }

  /// Pluriel manuel avec deux clés (singulier + pluriel).
  ///
  /// Utile pour cas spécifiques non couverts par `plural()`.
  /// ```dart
  /// svc.tp('events_seats', 'events_seats_plural', 3)
  /// ```
  String tp(String singularKey, String pluralKey, int count,
      {List<String>? args}) {
    if (singularKey.isEmpty || pluralKey.isEmpty) {
      debugPrint('[I18nService] ⚠️ tp() called with empty key');
      return '';
    }
    final key = count == 1 ? singularKey : pluralKey;
    final finalArgs = <String>[count.toString(), ...?args];
    return _loc.t(key, args: finalArgs);
  }

  /// Traduction avec paramètres nommés `{name}`.
  String tn(String key, Map<String, String> args) {
    if (key.isEmpty) {
      debugPrint('[I18nService] ⚠️ tn() called with empty key');
      return '';
    }
    return _loc.tn(key, args);
  }

  // ── RTL / Direction ────────────────────────────────────────────────────────

  /// La langue active est-elle RTL ?
  bool get isRtl => _isLanguageRtl(_loc.locale.languageCode);

  /// [TextDirection] correspondant à la langue active.
  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Détection RTL basée sur le code de langue.
  static bool _isLanguageRtl(String code) {
    const rtlCodes = {'ar', 'he', 'fa', 'ur', 'yi', 'ps', 'sd'};
    return rtlCodes.contains(code);
  }

  // ── Current locale info ────────────────────────────────────────────────────

  /// La [Locale] active.
  Locale get locale => _loc.locale;

  /// Le code de langue (e.g. `'fr'`, `'ln'`).
  String get languageCode => _loc.locale.languageCode;

  /// Le string intl-compatible (e.g. `'fr_FR'`, `'sw_TZ'`).
  String get intlLocale =>
      _intlLocaleMap[languageCode] ?? _intlLocaleMap['fr']!;

  /// Métadonnées de la langue active (nom, drapeau).
  LanguageInfo? get currentLanguageInfo =>
      kSupportedLanguages[languageCode];

  // ── Date / Time formatting ─────────────────────────────────────────────────

  /// Formatage date aware-locale (ex : "2 août 2025" en FR).
  ///
  /// Valide l'input et fallback sur ISO 8601 en cas d'erreur.
  String formatDate(DateTime date, {String? pattern}) {
    if (!_isValidDate(date)) {
      debugPrint('[I18nService] ⚠️ formatDate: invalid date');
      return '—';
    }

    final p = pattern ??
        _datePatternMap[languageCode] ??
        _datePatternMap['default']!;
    try {
      return _cache.dateFormat(p, intlLocale).format(date.toLocal());
    } catch (e) {
      debugPrint('[I18nService] ❌ formatDate failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return date.toIso8601String().substring(0, 10);
    }
  }

  /// Formatage heure aware-locale (24h par défaut).
  String formatTime(DateTime time, {bool use24h = true}) {
    if (!_isValidDate(time)) {
      debugPrint('[I18nService] ⚠️ formatTime: invalid date');
      return '—';
    }
    final pattern = use24h ? 'HH:mm' : 'hh:mm a';
    try {
      return _cache.dateFormat(pattern, intlLocale).format(time.toLocal());
    } catch (e) {
      debugPrint('[I18nService] ❌ formatTime failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return '--:--';
    }
  }

  /// Formatage date + heure aware-locale.
  String formatDateTime(DateTime dt, {String? pattern}) {
    if (!_isValidDate(dt)) {
      debugPrint('[I18nService] ⚠️ formatDateTime: invalid date');
      return '—';
    }
    final p = pattern ??
        _dateTimePatternMap[languageCode] ??
        _dateTimePatternMap['default']!;
    try {
      return _cache.dateFormat(p, intlLocale).format(dt.toLocal());
    } catch (e) {
      debugPrint('[I18nService] ❌ formatDateTime failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return dt.toIso8601String().substring(0, 16).replaceFirst('T', ' ');
    }
  }

  /// Temps relatif (ex : "il y a 5 min").
  ///
  /// **Plages** :
  /// - < 1 min → "à l'instant" (locale-specific)
  /// - < 60 min → "il y a n min"
  /// - < 24 h → "il y a n heures"
  /// - < 7 jours → "il y a n jours"
  /// - >= 7 jours → date absolue
  ///
  /// Dates futures traitées comme "à l'instant" / "bientôt".
  String relativeTime(DateTime past) {
    if (!_isValidDate(past)) {
      debugPrint('[I18nService] ⚠️ relativeTime: invalid date');
      return '—';
    }

    final now = DateTime.now();
    final diff = now.difference(past);
    final builtins = _builtins;

    // Dates futures
    if (diff.isNegative) {
      return builtins.inTheFuture;
    }

    // < 1 min
    if (diff.inSeconds < 60) {
      // Essayer clé i18n, sinon fallback sur builtin
      final key = t('common_just_now');
      return _isKeyMissing(key, 'common_just_now')
          ? builtins.justNow
          : key;
    }

    // < 60 min
    if (diff.inMinutes < 60) {
      final pluralStr = plural('minute', diff.inMinutes);
      // Construit "il y a X minutes" si clé relative existe
      final key = t('time_minutes_ago', args: [diff.inMinutes.toString()]);
      if (!_isKeyMissing(key, 'time_minutes_ago')) return key;
      return builtins.minutes(diff.inMinutes);
    }

    // < 24 h
    if (diff.inHours < 24) {
      final key = t('time_hours_ago', args: [diff.inHours.toString()]);
      if (!_isKeyMissing(key, 'time_hours_ago')) return key;
      return builtins.hours(diff.inHours);
    }

    // < 7 jours
    if (diff.inDays < 7) {
      final key = t('time_days_ago', args: [diff.inDays.toString()]);
      if (!_isKeyMissing(key, 'time_days_ago')) return key;
      return builtins.days(diff.inDays);
    }

    // >= 7 jours → date absolue
    return formatDate(past);
  }

  /// Vérifie si une clé a retourné sa propre valeur (indique clé manquante).
  bool _isKeyMissing(String result, String key) =>
      result == key || result.isEmpty;

  /// Builtin pour la langue courante (fallback FR).
  _RelativeTimeBuiltins get _builtins =>
      _relativeTimeBuiltins[languageCode] ?? _relativeTimeBuiltins['fr']!;

  // ── Number formatting ──────────────────────────────────────────────────────

  /// Formate un nombre avec séparateurs milliers/décimales aware-locale.
  String formatNumber(num value, {int? decimalDigits}) {
    try {
      final fmt = _cache.numberFormat(intlLocale);
      if (decimalDigits != null) {
        fmt.minimumFractionDigits = decimalDigits;
        fmt.maximumFractionDigits = decimalDigits;
      }
      return fmt.format(value);
    } catch (e) {
      debugPrint('[I18nService] ❌ formatNumber failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return value.toString();
    }
  }

  /// Formate un nombre en notation compacte (e.g. `12k`, `1.2M`).
  String formatCompact(num value) {
    try {
      return _cache.compactFormat(intlLocale).format(value);
    } catch (e) {
      debugPrint('[I18nService] ❌ formatCompact failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return value.toString();
    }
  }

  /// Formate une valeur monétaire.
  ///
  /// [symbol] défaut = monnaie de la langue (e.g. EUR pour FR, CDF pour LN).
  ///
  /// ```dart
  /// svc.formatCurrency(1500)                     // "1 500 €" (FR)
  /// svc.formatCurrency(1500, symbol: 'USD')      // "1 500 $"
  /// svc.formatCurrency(1500.5, decimals: 2)      // "1 500,50 €"
  /// ```
  String formatCurrency(num value, {String? symbol, int decimals = 0}) {
    final s = symbol ??
        _defaultCurrencyMap[languageCode] ??
        _defaultCurrencyMap['default']!;
    try {
      return _cache.currencyFormat(intlLocale, s, decimals).format(value);
    } catch (e) {
      debugPrint('[I18nService] ❌ formatCurrency failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return '$value $s';
    }
  }

  /// Formate un numéro de téléphone (best effort, pas de lib externe).
  String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    // Garde seulement chiffres et +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return phone;

    // Format international simple : +XXX XX XX XX XX
    if (cleaned.startsWith('+') && cleaned.length >= 10) {
      final cc = cleaned.substring(0, 3);
      final rest = cleaned.substring(3);
      final chunks = <String>[];
      for (var i = 0; i < rest.length; i += 2) {
        chunks.add(rest.substring(i,
            i + 2 > rest.length ? rest.length : i + 2));
      }
      return '$cc ${chunks.join(' ')}';
    }
    return cleaned;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Valide qu'une date est dans une plage raisonnable.
  bool _isValidDate(DateTime date) {
    final year = date.year;
    return year >= _kMinValidYear && year <= _kMaxValidYear;
  }
}

// ---------------------------------------------------------------------------
// Convenience extension
// ---------------------------------------------------------------------------

extension I18nServiceX on BuildContext {
  /// Retourne un [I18nService] pour le build context courant.
  ///
  /// ⚠️ **Ne pas utiliser** si [AppLocalizations] peut être null.
  /// Préférer [tryI18n] dans ce cas.
  I18nService get i18n => I18nService.of(this);

  /// Retourne un [I18nService] ou null si pas de localisations.
  I18nService? get tryI18n => I18nService.tryOf(this);
}

// ---------------------------------------------------------------------------
// RTL-aware Directionality wrapper
// ---------------------------------------------------------------------------

/// Wrappe [child] dans un [Directionality] basé sur la langue active.
///
/// ```dart
/// return LocaleDirectionality(child: Scaffold(...));
/// ```
class LocaleDirectionality extends StatelessWidget {
  final Widget child;
  const LocaleDirectionality({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final svc = I18nService.tryOf(context);
    final direction = svc?.textDirection ?? TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker helpers — uses kSupportedLanguages from locale_controller
// ---------------------------------------------------------------------------

/// Helpers pour le language picker UI.
///
/// Utilise [kSupportedLanguages] de [locale_controller.dart] comme source
/// unique de vérité (évite duplication).
class SupportedLanguages {
  SupportedLanguages._();

  /// Liste des langues pour affichage UI (avec code, nom natif, drapeau).
  static List<Map<String, String>> get all => kSupportedLanguages.values
      .map((info) => {
            'code': info.code,
            'name': info.nativeName,
            'flag': info.flag ?? '',
          })
      .toList();

  /// Récupère les infos d'une langue par son code.
  static Map<String, String>? forCode(String code) {
    final info = kSupportedLanguages[code];
    if (info == null) return null;
    return {
      'code': info.code,
      'name': info.nativeName,
      'flag': info.flag ?? '',
    };
  }

  /// Vérifie si [code] est une langue supportée.
  static bool isSupported(String code) =>
      kSupportedLanguages.containsKey(code);

  /// Nombre de langues supportées.
  static int get count => kSupportedLanguages.length;
}
