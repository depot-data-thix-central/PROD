// lib/presentation/thix_market/providers/currency_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/african_currencies.dart';
import '../core/currency_service.dart';

/// Provider pour la devise sélectionnée par l'utilisateur
class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super(AfricanCurrencies.defaultCode) {
    _load();
  }

  static const _prefKey = 'thix_selected_currency';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && AfricanCurrencies.byCode(saved) != null) {
      state = saved;
    }
  }

  Future<void> select(String code) async {
    if (AfricanCurrencies.byCode(code) == null) return;
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
    debugPrint('[Currency] 🔄 Selected: $code');
  }
}

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier();
});

/// Provider pour les taux de change (rafraîchis au démarrage)
final exchangeRatesProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  await CurrencyService.instance.refreshRates();
  // Expose tous les taux via un simple Map
  final rates = <String, double>{};
  for (final c in AfricanCurrencies.all) {
    rates[c.code] = CurrencyService.instance.rate(c.code);
  }
  return rates;
});

/// Provider helper : détecte la devise du pays de l'utilisateur
Future<String> detectUserCurrency() async {
  // Par défaut : CDF (RDC), à améliorer avec geolocation si besoin
  return AfricanCurrencies.defaultCode;
}
