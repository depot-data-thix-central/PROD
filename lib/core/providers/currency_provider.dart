import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/currency_registry.dart';

/// ============================================================================
/// CurrencyProvider
/// ============================================================================
///
/// Gère la devise sélectionnée par l'utilisateur avec persistance locale.
///
/// Features :
/// - Persistance via SharedPreferences
/// - Détection automatique au premier lancement
/// - Taux de change (à brancher sur une API plus tard)
/// - Conversion entre devises
/// ============================================================================
class CurrencyState {
  final ThixCurrency currency;
  final bool isLoading;
  final Map<String, double> exchangeRates;

  const CurrencyState({
    required this.currency,
    this.isLoading = false,
    this.exchangeRates = const {},
  });

  CurrencyState copyWith({
    ThixCurrency? currency,
    bool? isLoading,
    Map<String, double>? exchangeRates,
  }) {
    return CurrencyState(
      currency: currency ?? this.currency,
      isLoading: isLoading ?? this.isLoading,
      exchangeRates: exchangeRates ?? this.exchangeRates,
    );
  }

  /// Convertit un montant depuis une devise source vers la devise actuelle.
  num convert(num amount, {required String fromCurrency}) {
    if (fromCurrency == currency.code) return amount;

    final rate = exchangeRates['${fromCurrency}_${currency.code}'];
    if (rate == null) return amount; // Pas de taux disponible

    return amount * rate;
  }
}

class CurrencyNotifier extends Notifier<CurrencyState> {
  static const _storageKey = 'thix_selected_currency';

  @override
  CurrencyState build() {
    _loadPersisted();
    return CurrencyState(currency: CurrencyRegistry.byCode('XOF'));
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_storageKey);
      if (code != null) {
        state = state.copyWith(currency: CurrencyRegistry.byCode(code));
      }
    } catch (_) {}
  }

  /// Change la devise sélectionnée et persiste le choix.
  Future<void> setCurrency(String code) async {
    final cur = CurrencyRegistry.byCode(code);
    state = state.copyWith(currency: cur);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, code);
    } catch (_) {}
  }

  /// Change vers une devise complète.
  Future<void> setCurrencyObj(ThixCurrency cur) => setCurrency(cur.code);

  /// Charge les taux de change (à connecter à une API type exchangerate.host).
  Future<void> refreshExchangeRates() async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: brancher sur API de taux de change
      // Pour l'instant, quelques taux hardcodés à titre d'exemple
      final mockRates = {
        'USD_XOF': 605.0,
        'USD_XAF': 605.0,
        'USD_CDF': 2850.0,
        'USD_NGN': 1580.0,
        'USD_GHS': 15.5,
        'USD_KES': 130.0,
        'USD_ZAR': 18.5,
        'USD_MAD': 9.9,
        'USD_EGP': 48.5,
        'EUR_XOF': 655.957,
        'EUR_XAF': 655.957,
        'EUR_USD': 1.09,
      };
      state = state.copyWith(
        exchangeRates: mockRates,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final currencyProvider =
    NotifierProvider<CurrencyNotifier, CurrencyState>(CurrencyNotifier.new);
