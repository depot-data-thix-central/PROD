// lib/l10n/i18n_service.dart
//
// ============================================================================
// I18N SERVICE — Production Enterprise
// ============================================================================
//
// Enhanced i18n service providing date/time and number formatting helpers
// on top of [AppLocalizations].
//
// Supported languages (8):
//   fr, en, ar, zh, pt, ln, kg, sw
//
// How to add a new language:
//   1. Add the new [Locale] to [LocaleController.supportedLocales].
//   2. Add the language code with all translation keys to [AppLocalizations._strings].
//   3. Add the locale label to [AppLocalizations.localeLabel].
//   4. If the language is RTL, update [AppLocalizations.isRtl].
//   5. Add a flag + name entry to [LanguageSheet] and the JSON reference file.
//   6. Add the matching [intl] date/number symbol data if needed.
//   7. Add the language to [_intlLocaleMap], [_relativeTimeBuiltins], etc.
//
// Architecture:
//   - Wraps AppLocalizations with locale-aware formatting
//   - Caches DateFormat/NumberFormat instances for performance
//   - Validates all inputs (DateTime, numbers)
//   - Structured logs with [I18nService] prefix
//   - Full coverage for all 8 supported languages
//
// Usage:
//   ```dart
//   final svc = I18nService.of(context);
//   svc.t('home_premium_member')                    // Simple translation
//   svc.t('profile_followers', {'count': '5'})      // Parameterized
//   svc.tp('events_seats', 'events_seats_plural', 3) // Plural
//   svc.formatDate(DateTime.now())                  // Locale-aware date
//   svc.formatNumber(12345.6)                       // Locale-aware number
//   svc.relativeTime(pastDate)                      // "5 min ago"
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
/// Lingála (ln) and Kikongo (kg) fall back to French conventions
/// as intl doesn't ship dedicated data for these languages.
const Map<String, String> _intlLocaleMap = {
  'fr': 'fr_FR',
  'en': 'en_US',
  'ar': 'ar',
  'zh': 'zh_CN',
  'pt': 'pt_BR',
  'sw': 'sw_TZ',
  'ln': 'fr_FR', // Lingála → French conventions
  'kg': 'fr_CD', // Kikongo → French Congo conventions
};

/// Default date pattern per language.
const Map<String, String> _datePatternMap = {
  'zh': 'yyyy年M月d日',
  'ar': 'd MMMM yyyy',
  'default': 'd MMM yyyy',
};

/// Default datetime pattern per language.
const Map<String, String> _dateTimePatternMap = {
  'zh': 'yyyy年M月d日 HH:mm',
  'ar': 'd MMMM yyyy HH:mm',
  'default': 'd MMM yyyy HH:mm',
};

/// Relative-time builtin strings per language.
/// Each entry maps a time unit to a function (int n) → String.
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
    inTheFuture: 'Just now', // future treated as "now"
  ),
  'ar': _RelativeTimeBuiltins(
    justNow: 'الآن',
    minutes: (n) => 'منذ $n دقيقة',
    hours: (n) => 'منذ $n ساعة',
    days: (n) => 'منذ $n يوم',
    inTheFuture: 'قريبًا',
  ),
  'zh': _RelativeTimeBuiltins(
    justNow: '刚刚',
    minutes: (n) => '$n分钟前',
    hours: (n) => '$n小时前',
    days: (n) => '$n天前',
    inTheFuture: '刚刚',
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
};

/// Default supported currencies per language.
const Map<String, String> _defaultCurrencyMap = {
  'fr': 'EUR',
  'en': 'USD',
  'ar': 'SAR',
  'zh': 'CNY',
  'pt': 'BRL',
  'sw': 'TZS',
  'ln': 'CDF',
  'kg': 'CDF',
  'default': 'EUR',
};

// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Container for relative-time builtin strings of a language.
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

/// Cache for [DateFormat] and [NumberFormat] instances to avoid
/// expensive re-creation on every formatting call.
class _FormatCache {
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
}

// ============================================================================
// I18N SERVICE
// ============================================================================

