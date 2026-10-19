// lib/presentation/thix_market/core/currency_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'african_currencies.dart';

/// Service de taux de change — cache 6h, fallback sur taux par défaut
class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // Taux par rapport à USD (base de référence)
  // Mis à jour automatiquement depuis l'API, fallback sur ces valeurs si offline
  Map<String, double> _rates = {
    'USD': 1.0,
    'CDF': 2800.0,    // ~2800 FC = 1 USD (oct 2026)
    'XOF': 610.0,
    'XAF': 610.0,
    'EUR': 0.92,
    'NGN': 1550.0,
    'KES': 129.0,
    'ZAR': 17.5,
    'GHS': 15.8,
    'TZS': 2650.0,
    'UGX': 3700.0,
    'RWF': 1320.0,
    'ETB': 118.0,
    'MAD': 9.9,
    'EGP': 48.5,
    'DZD': 135.0,
    'TND': 3.1,
    'BWP': 13.6,
    'ZMW': 26.8,
    'MZN': 64.0,
    'AOA': 920.0,
    'BIF': 2870.0,
    'DJF': 178.0,
    'ERN': 15.0,
    'GMD': 71.0,
    'GNF': 8680.0,
    'KMF': 460.0,
    'LSL': 17.5,
    'LRD': 190.0,
    'LYD': 4.8,
    'MGA': 4580.0,
    'MWK': 1740.0,
    'MUR': 46.0,
    'NAD': 17.5,
    'SCR': 13.5,
    'SLL': 22500.0,
    'SOS': 571.0,
    'SSP': 1850.0,
    'SDG': 601.0,
    'SZL': 17.5,
    'CVE': 102.0,
    'MRU': 40.0,
    'ZWL': 26.0,
  };

  DateTime _lastUpdate = DateTime(2000);
  static const _cacheKey = 'thix_currency_rates_v1';
  static const _updateKey = 'thix_currency_rates_updated';
  static const Duration _cacheTtl = Duration(hours: 6);

  /// Taux actuel pour une devise donnée (vs USD)
  double rate(String code) => _rates[code.toUpperCase()] ?? 1.0;

  /// Convertit un montant d'une devise vers une autre
  double convert(double amount, {required String from, required String to}) {
    if (from == to) return amount;
    final fromRate = rate(from);
    final toRate = rate(to);
    if (fromRate == 0) return 0;
    // amount en USD = amount / fromRate, puis en devise cible = * toRate
    return (amount / fromRate) * toRate;
  }

  /// Formatte un prix avec symbole (ex: "2 500 FC", "$ 12.99")
  String formatPrice(double amount, {required String currencyCode, String lang = 'fr'}) {
    final cur = AfricanCurrencies.byCode(currencyCode);
    if (cur == null) return '$amount';
    final separator = lang == 'en' ? ',' : ' ';
    final decimal = lang == 'en' ? '.' : ',';
    
    // Si la devise n'a pas de centimes (FC, CFA, etc.) : entier
    final noDecimals = ['CDF', 'XOF', 'XAF', 'KMF', 'BIF', 'DJF', 'GNF', 'RWF', 'UGX', 'VND'];
    
    String formatted;
    if (noDecimals.contains(cur.code.toUpperCase())) {
      formatted = amount.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => separator,
      );
    } else {
      formatted = amount.toStringAsFixed(2).replaceAll('.', decimal);
      // Séparateur de milliers
      final parts = formatted.split(decimal);
      parts[0] = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => separator,
      );
      formatted = parts.join(decimal);
    }
    
    return '${cur.symbol} $formatted';
  }

  /// Charge les taux depuis le cache ou l'API
  Future<void> refreshRates({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdatedStr = prefs.getString(_updateKey);
    if (lastUpdatedStr != null) {
      _lastUpdate = DateTime.tryParse(lastUpdatedStr) ?? DateTime(2000);
    }

    if (!force && DateTime.now().difference(_lastUpdate) < _cacheTtl) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          _rates = Map<String, double>.from(json.decode(cached));
          debugPrint('[Currency] ✓ Loaded from cache');
          return;
        } catch (_) {}
      }
    }

    try {
      // ✅ API gratuite : https://open.er-api.com/v6/latest/USD
      final response = await _dio.get(
        'https://open.er-api.com/v6/latest/USD',
      );
      
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'];
        if (rates is Map) {
          final newRates = <String, double>{'USD': 1.0};
          for (final entry in rates.entries) {
            if (entry.key is String && entry.value is num) {
              newRates[entry.key] = (entry.value as num).toDouble();
            }
          }
          _rates = newRates;
          _lastUpdate = DateTime.now();
          
          await prefs.setString(_cacheKey, json.encode(_rates));
          await prefs.setString(_updateKey, _lastUpdate.toIso8601String());
          debugPrint('[Currency] ✓ Rates updated from API');
        }
      }
    } catch (e) {
      debugPrint('[Currency] ⚠️ API failed, using cached/default rates: $e');
    }
  }

  DateTime get lastUpdated => _lastUpdate;
}
