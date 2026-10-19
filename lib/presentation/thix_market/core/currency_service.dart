// lib/presentation/thix_market/core/currency_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'african_currencies.dart';

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Map<String, double> _rates = {
    'USD': 1.0,
    'CDF': 2800.0,
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
  
  static const String _cacheKey = 'thix_currency_rates_v1';
  static const String _updateKey = 'thix_currency_rates_updated';
  static const Duration _cacheTtl = Duration(hours: 6);

  double rate(String code) => _rates[code.toUpperCase()] ?? 1.0;

  double convert(double amount, {required String from, required String to}) {
    if (from == to) return amount;
    final fromRate = rate(from);
    final toRate = rate(to);
    if (fromRate == 0) return 0;
    return (amount / fromRate) * toRate;
  }

  String formatPrice(double amount, {required String currencyCode, String lang = 'fr'}) {
    final cur = AfricanCurrencies.byCode(currencyCode);
    if (cur == null) return '$amount';
    
    final separator = lang == 'en' ? ',' : ' ';
    final decimal = lang == 'en' ? '.' : ',';
    
    final noDecimals = ['CDF', 'XOF', 'XAF', 'KMF', 'BIF', 'DJF', 'GNF', 'RWF', 'UGX', 'VND'];
    
    String formatted;
    if (noDecimals.contains(cur.code.toUpperCase())) {
      formatted = amount.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => separator,
      );
    } else {
      formatted = amount.toStringAsFixed(2).replaceAll('.', decimal);
      final parts = formatted.split(decimal);
      parts[0] = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => separator,
      );
      formatted = parts.join(decimal);
    }
    
    return '${cur.symbol} $formatted';
  }

  /// 🔑 MÉTHODE PRINCIPALE : essaie Supabase, puis API externe, puis cache
  Future<void> refreshRates({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Vérifier le cache local
    final lastUpdatedStr = prefs.getString(_updateKey);
    if (lastUpdatedStr != null) {
      _lastUpdate = DateTime.tryParse(lastUpdatedStr) ?? DateTime(2000);
    }

    // Si le cache est récent (< 6h), on l'utilise
    if (!force && DateTime.now().difference(_lastUpdate) < _cacheTtl) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          _rates = Map<String, double>.from(json.decode(cached));
          debugPrint('[Currency] ✅ Chargé depuis le cache local');
          return;
        } catch (_) {}
      }
    }

    // ─── STRATÉGIE 1 : Essayer Supabase (rapide, fiable) ───
    try {
      debugPrint('[Currency] 🔄 Tentative Supabase...');
      
      final response = await Supabase.instance.client
          .rpc('get_latest_exchange_rates')
          .timeout(const Duration(seconds: 5));

      if (response != null && response is Map) {
        final newRates = <String, double>{'USD': 1.0};
        
        for (final entry in response.entries) {
          if (entry.key is String && entry.value is num) {
            newRates[entry.key] = (entry.value as num).toDouble();
          }
        }
        
        _rates = newRates;
        _lastUpdate = DateTime.now();
        
        await prefs.setString(_cacheKey, json.encode(_rates));
        await prefs.setString(_updateKey, _lastUpdate.toIso8601String());
        
        debugPrint('[Currency] ✅ Taux chargés depuis Supabase');
        return;
      }
    } catch (e) {
      debugPrint('[Currency] ⚠️ Supabase échoué: $e');
    }

    // ─── STRATÉGIE 2 : Fallback API externe ───
    try {
      debugPrint('[Currency] 🌍 Fallback API externe...');
      
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
          
          debugPrint('[Currency] ✅ Taux chargés depuis API externe (fallback)');
          return;
        }
      }
    } catch (e) {
      debugPrint('[Currency] ⚠️ API externe échouée: $e');
    }

    // ─── STRATÉGIE 3 : Utiliser les taux par défaut ───
    debugPrint('[Currency] ⚠️ Utilisation des taux par défaut');
    // _rates contient déjà les valeurs par défaut
  }

  DateTime get lastUpdated => _lastUpdate;
}
