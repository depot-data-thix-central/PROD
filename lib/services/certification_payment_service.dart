// lib/services/certification_payment_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/services/bcc_exchange_rate_service.dart';

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

  /// Standard + Premium → auto après paiement
  /// Entreprise → pending admin
  /// Officiel → invitation (non payable)
  bool _isAutoApprove(CertificationTier tier) =>
      tier == CertificationTier.standard || tier == CertificationTier.premium;

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
      final ok = await _payWithThixMoney(uid, amountCdf);
      final now = DateTime.now().toUtc().toIso8601String();

      await _client.from('certification_payments').update({
        'status': ok ? 'paid' : 'failed',
        'paid_at': ok ? now : null,
        'updated_at': now,
      }).eq('id', paymentId);

      if (ok) await _onPaidSuccess(uid, tier, paymentId, requestId);

      return CertificationPaymentResult(
        success: ok,
        status: ok ? 'paid' : 'failed',
        paymentId: paymentId,
        error: ok ? null : 'Solde THIX Money insuffisant',
      );
    }

    // 3. Mobile Money / Carte → Edge Function WonyaSoft dédiée
    try {
      final response = await _client.functions.invoke(
        'process-certification-payment',
        body: {
          'payment_id': paymentId,
          'user_id': uid,
          'tier': tier.value,
          'amount': amountCdf,
          'amount_usd': amountUsd,
          'currency': 'CDF',
          'payment_method': _normalizeMethod(paymentMethod),
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

        await _client.from('certification_payments').update({
          'status': 'awaiting_payment',
          'gateway_ref': ref,
          'gateway_payload': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', paymentId);

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

      await _client.from('certification_payments').update({
        'status': 'failed',
        'gateway_payload': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', paymentId);

      return CertificationPaymentResult(
        success: false,
        status: 'failed',
        paymentId: paymentId,
        error: err,
      );
    } catch (e) {
      debugPrint('❌ CertificationPaymentService: $e');
      await _client.from('certification_payments').update({
        'status': 'failed',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', paymentId);

      return CertificationPaymentResult(
        success: false,
        status: 'failed',
        paymentId: paymentId,
        error: e.toString(),
      );
    }
  }

  String _normalizeMethod(String method) {
    switch (method) {
      case 'orange_money':
      case 'africell':
      case 'mtn':
      case 'mobile_money':
        return 'mobile_money';
      case 'card':
      case 'carte':
        return 'card';
      default:
        return method; // mpesa, airtel, etc.
    }
  }

  Future<bool> _payWithThixMoney(String userId, double amountCdf) async {
    try {
      final result = await _client.rpc('deduct_wallet_balance', params: {
        'user_id': userId,
        'amount': amountCdf,
      });
      return result == true;
    } catch (e) {
      debugPrint('THIX Money cert: $e');
      return false;
    }
  }

  /// Après paiement réussi (THIX Money immédiat, ou rappel local si besoin)
  /// - Standard + Premium → tier actif tout de suite
  /// - Entreprise → status pending (admin)
  Future<void> _onPaidSuccess(
    String userId,
    CertificationTier tier,
    String paymentId,
    String? requestId,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final auto = _isAutoApprove(tier);

    if (requestId != null) {
      await _client.from('certification_requests').update({
        'status': auto ? 'approved' : 'pending',
        if (auto) 'reviewed_at': now,
        'updated_at': now,
      }).eq('id', requestId);
    }

    if (auto) {
      await _client.from('profiles').update({
        'certification_tier': tier.value,
        'certification_status': 'approved',
        'certified_at': now,
      }).eq('id', userId);
      debugPrint('✅ Auto-approved ${tier.value} for $userId');
    } else {
      // Entreprise : payé, en attente d'approbation admin
      await _client.from('profiles').update({
        'certification_status': 'pending',
      }).eq('id', userId);
      debugPrint('⏳ Enterprise pending admin for $userId');
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
}