/// A high-level i18n service that wraps [AppLocalizations] and adds
/// locale-aware date/time and number formatting with caching and validation.
class I18nService {
  final AppLocalizations _loc;
  final _FormatCache _cache = _FormatCache();

  I18nService(this._loc) {
    debugPrint('[I18nService] 🚀 Initialized for locale: ${_loc.locale.languageCode}');
  }

  /// Creates an [I18nService] from the nearest [AppLocalizations] in the tree.
  factory I18nService.of(BuildContext context) =>
      I18nService(AppLocalizations.of(context));

  // ── Translation API ────────────────────────────────────────────────────────

  /// Simple translation with fallback chain: lang → fr → en → key.
  ///
  /// Supports `{param}` placeholder substitution:
  /// ```dart
  /// svc.t('profile_followers', {'count': '42'}) // "42 abonnés"
  /// ```
  String t(String key, [Map<String, String>? params]) {
    if (key.isEmpty) {
      debugPrint('[I18nService] ⚠️ t() called with empty key');
      return '';
    }
    return _loc.t(key, params: params);
  }

  /// Plural-form helper. Returns the singular or plural translation depending
  /// on [count] and automatically substitutes `{count}`.
  ///
  /// ```dart
  /// svc.tp('events_seats', 'events_seats_plural', 3) // "3 places disponibles"
  /// ```
  String tp(String singularKey, String pluralKey, int count,
      [Map<String, String>? extra]) {
    if (singularKey.isEmpty || pluralKey.isEmpty) {
      debugPrint('[I18nService] ⚠️ tp() called with empty key');
      return '';
    }
    return _loc.tp(singularKey, pluralKey, count, params: extra);
  }

  // ── RTL / Direction ────────────────────────────────────────────────────────

  /// Whether the active locale uses right-to-left text direction.
  bool get isRtl => _loc.isRtl;

  /// The [TextDirection] that matches the active locale.
  TextDirection get textDirection => _loc.textDirection;

  // ── Current locale info ────────────────────────────────────────────────────

  /// The active [Locale].
  Locale get locale => _loc.locale;

  /// The language code of the active locale (e.g. `'fr'`, `'ar'`).
  String get languageCode => _loc.locale.languageCode;

  /// The intl-compatible locale string (e.g. `'fr_FR'`, `'zh_CN'`).
  String get intlLocale =>
      _intlLocaleMap[languageCode] ?? _intlLocaleMap['fr']!;

  // ── Date / Time formatting ─────────────────────────────────────────────────

