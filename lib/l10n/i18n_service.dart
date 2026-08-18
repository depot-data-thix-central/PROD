// lib/l10n/i18n_service.dart
//
// Enhanced i18n service providing date/time and number formatting helpers
// on top of [AppLocalizations].
//
// ─── How to add a new language ───────────────────────────────────────────────
// 1. Add the new [Locale] to [LocaleController.supportedLocales].
// 2. Add the language code with all translation keys to [AppLocalizations._strings].
// 3. Add the locale label to [AppLocalizations.localeLabel].
// 4. If the language is RTL, update [AppLocalizations.isRtl].
// 5. Add a flag + name entry to [LanguageSheet] and the JSON reference file.
// 6. Add the matching [intl] date/number symbol data if needed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';

/// A high-level i18n service that wraps [AppLocalizations] and adds
/// locale-aware date/time and number formatting.
///
/// Obtain via [I18nService.of] (context-based) or instantiate directly.
///
/// ```dart
/// final svc = I18nService.of(context);
///
/// svc.t('home_premium_member')               // Simple translation
/// svc.t('profile_followers', {'count': '5'}) // Parameterized
/// svc.tp('events_seats', 'events_seats_plural', 3) // Plural
/// svc.formatDate(DateTime.now())             // Locale-aware date
/// svc.formatNumber(12345.6)                  // Locale-aware number
/// ```
class I18nService {
  final AppLocalizations _loc;

  const I18nService(this._loc);

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
  String t(String key, [Map<String, String>? params]) =>
      _loc.t(key, params: params);

  /// Plural-form helper. Returns the singular or plural translation depending
  /// on [count] and automatically substitutes `{count}`.
  ///
  /// ```dart
  /// svc.tp('events_seats', 'events_seats_plural', 3) // "3 places disponibles"
  /// ```
  String tp(String singularKey, String pluralKey, int count,
      [Map<String, String>? extra]) =>
      _loc.tp(singularKey, pluralKey, count, params: extra);

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

  // ── Date / Time formatting ─────────────────────────────────────────────────

  /// Returns a locale-aware formatted date string.
  ///
  /// Uses abbreviated month names by default (e.g. `"2 août 2025"`).
  String formatDate(DateTime date, {String? pattern}) {
    final fmt = DateFormat(pattern ?? _datePattern, _intlLocale);
    return fmt.format(date);
  }

  /// Returns a locale-aware formatted time string (24-hour by default).
  String formatTime(DateTime time, {bool use24h = true}) {
    final pattern = use24h ? 'HH:mm' : 'hh:mm a';
    return DateFormat(pattern, _intlLocale).format(time);
  }

  /// Returns a locale-aware date + time string.
  String formatDateTime(DateTime dt, {String? pattern}) {
    final fmt = DateFormat(pattern ?? _dateTimePattern, _intlLocale);
    return fmt.format(dt);
  }

  /// Returns a relative time label (e.g. "il y a 5 minutes").
  /// Falls back to a formatted date when no relative-time keys are defined.
  String relativeTime(DateTime past) {
    final diff = DateTime.now().difference(past);
    // Use translation keys if defined, otherwise fall back to built-in values.
    if (diff.inSeconds < 60) {
      final key = t('just_now');
      return key == 'just_now' ? _builtinJustNow : key;
    }
    if (diff.inMinutes < 60) {
      final key = tp('minutes_ago_one', 'minutes_ago_other', diff.inMinutes);
      return (key == 'minutes_ago_one' || key == 'minutes_ago_other')
          ? _builtinMinutesAgo(diff.inMinutes)
          : key;
    }
    if (diff.inHours < 24) {
      final key = tp('hours_ago_one', 'hours_ago_other', diff.inHours);
      return (key == 'hours_ago_one' || key == 'hours_ago_other')
          ? _builtinHoursAgo(diff.inHours)
          : key;
    }
    if (diff.inDays < 7) {
      final key = tp('days_ago_one', 'days_ago_other', diff.inDays);
      return (key == 'days_ago_one' || key == 'days_ago_other')
          ? _builtinDaysAgo(diff.inDays)
          : key;
    }
    return formatDate(past);
  }

