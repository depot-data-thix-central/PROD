// lib/l10n/app_localizations.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Importez toutes vos futures langues ici
import 'app_localizations_fr.dart';
import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_zh.dart';

abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // === DÉCLARATION DE TOUTES VOS CLÉS (SANS LE TEXTE) ===
  // Vous listez juste ce qui existe, chaque fichier de langue donnera la vraie traduction.
  
  // COMMUN & UI
  String get common_back;
  String get common_close;
  String get common_cancel;
  String get common_confirm;
  String get common_error;
  String get common_success;
  // ... (Copiez/collez ici toutes vos variables sous la forme "String get nom_de_la_cle;")

  // Pour les fonctions avec paramètres :
  String common_items(int count);
  String edu_coming_soon(String category);
  // ...
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  // On liste ici les 6 codes de langues que vous supportez
  @override
  bool isSupported(Locale locale) {
    return ['fr', 'en', 'pt', 'sw', 'ar', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    // Le "Cerveau" : Si le téléphone est en anglais, on charge la classe English, etc.
    switch (locale.languageCode) {
      case 'en':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsEn());
      case 'pt':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsPt());
      case 'sw':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsSw());
      case 'ar':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsAr());
      case 'zh':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsZh());
      case 'fr':
      default:
        // Le français est la langue par défaut si on ne trouve pas
        return SynchronousFuture<AppLocalizations>(AppLocalizationsFr());
    }
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
