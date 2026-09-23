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
    required String paymentMethod, // mpesa | airtel | orange_money | afrimoney | card | thix_money
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

    // 1. Enregistrer le paiement local
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

    // 3. TOUS les autres paiements → SerdiPay (Mobile Money + Carte)
    try {
      final serdipay = SerdiPayService(_client);
      final telecom = _toSerdiPayTelecom(paymentMethod);

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

  /// Poll statut (page d'attente Mobile Money)
  Future<String?> getPaymentStatus(String paymentId) async {
    final row = await _client
        .from('certification_payments')
        .select('status')
        .eq('id', paymentId)
        .maybeSingle();
    return row?['status']?.toString();
  }

  /// Convertit la méthode de paiement UI vers le code telecom SerdiPay
  SerdipayTelecom _toSerdiPayTelecom(String method) {
    switch (method.toLowerCase()) {
      case 'airtel':
      case 'airtel_money':
        return SerdipayTelecom.airtel; // AM
      case 'orange_money':
      case 'orange':
        return SerdipayTelecom.orange; // OM
      case 'afrimoney':
      case 'afrimomo':
        return SerdipayTelecom.afrimoney; // AF
      case 'card':
      case 'carte':
        // Carte bancaire → on utilise MP comme fallback (SerdiPay gérera)
        return SerdipayTelecom.mpesa;
      case 'mpesa':
      default:
        return SerdipayTelecom.mpesa; // MP
    }
  }
}
