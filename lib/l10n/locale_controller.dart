import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const _key = 'app_locale_code';

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
    Locale('zh'),
    Locale('pt'),
    Locale('ln'),
    Locale('kg'),
    Locale('sw'),
  ];

  Locale _locale = const Locale('fr');
  Locale get locale => _locale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);

    if (code != null &&
        supportedLocales.any((l) => l.languageCode == code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.any((l) => l.languageCode == locale.languageCode)) {
      return;
    }

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  /// Revenir à la langue du téléphone
  Future<void> setSystem() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);

    _locale = const Locale('fr'); // ou utilise PlatformDispatcher.locale
    notifyListeners();
  }
}
