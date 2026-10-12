import 'package:flutter/material.dart';

/// Système de localisation THIX — "All in One"
/// Supporte les substitutions de paramètres : {0}, {1} et la pluralisation
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // 1. Liste des codes des 7 langues supportées
  static const List<String> supportedLanguages = [
    'fr', 'en', 'es', 'pt', 'sw', 'ar', 'zh',
  ];

  // 2. Noms d'affichage des langues
  static const Map<String, String> languageNames = {
    'fr': 'Français', 
    'en': 'English', 
    'es': 'Español', 
    'pt': 'Português',
    'sw': 'Kiswahili', 
    'ar': 'العربية', 
    'zh': '中文',    
  };

  // 3. Liaison avec les dictionnaires (Maps)
  static final Map<String, Map<String, String>> _localizedValues = {
    'fr': _fr,
    'en': _en,
    'es': _es,
    'pt': _pt,
    'sw': _sw,
    'ar': _ar,
    'zh': _zh,
  };
  

  /// Traduction standard avec paramètres {0}, {1}...
  String t(String key, {List<String>? args}) {
    final map = _localizedValues[locale.languageCode] ?? _fr;
    var value = map[key] ?? _fr[key] ?? key;
    if (args != null) {
      for (var i = 0; i < args.length; i++) {
        value = value.replaceAll('{$i}', args[i]);
      }
    }
    return value;
  }
  /// Traduction avec arguments nommés (Map)
  String tn(String key, Map<String, dynamic> args) {
    final map = _localizedValues[locale.languageCode] ?? _fr;
    var value = map[key] ?? _fr[key] ?? key;
    args.forEach((k, v) {
      value = value.replaceAll('{$k}', v.toString());
    });
    return value;
  }

  /// Pluralisation simple : _zero, _one, _many
  String plural(String key, int count, {List<String>? args}) {
    final suffix = count == 0 ? '_zero' : (count == 1 ? '_one' : '_many');
    final fullKey = '$key$suffix';
    final map = _localizedValues[locale.languageCode] ?? _fr;
    var value = map[fullKey] ?? map[key] ?? _fr[fullKey] ?? _fr[key] ?? key;
    value = value.replaceAll('{count}', count.toString());
    if (args != null) {
      for (var i = 0; i < args.length; i++) {
        value = value.replaceAll('{$i}', args[i]);
      }
    }
    return value;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLanguages.contains(locale.languageCode);
  
  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ════════════════════════════════════════════════════════════════════════════
// 🇫🇷 FRANÇAIS
// ════════════════════════════════════════════════════════════════════════════
const Map<String, String> _fr = {
  