  /// Returns a locale-aware formatted date string.
  ///
  /// Uses abbreviated month names by default (e.g. `"2 août 2025"`).
  /// Validates the input and falls back to ISO 8601 on error.
  String formatDate(DateTime date, {String? pattern}) {
    if (!_isValidDate(date)) {
      debugPrint('[I18nService] ⚠️ formatDate: invalid date');
      return '—';
    }

    final p = pattern ?? _datePatternMap[languageCode] ?? _datePatternMap['default']!;
    try {
      return _cache.dateFormat(p, intlLocale).format(date.toLocal());
    } catch (e) {
      debugPrint('[I18nService] ❌ formatDate failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return date.toIso8601String().substring(0, 10);
    }
  }

  /// Returns a locale-aware formatted time string (24-hour by default).
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

  /// Returns a locale-aware date + time string.
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

  /// Returns a relative time label (e.g. "il y a 5 minutes").
  ///
  /// **Ranges**:
  /// - < 1 min → "just now" (locale-specific)
  /// - < 60 min → "n minutes ago"
  /// - < 24 h → "n hours ago"
  /// - < 7 days → "n days ago"
  /// - >= 7 days → formatted absolute date
  ///
  /// Future dates are handled gracefully as "just now" / "soon".
  String relativeTime(DateTime past) {
    if (!_isValidDate(past)) {
      debugPrint('[I18nService] ⚠️ relativeTime: invalid date');
      return '—';
    }

    final now = DateTime.now();
    final diff = now.difference(past);

    // Handle future dates gracefully
    if (diff.isNegative) {
      return _builtins.inTheFuture;
    }

    final builtins = _builtins;

    // < 1 min → "just now"
    if (diff.inSeconds < 60) {
      final key = t('just_now');
      return key == 'just_now' ? builtins.justNow : key;
    }

    // < 60 min
    if (diff.inMinutes < 60) {
      final key = tp('minutes_ago_one', 'minutes_ago_other', diff.inMinutes);
      return (key == 'minutes_ago_one' || key == 'minutes_ago_other')
          ? builtins.minutes(diff.inMinutes)
          : key;
    }

    // < 24 h
    if (diff.inHours < 24) {
      final key = tp('hours_ago_one', 'hours_ago_other', diff.inHours);
      return (key == 'hours_ago_one' || key == 'hours_ago_other')
          ? builtins.hours(diff.inHours)
          : key;
    }

    // < 7 days
    if (diff.inDays < 7) {
      final key = tp('days_ago_one', 'days_ago_other', diff.inDays);
      return (key == 'days_ago_one' || key == 'days_ago_other')
          ? builtins.days(diff.inDays)
          : key;
    }

    // >= 7 days → absolute date
    return formatDate(past);
  }

  /// Returns the builtins for the current language (with fallback to FR).
  _RelativeTimeBuiltins get _builtins =>
      _relativeTimeBuiltins[languageCode] ?? _relativeTimeBuiltins['fr']!;

  // ── Number formatting ──────────────────────────────────────────────────────

  /// Formats [value] with locale-aware thousands / decimal separators.
  ///
  /// [decimalDigits] forces the number of fractional digits.
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

  /// Formats [value] as a compact number (e.g. `12k`, `1.2M`).
  String formatCompact(num value) {
    try {
      return _cache.compactFormat(intlLocale).format(value);
    } catch (e) {
      debugPrint('[I18nService] ❌ formatCompact failed: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return value.toString();
    }
  }

  /// Formats [value] as a currency amount.
  ///
  /// [symbol] defaults to the language's default currency (e.g. EUR for FR,
  /// CDF for LN/KG). Pass explicitly for cross-border use cases.
  ///
  /// ```dart
  /// svc.formatCurrency(1500)                          // "1 500 €" (FR)
  /// svc.formatCurrency(1500, symbol: 'USD')           // "1 500 $"
  /// svc.formatCurrency(1500.5, decimals: 2)           // "1 500,50 €"
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

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Validates that [date] is not too far in the past/future.
  bool _isValidDate(DateTime date) {
    // Reject absurd dates (before 1900 or after 2200)
    final year = date.year;
    if (year < 1900 || year > 2200) return false;
    return true;
  }
}

// ---------------------------------------------------------------------------
// Convenience extension
// ---------------------------------------------------------------------------

extension I18nServiceX on BuildContext {
  /// Returns an [I18nService] for the current build context.
  I18nService get i18n => I18nService.of(this);
}

// ---------------------------------------------------------------------------
// RTL-aware Directionality wrapper
// ---------------------------------------------------------------------------

/// Wraps [child] in a [Directionality] widget whose direction is derived from
/// the active locale. Use this at screen/page level when RTL support matters.
///
/// ```dart
/// return LocaleDirectionality(child: Scaffold(...));
/// ```
class LocaleDirectionality extends StatelessWidget {
  final Widget child;
  const LocaleDirectionality({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Directionality(
      textDirection: loc.textDirection,
      child: child,
    );
  }
}

/// Provides the list of supported language configs for the language picker.
class SupportedLanguages {
  SupportedLanguages._();

  static const List<Map<String, String>> all = [
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'pt', 'name': 'Português', 'flag': '🇵🇹'},
    {'code': 'ln', 'name': 'Lingála', 'flag': '🇨🇩'},
    {'code': 'kg', 'name': 'Kikongo', 'flag': '🇨🇩'},
    {'code': 'sw', 'name': 'Kiswahili', 'flag': '🇹🇿'},
  ];

  static Map<String, String>? forCode(String code) {
    for (final lang in all) {
      if (lang['code'] == code) return lang;
    }
    return null;
  }

  /// Returns true if [code] is a supported language.
  static bool isSupported(String code) =>
      all.any((l) => l['code'] == code);
}