  // Built-in relative-time strings used when translation keys are absent.
  String get _builtinJustNow {
    switch (languageCode) {
      case 'en': return 'Just now';
      case 'ar': return 'الآن';
      case 'pt': return 'Agora';
      case 'sw': return 'Sasa hivi';
      default:   return 'À l\'instant';
    }
  }

  String _builtinMinutesAgo(int n) {
    switch (languageCode) {
      case 'en': return 'il y a $n min${n > 1 ? 's' : ''}'; // reuse fr pattern
      case 'ar': return 'منذ $n دقيقة';
      case 'pt': return 'há $n min';
      case 'sw': return 'dakika $n zilizopita';
      default:   return 'il y a $n min${n > 1 ? 's' : ''}';
    }
  }

  String _builtinHoursAgo(int n) {
    switch (languageCode) {
      case 'en': return '$n hour${n > 1 ? 's' : ''} ago';
      case 'ar': return 'منذ $n ساعة';
      case 'pt': return 'há $n hora${n > 1 ? 's' : ''}';
      case 'sw': return 'saa $n zilizopita';
      default:   return 'il y a $n heure${n > 1 ? 's' : ''}';
    }
  }

  String _builtinDaysAgo(int n) {
    switch (languageCode) {
      case 'en': return '$n day${n > 1 ? 's' : ''} ago';
      case 'ar': return 'منذ $n يوم';
      case 'pt': return 'há $n dia${n > 1 ? 's' : ''}';
      case 'sw': return 'siku $n zilizopita';
      default:   return 'il y a $n jour${n > 1 ? 's' : ''}';
    }
  }

  // ── Number formatting ──────────────────────────────────────────────────────

  /// Formats [value] with locale-aware thousands / decimal separators.
  String formatNumber(num value, {int? decimalDigits}) {
    final fmt = NumberFormat.decimalPattern(_intlLocale);
    if (decimalDigits != null) {
      fmt.minimumFractionDigits = decimalDigits;
      fmt.maximumFractionDigits = decimalDigits;
    }
    return fmt.format(value);
  }

  /// Formats [value] as a compact number (e.g. `12k`, `1.2M`).
  String formatCompact(num value) =>
      NumberFormat.compact(locale: _intlLocale).format(value);

  /// Formats [value] as a currency amount.
  /// [symbol] defaults to `'XAF'` (CFA franc, regional default).
  String formatCurrency(num value, {String symbol = 'XAF', int decimals = 0}) {
    final fmt = NumberFormat.currency(
      locale: _intlLocale,
      symbol: symbol,
      decimalDigits: decimals,
    );
    return fmt.format(value);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Maps language codes to intl locale strings.
  String get _intlLocale {
    switch (languageCode) {
      case 'fr':
        return 'fr_FR';
      case 'en':
        return 'en_US';
      case 'ar':
        return 'ar';
      case 'zh':
        return 'zh_CN';
      case 'pt':
        return 'pt_BR';
      case 'sw':
        return 'sw';
      case 'ln':
      case 'kg':
        // Lingála and Kikongo: fall back to French formatting conventions
        return 'fr_FR';
      default:
        return 'fr_FR';
    }
  }

  String get _datePattern {
    switch (languageCode) {
      case 'zh':
        return 'yyyy年M月d日';
      case 'ar':
        return 'd MMMM yyyy';
      default:
        return 'd MMM yyyy';
    }
  }

  String get _dateTimePattern {
    switch (languageCode) {
      case 'zh':
        return 'yyyy年M月d日 HH:mm';
      case 'ar':
        return 'd MMMM yyyy HH:mm';
      default:
        return 'd MMM yyyy HH:mm';
    }
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

  static Map<String, String>? forCode(String code) =>
      all.where((l) => l['code'] == code).firstOrNull;
}
