// lib/services/bcc_exchange_rate_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ExchangeRateQuote {
  final double usdToCdf; // 1 USD = X CDF
  final DateTime asOf;
  final String source; // 'BCC' | 'fallback' | 'cache'
  final bool isOfficialBcc;

  const ExchangeRateQuote({
    required this.usdToCdf,
    required this.asOf,
    required this.source,
    required this.isOfficialBcc,
  });

  int cdfForUsd(double usd) => (usd * usdToCdf).round();

  String formatCdf(double usd) {
    final n = cdfForUsd(usd);
    final s = n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '$s CDF';
  }
}

class BccExchangeRateService {
  final SupabaseClient _client;
  BccExchangeRateService(this._client);

  static const _fallbackRate = 2265.0; // dernier ordre de grandeur BCC connu

  /// Taux du jour (cache DB → API → fallback)
  Future<ExchangeRateQuote> getUsdToCdf() async {
    // 1) Cache Supabase (rempli par Edge Function / admin)
    try {
      final row = await _client
          .from('exchange_rates')
          .select('usd_to_cdf, as_of, source')
          .eq('pair', 'USD_CDF')
          .order('as_of', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row != null) {
        final rate = (row['usd_to_cdf'] as num).toDouble();
        final asOf = DateTime.tryParse(row['as_of'].toString()) ?? DateTime.now();
        final src = row['source']?.toString() ?? 'cache';
        // Accepter le cache s'il a moins de 36h
        if (DateTime.now().difference(asOf).inHours < 36) {
          return ExchangeRateQuote(
            usdToCdf: rate,
            asOf: asOf,
            source: src,
            isOfficialBcc: src.toUpperCase().contains('BCC'),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ exchange_rates cache: $e');
    }

    // 2) Fallback API publique (indicatif, pas officiel BCC)
    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = body['rates'] as Map<String, dynamic>?;
        final cdf = (rates?['CDF'] as num?)?.toDouble();
        if (cdf != null && cdf > 0) {
          final quote = ExchangeRateQuote(
            usdToCdf: cdf,
            asOf: DateTime.now().toUtc(),
            source: 'open.er-api (indicatif)',
            isOfficialBcc: false,
          );
          // Optionnel : écrire en cache
          unawaited(_saveCache(quote));
          return quote;
        }
      }
    } catch (e) {
      debugPrint('⚠️ FX fallback: $e');
    }

    // 3) Dernier recours
    return ExchangeRateQuote(
      usdToCdf: _fallbackRate,
      asOf: DateTime.now().toUtc(),
      source: 'fallback local',
      isOfficialBcc: false,
    );
  }

  Future<void> _saveCache(ExchangeRateQuote q) async {
    try {
      await _client.from('exchange_rates').upsert({
        'pair': 'USD_CDF',
        'usd_to_cdf': q.usdToCdf,
        'as_of': q.asOf.toIso8601String(),
        'source': q.source,
      }, onConflict: 'pair');
    } catch (_) {}
  }
}

void unawaited(Future<void> f) {}
