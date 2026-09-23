// lib/services/certification_payment_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/serdipay_transaction.dart';
import 'package:thix_id/services/bcc_exchange_rate_service.dart';
import 'package:thix_id/services/serdipay_service.dart';

class CertificationPaymentResult {
  final bool success;
  final String status; // paid | awaiting_payment | failed
  final bool needsWaiting;
  final String? paymentId;
  final String? error;
  final Map<String, dynamic>? data;

  const CertificationPaymentResult({
    required this.success,
    required this.status,
    this.needsWaiting = false,
    this.paymentId,
    this.error,
    this.data,
  });
}

class CertificationPaymentService {
  final SupabaseClient _client;
  final BccExchangeRateService _fx;

  CertificationPaymentService(this._client)
      : _fx = BccExchangeRateService(_client);

  String? get _uid => _client.auth.currentUser?.id;

  /// Démarre un paiement pour un tier (Standard / Premium / Entreprise)
  Future<CertificationPaymentResult> initiate({
    required CertificationTier tier,
    required String paymentMethod, // mpesa | airtel | orange_money | card | thix_money
    String? phoneNumber,
    String? requestId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const CertificationPaymentResult(
        success: false,
        status: 'failed',
        error: 'Non authentifié',
      );
    }

    if (tier.isInviteOnly || tier.priceUsd == null) {
      return const CertificationPaymentResult(
        success: false,
        status: 'failed',
        error: 'Ce niveau n\'est pas payable (invitation uniquement)',
      );
    }

    final quote = await _fx.getUsdToCdf();
    final amountUsd = tier.priceUsd!;
    final amountCdf = quote.cdfForUsd(amountUsd).toDouble();

    // 1. Enregistrer le paiement local — c'est CETTE ligne (amount_cdf,
    // tier) qui fait foi côté serveur pour toute la suite du flux, jamais
    // une valeur renvoyée plus tard par le client.
    final insert = await _client
        .from('certification_payments')
        .insert({
          'user_id': uid,
          'request_id': requestId,
          'tier': tier.value,
          'amount_usd': amountUsd,
          'amount_cdf': amountCdf,
          'fx_rate': quote.usdToCdf,
          'fx_source': quote.source,
          'currency': 'CDF',
          'payment_method': paymentMethod,
          'phone_number': phoneNumber,
          'status': 'pending',
        })
        .select('id')
        .single();

    final paymentId = insert['id']?.toString();
    if (paymentId == null) {
      return const CertificationPaymentResult(
        success: false,
        status: 'failed',
        error: 'Impossible de créer le paiement',
      );
    }

    // 2. THIX Money (interne, pas de gateway)
    if (paymentMethod == 'thix_money') {
      try {
        final result = await _client.rpc(
          'rpc_pay_certification_with_wallet',
          params: {'p_payment_id': paymentId},
        ) as Map<String, dynamic>;

        final ok = result['success'] == true;
        return CertificationPaymentResult(
          success: ok,
          status: ok ? 'paid' : 'failed',
          paymentId: paymentId,
          error: ok ? null : (result['error']?.toString() ?? 'Paiement échoué'),
        );
      } catch (e) {
        debugPrint('THIX Money cert RPC error: $e');
        return CertificationPaymentResult(
          success: false,
          status: 'failed',
          paymentId: paymentId,
          error: 'Solde THIX Money insuffisant ou erreur de paiement',
        );
      }
    }

    // 3. Mobile Money via SerdiPay (M-Pesa, Airtel, Orange, Afrimoney)
    if (_isSerdipayMethod(paymentMethod)) {
      try {
        final serdipay = SerdiPayService(_client);
        final telecom = SerdipayTelecom.fromPaymentMethod(paymentMethod);

        final result = await serdipay.initiate(
          type: SerdipayPaymentType.certification,
          referenceId: paymentId,
          amount: amountCdf,
          currency: 'CDF',
          telecom: telecom,
          phoneNumber: phoneNumber ?? '',
        );

        if (result.success) {
          return CertificationPaymentResult(
            success: true,
            status: result.status,
            needsWaiting: result.needsWaiting,
            paymentId: result.transactionId ?? paymentId,
            data: result.data,
          );
        } else {
          return CertificationPaymentResult(
            success: false,
            status: 'failed',
            paymentId: paymentId,
            error: result.error ?? 'Erreur SerdiPay',
          );
        }
      } catch (e) {
        debugPrint('❌ SerdiPay certification error: $e');
        return CertificationPaymentResult(
          success: false,
          status: 'failed',
          paymentId: paymentId,
          error: 'Erreur SerdiPay: $e',
        );
      }
    }

    // 4. Carte bancaire → Edge Function WonyaSoft dédiée.
    // ✅ On n'envoie plus 'amount'/'amount_usd'/'tier' au corps de la
    // requête : l'Edge Function les relit désormais depuis la ligne
    // certification_payments en base (voir process-certification-payment),
    // ce qui empêche toute tentative de payer un montant modifié.
    try {
      final response = await _client.functions.invoke(
        'process-certification-payment',
        body: {
          'payment_id': paymentId,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        },
      );

      debugPrint('cert payment response: ${response.status} ${response.data}');

      final data = response.data;
      final ok = response.status == 200 &&
          data != null &&
          (data is Map) &&
          data['success'] == true;

      if (ok) {
        final ref = data['transaction_id']?.toString() ??
            data['ref_transa']?.toString();

        return CertificationPaymentResult(
          success: true,
          status: 'awaiting_payment',
          needsWaiting: true,
          paymentId: paymentId,
          data: Map<String, dynamic>.from(data as Map),
        );
      }

      final err = (data is Map ? data['error']?.toString() : null) ??
          'Échec initiation paiement certification';

      return CertificationPaymentResult(
        success: false,
        status: 'failed',
        paymentId: paymentId,
        error: err,
      );
    } catch (e) {
      debugPrint('❌ CertificationPaymentService (WonyaSoft): $e');
      return CertificationPaymentResult(
        success: false,
        status: 'failed',
        paymentId: paymentId,
        error: e.toString(),
      );
    }
  }

  /// Poll statut (page d'attente Mobile Money)
  Future<String?> getPaymentStatus(String paymentId) async {
    final row = await _client
        .from('certification_payments')
        .select('status')
        .eq('id', paymentId)
        .maybeSingle();
    return row?['status']?.toString();
  }

  /// Vérifie si la méthode de paiement est supportée par SerdiPay (Mobile Money RDC)
  bool _isSerdipayMethod(String method) {
    const serdiMethods = {
      'mpesa',
      'airtel',
      'airtel_money',
      'orange_money',
      'orange',
      'afrimoney',
      'afrimomo',
      'mobile_money',
    };
    return serdiMethods.contains(method.toLowerCase());
  }
}
